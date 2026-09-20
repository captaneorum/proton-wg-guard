#!/usr/bin/env bash
set -euo pipefail

[[ $EUID -eq 0 ]] || {
    echo "Run with sudo: sudo $0" >&2
    exit 1
}

systemctl stop proton-wg-guard.service 2>/dev/null || true

if [[ -x /usr/local/sbin/proton-wg-guard ]]; then
    /usr/local/sbin/proton-wg-guard remove
else
    nft delete table inet proton_killswitch 2>/dev/null || true
fi

echo "Kill switch temporarily DISABLED."
echo "Reconnect watchdog STOPPED."
