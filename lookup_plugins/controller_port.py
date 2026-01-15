from __future__ import annotations

import socket
from typing import Any, Dict, List

from ansible.plugins.lookup import LookupBase


class LookupModule(LookupBase):
    """Attempt a TCP connection from the controller and return result metadata."""

    def run(self, terms: Any, variables: Dict[str, Any] | None = None, **kwargs: Any) -> List[Dict[str, Any]]:
        host = kwargs.get("host")
        port = kwargs.get("port")
        timeout = float(kwargs.get("timeout", 5))

        if not host:
            raise ValueError("controller_port lookup requires 'host'")
        if port is None:
            raise ValueError("controller_port lookup requires 'port'")

        port_int = int(port)
        result = {
            "host": host,
            "port": port_int,
            "timeout": timeout,
            "reachable": False,
            "error": None,
        }

        try:
            with socket.create_connection((host, port_int), timeout=timeout):
                result["reachable"] = True
        except Exception as exc:  # noqa: BLE001 - surface socket errors
            result["error"] = str(exc)

        return [result]
