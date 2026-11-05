#!/usr/bin/env python3
"""Read-only Linux resource/service summary. Does not inspect secret configs."""
import argparse
import json
import platform
import shutil
import subprocess


def probe(argv):
    if not shutil.which(argv[0]):
        return {"status": "unknown", "reason": "tool unavailable"}
    try:
        r = subprocess.run(argv, capture_output=True, text=True, timeout=15)
        if r.returncode:
            return {"status": "unknown", "reason": "command failed", "exit": r.returncode}
        return {"status": "observed", "value": r.stdout.strip()}
    except (OSError, subprocess.TimeoutExpired):
        return {"status": "unknown", "reason": "command unavailable or timed out"}


def main():
    argparse.ArgumentParser(description=__doc__).parse_args()
    if platform.system() != "Linux":
        print(json.dumps({"status": "unsupported", "required": "Linux"}))
        return 2
    checks = {
        "os": ["uname", "-srmo"], "cpu": ["getconf", "_NPROCESSORS_ONLN"],
        "memory": ["free", "-b"], "root_disk": ["df", "-B1", "/"],
    }
    result = {k: probe(v) for k, v in checks.items()}
    for unit in ("xray", "sing-box", "hysteria-server", "nginx", "certbot.timer", "vnstat"):
        result[unit] = probe(["systemctl", "show", unit, "--property=LoadState,ActiveState,SubState,User,Group,Restart"])
    result["not_covered"] = ["credentials/configs", "SSH fingerprint/auth", "listeners/firewall", "TLS/hooks", "logs/backups", "provider quota"]
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 1 if any(v.get("status") == "unknown" for v in result.values() if isinstance(v, dict)) else 0


if __name__ == "__main__":
    raise SystemExit(main())
