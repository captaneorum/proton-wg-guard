# Security

## Reporting

Please do not include WireGuard private keys, VPN credentials, passwords, or other secrets in bug reports.

Useful diagnostic data normally includes:

- distribution and version;
- NetworkManager version;
- nftables version;
- WireGuard interface name;
- peer endpoint IP and port;
- relevant `journalctl -u proton-wg-guard` output;
- `nft list table inet proton_killswitch`.

The WireGuard public key and peer public key are not authentication secrets, but they are usually unnecessary for troubleshooting.

## Threat model

The project is intended to prevent accidental clear-network traffic when a NetworkManager-managed WireGuard tunnel disappears.

It is not intended to defend against:

- a compromised root account;
- malicious kernel modules;
- arbitrary modification of nftables by privileged processes;
- a compromised VPN server;
- traffic intentionally generated outside the host network namespace.
