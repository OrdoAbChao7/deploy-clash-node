#!/usr/bin/env python3
"""Fetch a public HTTPS target through a local HTTP proxy (no secret URLs).

Config JSON: proxy, url, optional expected_status (default 200), marker, timeout.
The config is a local file; no URLs, response bodies or errors are printed.
"""
import argparse
import http.client
import json
from pathlib import Path
import ssl
import time
from urllib.parse import urlsplit


def check(c):
    proxy, target = urlsplit(c["proxy"]), urlsplit(c["url"])
    timeout = float(c.get("timeout", 15))
    if (proxy.scheme != "http" or proxy.hostname not in ("127.0.0.1", "localhost", "::1")
            or proxy.username or proxy.password or proxy.query or proxy.fragment
            or proxy.path not in ("", "/") or target.scheme != "https" or not target.hostname
            or target.username or target.password or target.fragment or not 0 < timeout <= 60):
        raise ValueError("invalid config")
    # Explicit HTTP CONNECT avoids environment NO_PROXY bypassing the chosen proxy.
    conn = http.client.HTTPSConnection(proxy.hostname, proxy.port or 80, timeout=timeout,
                                       context=ssl.create_default_context())
    conn.set_tunnel(target.hostname, target.port or 443)
    start = time.monotonic()
    try:
        conn.request("GET", (target.path or "/") + ("?" + target.query if target.query else ""),
                     headers={"User-Agent": "deploy-clash-node-health/2", "Connection": "close"})
        r = conn.getresponse()
        body = r.read(1024 * 1024)
        ok = r.status == int(c.get("expected_status", 200))
        if c.get("marker"):
            ok = ok and str(c["marker"]).encode() in body
        return {"ok": ok, "status": r.status, "seconds": round(time.monotonic() - start, 3),
                "bytes_read": len(body), "scope": "HTTPS request only; no route/UDP/stability proof"}
    finally:
        conn.close()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config", type=Path, required=True)
    a = p.parse_args()
    try:
        result = check(json.loads(a.config.read_text(encoding="utf-8-sig")))
    except (OSError, ValueError, KeyError, TypeError, http.client.HTTPException):
        result = {"ok": False, "error": "configuration or request failed; details suppressed"}
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
