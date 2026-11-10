"""Configuration variables for the Guardian local edge scanner."""

import os
from pathlib import Path

# Server Gateway Settings
SERVER_HOST = "0.0.0.0"
SERVER_PORT = 5000

# mDNS Discovery Settings
MDNS_SERVICE_NAME = "raspberrypi"
MDNS_SERVICE_TYPE = "_http._tcp.local."
MDNS_HOSTNAME = "raspberrypi.local."

# File & Storage Paths
TEMP_IMAGE_PATH = "/tmp/guardian_capture.jpg"
OLLAMA_MODEL_CONFIG_PATH = Path("/home/navaspi/.config/guardian/ollama_model")

# Camera Service Settings
CAMERA_CAPTURE_TIMEOUT_SECONDS = 15
CAMERA_DEVICE_INDEX = 0
CAMERA_RESOLUTION_WIDTH = 1280
CAMERA_RESOLUTION_HEIGHT = 720

# Ollama Endpoint Configuration
OLLAMA_API_BASE = "http://127.0.0.1:11434"

# Increased timeout to 300 seconds to allow the model to load into memory
OLLAMA_TIMEOUT_SECONDS = 300

# Set the active model directly to moondream
OLLAMA_MODEL = "moondream"

# Physical Hardware LED Pins (BCM GPIO numbers)
PIN_RED_LED = 17
PIN_YELLOW_LED = 27
PIN_GREEN_LED = 22
