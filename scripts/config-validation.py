#!/usr/bin/env python3
"""Validate a candidate with its actual core; native output is never printed.

The work directory must be an existing isolated directory. Validation may fetch
providers or create cache files. This is not a live connectivity test.
Optional --error-file writes core output to a protected file for diagnosis.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--core", choices=["mihomo", "xray", "sing-box"], required=True)
    p.add_argument("--binary", type=Path, required=True)
    p.add_argument("--config", type=Path, required=True)
    p.add_argument("--work-dir", type=Path, required=True)
    p.add_argument("--timeout", type=int, default=60)
    p.add_argument("--expect-binary-sha256", help="optional expected SHA256 of --binary")
    p.add_argument("--error-file", type=Path, help="optional protected file for core output")
    a = p.parse_args()
    if not a.binary.is_file() or not a.config.is_file() or not a.work_dir.is_dir() or not 1 <= a.timeout <= 300:
        p.error("existing binary/config/isolated work directory and timeout 1..300 required")
    if a.expect_binary_sha256 is not None:
        if not re.fullmatch(r"[a-fA-F0-9]{64}", a.expect_binary_sha256):
            p.error("--expect-binary-sha256 must be 64 hex characters")
        actual = sha256_file(a.binary)
        if actual.lower() != a.expect_binary_sha256.lower():
            print(json.dumps({"config_valid": False, "error": "binary checksum mismatch"}))
            return 1
    commands = {
        "mihomo": ["-t", "-d", str(a.work_dir.resolve()), "-f", str(a.config.resolve())],
        "xray": ["run", "-test", "-config", str(a.config.resolve())],
        "sing-box": ["check", "-c", str(a.config.resolve())],
    }
    err = None
    try:
        if a.error_file is not None:
            fd = os.open(a.error_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            err = os.fdopen(fd, "wb")
        r = subprocess.run([str(a.binary.resolve()), *commands[a.core]], cwd=a.work_dir,
                           stdout=err if err is not None else subprocess.DEVNULL,
                           stderr=subprocess.STDOUT if err is not None else subprocess.DEVNULL,
                           timeout=a.timeout)
        print(json.dumps({"core": a.core, "config_valid": r.returncode == 0, "exit": r.returncode,
                          "errors_captured": a.error_file is not None,
                          "scope": "native validation only; not a connectivity test"}))
        return 0 if r.returncode == 0 else 1
    except (OSError, subprocess.TimeoutExpired):
        print(json.dumps({"config_valid": False, "error": "launch failed or timed out"}))
        return 1
    finally:
        if err is not None:
            err.close()


if __name__ == "__main__":
    raise SystemExit(main())
