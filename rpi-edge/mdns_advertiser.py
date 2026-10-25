"""
mDNS Broadcaster using zeroconf.
Allows the mobile client to locate 'raspberrypi.local' dynamically without hardcoded IPs.
"""

import socket
import logging
from zeroconf import IPVersion, ServiceInfo, Zeroconf
from config import MDNS_SERVICE_NAME, MDNS_SERVICE_TYPE, MDNS_HOSTNAME, SERVER_PORT

logger = logging.getLogger("MDNSAdvertiser")


def get_outbound_ip() -> str:
    """Finds the primary local IP address routed for standard local networks."""
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(("10.255.255.255", 1))
        ip = s.getsockname()[0]
    except Exception:
        ip = "127.0.0.1"
    finally:
        s.close()
    return ip


class MDNSServiceManager:
    def __init__(self):
        self.zeroconf = Zeroconf(ip_version=IPVersion.V4Only)
        self.info = None

    def start(self) -> None:
        local_ip = get_outbound_ip()
        desc = {"version": "1.0.0", "path": "/api/v1"}
        
        self.info = ServiceInfo(
            type_=MDNS_SERVICE_TYPE,
            name=f"{MDNS_SERVICE_NAME}.{MDNS_SERVICE_TYPE}",
            addresses=[socket.inet_aton(local_ip)],
            port=SERVER_PORT,
            properties=desc,
            server=MDNS_HOSTNAME
        )
        logger.info(f"Registering mDNS service {MDNS_HOSTNAME} pointing to {local_ip}:{SERVER_PORT}")
        self.zeroconf.register_service(self.info)

    def stop(self) -> None:
        if self.info:
            logger.info("Unregistering mDNS service...")
            self.zeroconf.unregister_service(self.info)
        self.zeroconf.close()
