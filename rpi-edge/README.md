# Raspberry Pi edge service

This service runs the camera, Ollama vision inference, and status LEDs on the Pi.
It targets Raspberry Pi OS Bookworm on Raspberry Pi 5 and uses `rpicam-still`
(or `libcamera-still`) for CSI cameras and `fswebcam` as a USB-camera fallback.

## Initial setup

Run setup as the same Linux account that will run the daemon so its selected
Ollama model is saved in that account's `~/.config/guardian-edge/ollama-model`.
The setup command runs the official Ollama installer, enables and starts
`ollama.service`, waits for its local API to respond, and pulls
`llama3.2-vision`. If that pull fails, it tries `llava`.

```sh
cd rpi-edge
python3 -m pip install -r requirements.txt
python3 ollama_service.py --setup
```

The installer and service-management steps need network access and permission
to install software and manage system services (typically through `sudo`).
Camera utilities and the Python GPIO driver may also be installed using the OS
packages appropriate to the Pi:

```sh
sudo apt install rpicam-apps fswebcam python3-lgpio
```

Connect the red, yellow, and green LEDs to BCM GPIO pins 17, 27, and 22
respectively, with suitable current-limiting resistors. Override these defaults
with `GUARDIAN_PIN_RED_LED`, `GUARDIAN_PIN_YELLOW_LED`, and
`GUARDIAN_PIN_GREEN_LED` if the wiring differs.

## Run

```sh
python3 server.py
```

For continuous operation, install `guardian.service` after updating its
`User`, `WorkingDirectory`, and `ExecStart` values to match the deployment.
The service uses systemd automatic restart behavior and starts after
`ollama.service`.

The camera and Ollama timeouts, image dimensions, listen address, port, model,
and API URL can be overridden with `GUARDIAN_CAMERA_TIMEOUT_SECONDS`,
`GUARDIAN_CAMERA_WIDTH`, `GUARDIAN_CAMERA_HEIGHT`, `GUARDIAN_HOST`,
`GUARDIAN_PORT`, `OLLAMA_TIMEOUT_SECONDS`, `OLLAMA_MODEL`, and
`OLLAMA_API_BASE`.
