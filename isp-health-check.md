# ISP Failover — Research & Implementation TODO

## Phase 1 — Understand Your ISP Setup

- [ ] Confirm connection type for each ISP (PPPoE / DHCP / IPoE / Static)
- [ ] Check if either ISP is behind CGNAT (verify with `curl ifconfig.me` vs gateway IP)
- [ ] Check if either ISP offers dual-stack (IPv4 + IPv6)
- [ ] Confirm if either ISP provides a static IP or if it's dynamic
- [ ] Check if PPPoE ISP responds to LCP echo keepalives (some don't)
- [ ] Identify actual WAN interface names on BPi (DSA ports vs logical interfaces)
- [ ] Confirm which ISP has real inbound reachability (matters for dead man's ping)

---

## Phase 2 — Study ISP Internals

- [ ] Understand residential vs leased line differences (DHCP/PPPoE vs static, no SLA vs SLA)
- [ ] Understand last mile failure vs upstream/backbone failure and why they need different probes
- [ ] Understand CGNAT — how it breaks inbound, port forwarding, and external probing
- [ ] Understand PPPoE session lifecycle — LCP, NCP, why session can appear up while broken
- [ ] Understand IPoE — how it differs from plain DHCP despite looking similar
- [ ] Understand dual-stack failure modes — v4 and v6 can fail independently
- [ ] Read RFC 1812 — foundational IP router requirements
- [ ] Read FRRouting multihoming docs — understand what problems exist even if not using FRR
- [ ] Browse RIPE NCC labs blog — practical ISP-adjacent failover and multihoming articles
- [ ] Browse NANOG mailing list archives — real ISP engineer failure scenario discussions

---

## Phase 3 — Health Check Design

- [ ] Understand why gateway ping alone is insufficient (upstream can die, gateway stays up)
- [ ] Understand why probing must be interface-bound (`ping -I <iface>`) not just default route
- [ ] Design multi-target probe strategy (8.8.8.8, 1.1.1.1, 9.9.9.9 — different AS paths)
- [ ] Decide between ICMP ping vs TCP SYN probe (TCP tests fuller stack)
- [ ] Add DNS resolution as a canary probe (ISPs often break DNS first)
- [ ] Design state machine (HEALTHY → FAILING → DEAD → RECOVERING → HEALTHY)
- [ ] Define failure thresholds (N consecutive failures to declare dead, M successes to recover)
- [ ] Handle flapping — never switch on a single failure
- [ ] Design per-ISP profiles (PPPoE gets LCP state check, DHCP gets lease renewal watch, etc.)
- [ ] Factor IPv6 health checking independently from IPv4 if dual-stack

---

## Phase 4 — BPi-Specific Concerns

- [ ] Understand MT7988A / MT7986A DSA switch fabric — identify correct logical interfaces for WAN
- [ ] Verify hardware NAT offload doesn't silently drop health check probe traffic
- [ ] Verify XDP support level per interface (native vs generic) on custom kernel
- [ ] Confirm BPF JIT is enabled in kernel config (`CONFIG_BPF_JIT=y`)
- [ ] Test that `ping -I <waniface>` behaves correctly through DSA hierarchy
- [ ] Confirm TCP SYN probes source correctly from the right interface

---

## Phase 5 — Failover Script

- [ ] Write health check function (multi-target, interface-bound, majority vote)
- [ ] Write per-ISP state machine
- [ ] Write `initialize_state()` — re-probes on startup, never assumes prior state
- [ ] Write switchover hook that manipulates your existing PBR rules (nftables / ip rule)
- [ ] Handle PPPoE reconnect differently from DHCP route re-add in recovery logic
- [ ] Log all state transitions to journald (`logger -t isp-failover`)
- [ ] Handle dual-ISP-down scenario explicitly (both dead at once)

---

## Phase 6 — Set and Forget Hardening

- [ ] Write systemd unit with `Restart=always` and `RestartSec=5`
- [ ] Enable and test service survives reboot
- [ ] Implement dead man's ping — board periodically contacts VPS, VPS alerts if it stops
- [ ] Test full failover end-to-end with ISP1 physically disconnected
- [ ] Test recovery end-to-end with ISP1 reconnected
- [ ] Test daemon restart mid-failover — does it re-assert correct state cleanly?
- [ ] Verify `journalctl -t isp-failover` gives clean readable history

---

## Future / Nice To Have

- [ ] Investigate BFD — understand why it requires ISP cooperation and when it applies
- [ ] Understand BGP multihoming — the "production" version of what you're building
- [ ] Understand PI (Provider Independent) address space — why datacenters don't have the IP-change problem
- [ ] Consider load balancing across both ISPs when both healthy (not just failover)
