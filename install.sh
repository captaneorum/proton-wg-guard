#!/usr/bin/env bash
set -euo pipefail

TABLE="proton_killswitch"
STATE_DIR="/etc/proton-wg-guard"
CONFIG_FILE="$STATE_DIR/config"
STATE_FILE="$STATE_DIR/state.conf"
HELPER_DST="/usr/local/sbin/proton-wg-guard"
SERVICE_DST="/etc/systemd/system/proton-wg-guard.service"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

die() {
    echo "ERROR: $*" >&2
    exit 1
}

[[ $EUID -eq 0 ]] || die "Run with sudo: sudo $0 [WIREGUARD_INTERFACE]"

for cmd in nmcli wg nft systemctl ip grep awk sed install; do
    command -v "$cmd" >/dev/null 2>&1 || die "Missing required command: $cmd"
done

[[ -f "$SCRIPT_DIR/src/proton-wg-guard" ]] || die "Missing src/proton-wg-guard"
[[ -f "$SCRIPT_DIR/systemd/proton-wg-guard.service" ]] || die "Missing systemd service file"

requested_if="${1:-}"

mapfile -t wg_interfaces < <(wg show interfaces | tr ' ' '\n' | sed '/^$/d')

[[ ${#wg_interfaces[@]} -gt 0 ]] || die "No active WireGuard interface found. Connect the VPN first."

if [[ -n "$requested_if" ]]; then
    printf '%s\n' "${wg_interfaces[@]}" | grep -Fxq "$requested_if" \
        || die "WireGuard interface '$requested_if' is not active."
    WG_IF="$requested_if"
elif [[ ${#wg_interfaces[@]} -eq 1 ]]; then
    WG_IF="${wg_interfaces[0]}"
else
    echo "Active WireGuard interfaces:"
    printf '  %s\n' "${wg_interfaces[@]}"
    die "More than one interface is active. Re-run as: sudo $0 INTERFACE"
fi

CON_NAME="$(nmcli -g GENERAL.CONNECTION device show "$WG_IF" 2>/dev/null | head -n1 || true)"
[[ -n "$CON_NAME" && "$CON_NAME" != "--" ]] \
    || die "Could not identify a NetworkManager connection for $WG_IF."

UUID="$(nmcli -g connection.uuid connection show "$CON_NAME" | head -n1)"
[[ -n "$UUID" ]] || die "Could not read NetworkManager connection UUID."

mapfile -t endpoints < <(wg show "$WG_IF" endpoints | awk '$2 != "(none)" {print $2}')
[[ ${#endpoints[@]} -eq 1 ]] \
    || die "Expected exactly one WireGuard peer endpoint; found ${#endpoints[@]}."

ENDPOINT="${endpoints[0]}"

if [[ "$ENDPOINT" =~ ^\[([^]]+)\]:([0-9]+)$ ]]; then
    ENDPOINT_FAMILY="ip6"
    ENDPOINT_IP="${BASH_REMATCH[1]}"
    ENDPOINT_PORT="${BASH_REMATCH[2]}"
elif [[ "$ENDPOINT" =~ ^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):([0-9]+)$ ]]; then
    ENDPOINT_FAMILY="ip"
    ENDPOINT_IP="${BASH_REMATCH[1]}"
    ENDPOINT_PORT="${BASH_REMATCH[2]}"
else
    die "Unsupported endpoint '$ENDPOINT'. Only literal IPv4/IPv6 endpoints are supported."
fi

mkdir -p "$STATE_DIR"
chmod 700 "$STATE_DIR"

if [[ ! -f "$STATE_FILE" ]]; then
    OLD_AUTOCONNECT="$(nmcli -g connection.autoconnect connection show uuid "$UUID" | head -n1)"
    OLD_RETRIES="$(nmcli -g connection.autoconnect-retries connection show uuid "$UUID" | head -n1)"

    cat > "$STATE_FILE" <<EOF
UUID=$(printf '%q' "$UUID")
OLD_AUTOCONNECT=$(printf '%q' "$OLD_AUTOCONNECT")
OLD_RETRIES=$(printf '%q' "$OLD_RETRIES")
EOF
    chmod 600 "$STATE_FILE"
fi

cat > "$CONFIG_FILE" <<EOF
WG_IF=$(printf '%q' "$WG_IF")
CON_NAME=$(printf '%q' "$CON_NAME")
UUID=$(printf '%q' "$UUID")
ENDPOINT_FAMILY=$(printf '%q' "$ENDPOINT_FAMILY")
ENDPOINT_IP=$(printf '%q' "$ENDPOINT_IP")
ENDPOINT_PORT=$(printf '%q' "$ENDPOINT_PORT")
EOF
chmod 600 "$CONFIG_FILE"

install -m 0755 "$SCRIPT_DIR/src/proton-wg-guard" "$HELPER_DST"
install -m 0644 "$SCRIPT_DIR/systemd/proton-wg-guard.service" "$SERVICE_DST"

nmcli connection modify uuid "$UUID" \
    connection.autoconnect yes \
    connection.autoconnect-retries 0

systemctl daemon-reload
systemctl enable proton-wg-guard.service >/dev/null

# Apply the kill switch before restarting the watchdog.
"$HELPER_DST" apply
systemctl restart proton-wg-guard.service

echo
echo "Installed successfully."
echo "WireGuard interface : $WG_IF"
echo "Connection          : $CON_NAME"
echo "Endpoint            : $ENDPOINT"
echo "Kill switch         : ACTIVE"
echo "Reconnect watchdog  : ACTIVE"
echo
echo "Check:"
echo "  sudo systemctl status proton-wg-guard --no-pager"
echo "  sudo nft list table inet proton_killswitch"
