"""Bounded still-image capture for Raspberry Pi and USB cameras."""

import os
import shutil
import logging
import subprocess
from config import (
    CAMERA_CAPTURE_TIMEOUT_SECONDS,
    CAMERA_RESOLUTION_HEIGHT,
    CAMERA_RESOLUTION_WIDTH,
    TEMP_IMAGE_PATH,
)

logger = logging.getLogger("CameraService")


class CameraService:
    def __init__(self):
        self.rpicam_bin = shutil.which("rpicam-still") or shutil.which("libcamera-still")
        self.fswebcam_bin = shutil.which("fswebcam")

    def capture_frame(self, target_path: str = TEMP_IMAGE_PATH) -> bool:
        """Capture an image with a CSI camera, falling back to fswebcam for USB."""
        try:
            os.makedirs(os.path.dirname(os.path.abspath(target_path)), exist_ok=True)
        except OSError:
            logger.exception("Unable to prepare image directory for %s", target_path)
            return False

        if self.rpicam_bin:
            if self._capture(self._rpicam_command(target_path), target_path, "rpicam"):
                return True

        if self.fswebcam_bin:
            if self._capture(self._fswebcam_command(target_path), target_path, "fswebcam"):
                return True

        logger.error("No camera capture backend produced a valid image.")
        return False

    def _rpicam_command(self, target_path: str) -> list[str]:
        return [
            self.rpicam_bin or "rpicam-still",
            "-o", target_path,
            "-t", "800",
            "--width", str(CAMERA_RESOLUTION_WIDTH),
            "--height", str(CAMERA_RESOLUTION_HEIGHT),
            "-n",
            "--immediate",
        ]

    def _fswebcam_command(self, target_path: str) -> list[str]:
        return [
            self.fswebcam_bin or "fswebcam",
            "-r", f"{CAMERA_RESOLUTION_WIDTH}x{CAMERA_RESOLUTION_HEIGHT}",
            "--no-banner",
            target_path,
        ]

    def _capture(self, command: list[str], target_path: str, backend: str) -> bool:
        try:
            os.remove(target_path)
        except FileNotFoundError:
            pass
        except OSError:
            logger.exception("Unable to remove previous image at %s", target_path)
            return False

        try:
            subprocess.run(
                command,
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                text=True,
                timeout=CAMERA_CAPTURE_TIMEOUT_SECONDS,
            )
            if os.path.isfile(target_path) and os.path.getsize(target_path) > 0:
                return True
            logger.error("%s completed without producing an image.", backend)
        except subprocess.TimeoutExpired:
            logger.error("%s capture timed out.", backend)
        except subprocess.CalledProcessError as error:
            logger.error(
                "%s capture failed: %s",
                backend,
                (error.stderr or "").strip() or error,
            )
        except OSError:
            logger.exception("Unable to run %s.", backend)

        try:
            os.remove(target_path)
        except FileNotFoundError:
            pass
        except OSError:
            logger.exception("Unable to remove failed image at %s", target_path)
        return False
