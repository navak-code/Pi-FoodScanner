#!/usr/bin/env python3
"""
Smart Guardian System - Raspberry Pi Edge Daemon
Manages camera capture, structured Ollama vision JSON inference, 
mDNS service registration, and a thread-safe GPIO physical LED state machine.
"""

import os
import sys
import time
import json
import socket
import logging
import threading
from typing import Dict, List, Any
import requests

# Fallback pattern for GPIO mapping to ensure hardware portability
try:
    import RPi.GPIO as GPIO
except ImportError:
    # Emulated GPIO layer for development environment testing
    class MockGPIO:
        BCM = 11
        OUT = 12
        LOW = 0
        HIGH = 1
        def setmode(self, mode): pass
        def setup(self, pin, mode): pass
        def output(self, pin, val): pass
        def cleanup(self): pass
    GPIO = MockGPIO()

# Fallback pattern for Camera capturing
try:
    import subprocess
    HAS_LIBCAMERA = True
except Exception:
    HAS_LIBCAMERA = False

from flask import Flask, jsonify, request
from zeroconf import IPVersion, Info, Zeroconf

# Configure logging
logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(threadName)s: %(message)s")
logger = logging.getLogger("GuardianPi")

# GPIO Pin Mapping (BCM numbering)
RED_PIN = 17
YELLOW_PIN = 27
GREEN_PIN = 22

# System global variables
FLASK_PORT = 5000
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL_NAME = "llava"  # Default vision model supported locally on Pi 5

# Global Threading State Machine
class LEDController:
    def __init__(self):
        self.lock = threading.Lock()
        self.current_state = "GREEN"  # GREEN, YELLOW, RED, ERROR, ENV_ALERT
        self.running = True
        self.thread = threading.Thread(target=self._state_worker, daemon=True)
        
        # Initialize physical GPIO setup safely
        GPIO.setmode(GPIO.BCM)
        for pin in [RED_PIN, YELLOW_PIN, GREEN_PIN]:
            GPIO.setup(pin, GPIO.OUT)
            GPIO.output(pin, GPIO.LOW)
        
        self.thread.start()

    def set_state(self, state: str):
        with self.lock:
            if state in ["GREEN", "YELLOW", "RED", "ERROR", "ENV_ALERT"]:
                logger.info(f"Transitioning LED State to: {state}")
                self.current_state = state
            else:
                logger.error(f"Attempted invalid state transition to: {state}")

    def _state_worker(self):
        flash_toggle = False
        while self.running:
            with self.lock:
                state = self.current_state

            # Handle states sequentially
            if state == "GREEN":
                GPIO.output(GREEN_PIN, GPIO.HIGH)
                GPIO.output(YELLOW_PIN, GPIO.LOW)
                GPIO.output(RED_PIN, GPIO.LOW)
                time.sleep(0.2)
            elif state == "YELLOW":
                GPIO.output(GREEN_PIN, GPIO.LOW)
                GPIO.output(YELLOW_PIN, GPIO.HIGH)
                GPIO.output(RED_PIN, GPIO.LOW)
                time.sleep(0.2)
            elif state == "RED":
                GPIO.output(GREEN_PIN, GPIO.LOW)
                GPIO.output(YELLOW_PIN, GPIO.LOW)
                GPIO.output(RED_PIN, GPIO.HIGH)
                time.sleep(0.2)
            elif state == "ERROR":
                # Flash RED & GREEN Alternately/Asynchronously
                flash_toggle = not flash_toggle
                GPIO.output(YELLOW_PIN, GPIO.LOW)
                GPIO.output(RED_PIN, GPIO.HIGH if flash_toggle else GPIO.LOW)
                GPIO.output(GREEN_PIN, GPIO.LOW if flash_toggle else GPIO.HIGH)
                time.sleep(0.3)
            elif state == "ENV_ALERT":
                # Flash YELLOW Asynchronously
                flash_toggle = not flash_toggle
                GPIO.output(RED_PIN, GPIO.LOW)
                GPIO.output(GREEN_PIN, GPIO.LOW)
                GPIO.output(YELLOW_PIN, GPIO.HIGH if flash_toggle else GPIO.LOW)
                time.sleep(0.4)

    def cleanup(self):
        self.running = False
        if self.thread.is_alive():
            self.thread.join(timeout=1.0)
        GPIO.output(RED_PIN, GPIO.LOW)
        GPIO.output(YELLOW_PIN, GPIO.LOW)
        GPIO.output(GREEN_PIN, GPIO.LOW)
        GPIO.cleanup()

# Instantiate the global system lock and thread-safe driver
led_system = LEDController()

app = Flask(__name__)

def capture_image_local(target_path: str = "/tmp/capture.jpg") -> bool:
    """Attempts to capture a frame from the RPi Camera Module."""
    logger.info("Triggering hardware camera capture module...")
    if HAS_LIBCAMERA:
        try:
            # Using modern RPi 5 native libcamera stack
            cmd = ["libcamera-still", "-o", target_path, "-t", "1000", "--width", "640", "--height", "480", "-n"]
            subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return True
        except Exception as e:
            logger.error(f"libcamera-still capture failed: {e}")
            
    # Universal fallback capture path using standard fswebcam
    try:
        cmd = ["fswebcam", "-r", "640x480", "--no-banner", target_path]
        subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return True
    except Exception as e:
        logger.error(f"Fallback fswebcam capture failed: {e}")
        return False

def analyze_with_ollama(image_path: str) -> List[str]:
    """Sends image to local Ollama instance utilizing strict structural JSON instructions."""
    import base64
    if not os.path.exists(image_path):
        logger.error("Image target path does not exist for analysis.")
        return []

    try:
        with open(image_path, "rb") as f:
            image_b64 = base64.b64encode(f.read()).decode("utf-8")

        payload = {
            "model": MODEL_NAME,
            "prompt": "Analyze the ingredients or items visible in this food/environment. You must respond with a JSON array listing the components or raw ingredients under key 'ingredients'. Provide nothing else but valid JSON. Example: {\"ingredients\": [\"peanut\", \"dairy\"]}",
            "images": [image_b64],
            "stream": False,
            "format": "json" # Forces Ollama schema validation outputs
        }

        logger.info(f"Querying Ollama vision agent locally ({MODEL_NAME})...")
        response = requests.post(OLLAMA_URL, json=payload, timeout=45)
        if response.status_code == 200:
            result_text = response.json().get("response", "{}")
            logger.info(f"Ollama Raw JSON Response: {result_text}")
            parsed = json.loads(result_text)
            return parsed.get("ingredients", [])
        else:
            logger.error(f"Ollama returned non-200 code: {response.status_code}")
            return []
    except Exception as e:
        logger.error(f"Failed pipeline processing in Ollama client: {e}")
        return []

@app.route("/capture", methods=["POST"])
def capture_and_process():
    """Trigger API: Captures image on Pi and returns structured analysis back to app."""
    temp_path = "/tmp/current_scan.jpg"
    if not capture_image_local(temp_path):
        led_system.set_state("ERROR")
        return jsonify({"error": "Failed to capture image from camera hardware"}), 500

    ingredients = analyze_with_ollama(temp_path)
    if not ingredients:
        # Fallback to general error state if inference yields empty structures
        led_system.set_state("ERROR")
        return jsonify({"ingredients": [], "warning": "Failed parsing or no ingredients found"}), 200

    return jsonify({
        "ingredients": ingredients,
        "timestamp": time.time()
    }), 200

@app.route("/set-state", methods=["POST"])
def set_state():
    """App-driven API to assign current system status updates to physical GPIO flags."""
    data = request.json or {}
    state = data.get("state", "GREEN")
    led_system.set_state(state)
    return jsonify({"status": "acknowledged", "state": state}), 200

def get_local_ip() -> str:
    """Attempts resolution of system IP to map local dynamic routing."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        # Does not have to be reachable to extract self host IP mapping
        s.connect(('8.8.8.8', 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = '127.0.0.1'
    finally:
        s.close()
    return ip

def start_mdns_advertiser(local_ip: str):
    """Binds dynamic mDNS profile matching 'raspberrypi.local' domain resolving."""
    desc = {'path': '/capture'}
    info = Info(
        "_http._tcp.local.",
        "DietaryGuardian._http._tcp.local.",
        addresses=[socket.inet_aton(local_ip)],
        port=FLASK_PORT,
        properties=desc,
        server="raspberrypi.local."
    )
    zeroconf = Zeroconf(ip_version=IPVersion.V4Only)
    logger.info(f"Advertising dynamic system service via mDNS as raspberrypi.local ({local_ip})")
    zeroconf.register_service(info)
    return zeroconf, info

if __name__ == "__main__":
    local_ip = get_local_ip()
    zeroconf, service_info = start_mdns_advertiser(local_ip)
    
    try:
        logger.info(f"Launching Guardian Pi Flask daemon on {local_ip}:{FLASK_PORT}")
        app.run(host="0.0.0.0", port=FLASK_PORT, debug=False, use_reloader=False)
    except KeyboardInterrupt:
        pass
    finally:
        logger.info("Cleaning up network and hardware resources...")
        zeroconf.unregister_service(service_info)
        zeroconf.close()
        led_system.cleanup()
        sys.exit(0)
