import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trigger_item.dart';
import 'storage_service.dart';
import 'pi_api_service.dart';

class AnalysisResult {
  final String source; // 'EDGE_PI', 'BARCODE_DATABASE', or 'CLOUD_FALLBACK'
  final List<String> ingredients;
  final List<String> crossContaminationRisks;
  final List<String> redFlags;
  final List<String> yellowFlags;
  final String overallRating;

  AnalysisResult({
    required this.source,
    required this.ingredients,
    required this.crossContaminationRisks,
    required this.redFlags,
    required this.yellowFlags,
    required this.overallRating,
  });
}

class HybridAnalyzerService {
  /// 1. UPC / Barcode Lookup via Open Food Facts (Zero-hallucination ground truth)
  static Future<AnalysisResult?> analyzeBarcode(String barcode) async {
    try {
      final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
      final response = await http.get(url, headers: {'User-Agent': 'GuardianDietaryApp/1.0'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 && data['product'] != null) {
          final product = data['product'];
          
          // Extract primary ingredients
          final List<String> ingredients = [];
          if (product['ingredients_text_en'] != null) {
            ingredients.addAll(
              product['ingredients_text_en']
                  .toString()
                  .toLowerCase()
                  .split(RegExp(r'[,;]'))
                  .map((e) => e.replaceAll(RegExp(r'[\(\)\[\]\.\*]'), '').trim())
                  .where((e) => e.isNotEmpty),
            );
          }

          // Extract traces and allergens
          final List<String> traces = [];
          if (product['traces_tags'] != null) {
            traces.addAll(
              List<String>.from(product['traces_tags'])
                  .map((e) => e.replaceAll('en:', '').replaceAll('-', ' ').trim()),
            );
          }

          return _evaluateMatches(
            source: 'BARCODE_DATABASE (${product['product_name'] ?? 'Product'})',
            ingredients: ingredients,
            contaminationRisks: traces,
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// 2. Primary Scan Router: Attempts Edge Pi first, then reports failure for failover
  static Future<AnalysisResult> runFullScanWithFailover() async {
    try {
      // Attempt Edge Pi analysis via mDNS
      final ingredients = await PiApiService.triggerCaptureAndInference();
      return _evaluateMatches(
        source: 'EDGE_PI',
        ingredients: ingredients,
        contaminationRisks: [],
      );
    } catch (edgeError) {
      // Return empty failure flag to let UI trigger on-device camera fallback
      rethrow;
    }
  }

  /// Cross-evaluates extracted ingredients against user's stored triggers
  static AnalysisResult _evaluateMatches({
    required String source,
    required List<String> ingredients,
    required List<String> contaminationRisks,
  }) {
    final activeTriggers = StorageService.getAllTriggers();
    final List<String> redHits = [];
    final List<String> yellowHits = [];

    void checkItem(String name, bool isTrace) {
      final sanitized = name.toLowerCase().trim();
      for (var trigger in activeTriggers) {
        if (sanitized.contains(trigger.name.toLowerCase()) ||
            trigger.name.toLowerCase().contains(sanitized)) {
          final label = isTrace ? '$name (Trace Contamination)' : name;
          if (trigger.severity == 2 && !redHits.contains(label)) {
            redHits.add(label);
          } else if (trigger.severity == 1 && !yellowHits.contains(label)) {
            yellowHits.add(label);
          }
        }
      }
    }

    for (var item in ingredients) {
      checkItem(item, false);
    }
    for (var trace in contaminationRisks) {
      checkItem(trace, true);
    }

    String rating = 'SAFE';
    if (redHits.isNotEmpty) {
      rating = 'HIGH RISK';
    } else if (yellowHits.isNotEmpty) {
      rating = 'CAUTION';
    }

    return AnalysisResult(
      source: source,
      ingredients: ingredients,
      crossContaminationRisks: contaminationRisks,
      redFlags: redHits,
      yellowFlags: yellowHits,
      overallRating: rating,
    );
  }
}
