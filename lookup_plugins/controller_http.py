from __future__ import annotations

import ssl
from typing import Any, Dict, Iterable, List
from urllib import error, request

from ansible.plugins.lookup import LookupBase


class LookupModule(LookupBase):
    """Perform an HTTP request from the controller and capture the result."""

    def run(self, terms: Any, variables: Dict[str, Any] | None = None, **kwargs: Any) -> List[Dict[str, Any]]:
        url = kwargs.get("url")
        host = kwargs.get("host")
        port = kwargs.get("port")
        scheme = kwargs.get("scheme", "http")
        path = kwargs.get("path", "/")
        method = kwargs.get("method", "GET")
        timeout = float(kwargs.get("timeout", 10))
        allowed_status = kwargs.get("allowed_status", [200, 404])
        validate_certs = kwargs.get("validate_certs", True)

        if not url:
            if host is None or port is None:
                raise ValueError("controller_http lookup requires 'url' or both 'host' and 'port'")
            url = f"{scheme}://{host}:{port}{path}"

        status_allowlist: Iterable[int] = [int(code) for code in allowed_status]
        result = {
            "url": url,
            "status_code": None,
            "ok": False,
            "body": "",
            "error": None,
        }

        context = None
        if not validate_certs and url.startswith("https"):
            context = ssl._create_unverified_context()

        try:
            req = request.Request(url, method=method)
            with request.urlopen(req, timeout=timeout, context=context) as resp:
                result["status_code"] = resp.getcode()
                result["body"] = resp.read().decode("utf-8", errors="replace")
                result["ok"] = result["status_code"] in status_allowlist
        except error.HTTPError as exc:
            result["status_code"] = exc.code
            result["body"] = exc.read().decode("utf-8", errors="replace")
            result["ok"] = exc.code in status_allowlist
            result["error"] = str(exc)
        except Exception as exc:  # noqa: BLE001
            result["error"] = str(exc)

        return [result]
