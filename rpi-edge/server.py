#!/usr/bin/env python3
"""
Production Flask server for Guardian Raspberry Pi backend.
Exposes endpoints for camera capture, state transitions, and health checks.
"""

import sys
import signal
import logging
import threading
from flask import Flask, request, jsonify

from config import SERVER_HOST, SERVER_PORT, TEMP_IMAGE_PATH
from gpio_controller import ThreadSafeGPIOController
from camera_service import CameraService
from ollama_service import OllamaVisionService
from mdns_advertiser import MDNSServiceManager

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] (%(threadName)s) %(message)s"
)
logger = logging.getLogger("GuardianServer")

app = Flask(__name__)

# Initialize hardware controllers
gpio_controller = ThreadSafeGPIOController()
camera_service = CameraService()
vision_service = OllamaVisionService()
mdns_manager = MDNSServiceManager()
scan_lock = threading.Lock()


@app.route("/api/v1/health", methods=["GET"])
def health_check():
    return jsonify({
        "status": "healthy",
        "gpio_state": gpio_controller.get_state()
    }), 200


@app.route("/api/v1/capture-and-analyze", methods=["POST"])
def capture_and_analyze():
    """Captures a photo via hardware camera, runs Ollama vision, and returns ingredients."""
    logger.info("Received capture-and-analyze request")

    # The image path is shared, so serialize capture through inference as one job.
    with scan_lock:
        success = camera_service.capture_frame(TEMP_IMAGE_PATH)
        if not success:
            gpio_controller.set_state("ERROR")
            return jsonify({
                "error": "Failed to capture image from camera hardware",
                "ingredients": []
            }), 500

        ingredients = vision_service.analyze_image(TEMP_IMAGE_PATH)

    if not ingredients:
        gpio_controller.set_state("ERROR")
        return jsonify({
            "warning": "No ingredients recognized or inference failed",
            "ingredients": []
        }), 200

    return jsonify({
        "ingredients": ingredients,
        "count": len(ingredients)
    }), 200


@app.route("/api/v1/gpio/state", methods=["POST"])
def update_gpio_state():
    """Updates physical LED state machine based on client trigger evaluation."""
    payload = request.get_json(force=True, silent=True) or {}
    new_state = payload.get("state")
    
    if new_state not in ["GREEN", "YELLOW", "RED", "ERROR", "ENV_ALERT", "OFF"]:
        return jsonify({"error": f"Invalid state: {new_state}"}), 400

    gpio_controller.set_state(new_state)
    return jsonify({
        "status": "success",
        "current_state": gpio_controller.get_state()
    }), 200


def handle_shutdown(signum, frame):
    logger.info("Stopping Guardian Edge Server...")
    try:
        mdns_manager.stop()
    finally:
        gpio_controller.shutdown()
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGINT, handle_shutdown)
    signal.signal(signal.SIGTERM, handle_shutdown)

    # Start mDNS broadcaster
    mdns_manager.start()
    
    logger.info(f"Starting Guardian server on {SERVER_HOST}:{SERVER_PORT}")
    app.run(host=SERVER_HOST, port=SERVER_PORT, threaded=True)
