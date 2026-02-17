
# DHCPv6 & IPv6 RFC Reference Guide

> A reference document covering the IETF standards that underpin DHCPv6, relay agents, and the broader IPv6 stack.

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

DHCPv6 sits near the top of the IPv6 stack. Everything below it must be functional first — particularly NDP and link-local addressing. On a broken IPv6 network, DHCPv6 is often the last thing to fix, not the first.

---

## 1. IPv6 Core Architecture (The Foundation)

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 8200](https://datatracker.ietf.org/doc/html/rfc8200) | IPv6 Specification | Obsoletes RFC 2460. The base IPv6 protocol. |
| [RFC 4291](https://datatracker.ietf.org/doc/html/rfc4291) | IPv6 Addressing Architecture | Defines address types, scopes, and formats. |

---

## 2. ICMPv6 & Neighbor Discovery

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 4443](https://datatracker.ietf.org/doc/html/rfc4443) | ICMPv6 | Error and informational messages for IPv6. |
| [RFC 4861](https://datatracker.ietf.org/doc/html/rfc4861) | Neighbor Discovery Protocol (NDP) | Replaces ARP. **DHCPv6 is triggered by RA flags (M/O bits).** |

---

## 3. SLAAC (Stateless Address Autoconfiguration)

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 4862](https://datatracker.ietf.org/doc/html/rfc4862) | SLAAC | The `M` flag (Managed) in RA tells clients to use DHCPv6. |

---

## 4. UDP/IP Transport

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 768](https://datatracker.ietf.org/doc/html/rfc768) | UDP | DHCPv6 runs over UDP ports 546/547. |
| [RFC 9293](https://datatracker.ietf.org/doc/html/rfc9293) | TCP | Relevant for Kea's control socket and MySQL backend. |

---

## 5. Multicast Addressing

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 2375](https://datatracker.ietf.org/doc/html/rfc2375) | IPv6 Multicast Address Assignments | Initial definitions for well-known multicast. |
| [RFC 4291](https://datatracker.ietf.org/doc/html/rfc4291) | Solicited-Node Multicast | Critical for NDP which precedes DHCPv6. |

### DHCPv6 Well-Known Multicast Addresses

| Address | Scope | Purpose |
| --- | --- | --- |
| `ff02::1:2` | Link-local | All DHCP Relay Agents and Servers |
| `ff05::1:3` | Site-local | All DHCP Servers |

---

## 6. Link-Local Addressing

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 4291](https://datatracker.ietf.org/doc/html/rfc4291) | Link-Local Scope (`fe80::/10`) | Critical for relay agents—relay identification uses `fe80::` addresses. |

---

## 7. Core DHCPv6 Protocol

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 8415](https://datatracker.ietf.org/doc/html/rfc8415) | DHCPv6 (Revised) | Supersedes RFC 3315. The modern "Bible" for DHCPv6. |
| [RFC 8415 §20](https://www.google.com/search?q=https://datatracker.ietf.org/doc/html/rfc8415%23section-20) | Relay Agent Behavior | Details on `Relay-Forward` and `Relay-Reply` messages. |

---

## 8. DHCPv6 Options

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 3646](https://datatracker.ietf.org/doc/html/rfc3646) | DNS Config Options for DHCPv6 | Specifically DNS servers (Option 23) and Search Lists (Option 24). |

---

## 9. IPv6 Address Types

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 4193](https://datatracker.ietf.org/doc/html/rfc4193) | Unique Local Addresses (ULA) | Private addressing (`fd00::/8`). |
| [RFC 4941](https://datatracker.ietf.org/doc/html/rfc4941) | Privacy Extensions | Defines temporary addresses to prevent device tracking. |

---

## 10. DNS Integration

| RFC | Title | Notes |
| --- | --- | --- |
| [RFC 1035](https://datatracker.ietf.org/doc/html/rfc1035) | Domain Names - Implementation | The core DNS specification. |
| [RFC 3596](https://datatracker.ietf.org/doc/html/rfc3596) | DNS Extensions for IPv6 | Defines the **AAAA** record type. |

---

## 11. Additional Considerations

| Standard | Title | Notes |
| --- | --- | --- |
| [RFC 7084](https://datatracker.ietf.org/doc/html/rfc7084) | Requirements for IPv6 CE Routers | Blueprint for home/office gateway behavior. |
| [RFC 7844](https://datatracker.ietf.org/doc/html/rfc7844) | Anonymity Profiles for DHCP | Mitigates fingerprinting via DHCP options. |
| [IEEE 802.1Q](https://ieeexplore.ieee.org/document/8403927) | VLAN Tagging | Protocol for carrying multiple subnets over one link. |

---

## Quick Reference: Key Port Numbers

| Protocol | Port | Direction |
| --- | --- | --- |
| DHCPv6 Client | UDP 546 | Listens for replies |
| DHCPv6 Server/Relay | UDP 547 | Listens for requests |

---
