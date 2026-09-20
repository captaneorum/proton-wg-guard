#!/usr/bin/env bash
set -euo pipefail

TABLE="proton_killswitch"
STATE_DIR="/etc/proton-wg-guard"
STATE_FILE="$STATE_DIR/state.conf"
HELPER="/usr/local/sbin/proton-wg-guard"
SERVICE="/etc/systemd/system/proton-wg-guard.service"

[[ $EUID -eq 0 ]] || {
    echo "Run with sudo: sudo $0" >&2
    exit 1
}

systemctl disable --now proton-wg-guard.service >/dev/null 2>&1 || true
nft delete table inet "$TABLE" 2>/dev/null || true

if [[ -r "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE_FILE"

    if [[ -n "${UUID:-}" ]] && nmcli connection show uuid "$UUID" >/dev/null 2>&1; then
        if [[ -n "${OLD_AUTOCONNECT:-}" ]]; then
            nmcli connection modify uuid "$UUID" \
                connection.autoconnect "$OLD_AUTOCONNECT" || true
        fi

        if [[ -n "${OLD_RETRIES:-}" ]]; then
            nmcli connection modify uuid "$UUID" \
                connection.autoconnect-retries "$OLD_RETRIES" || true
        fi
    fi
fi

rm -f "$SERVICE" "$HELPER"
rm -rf "$STATE_DIR"

systemctl daemon-reload
systemctl reset-failed proton-wg-guard.service >/dev/null 2>&1 || true

echo "proton-wg-guard removed."
echo "Previous NetworkManager autoconnect settings restored when available."
