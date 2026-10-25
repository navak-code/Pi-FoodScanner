"""
Thread-safe GPIO State Machine.
Manages physical LEDs with mutex locks to support non-blocking asynchronous flashes.
"""

import time
import logging
import threading
from typing import Literal
from config import PIN_RED_LED, PIN_YELLOW_LED, PIN_GREEN_LED

logger = logging.getLogger("GPIOController")

StateLiteral = Literal["GREEN", "YELLOW", "RED", "ERROR", "ENV_ALERT", "OFF"]

# Platform-independent GPIO interface
try:
    import lgpio
    CHIP = lgpio.gpiochip_open(0)
    for pin in [PIN_RED_LED, PIN_YELLOW_LED, PIN_GREEN_LED]:
        lgpio.gpio_claim_output(CHIP, pin)
    GPIO_DRIVER = "lgpio"
except Exception:
    try:
        import RPi.GPIO as RPi_GPIO
        RPi_GPIO.setmode(RPi_GPIO.BCM)
        for pin in [PIN_RED_LED, PIN_YELLOW_LED, PIN_GREEN_LED]:
            RPi_GPIO.setup(pin, RPi_GPIO.OUT)
            RPi_GPIO.output(pin, RPi_GPIO.LOW)
        GPIO_DRIVER = "rpigpio"
    except Exception:
        GPIO_DRIVER = "mock"
        logger.warning("No native GPIO hardware found. Operating in MOCK mode.")


def _write_pin(pin: int, state: bool) -> None:
    if GPIO_DRIVER == "lgpio":
        lgpio.gpio_write(CHIP, pin, 1 if state else 0)
    elif GPIO_DRIVER == "rpigpio":
        RPi_GPIO.output(pin, RPi_GPIO.HIGH if state else RPi_GPIO.LOW)
    else:
        pass


class ThreadSafeGPIOController:
    """Controls physical indicator lights using a dedicated background worker."""

    def __init__(self):
        self._lock = threading.Lock()
        self._state: StateLiteral = "OFF"
        self._is_running = True
        self._worker_thread = threading.Thread(target=_run_state_loop, args=(self,), daemon=True)
        self._worker_thread.start()

    def set_state(self, new_state: StateLiteral) -> None:
        with self._lock:
            if new_state != self._state:
                logger.info(f"GPIO transition: {self._state} -> {new_state}")
                self._state = new_state

    def get_state(self) -> StateLiteral:
        with self._lock:
            return self._state

    def shutdown(self) -> None:
        self._is_running = False
        self.set_state("OFF")
        _write_pin(PIN_RED_LED, False)
        _write_pin(PIN_YELLOW_LED, False)
        _write_pin(PIN_GREEN_LED, False)
        if GPIO_DRIVER == "lgpio":
            lgpio.gpiochip_close(CHIP)
        elif GPIO_DRIVER == "rpigpio":
            RPi_GPIO.cleanup()


def _run_state_loop(controller: ThreadSafeGPIOController) -> None:
    blink_toggle = False
    while controller._is_running:
        with controller._lock:
            state = controller._state

        if state == "GREEN":
            _write_pin(PIN_RED_LED, False)
            _write_pin(PIN_YELLOW_LED, False)
            _write_pin(PIN_GREEN_LED, True)
            time.sleep(0.1)

        elif state == "YELLOW":
            _write_pin(PIN_RED_LED, False)
            _write_pin(PIN_YELLOW_LED, True)
            _write_pin(PIN_GREEN_LED, False)
            time.sleep(0.1)

        elif state == "RED":
            _write_pin(PIN_RED_LED, True)
            _write_pin(PIN_YELLOW_LED, False)
            _write_pin(PIN_GREEN_LED, False)
            time.sleep(0.1)

        elif state == "ERROR":
            # Asynchronous flash: Red and Green alternate
            blink_toggle = not blink_toggle
            _write_pin(PIN_YELLOW_LED, False)
            _write_pin(PIN_RED_LED, blink_toggle)
            _write_pin(PIN_GREEN_LED, not blink_toggle)
            time.sleep(0.3)

        elif state == "ENV_ALERT":
            # Environmental alert: Yellow pulses asynchronously
            blink_toggle = not blink_toggle
            _write_pin(PIN_RED_LED, False)
            _write_pin(PIN_GREEN_LED, False)
            _write_pin(PIN_YELLOW_LED, blink_toggle)
            time.sleep(0.4)

        elif state == "OFF":
            _write_pin(PIN_RED_LED, False)
            _write_pin(PIN_YELLOW_LED, False)
            _write_pin(PIN_GREEN_LED, False)
            time.sleep(0.2)
