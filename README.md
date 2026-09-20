# proton-wg-guard

A small Linux kill switch and automatic reconnect watchdog for **ProtonVPN WireGuard profiles managed by NetworkManager**.

It is designed for systems using:

- NetworkManager
- WireGuard
- nftables
- systemd
- optionally firewalld

The project creates its own nftables table and does **not** modify firewalld's own table.

## What it does

When enabled:

1. Allows ordinary outbound traffic only through the selected WireGuard interface.
2. Allows the WireGuard UDP connection to the VPN server outside the tunnel so the tunnel can reconnect.
3. Allows DHCP and minimal IPv6 neighbour/router discovery needed to retain network connectivity.
4. Blocks ordinary IPv4 and IPv6 traffic if the VPN tunnel disappears.
5. Enables NetworkManager autoconnect for the selected WireGuard profile.
6. Runs a systemd watchdog that asks NetworkManager to reconnect the VPN when it becomes inactive.

## Important warning

A kill switch intentionally blocks network access when the VPN is unavailable.

Keep a local terminal open when testing. If you lose connectivity, you can temporarily disable the kill switch with:

```bash
sudo /usr/local/sbin/proton-wg-guard remove
sudo systemctl stop proton-wg-guard
```

or use the included `disable.sh` script.

## Requirements

Install these first:

### openSUSE Tumbleweed

```bash
sudo zypper install wireguard-tools nftables NetworkManager
```

### Fedora

```bash
sudo dnf install wireguard-tools nftables NetworkManager
```

### Debian / Ubuntu

```bash
sudo apt install wireguard-tools nftables network-manager
```

The WireGuard tunnel must already be configured in NetworkManager and connected at least once.

## Install

Clone the repository:

```bash
git clone https://github.com/YOUR-USER/proton-wg-guard.git
cd proton-wg-guard
```

Connect the ProtonVPN WireGuard profile, then run:

```bash
sudo ./install.sh
```

The installer automatically detects an active NetworkManager WireGuard connection.

If more than one WireGuard tunnel is active, specify the interface:

```bash
sudo ./install.sh wg0
```

or, for a named interface:

```bash
sudo ./install.sh uk-IS-UK-1
```

## Check status

```bash
sudo systemctl status proton-wg-guard --no-pager
```

View the kill-switch rules:

```bash
sudo nft list table inet proton_killswitch
```

View recent watchdog messages:

```bash
journalctl -u proton-wg-guard -n 50 --no-pager
```

## Temporarily disable

```bash
sudo ./disable.sh
```

This stops the watchdog and removes only the project's nftables table.

To enable it again:

```bash
sudo ./enable.sh
```

## Uninstall

```bash
sudo ./uninstall.sh
```

The uninstaller:

- stops and disables the watchdog;
- removes the `proton_killswitch` nftables table;
- restores the NetworkManager autoconnect settings saved during installation;
- removes files installed by this project.

It does not remove your ProtonVPN WireGuard profile.

## Design

The kill-switch table contains an outbound base chain with a default policy of `drop`.

It permits:

- loopback;
- traffic leaving through the WireGuard interface;
- UDP to the detected WireGuard peer endpoint;
- DHCPv4 and DHCPv6;
- essential IPv6 neighbour/router discovery.

Everything else is dropped while the kill switch is active.

The nftables hook priority is deliberately earlier than firewalld's ordinary output filtering, so the project's drop policy cannot be bypassed by later permissive firewall rules.

## Supported endpoint formats

The installer supports:

- IPv4 WireGuard endpoints, for example `185.159.158.22:51820`
- IPv6 WireGuard endpoints, for example `[2001:db8::1]:51820`

Hostname endpoints are intentionally rejected. A fixed IP endpoint avoids opening DNS outside the VPN just to reconnect. Most Proton WireGuard profiles use an IP endpoint.

## Multiple peers

This project expects the selected WireGuard interface to have one active peer endpoint.

If several peers are configured, installation stops rather than guessing which peer is the VPN gateway.

## LAN access

LAN traffic is blocked by default.

That is intentional: this project aims for a strict kill switch.

If you need printers, NAS devices, SSH to another LAN host, or other local services, add explicit LAN exceptions only after considering the privacy implications.

## IPv6

IPv6 is covered by the same `inet` nftables table.

Minimal ICMPv6 neighbour/router discovery is allowed outside the tunnel because IPv6 networking may require it. Ordinary IPv6 Internet traffic is still blocked when the tunnel is unavailable.

## firewalld

firewalld can remain enabled.

This project creates:

```text
table inet proton_killswitch
```

and does not edit:

```text
table inet firewalld
```

## Security notes

- The WireGuard private key is never copied by this project.
- The installer reads only interface, NetworkManager profile, endpoint, port and autoconnect metadata.
- The saved state file is mode `0600`.
- The state directory is mode `0700`.
- No DNS queries are required by the watchdog.
- No external network service is contacted by the scripts themselves.

## Files installed

```text
/usr/local/sbin/proton-wg-guard
/etc/proton-wg-guard/config
/etc/proton-wg-guard/state.conf
/etc/systemd/system/proton-wg-guard.service
```

## Test procedure

After installation:

1. Confirm Internet access works normally through the VPN.
2. Run:

   ```bash
   sudo nft list table inet proton_killswitch
   ```

3. Stop the VPN connection manually:

   ```bash
   nmcli connection down "<your WireGuard connection name>"
   ```

4. Ordinary Internet access should stop immediately.
5. The watchdog should bring the WireGuard connection back up.
6. Internet access should resume only through WireGuard.

You can monitor this with:

```bash
journalctl -fu proton-wg-guard
```

## Scope

This is not an official Proton AG project.

It is intended for manually imported ProtonVPN WireGuard configurations managed by NetworkManager.

## License

MIT
