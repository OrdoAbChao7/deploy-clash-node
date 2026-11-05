#!/usr/bin/env python3
"""Validate a candidate with its actual core; native output is never printed.

The work directory must be an existing isolated directory. Validation may fetch
providers or create cache files. This is not a live connectivity test.
"""
import argparse
import json
from pathlib import Path
import subprocess


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--core", choices=["mihomo", "xray", "sing-box"], required=True)
    p.add_argument("--binary", type=Path, required=True)
    p.add_argument("--config", type=Path, required=True)
    p.add_argument("--work-dir", type=Path, required=True)
    p.add_argument("--timeout", type=int, default=60)
    a = p.parse_args()
    if not a.binary.is_file() or not a.config.is_file() or not a.work_dir.is_dir() or not 1 <= a.timeout <= 300:
        p.error("existing binary/config/isolated work directory and timeout 1..300 required")
    commands = {
        "mihomo": ["-t", "-d", str(a.work_dir.resolve()), "-f", str(a.config.resolve())],
        "xray": ["run", "-test", "-config", str(a.config.resolve())],
        "sing-box": ["check", "-c", str(a.config.resolve())],
    }
    try:
        r = subprocess.run([str(a.binary.resolve()), *commands[a.core]], cwd=a.work_dir,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=a.timeout)
        print(json.dumps({"core": a.core, "config_valid": r.returncode == 0, "exit": r.returncode,
                          "scope": "native validation only; errors suppressed to protect secrets"}))
        return 0 if r.returncode == 0 else 1
    except (OSError, subprocess.TimeoutExpired):
        print(json.dumps({"config_valid": False, "error": "launch failed or timed out"}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
