# Pi-FoodScanner

A pocket-sized smart food scanning and image analysis device powered by a Raspberry Pi 5, camera module, local Ollama LLM, Roboflow vision model, and the SunFounder AI Fusion HAT+.

## Features

* **Edge AI Vision:** Uses a Roboflow vision model for rapid food and object detection.
* **Local LLM Processing:** Integrates with Ollama running locally on the Raspberry Pi 5 for privacy-focused, offline reasoning and dietary insights.
* **Hardware Integration:** Built with the [SunFounder AI Fusion HAT+](https://github.com/) to streamline power and sensor management.
* **Cross-Platform Companion App:** Built with [FlutterFlow](https://github.com/) supporting mobile and desktop interfaces (`android`, `ios`, `linux`, `macos`, `windows`, `web`).

## Project Structure

* `rpi-edge/`: Edge device scripts and model configuration files.
* `lib/`: Flutter application source code.
* `app.py`: Main backend coordination script.
* `pubspec.yaml`: Flutter project dependencies.

## Getting Started

1. Clone the repository and configure your environment variables.
2. Set up the Python dependencies and local Ollama instance on your Raspberry Pi 5.
3. Run the backend service via `python app.py`.
