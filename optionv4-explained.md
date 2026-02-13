To provide a comprehensive reference, the links below point to the official **IANA (Internet Assigned Numbers Authority)** registry and the corresponding **RFC (Request for Comments)** standards. 

Additionally, this profile aligns with the built-in definitions provided by **ISC Kea**, a modern, high-performance DHCP server. These options are verified as supported by Kea in their official [all-options.json reference](https://gitlab.isc.org/isc-projects/kea/-/blob/master/doc/examples/kea4/all-options.json?ref_type=heads).

---

# DHCPv4 Option Reference

## Router / Firewall Deployment Profile (Modern + Legacy Coverage)

---

## Purpose

This DHCP configuration is designed to:

* Support modern enterprise clients
* Maintain compatibility with legacy systems
* Provide full routing and provisioning support
* Preserve historical protocol interoperability where required

**Compliance Note:** All options listed below follow [IANA BOOTP/DHCP Parameters](https://www.iana.org/assignments/bootp-dhcp-parameters/bootp-dhcp-parameters.xhtml) and are supported by the [ISC Kea DHCPv4 engine](https://gitlab.isc.org/isc-projects/kea/-/blob/master/doc/examples/kea4/all-options.json?ref_type=heads).

---

# 1. Core Network Operation (Essential)

Required for basic IP connectivity. Standards defined in [RFC 2132](https://datatracker.ietf.org/doc/html/rfc2132).

| Code | Name | Purpose | Specification |
| :--- | :--- | :--- | :--- |
| 1 | Subnet Mask | Defines client subnet boundary | [RFC 2132, Sec 3.3](https://datatracker.ietf.org/doc/html/rfc2132#section-3.3) |
| 3 | Routers | Default gateway | [RFC 2132, Sec 3.5](https://datatracker.ietf.org/doc/html/rfc2132#section-3.5) |
| 6 | Domain Name Servers | DNS resolution | [RFC 2132, Sec 3.8](https://datatracker.ietf.org/doc/html/rfc2132#section-3.8) |
| 15 | Domain Name | Default DNS suffix | [RFC 2132, Sec 3.17](https://datatracker.ietf.org/doc/html/rfc2132#section-3.17) |
| 26 | Interface MTU | Defines client MTU | [RFC 2132, Sec 4.6](https://datatracker.ietf.org/doc/html/rfc2132#section-4.6) |
| 28 | Broadcast Address | Subnet broadcast | [RFC 2132, Sec 3.14](https://datatracker.ietf.org/doc/html/rfc2132#section-3.14) |
| 42 | NTP Servers | Time synchronization | [RFC 2132, Sec 8.3](https://datatracker.ietf.org/doc/html/rfc2132#section-8.3) |
| 54 | DHCP Server Identifier | Identifies DHCP server | [RFC 2132, Sec 9.7](https://datatracker.ietf.org/doc/html/rfc2132#section-9.7) |
| 119 | Domain Search | DNS search domains | [RFC 3397](https://datatracker.ietf.org/doc/html/rfc3397) |
| 121 | Classless Static Route | Modern route injection | [RFC 3442](https://datatracker.ietf.org/doc/html/rfc3442) |

---

# 2. Advanced Routing & IP Behavior (Situational)

These influence routing behavior and IP stack characteristics.

| Code | Name | Use Case | Reference |
| :--- | :--- | :--- | :--- |
| 33 | Static Routes | Legacy route injection | [RFC 2132, Sec 7.6](https://datatracker.ietf.org/doc/html/rfc2132#section-7.6) |
| 118 | Subnet Selection | Multi-subnet relay environments | [RFC 3011](https://datatracker.ietf.org/doc/html/rfc3011) |
| 19 | IP Forwarding | Enable client routing | [RFC 2132, Sec 4.1](https://datatracker.ietf.org/doc/html/rfc2132#section-4.1) |
| 31 | Router Discovery | ICMP router discovery | [RFC 2132, Sec 5.1](https://datatracker.ietf.org/doc/html/rfc2132#section-5.1) |
| 23 | Default IP TTL | Set default Hop Limit | [RFC 2132, Sec 4.3](https://datatracker.ietf.org/doc/html/rfc2132#section-4.3) |
| 35 | ARP Cache Timeout | ARP aging control | [RFC 2132, Sec 6.3](https://datatracker.ietf.org/doc/html/rfc2132#section-6.3) |

---

# 3. Legacy Enterprise Infrastructure

Required only in environments running older directory or naming systems.

## NetBIOS / WINS (Pre-Active Directory Windows)
| Code | Name | Reference |
| :--- | :--- | :--- |
| 44 | NetBIOS Name Servers | [RFC 2132, Sec 8.7](https://datatracker.ietf.org/doc/html/rfc2132#section-8.7) |
| 46 | NetBIOS Node Type | [RFC 2132, Sec 8.9](https://datatracker.ietf.org/doc/html/rfc2132#section-8.9) |

## NIS / NIS+ (Unix Legacy)
| Code | Name | Reference |
| :--- | :--- | :--- |
| 40 | NIS Domain | [RFC 2132, Sec 8.1](https://datatracker.ietf.org/doc/html/rfc2132#section-8.1) |
| 64 | NIS+ Domain Name | [RFC 2132, Sec 8.11](https://datatracker.ietf.org/doc/html/rfc2132#section-8.11) |

## Novell NetWare / Banyan VINES
| Code | Name | Reference |
| :--- | :--- | :--- |
| 85 | NDS Servers | [RFC 2241](https://datatracker.ietf.org/doc/html/rfc2241) |
| 75 | StreetTalk Server | [RFC 2132, Sec 10.8](https://datatracker.ietf.org/doc/html/rfc2132#section-10.8) |

---

# 4. Boot & Device Provisioning

Required for PXE boot, diskless systems, and automated appliance deployment.

| Code | Name | Use | Reference |
| :--- | :--- | :--- | :--- |
| 66 | TFTP Server Name | Boot server | [RFC 2132, Sec 9.4](https://datatracker.ietf.org/doc/html/rfc2132#section-9.4) |
| 67 | Boot File Name | Boot image | [RFC 2132, Sec 9.5](https://datatracker.ietf.org/doc/html/rfc2132#section-9.5) |
| 93 | Client System Architecture | PXE architecture type | [RFC 4578](https://datatracker.ietf.org/doc/html/rfc4578) |
| 97 | UUID/GUID | Client identifier | [RFC 4578](https://datatracker.ietf.org/doc/html/rfc4578) |

---

# 5. Application Service Location (Legacy Model)

Historical model for service discovery (predating DNS SRV).

| Code | Name | Reference |
| :--- | :--- | :--- |
| 69 | SMTP Server | [RFC 2132, Sec 10.2](https://datatracker.ietf.org/doc/html/rfc2132#section-10.2) |
| 72 | WWW Server | [RFC 2132, Sec 10.5](https://datatracker.ietf.org/doc/html/rfc2132#section-10.5) |
| 9 | LPR Servers | [RFC 2132, Sec 3.11](https://datatracker.ietf.org/doc/html/rfc2132#section-3.11) |
| 48 | Font Servers | [RFC 2132, Sec 8.11](https://datatracker.ietf.org/doc/html/rfc2132#section-8.11) |

---

# 6. Service Discovery & Directory Extensions

| Code | Name | Reference |
| :--- | :--- | :--- |
| 78 | SLP Directory Agent | [RFC 2610](https://datatracker.ietf.org/doc/html/rfc2610) |
| 112 | NetInfo Server Address | [RFC 3679](https://datatracker.ietf.org/doc/html/rfc3679) |

---

# 7. Mobility, Transition & Specialized Networking

| Code | Name | Reference |
| :--- | :--- | :--- |
| 68 | Mobile IP Home Agent | [RFC 2132, Sec 9.6](https://datatracker.ietf.org/doc/html/rfc2132#section-9.6) |
| 212 | 6rd (IPv6 Deployment) | [RFC 5969](https://datatracker.ietf.org/doc/html/rfc5969) |
| 108 | v6-only-preferred | [RFC 8925](https://datatracker.ietf.org/doc/html/rfc8925) |

---

# 8. Security & Modern Access Control

| Code | Name | Purpose | Reference |
| :--- | :--- | :--- | :--- |
| 114 | Captive Portal | Guest login URI | [RFC 8910](https://datatracker.ietf.org/doc/html/rfc8910) |
| 162 | v4 DNR | Encrypted DNS discovery | [RFC 9463](https://datatracker.ietf.org/doc/html/rfc9463) |

---

# 9. Historical / Rarely Used Options

| Code | Name | Reference |
| :--- | :--- | :--- |
| 2 | Time Offset | [RFC 2132, Sec 3.4](https://datatracker.ietf.org/doc/html/rfc2132#section-3.4) |
| 5 | Name Servers (IEN-116) | [RFC 2132, Sec 3.7](https://datatracker.ietf.org/doc/html/rfc2132#section-3.7) |

---

# 10. Vendor & Custom Options

| Code | Name | Reference |
| :--- | :--- | :--- |
| 60 | Vendor Class Identifier | [RFC 2132, Sec 9.13](https://datatracker.ietf.org/doc/html/rfc2132#section-9.13) |
| 43 | Vendor Specific Info | [RFC 2132, Sec 8.4](https://datatracker.ietf.org/doc/html/rfc2132#section-8.4) |
| 124 | VIVCO (Vendor-Identifying) | [RFC 3925](https://datatracker.ietf.org/doc/html/rfc3925) |