/// Illness configurations and pre-populated trigger libraries.
class IllnessPreset {
  final String title;
  final List<String> defaultTriggers;

  const IllnessPreset({required this.title, required this.defaultTriggers});

  static const List<IllnessPreset> catalog = [
    IllnessPreset(
      title: 'Mast Cell Activation Syndrome (MCAS)',
      defaultTriggers: [
        'Histamine', 'Fermented foods', 'Spinach', 'Tomato', 'Artificial dyes',
        'Sulfites', 'Preservatives', 'Shellfish', 'Leftover meats', 'Aged cheese',
        'Alcohol', 'Strawberries', 'Canned fish', 'Yeast'
      ],
    ),
    IllnessPreset(
      title: 'Celiac Disease',
      defaultTriggers: [
        'Wheat', 'Barley', 'Rye', 'Gluten', 'Spelt', 'Brewer\'s yeast',
        'Semolina', 'Malt', 'Farina', 'Durum', 'Graham flour'
      ],
    ),
    IllnessPreset(
      title: 'Histamine Intolerance',
      defaultTriggers: [
        'Avocado', 'Eggplant', 'Red wine', 'Vinegar', 'Mackerel', 'Sardines',
        'Smoked salmon', 'Salami', 'Sauerkraut', 'Kombucha'
      ],
    ),
    IllnessPreset(
      title: 'Irritable Bowel Syndrome (IBS - High FODMAP)',
      defaultTriggers: [
        'Garlic', 'Onion', 'High fructose corn syrup', 'Apples', 'Mushrooms',
        'Cauliflower', 'Beans', 'Lactose', 'Wheat', 'Honey'
      ],
    ),
    IllnessPreset(
      title: 'Eosinophilic Esophagitis (EoE - Top 6)',
      defaultTriggers: [
        'Milk', 'Eggs', 'Wheat', 'Soy', 'Peanuts', 'Tree nuts', 'Fish', 'Shellfish'
      ],
    ),
    IllnessPreset(
      title: 'Lactose & Dairy Intolerance',
      defaultTriggers: [
        'Milk', 'Heavy cream', 'Butter', 'Whey', 'Casein', 'Lactose',
        'Soft cheeses', 'Ice cream'
      ],
    ),
    IllnessPreset(
      title: 'Asthma & Airway Hypersensitivity',
      defaultTriggers: [
        'Sulfites', 'Sodium metabisulfite', 'Potassium bisulfite', 'MSG',
        'Aspirin/Salicylates', 'Tartrazine'
      ],
    ),
    IllnessPreset(
      title: 'Systemic Nickel Allergy Syndrome (SNAS)',
      defaultTriggers: [
        'Chocolate', 'Cocoa', 'Oats', 'Nuts', 'Legumes', 'Soybeans',
        'Canned foods', 'Whole wheat', 'Tea'
      ],
    ),
    IllnessPreset(
      title: 'Chronic Spontaneous Urticaria',
      defaultTriggers: [
        'Benzoates', 'BHA', 'BHT', 'Azo dyes', 'Salicylates', 'Nitrates'
      ],
    ),
    IllnessPreset(
      title: 'Systemic Mastocytosis',
      defaultTriggers: [
        'Alcohol', 'Spicy foods', 'Shellfish', 'Preservatives', 'NSAIDs',
        'Artificial flavorings', 'Caffeine'
      ],
    ),
    IllnessPreset(
      title: 'Custom Triggers',
      defaultTriggers: [],
    ),
  ];
}
