#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || {
    echo "Run with sudo: sudo $0" >&2
    exit 1
}

[[ -x /usr/local/sbin/proton-wg-guard ]] || {
    echo "proton-wg-guard is not installed." >&2
    exit 1
}

systemctl start proton-wg-guard.service

echo "Kill switch ACTIVE."
echo "Reconnect watchdog ACTIVE."
