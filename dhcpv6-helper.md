# DHCPv6 & IPv6 RFC Reference Guide

> A reference document covering the IETF standards that underpin DHCPv6,
> relay agents, and the broader IPv6 stack.

---

## The Dependency Chain

```
RFC 8200 (IPv6 Core)
    └── RFC 4291 (Addressing)
            └── RFC 4443 (ICMPv6)
                    └── RFC 4861 (NDP/RA)
                            └── RFC 4862 (SLAAC)
                                    └── RFC 8415 (DHCPv6)
                                            └── Kea + Relay Setup
```

DHCPv6 sits near the top of the IPv6 stack. Everything below it must be
functional first — particularly NDP and link-local addressing. On a broken
IPv6 network, DHCPv6 is often the last thing to fix, not the first.

---

## 1. IPv6 Core Architecture (The Foundation)

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 8200 | IPv6 Specification | Obsoletes RFC 2460. The base IPv6 protocol — everything else builds on this |
| RFC 4291 | IPv6 Addressing Architecture | Defines address types, scopes, and formats. Without this, DHCPv6 address assignment has no framework |

---

## 2. ICMPv6 & Neighbor Discovery

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 4443 | ICMPv6 | Error and informational messages. DHCPv6 relies on this for network reachability |
| RFC 4861 | Neighbor Discovery Protocol (NDP) | Replaces ARP in IPv6. Defines Router Solicitation/Advertisement. **DHCPv6 is triggered by RA flags (M/O bits) set here** |

---

## 3. SLAAC (Stateless Address Autoconfiguration)

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 4862 | SLAAC | The alternative to DHCPv6. The `M` flag (Managed) in RA tells clients to use DHCPv6 instead |

---

## 4. UDP/IP Transport

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 768 | UDP | DHCPv6 runs over UDP ports 546/547. Must exist before DHCPv6 can function |
| RFC 9293 | TCP (obsoletes RFC 793) | Not used by DHCPv6 directly, but relevant for Kea's control socket and MySQL backend |

---

## 5. Multicast Addressing

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 4291 / RFC 2375 | IPv6 Multicast Addresses | DHCPv6 uses well-known multicast addresses. Clients send to multicast initially, not unicast |
| RFC 4291 | Solicited-Node Multicast | Used by NDP which triggers DHCPv6 |

### DHCPv6 Well-Known Multicast Addresses
| Address | Scope | Purpose |
|---------|-------|---------|
| `ff02::1:2` | Link-local | All DHCP Relay Agents and Servers |
| `ff05::1:3` | Site-local | All DHCP Servers |

---

## 6. Link-Local Addressing

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 4291 | Link-Local Scope (`fe80::/10`) | Critical for relay agents — relay identification uses `fe80::` addresses. Must be established before DHCPv6 can operate |

---

## 7. Core DHCPv6 Protocol

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 8415 | DHCPv6 (supersedes RFC 3315) | Main DHCPv6 specification. Defines client-server communication, message types, options, and relay agent behavior |
| RFC 8415 §20 | Relay Agent Behavior | How relays forward messages, relay-forward/reply messages, link-local addressing for relay identification, multi-hop relay support |

---

## 8. DHCPv6 Options

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 3646 | DNS Configuration Options for DHCPv6 | DNS servers option (option 23). Maps to `dns-servers` in Kea config |
| RFC 8415 | IA_NA, IA_TA, Status Codes | Identity Association for Non-temporary/Temporary Addresses |

---

## 9. IPv6 Address Types

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 4193 | Unique Local IPv6 Unicast Addresses (ULA) | Your `fd12:3456:789a::/48` prefix. Private IPv6 addressing, similar to RFC 1918 for IPv4 |
| RFC 4941 | Privacy Extensions for SLAAC | Temporary addresses. Influences whether clients prefer DHCPv6 or SLAAC |

---

## 10. DNS Integration

| RFC | Title | Notes |
|-----|-------|-------|
| RFC 1034/1035 | DNS Core | Precedes everything. DHCPv6 distributes DNS server info but DNS itself is defined here |
| RFC 3596 | DNS Extensions for IPv6 | AAAA records. Relevant when DHCPv6 assigns addresses that need DNS registration |

---

## 11. Additional Considerations

| RFC/Standard | Title | Notes |
|-----|-------|-------|
| RFC 7084 | Basic Requirements for IPv6 Customer Edge Routers | Relevant if this is a gateway/router setup |
| RFC 7844 | Anonymity Profiles for DHCP Clients | Privacy considerations, not implemented by default |
| IEEE 802.1Q | VLAN Tagging | Not an RFC but relevant — defines VLAN 10, 20, etc. tagging used with dhcrelay6 |

---

## 12. RFCs Directly Active in This Setup

| RFC | Where It Applies |
|-----|-----------------|
| RFC 8200 | Base IPv6 on enp7s0 and VLAN interfaces |
| RFC 4291 | ULA addressing (`fd12::/48`), link-local (`fe80::`) |
| RFC 4861 | NDP/RA on VLAN interfaces (radvd / systemd-networkd IPv6SendRA) |
| RFC 4862 | SLAAC if `AdvAutonomous on` in radvd |
| RFC 8415 | Kea DHCPv6 server + dhcrelay6 relay agents |
| RFC 4193 | Your ULA prefix `fd12:3456:789a::/48` |
| RFC 3646 | `dns-servers` option in kea-dhcp6.conf |
| IEEE 802.1Q | VLAN interfaces (vlan10, vlan20, etc.) |

---

## Quick Reference: Key Port Numbers

| Protocol | Port | Direction |
|----------|------|-----------|
| DHCPv6 Client | UDP 546 | Listens for replies |
| DHCPv6 Server/Relay | UDP 547 | Listens for requests |

---

*Last updated: February 2026*