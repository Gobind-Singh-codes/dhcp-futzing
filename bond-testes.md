# ISC DHCP Bond Interface Test Cases — UTM/NGFW
> Components: `isc-dhcp-relay` · `kea-dhcp4` · `kea-dhcp6`  
> Focus: Bond interface quirks, failover behavior, silent failure modes

---

## Legend

| Symbol | Meaning |
|--------|---------|
| 🔴 | High priority — silent failure risk |
| 🟡 | Medium priority |
| 🟢 | Low priority / regression check |
| NEG | Negative test (expect failure) |

---

## Category A — Interface Binding

| TC-ID | Component | Bond Mode | Description | Priority | Pass |
|-------|-----------|-----------|-------------|----------|------|
| A-01 | `kea-dhcp4` | any | Kea binds to logical bond (`bond0`), not slave NIC | 🔴 | - [ ] |
| A-02 | `kea-dhcp4` | any | NEG: Kea binds to slave NIC `eth0` directly — verify silent DHCP death on failover | 🔴 | - [ ] |
| A-03 | `kea-dhcp6` | any | Kea binds to logical bond (`bond0`), not slave NIC | 🔴 | - [ ] |
| A-04 | `isc-dhcp-relay` | any | Relay binds to bond interface as upstream/downstream | 🟡 | - [ ] |
| A-05 | `kea-dhcp4` | any | Sub-interface binding `bond0.10` correctly resolves to VLAN 10 subnet | 🔴 | - [ ] |
| A-06 | `kea-dhcp4` | any | Sub-interface binding `bond0.20` correctly resolves to VLAN 20 subnet | 🔴 | - [ ] |
| A-07 | `kea-dhcp6` | any | Sub-interface binding `bond0.10` resolves to correct DHCPv6 subnet | 🟡 | - [ ] |
| A-08 | `kea-dhcp4` | active-backup | Binding survives slave NIC removal and hot re-add | 🔴 | - [ ] |
| A-09 | `kea-dhcp6` | active-backup | Binding survives slave NIC removal and hot re-add | 🟡 | - [ ] |
| A-10 | `isc-dhcp-relay` | active-backup | Relay interface binding survives slave removal | 🟡 | - [ ] |
| A-11 | `kea-dhcp4` | LACP | Binding stable during LACP renegotiation | 🟡 | - [ ] |
| A-12 | `kea-dhcp4` | any | NEG: `interface` directive in subnet4 mismatches bond name — verify rejected lease | 🟡 | - [ ] |

---

## Category B — Failover & Redundancy

| TC-ID | Component | Bond Mode | Description | Priority | Pass |
|-------|-----------|-----------|-------------|----------|------|
| B-01 | `kea-dhcp4` | active-backup | Pull primary slave — DISCOVER still answered within 1s | 🔴 | - [ ] |
| B-02 | `kea-dhcp4` | active-backup | Pull primary slave — existing leases renew successfully | 🔴 | - [ ] |
| B-03 | `kea-dhcp6` | active-backup | Pull primary slave — SOLICIT still answered | 🔴 | - [ ] |
| B-04 | `isc-dhcp-relay` | active-backup | Pull primary slave — relay continues forwarding DISCOVER | 🔴 | - [ ] |
| B-05 | `kea-dhcp4` | LACP | Degrade one LACP member — no packet loss on DISCOVER | 🟡 | - [ ] |
| B-06 | `kea-dhcp4` | LACP | NEG: `balance-alb` mode — capture DISCOVER on all slaves, verify none dropped by Kea raw socket | 🔴 | - [ ] |
| B-07 | `kea-dhcp6` | LACP | SOLICIT/ADVERTISE roundtrip stable during LACP member degradation | 🟡 | - [ ] |
| B-08 | `kea-dhcp4` | any | Full bond down + restore — verify Kea resumes without restart | 🟡 | - [ ] |
| B-09 | `kea-dhcp6` | any | Full bond down + restore — verify Kea resumes without restart | 🟡 | - [ ] |
| B-10 | `isc-dhcp-relay` | any | Full bond down + restore — relay resumes forwarding | 🟡 | - [ ] |
| B-11 | `kea-dhcp4` | active-backup | MAC address in lease DB is consistent pre/post failover | 🔴 | - [ ] |
| B-12 | `kea-dhcp4` | balance-alb | MAC address drift detected — verify lease DB behavior (dup or reject) | 🔴 | - [ ] |
| B-13 | `kea-dhcp4` | any | Rapid failover loop (5x in 60s) — no lease DB corruption | 🟡 | - [ ] |

---

## Category C — Relay Specific (`isc-dhcp-relay`)

| TC-ID | Component | Bond Mode | Description | Priority | Pass |
|-------|-----------|-----------|-------------|----------|------|
| C-01 | `isc-dhcp-relay` | any | `giaddr` reflects bond IP, not slave NIC IP | 🔴 | - [ ] |
| C-02 | `isc-dhcp-relay` | active-backup | `giaddr` still reflects bond IP after slave failover | 🔴 | - [ ] |
| C-03 | `isc-dhcp-relay` | any | NEG: asymmetric routing on bond — relay response dropped, verify and log | 🔴 | - [ ] |
| C-04 | `isc-dhcp-relay` | any | Relay response routing back through correct bond interface | 🟡 | - [ ] |
| C-05 | `isc-dhcp-relay` | any | Relay operates correctly on `bond0.10` sub-interface (VLAN 10) | 🟡 | - [ ] |
| C-06 | `isc-dhcp-relay` | any | Relay operates correctly on `bond0.20` sub-interface (VLAN 20) | 🟡 | - [ ] |
| C-07 | `isc-dhcp-relay` | any | Multi-VLAN relay: `bond0.10` and `bond0.20` simultaneously — no cross-VLAN lease bleed | 🔴 | - [ ] |
| C-08 | `isc-dhcp-relay` | any | Relay correctly appends Option 82 circuit-id reflecting bond, not slave | 🟡 | - [ ] |
| C-09 | `isc-dhcp-relay` | any | NEG: relay upstream points to wrong interface — verify OFFER never reaches client | 🟢 | - [ ] |
| C-10 | `isc-dhcp-relay` | LACP | `giaddr` consistent across all LACP members during load distribution | 🟡 | - [ ] |

---

## Category D — DHCPv6 Specific (`kea-dhcp6`)

| TC-ID | Component | Bond Mode | Description | Priority | Pass |
|-------|-----------|-----------|-------------|----------|------|
| D-01 | `kea-dhcp6` | active-backup | Link-local (`fe80::`) address stable on bond across failover | 🔴 | - [ ] |
| D-02 | `kea-dhcp6` | balance-alb | Link-local address does NOT shift to slave MAC post-failover | 🔴 | - [ ] |
| D-03 | `kea-dhcp6` | any | DUID persists across bond failover — no DUID regeneration | 🔴 | - [ ] |
| D-04 | `kea-dhcp6` | any | NEG: DUID changes after failover — verify Kea handles rebind correctly | 🔴 | - [ ] |
| D-05 | `kea-dhcp6` | any | SLAAC co-existence — DHCPv6 leases not duplicated with SLAAC addresses | 🟡 | - [ ] |
| D-06 | `kea-dhcp6` | any | Prefix delegation (IA_PD) stable across bond failover | 🟡 | - [ ] |
| D-07 | `kea-dhcp6` | any | SOLICIT → ADVERTISE → REQUEST → REPLY full flow over bond | 🟡 | - [ ] |
| D-08 | `kea-dhcp6` | any | RENEW accepted after bond failover without full re-handshake | 🟡 | - [ ] |
| D-09 | `kea-dhcp6` | any | REBIND initiated when RENEW fails — client recovers cleanly | 🟡 | - [ ] |
| D-10 | `kea-dhcp6` | any | Multicast traffic (`ff02::1:2`) correctly received on bond interface | 🔴 | - [ ] |
| D-11 | `kea-dhcp6` | LACP | Multicast not dropped by LACP load balancer during member degradation | 🔴 | - [ ] |

---

## Category E — Lease Integrity

| TC-ID | Component | Bond Mode | Description | Priority | Pass |
|-------|-----------|-----------|-------------|----------|------|
| E-01 | `kea-dhcp4` | active-backup | No duplicate leases issued during failover switchover | 🔴 | - [ ] |
| E-02 | `kea-dhcp4` | any | Lease renewal accepted after MAC drift (when `match-client-id true`) | 🔴 | - [ ] |
| E-03 | `kea-dhcp4` | any | Lease renewal rejected after MAC drift (when `match-client-id false`) | 🔴 | - [ ] |
| E-04 | `kea-dhcp4` | any | Lease DB consistent after bond interface flap | 🟡 | - [ ] |
| E-05 | `kea-dhcp6` | any | No duplicate IA_NA leases across failover | 🔴 | - [ ] |
| E-06 | `kea-dhcp6` | any | Lease DB consistent after bond interface flap | 🟡 | - [ ] |
| E-07 | `kea-dhcp4` | any | Expired leases correctly reclaimed after bond restore | 🟢 | - [ ] |
| E-08 | `kea-dhcp4` | any | NEG: lease DB write failure during failover — Kea logs error, does not silently corrupt | 🟡 | - [ ] |
| E-09 | `kea-dhcp4` | any | `hwaddr` value in lease file matches bond virtual MAC, not slave MAC | 🔴 | - [ ] |
| E-10 | `kea-dhcp6` | any | DUID in lease file stable across multiple failover cycles | 🔴 | - [ ] |

---

## Category F — Socket Mode (`kea-dhcp4` / `kea-dhcp6`)

| TC-ID | Component | Bond Mode | Description | Priority | Pass |
|-------|-----------|-----------|-------------|----------|------|
| F-01 | `kea-dhcp4` | active-backup | Raw socket mode — DISCOVER received and answered correctly | 🟡 | - [ ] |
| F-02 | `kea-dhcp4` | LACP / balance-alb | NEG: Raw socket mode — packet capture confirms no missed DISCOVERs on non-primary slave | 🔴 | - [ ] |
| F-03 | `kea-dhcp4` | LACP | UDP socket mode as fallback — functional parity with raw socket | 🟡 | - [ ] |
| F-04 | `kea-dhcp4` | balance-alb | UDP socket mode — DISCOVER/OFFER/REQUEST/ACK full flow verified | 🟡 | - [ ] |
| F-05 | `kea-dhcp6` | active-backup | Raw socket multicast receive on bond — SOLICIT not dropped | 🟡 | - [ ] |
| F-06 | `kea-dhcp6` | LACP | Raw socket multicast — no SOLICIT drops under member degradation | 🔴 | - [ ] |
| F-07 | `kea-dhcp4` | any | Packet capture (`tcpdump bond0`) confirms all 4 DORA stages visible on bond, not slave | 🟡 | - [ ] |
| F-08 | `kea-dhcp4` | any | Switching from raw to UDP socket mode does not require lease DB wipe | 🟢 | - [ ] |

---

## Summary Scorecard

| Category | Total TCs | 🔴 High | 🟡 Medium | 🟢 Low |
|----------|-----------|---------|----------|--------|
| A — Interface Binding | 12 | 6 | 5 | 1 |
| B — Failover & Redundancy | 13 | 7 | 6 | 0 |
| C — Relay Specific | 10 | 5 | 4 | 1 |
| D — DHCPv6 Specific | 11 | 5 | 6 | 0 |
| E — Lease Integrity | 10 | 6 | 3 | 1 |
| F — Socket Mode | 8 | 3 | 4 | 1 |
| **Total** | **64** | **32** | **28** | **4** |

---

## Recommended Execution Order (First Pass)

Hit these 10 first — they cover the highest-risk silent failure modes:

- [ ] **F-02** — Raw socket on LACP/balance-alb (most likely silent drop)
- [ ] **C-01** — `giaddr` source interface check
- [ ] **C-03** — Asymmetric routing on relay
- [ ] **B-11** — MAC consistency pre/post failover
- [ ] **B-12** — MAC drift on balance-alb
- [ ] **E-01** — Duplicate lease detection
- [ ] **E-09** — `hwaddr` in lease = bond MAC not slave MAC
- [ ] **D-01** — Link-local stability on bond failover
- [ ] **D-03** — DUID persistence across failover
- [ ] **D-10** — Multicast received on bond

---

*Generated for: ISC DHCP Relay + Kea DHCPv4 + Kea DHCPv6 — UTM/NGFW bond interface validation*
