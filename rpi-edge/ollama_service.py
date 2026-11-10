"""Ollama vision client and explicit first-time Ollama setup routine."""

import argparse
import base64
import json
import logging
import os
import re
import shutil
import subprocess
import time
from pathlib import Path
from typing import List

import requests

from config import (
    OLLAMA_API_BASE,
    OLLAMA_MODEL,
    OLLAMA_MODEL_CONFIG_PATH,
    OLLAMA_TIMEOUT_SECONDS,
)

logger = logging.getLogger("OllamaService")

_VISION_MODELS = ("moondream", "llava", "llama3.2-vision")

# Common food catalog for reliable entity extraction from descriptive text
COMMON_FOODS = {
    "apple", "red apple", "green apple", "banana", "orange", "pear", "peach",
    "plum", "grape", "grapes", "strawberry", "strawberries", "blueberry",
    "blueberries", "raspberry", "lemon", "lime", "watermelon", "melon",
    "tomato", "tomatoes", "potato", "potatoes", "onion", "garlic", "carrot",
    "carrots", "broccoli", "spinach", "lettuce", "cucumber", "pepper", "peppers",
    "bell pepper", "corn", "mushroom", "mushrooms", "avocado", "celery",
    "bread", "toast", "bagel", "croissant", "pasta", "rice", "noodle", "noodles",
    "cereal", "oats", "oatmeal", "flour", "tortilla", "crackers",
    "cheese", "cheddar", "mozzarella", "parmesan", "milk", "butter", "cream",
    "yogurt", "egg", "eggs", "tofu",
    "peanut", "peanuts", "peanut butter", "almond", "almonds", "walnut",
    "cashew", "pecan", "sesame", "chia", "sunflower seed",
    "chicken", "beef", "pork", "bacon", "sausage", "turkey", "fish", "salmon",
    "tuna", "shrimp", "meat", "steak",
    "sugar", "honey", "chocolate", "cookie", "cake", "candy", "ice cream",
    "coffee", "tea", "juice", "soup", "salad", "sandwich", "pizza", "burger"
}


class OllamaVisionService:
    def __init__(self, api_base: str = OLLAMA_API_BASE, model: str = None):
        self.api_base = api_base.rstrip("/")
        self.endpoint = f"{self.api_base}/api/generate"

        if model:
            self.model = model
        elif OLLAMA_MODEL_CONFIG_PATH.exists():
            self.model = OLLAMA_MODEL_CONFIG_PATH.read_text(encoding="utf-8").strip()
        else:
            self.model = OLLAMA_MODEL or "moondream"

        logger.info("OllamaVisionService initialized using model: %s", self.model)

    def _extract_items(self, raw_text: str) -> List[str]:
        """Extract recognized food items from Moondream's descriptive text."""
        clean_text = raw_text.strip().lower()
        if not clean_text:
            return []

        found_items = []

        # 1. Match against known food entities
        # Check multi-word items first (e.g. 'peanut butter' before 'peanut')
        sorted_foods = sorted(COMMON_FOODS, key=len, reverse=True)
        for food in sorted_foods:
            # Word-boundary matching
            pattern = rf"\b{re.escape(food)}\b"
            if re.search(pattern, clean_text):
                # Avoid adding redundant sub-words if a larger term is already matched
                if not any(food in existing for existing in found_items):
                    found_items.append(food)

        # 2. If matched items found, return them
        if found_items:
            return found_items

        # 3. Fallback: Parse commas/bullets if it returned a list
        tokens = re.split(r"[,;\n]+", clean_text)
        candidates = []
        ignore_words = {"in the image", "the image", "there is", "there are", "picture", "photo"}
        for token in tokens:
            t = re.sub(r"^[-*•0-9.)\s]+", "", token).strip()
            t = re.sub(r"^(a|an|the|some)\s+", "", t).strip()
            if t and len(t) < 30 and not any(ign in t for ign in ignore_words):
                if t not in candidates:
                    candidates.append(t)

        return candidates if candidates else ["food item"]

    def analyze_image(self, image_path: str) -> List[str]:
        """Return normalized ingredient names from a captured image."""
        try:
            with open(image_path, "rb") as image_file:
                image_bytes = base64.b64encode(image_file.read()).decode("ascii")
        except OSError:
            logger.exception("Failed to read image at %s", image_path)
            return []

        # Natural conversational prompt that Moondream excels at
        payload = {
            "model": self.model,
            "prompt": "What food or food related sub-ingredients do you see in this picture? Name each item in list format with commas inbetween each new item.",
            "images": [image_bytes],
            "stream": False,
            "options": {"temperature": 0.2},
        }

        try:
            response = requests.post(
                self.endpoint,
                json=payload,
                timeout=OLLAMA_TIMEOUT_SECONDS,
            )
            response.raise_for_status()
            ollama_result = response.json()

            if not isinstance(ollama_result, dict):
                logger.error("Ollama returned an invalid response object.")
                return []

            raw_response = ollama_result.get("response", "").strip()
            logger.info("Ollama RAW OUTPUT:\n%s", raw_response)

            items = self._extract_items(raw_response)
            logger.info("Parsed ingredients: %s", items)
            return items

        except requests.exceptions.RequestException:
            logger.exception("Ollama inference request failed.")
            return []
        except Exception:
            logger.exception("Unexpected error during inference processing.")
            return []


def _run_privileged(command: list[str]) -> None:
    if os.geteuid() == 0:
        full_command = command
    else:
        sudo = shutil.which("sudo")
        if not sudo:
            raise RuntimeError("sudo is required to manage the Ollama system service.")
        full_command = [sudo, *command]
    subprocess.run(full_command, check=True, text=True, timeout=120)


def _wait_for_ollama(api_base: str, timeout_seconds: int = 60) -> None:
    deadline = time.monotonic() + timeout_seconds
    while time.monotonic() < deadline:
        try:
            response = requests.get(f"{api_base.rstrip('/')}/api/tags", timeout=2)
            if response.ok:
                logger.info("Ollama service is responding at %s", api_base)
                return
        except requests.exceptions.RequestException:
            pass
        time.sleep(2)
    raise RuntimeError(
        f"Ollama service did not become available at {api_base} "
        f"within {timeout_seconds} seconds."
    )


def setup_ollama(
    api_base: str = OLLAMA_API_BASE,
    model_config_path: Path = OLLAMA_MODEL_CONFIG_PATH,
) -> str:
    """Install Ollama, enable its background service, and pull a vision model."""
    logger.info("Installing/Updating Ollama using the official installer.")
    try:
        subprocess.run(
            [
                "bash",
                "-o",
                "pipefail",
                "-c",
                "curl -fsSL https://ollama.com/install.sh | sh",
            ],
            check=True,
            timeout=900,
        )
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise RuntimeError("The Ollama installer failed.") from error

    ollama_bin = shutil.which("ollama")
    if ollama_bin is None:
        raise RuntimeError("Ollama installation completed, but 'ollama' was not found.")

    try:
        _run_privileged(["systemctl", "enable", "--now", "ollama"])
    except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired) as error:
        raise RuntimeError("Unable to enable and start the Ollama service.") from error

    _wait_for_ollama(api_base)

    for model in _VISION_MODELS:
        logger.info("Pulling vision model %s.", model)
        try:
            subprocess.run(
                [ollama_bin, "pull", model],
                check=True,
                timeout=3600,
            )
        except (OSError, subprocess.CalledProcessError, subprocess.TimeoutExpired):
            logger.exception("Unable to pull vision model %s.", model)
            continue

        model_config_path.parent.mkdir(parents=True, exist_ok=True)
        model_config_path.write_text(f"{model}\n", encoding="utf-8")
        logger.info("Ollama setup complete with model %s.", model)
        return model

    raise RuntimeError("Could not pull any supported vision model.")


def main() -> None:
    parser = argparse.ArgumentParser(description="Configure local Ollama vision inference.")
    parser.add_argument(
        "--setup",
        action="store_true",
        help="Install Ollama, start its service, and pull a supported vision model.",
    )
    args = parser.parse_args()
    if not args.setup:
        parser.error("pass --setup to install and configure Ollama")

    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")
    setup_ollama()


if __name__ == "__main__":
    main()
