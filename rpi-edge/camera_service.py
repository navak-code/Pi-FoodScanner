"""
Camera module capture service.
Supports Raspberry Pi 5 rpicam-still (libcamera) with OpenCV/V4L2 fallback.
"""

import os
import shutil
import logging
import subprocess
from config import TEMP_IMAGE_PATH, CAMERA_RESOLUTION_WIDTH, CAMERA_RESOLUTION_HEIGHT

logger = logging.getLogger("CameraService")


class CameraService:
    def __init__(self):
        # Determine available camera utility on Raspberry Pi OS Bookworm
        self.rpicam_bin = shutil.which("rpicam-still") or shutil.which("libcamera-still")

    def capture_frame(self, target_path: str = TEMP_IMAGE_PATH) -> bool:
        """Captures a still image from the attached camera module."""
        if os.path.exists(target_path):
            try:
                os.remove(target_path)
            except OSError:
                pass

        if self.rpicam_bin:
            cmd = [
                self.rpicam_bin,
                "-o", target_path,
                "-t", "800",
                "--width", str(CAMERA_RESOLUTION_WIDTH),
                "--height", str(CAMERA_RESOLUTION_HEIGHT),
                "-n",
                "--immediate"
            ]
            try:
                subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                if os.path.exists(target_path) and os.path.getsize(target_path) > 0:
                    return True
            except Exception as e:
                logger.error(f"Hardware camera capture failed: {e}")

        # Fallback to fswebcam / USB camera device
        fswebcam_bin = shutil.which("fswebcam")
        if fswebcam_bin:
            cmd = [
                fswebcam_bin,
                "-r", f"{CAMERA_RESOLUTION_WIDTH}x{CAMERA_RESOLUTION_HEIGHT}",
                "--no-banner",
                target_path
            ]
            try:
                subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                return os.path.exists(target_path) and os.path.getsize(target_path) > 0
            except Exception as e:
                logger.error(f"Fallback fswebcam capture failed: {e}")

        logger.critical("No functional camera capture backend detected.")
        return False
