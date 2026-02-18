# DHCPv6 Option Reference

**Router / Firewall Deployment Profile — Modern + Legacy Coverage**

---

## Overview

This DHCPv6 configuration reference is designed to:

- Support modern enterprise IPv6 clients
- Maintain compatibility with transitional dual-stack environments
- Provide full address, prefix, and service provisioning support
- Cover relay agent and advanced deployment scenarios

> [!NOTE]
> All options listed below conform to [IANA DHCPv6 Parameters](https://www.iana.org/assignments/dhcpv6-parameters/dhcpv6-parameters.xhtml) and are verified as supported by the [ISC Kea DHCPv6 engine](https://gitlab.isc.org/isc-projects/kea/-/blob/master/doc/examples/kea6/all-options.json?ref_type=heads). The primary DHCPv6 standard is [RFC 8415](https://datatracker.ietf.org/doc/html/rfc8415), which obsoletes the earlier [RFC 3315](https://datatracker.ietf.org/doc/html/rfc3315).

> [!IMPORTANT]
> DHCPv6 operates fundamentally differently from DHCPv4. It uses **multicast** rather than broadcast, does not distribute a default gateway (clients learn this via Router Advertisement / SLAAC), and separates address assignment from network configuration. Always deploy alongside a correctly configured **ICMPv6 Router Advertisement** setup.

---

## Table of Contents

- [1. Core Protocol Operation](#1-core-protocol-operation-essential)
- [2. Address & Prefix Assignment](#2-address--prefix-assignment)
- [3. Network Configuration](#3-network-configuration)
- [4. Boot & Device Provisioning](#4-boot--device-provisioning)
- [5. Legacy Enterprise Infrastructure](#5-legacy-enterprise-infrastructure)
  - [NIS / NIS+](#nis--nis-unix-legacy)
  - [SIP Services](#sip-services)
- [6. Relay Agent Options](#6-relay-agent-options)
- [7. Service Discovery & Location](#7-service-discovery--location)
- [8. Security & Modern Access Control](#8-security--modern-access-control)
- [9. Historical / Deprecated Options](#9-historical--deprecated-options)
- [10. Vendor & Custom Options](#10-vendor--custom-options)

---

## 1. Core Protocol Operation (Essential)

These options are fundamental to DHCPv6 message exchange and server/client identification. Defined in [RFC 8415](https://datatracker.ietf.org/doc/html/rfc8415).

| Code | Name | Purpose | Specification |
| :---: | :--- | :--- | :--- |
| 1 | CLIENTID | Client DUID identifier | [RFC 8415 §21.2](https://datatracker.ietf.org/doc/html/rfc8415#section-21.2) |
| 2 | SERVERID | Server DUID identifier | [RFC 8415 §21.3](https://datatracker.ietf.org/doc/html/rfc8415#section-21.3) |
| 6 | ORO | Option Request Option — client requests specific options | [RFC 8415 §21.7](https://datatracker.ietf.org/doc/html/rfc8415#section-21.7) |
| 7 | Preference | Server preference value for multi-server selection | [RFC 8415 §21.8](https://datatracker.ietf.org/doc/html/rfc8415#section-21.8) |
| 8 | Elapsed Time | Time since client began current exchange | [RFC 8415 §21.9](https://datatracker.ietf.org/doc/html/rfc8415#section-21.9) |
| 11 | Authentication | DHCP message authentication | [RFC 8415 §21.11](https://datatracker.ietf.org/doc/html/rfc8415#section-21.11) |
| 12 | Server Unicast | Permits client to unicast to server | [RFC 8415 §21.12](https://datatracker.ietf.org/doc/html/rfc8415#section-21.12) |
| 13 | Status Code | Status of a DHCPv6 operation | [RFC 8415 §21.13](https://datatracker.ietf.org/doc/html/rfc8415#section-21.13) |
| 14 | Rapid Commit | Enables two-message exchange | [RFC 8415 §21.14](https://datatracker.ietf.org/doc/html/rfc8415#section-21.14) |
| 19 | Reconfigure Message | Server-initiated reconfiguration | [RFC 8415 §21.19](https://datatracker.ietf.org/doc/html/rfc8415#section-21.19) |
| 20 | Reconfigure Accept | Client signals reconfigure support | [RFC 8415 §21.20](https://datatracker.ietf.org/doc/html/rfc8415#section-21.20) |
| 32 | Information Refresh Time | Validity period for stateless DHCPv6 data | [RFC 8415 §21.23](https://datatracker.ietf.org/doc/html/rfc8415#section-21.23) |

---

## 2. Address & Prefix Assignment

Options governing how IPv6 addresses and prefixes are assigned and tracked.

> [!NOTE]
> DHCPv6 does **not** assign a default gateway. Default route information is delivered via ICMPv6 Router Advertisements (RA) per [RFC 4861](https://datatracker.ietf.org/doc/html/rfc4861).

| Code | Name | Purpose | Specification |
| :---: | :--- | :--- | :--- |
| 3 | IA_NA | Identity Association for Non-temporary Addresses | [RFC 8415 §21.4](https://datatracker.ietf.org/doc/html/rfc8415#section-21.4) |
| 4 | IA_TA | Identity Association for Temporary Addresses | [RFC 8415 §21.5](https://datatracker.ietf.org/doc/html/rfc8415#section-21.5) |
| 5 | IAADDR | IPv6 address within an IA_NA or IA_TA | [RFC 8415 §21.6](https://datatracker.ietf.org/doc/html/rfc8415#section-21.6) |
| 25 | IA_PD | Identity Association for Prefix Delegation | [RFC 8415 §21.21](https://datatracker.ietf.org/doc/html/rfc8415#section-21.21) |
| 26 | IAPREFIX | IPv6 prefix within an IA_PD | [RFC 8415 §21.22](https://datatracker.ietf.org/doc/html/rfc8415#section-21.22) |
| 39 | FQDN | Client fully qualified domain name | [RFC 4704](https://datatracker.ietf.org/doc/html/rfc4704) |

---

## 3. Network Configuration

Options providing DNS, NTP, and other network service configuration to clients.

| Code | Name | Purpose | Specification |
| :---: | :--- | :--- | :--- |
| 23 | DNS Recursive Name Server | IPv6 DNS resolver addresses | [RFC 3646 §3](https://datatracker.ietf.org/doc/html/rfc3646#section-3) |
| 24 | Domain Search List | DNS search domain list | [RFC 3646 §4](https://datatracker.ietf.org/doc/html/rfc3646#section-4) |
| 52 | IPv6 Timezone (POSIX) | Client timezone (POSIX string) | [RFC 4833 §4](https://datatracker.ietf.org/doc/html/rfc4833#section-4) |
| 53 | IPv6 Timezone (TZ DB) | Client timezone (tz database name) | [RFC 4833 §4](https://datatracker.ietf.org/doc/html/rfc4833#section-4) |
| 56 | NTP Server | NTP/SNTP server addresses | [RFC 5908](https://datatracker.ietf.org/doc/html/rfc5908) |

> [!WARNING]
> Option 31 (SNTP Server List) is deprecated. Use Option 56 (NTP Server) per [RFC 5908](https://datatracker.ietf.org/doc/html/rfc5908) in all new deployments.

---

## 4. Boot & Device Provisioning

Required for PXE boot, diskless systems, and automated appliance deployment over IPv6.

| Code | Name | Use | Reference |
| :---: | :--- | :--- | :--- |
| 59 | Boot File URL | URL of the boot file | [RFC 5970 §3.1](https://datatracker.ietf.org/doc/html/rfc5970#section-3.1) |
| 60 | Boot File Parameters | Parameters passed to the boot file | [RFC 5970 §3.2](https://datatracker.ietf.org/doc/html/rfc5970#section-3.2) |
| 61 | Client System Architecture Type | PXE architecture identifier | [RFC 5970 §3.3](https://datatracker.ietf.org/doc/html/rfc5970#section-3.3) |
| 62 | Client Network Interface Identifier | Network interface type and version | [RFC 5970 §3.4](https://datatracker.ietf.org/doc/html/rfc5970#section-3.4) |

---

## 5. Legacy Enterprise Infrastructure

> [!IMPORTANT]
> The options in this section are required only in environments still running older directory or naming systems. They are not needed in modern deployments.

### NIS / NIS+ (Unix Legacy)

| Code | Name | Reference |
| :---: | :--- | :--- |
| 27 | NIS Servers | [RFC 3898 §2](https://datatracker.ietf.org/doc/html/rfc3898#section-2) |
| 28 | NIS+ Servers | [RFC 3898 §3](https://datatracker.ietf.org/doc/html/rfc3898#section-3) |
| 29 | NIS Domain Name | [RFC 3898 §4](https://datatracker.ietf.org/doc/html/rfc3898#section-4) |
| 30 | NIS+ Domain Name | [RFC 3898 §5](https://datatracker.ietf.org/doc/html/rfc3898#section-5) |

### SIP Services

| Code | Name | Reference |
| :---: | :--- | :--- |
| 21 | SIP Server Domain Name List | [RFC 3319 §3](https://datatracker.ietf.org/doc/html/rfc3319#section-3) |
| 22 | SIP Server IPv6 Address List | [RFC 3319 §4](https://datatracker.ietf.org/doc/html/rfc3319#section-4) |

---

## 6. Relay Agent Options

Used by DHCPv6 relay agents to pass subscriber and topology information to the server.

| Code | Name | Purpose | Reference |
| :---: | :--- | :--- | :--- |
| 9 | Relay Message | Encapsulated client message forwarded by relay | [RFC 8415 §21.10](https://datatracker.ietf.org/doc/html/rfc8415#section-21.10) |
| 18 | Interface-ID | Relay agent interface identifier | [RFC 8415 §21.18](https://datatracker.ietf.org/doc/html/rfc8415#section-21.18) |
| 37 | Remote ID | Relay agent remote ID (e.g. circuit info) | [RFC 4649](https://datatracker.ietf.org/doc/html/rfc4649) |
| 38 | Subscriber-ID | Relay agent subscriber identifier | [RFC 4580](https://datatracker.ietf.org/doc/html/rfc4580) |
| 67 | Relay-Supplied Options | Options injected by relay on server's behalf | [RFC 6422](https://datatracker.ietf.org/doc/html/rfc6422) |

---

## 7. Service Discovery & Location

| Code | Name | Reference |
| :---: | :--- | :--- |
| 33 | BCMCS Controller Domain Name List | [RFC 4280 §4](https://datatracker.ietf.org/doc/html/rfc4280#section-4) |
| 34 | BCMCS Controller IPv6 Address | [RFC 4280 §3](https://datatracker.ietf.org/doc/html/rfc4280#section-3) |
| 36 | Civic Location (GEOCONF_CIVIC) | [RFC 4776](https://datatracker.ietf.org/doc/html/rfc4776) |

---

## 8. Security & Modern Access Control

| Code | Name | Purpose | Reference |
| :---: | :--- | :--- | :--- |
| 88 | DNR | Encrypted DNS server discovery | [RFC 9463](https://datatracker.ietf.org/doc/html/rfc9463) |
| 103 | Captive Portal | Guest network login URI | [RFC 8910](https://datatracker.ietf.org/doc/html/rfc8910) |

---

## 9. Historical / Deprecated Options

> [!CAUTION]
> These options are included for completeness and legacy interoperability only. They should not be configured in new deployments.

| Code | Name | Notes | Reference |
| :---: | :--- | :--- | :--- |
| 31 | SNTP Server List | Deprecated — replaced by Option 56 | [RFC 4075](https://datatracker.ietf.org/doc/html/rfc4075) |
| 10 | Relay Agent Remote ID | Obsoleted by Option 37 | [RFC 3315](https://datatracker.ietf.org/doc/html/rfc3315) |

---

## 10. Vendor & Custom Options

| Code | Name | Reference |
| :---: | :--- | :--- |
| 15 | User Class | [RFC 8415 §21.15](https://datatracker.ietf.org/doc/html/rfc8415#section-21.15) |
| 16 | Vendor Class | [RFC 8415 §21.16](https://datatracker.ietf.org/doc/html/rfc8415#section-21.16) |
| 17 | Vendor-specific Information | [RFC 8415 §21.17](https://datatracker.ietf.org/doc/html/rfc8415#section-21.17) |

---

## References

| Standard | Description |
| :--- | :--- |
| [IANA DHCPv6 Parameters](https://www.iana.org/assignments/dhcpv6-parameters/dhcpv6-parameters.xhtml) | Authoritative registry of all DHCPv6 option codes |
| [ISC Kea all-options.json (v6)](https://gitlab.isc.org/isc-projects/kea/-/blob/master/doc/examples/kea6/all-options.json?ref_type=heads) | Kea DHCPv6 supported option reference |
| [RFC 3315](https://datatracker.ietf.org/doc/html/rfc3315) | DHCPv6 (original — obsoleted by RFC 8415) |
| [RFC 3319](https://datatracker.ietf.org/doc/html/rfc3319) | DHCPv6 Options for SIP Servers |
| [RFC 3646](https://datatracker.ietf.org/doc/html/rfc3646) | DNS Configuration Options for DHCPv6 |
| [RFC 3898](https://datatracker.ietf.org/doc/html/rfc3898) | NIS Options for DHCPv6 |
| [RFC 4075](https://datatracker.ietf.org/doc/html/rfc4075) | SNTP Configuration Option for DHCPv6 (deprecated) |
| [RFC 4280](https://datatracker.ietf.org/doc/html/rfc4280) | DHCP Options for BMCS |
| [RFC 4580](https://datatracker.ietf.org/doc/html/rfc4580) | DHCPv6 Relay Agent Subscriber-ID Option |
| [RFC 4649](https://datatracker.ietf.org/doc/html/rfc4649) | DHCPv6 Relay Agent Remote-ID Option |
| [RFC 4704](https://datatracker.ietf.org/doc/html/rfc4704) | DHCPv6 Client FQDN Option |
| [RFC 4776](https://datatracker.ietf.org/doc/html/rfc4776) | Civic Location Option for DHCP |
| [RFC 4833](https://datatracker.ietf.org/doc/html/rfc4833) | Timezone Options for DHCP |
| [RFC 4861](https://datatracker.ietf.org/doc/html/rfc4861) | IPv6 Neighbor Discovery (Router Advertisements) |
| [RFC 5908](https://datatracker.ietf.org/doc/html/rfc5908) | NTP Server Option for DHCPv6 |
| [RFC 5970](https://datatracker.ietf.org/doc/html/rfc5970) | DHCPv6 Options for Network Boot |
| [RFC 6422](https://datatracker.ietf.org/doc/html/rfc6422) | Relay-Supplied DHCP Options |
| [RFC 8415](https://datatracker.ietf.org/doc/html/rfc8415) | DHCPv6 (current standard) |
| [RFC 8910](https://datatracker.ietf.org/doc/html/rfc8910) | Captive-Portal Identification in DHCP |
| [RFC 9463](https://datatracker.ietf.org/doc/html/rfc9463) | DHCP and RA Options for Encrypted DNS Discovery |

---

## Disclaimer

> [!WARNING]
> The ISC Kea DHCPv6 engine configuration and supported option set may change between releases. The option support referenced in this document was verified against the Kea `all-options.json` example at the time of writing. Always consult the [official ISC Kea documentation](https://kea.readthedocs.io/en/latest/) and release notes for your specific version before deploying.