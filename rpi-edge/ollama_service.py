"""
Ollama vision client enforcing strict JSON output schemas.
Prevents natural language and markdown code blocks from corrupting inference results.
"""

import base64
import json
import logging
import requests
from typing import List, Dict, Any
from config import OLLAMA_API_BASE, OLLAMA_MODEL, OLLAMA_TIMEOUT_SECONDS

logger = logging.getLogger("OllamaService")

# Exact JSON schema enforced at the Ollama engine level
INGREDIENTS_JSON_SCHEMA: Dict[str, Any] = {
    "type": "object",
    "properties": {
        "ingredients": {
            "type": "array",
            "items": {"type": "string"},
            "description": "List of all raw ingredients, chemicals, preservatives, or food substances identified."
        }
    },
    "required": ["ingredients"]
}


class OllamaVisionService:
    def __init__(self, api_base: str = OLLAMA_API_BASE, model: str = OLLAMA_MODEL):
        self.endpoint = f"{api_base}/api/generate"
        self.model = model

    def analyze_image(self, image_path: str) -> List[str]:
        """Loads captured image, sends it to Ollama, and extracts the parsed ingredients."""
        try:
            with open(image_path, "rb") as img_file:
                image_bytes = base64.b64encode(img_file.read()).decode("utf-8")
        except Exception as e:
            logger.error(f"Failed to read image at {image_path}: {e}")
            return []

        payload = {
            "model": self.model,
            "prompt": (
                "You are an analytical laboratory system. Examine this image and list every "
                "food ingredient, chemical, or dietary component present. "
                "Respond ONLY with valid JSON following the schema."
            ),
            "images": [image_bytes],
            "stream": False,
            "format": INGREDIENTS_JSON_SCHEMA,
            "options": {
                "temperature": 0.1
            }
        }

        try:
            response = requests.post(self.endpoint, json=payload, timeout=OLLAMA_TIMEOUT_SECONDS)
            if response.status_code != 200:
                logger.error(f"Ollama returned HTTP {response.status_code}: {response.text}")
                return []

            raw_response = response.json().get("response", "{}")
            logger.info(f"Ollama raw JSON output: {raw_response}")
            
            parsed = json.loads(raw_response)
            items = parsed.get("ingredients", [])
            return [str(item).strip().lower() for item in items if str(item).strip()]

        except json.JSONDecodeError as jde:
            logger.error(f"JSON parsing error from Ollama response: {jde}")
            return []
        except requests.exceptions.RequestException as re:
            logger.error(f"Network error querying Ollama service: {re}")
            return []
