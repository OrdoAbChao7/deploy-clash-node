#!/usr/bin/env python3
"""Fetch public HTTPS targets through a local HTTP proxy.

Config: one check object, or {"checks": [...]} for multiple checks.
Each check: proxy, url, optional expected_status (int or list), marker,
marker_absent, timeout, max_bytes, name.
The config is a local file; no URLs, response bodies or proxy credentials are
printed. This is an HTTPS request test, not route/UDP/stability proof.
"""
import argparse
import http.client
import json
from pathlib import Path
import ssl
import time
from urllib.parse import urlsplit

DEFAULT_MAX_BYTES = 1024 * 1024
MAX_CHECKS = 50


def _validate(c):
    if not isinstance(c, dict):
        raise ValueError("check must be an object")
    proxy_raw, target_raw = c.get("proxy"), c.get("url")
    if not isinstance(proxy_raw, str) or not isinstance(target_raw, str):
        raise ValueError("proxy and url must be strings")
    proxy, target = urlsplit(proxy_raw), urlsplit(target_raw)
    timeout = float(c.get("timeout", 15))
    expected = c.get("expected_status", 200)
    if isinstance(expected, int):
        statuses = {expected}
    elif isinstance(expected, list) and expected and all(isinstance(x, int) for x in expected):
        statuses = set(expected)
    else:
        raise ValueError("invalid expected_status")
    if any(not 100 <= s <= 599 for s in statuses):
        raise ValueError("invalid expected_status")
    max_bytes = int(c.get("max_bytes", DEFAULT_MAX_BYTES))
    marker, marker_absent = c.get("marker"), c.get("marker_absent")
    if marker is not None and not isinstance(marker, str):
        raise ValueError("invalid marker")
    if marker_absent is not None and not isinstance(marker_absent, str):
        raise ValueError("invalid marker_absent")
    if marker is not None and marker_absent is not None:
        raise ValueError("marker and marker_absent are mutually exclusive")
    if (proxy.scheme != "http" or proxy.hostname not in ("127.0.0.1", "localhost", "::1")
            or proxy.username or proxy.password or proxy.query or proxy.fragment
            or proxy.path not in ("", "/") or target.scheme != "https" or not target.hostname
            or target.username or target.password or target.fragment
            or not 0 < timeout <= 60 or not 1 <= max_bytes <= 10 * 1024 * 1024):
        raise ValueError("invalid config")
    return proxy, target, statuses, timeout, max_bytes, marker, marker_absent


def check(c):
    proxy, target, statuses, timeout, max_bytes, marker, marker_absent = _validate(c)
    # HTTPSConnection establishes the CONNECT tunnel first, then TLS to the target.
    conn = http.client.HTTPSConnection(proxy.hostname, proxy.port or 80, timeout=timeout,
                                       context=ssl.create_default_context())
    conn.set_tunnel(target.hostname, target.port or 443)
    start = time.monotonic()
    try:
        path = (target.path or "/") + ("?" + target.query if target.query else "")
        conn.request("GET", path, headers={"User-Agent": "deploy-clash-node-health/3",
                                           "Connection": "close"})
        r = conn.getresponse()
        body = r.read(max_bytes)
        ok = r.status in statuses
        if marker is not None:
            ok = ok and marker.encode() in body
        if marker_absent is not None:
            ok = ok and marker_absent.encode() not in body
        result = {"ok": ok, "status": r.status, "seconds": round(time.monotonic() - start, 3),
                  "bytes_read": len(body),
                  "scope": "HTTPS request only; no route/UDP/stability proof"}
        if isinstance(c.get("name"), str):
            result["name"] = c["name"]
        return result
    finally:
        conn.close()


def _suppressed():
    return {"ok": False, "error": "configuration or request failed; details suppressed"}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--config", type=Path, required=True)
    a = p.parse_args()
    try:
        config = json.loads(a.config.read_text(encoding="utf-8-sig"))
        if isinstance(config, dict) and "checks" in config:
            checks = config["checks"]
            if not isinstance(checks, list) or not 1 <= len(checks) <= MAX_CHECKS:
                raise ValueError("checks must be a non-empty list")
            results = []
            for c in checks:
                try:
                    results.append(check(c))
                except (OSError, ValueError, KeyError, TypeError, http.client.HTTPException):
                    results.append(_suppressed())
            passed = sum(1 for r in results if r.get("ok"))
            result = {"ok": passed == len(results), "passed": passed,
                      "total": len(results), "checks": results}
        else:
            result = check(config)
    except (OSError, ValueError, KeyError, TypeError, http.client.HTTPException):
        result = _suppressed()
    print(json.dumps(result))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
