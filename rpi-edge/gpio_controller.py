"""Thread-safe, background-thread controller for the status LEDs."""

import logging
import threading
from typing import Literal

from config import PIN_GREEN_LED, PIN_RED_LED, PIN_YELLOW_LED

logger = logging.getLogger("GPIOController")

StateLiteral = Literal["GREEN", "YELLOW", "RED", "ERROR", "ENV_ALERT", "OFF"]
_PINS = (PIN_RED_LED, PIN_YELLOW_LED, PIN_GREEN_LED)

try:
    import lgpio
except ImportError:
    lgpio = None


class ThreadSafeGPIOController:
    """Updates LEDs asynchronously; state changes never wait for blink delays."""

    def __init__(self):
        self._lock = threading.Lock()
        self._wake_event = threading.Event()
        self._state: StateLiteral = "OFF"
        self._is_running = True
        self._chip = None

        if lgpio is None:
            logger.warning("lgpio is unavailable; LEDs will run in mock mode.")
        else:
            try:
                self._chip = lgpio.gpiochip_open(0)
                for pin in _PINS:
                    lgpio.gpio_claim_output(self._chip, pin, 0)
            except Exception:
                if self._chip is not None:
                    try:
                        lgpio.gpiochip_close(self._chip)
                    except Exception:
                        logger.exception("Unable to close partially initialized GPIO chip.")
                    self._chip = None
                logger.exception("Unable to initialize lgpio; LEDs will run in mock mode.")

        self._worker_thread = threading.Thread(
            target=self._run_state_loop,
            name="gpio-state-machine",
            daemon=True,
        )
        self._worker_thread.start()

    def set_state(self, new_state: StateLiteral) -> None:
        if new_state not in ("GREEN", "YELLOW", "RED", "ERROR", "ENV_ALERT", "OFF"):
            raise ValueError(f"Unsupported LED state: {new_state}")
        with self._lock:
            if not self._is_running:
                return
            if new_state != self._state:
                logger.info("GPIO transition: %s -> %s", self._state, new_state)
                self._state = new_state
                self._wake_event.set()

    def get_state(self) -> StateLiteral:
        with self._lock:
            return self._state

    def shutdown(self) -> None:
        with self._lock:
            if not self._is_running:
                return
            self._is_running = False
            self._state = "OFF"
            self._wake_event.set()

        self._worker_thread.join(timeout=2)
        if self._worker_thread.is_alive():
            logger.error("LED worker did not stop; leaving the GPIO chip open.")
            return

        self._write_outputs((False, False, False))
        if self._chip is not None:
            lgpio.gpiochip_close(self._chip)
            self._chip = None

    def _write_outputs(self, outputs: tuple[bool, bool, bool]) -> None:
        if self._chip is None:
            return
        try:
            for pin, enabled in zip(_PINS, outputs):
                lgpio.gpio_write(self._chip, pin, int(enabled))
        except Exception:
            logger.exception("Failed to update indicator LEDs.")

    def _run_state_loop(self) -> None:
        blink_toggle = False
        last_state = None

        while True:
            with self._lock:
                if not self._is_running:
                    break
                state = self._state
                self._wake_event.clear()

            if state != last_state:
                blink_toggle = False
                last_state = state

            if state == "GREEN":
                self._write_outputs((False, False, True))
                delay = None
            elif state == "YELLOW":
                self._write_outputs((False, True, False))
                delay = None
            elif state == "RED":
                self._write_outputs((True, False, False))
                delay = None
            elif state == "ERROR":
                blink_toggle = not blink_toggle
                self._write_outputs((blink_toggle, False, not blink_toggle))
                delay = 0.3
            elif state == "ENV_ALERT":
                blink_toggle = not blink_toggle
                self._write_outputs((False, blink_toggle, False))
                delay = 0.4
            else:
                self._write_outputs((False, False, False))
                delay = None

            self._wake_event.wait(delay)
