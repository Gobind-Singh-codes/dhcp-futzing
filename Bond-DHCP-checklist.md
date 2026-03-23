# Bond Interface DHCP Acquisition — Lab Prep

## The Core Problem

Linux bonding and DHCP have fundamentally different mental models about what a "device" is. DHCP operates at Layer 2 — it identifies clients by MAC address. Bonding also operates at Layer 2, but it creates a logical interface over one or more physical NICs, each of which has its own MAC. Depending on the bonding mode, the MAC presented to the network — and therefore to Kea — can be fixed, rotating, or per-slave. This is the root of every weird thing you are about to observe.

> **Key insight:** Kea assigns leases per MAC. If the MAC bond0 presents changes (failover, mode switch, ALB rewrite), Kea will either assign a second lease, let the old one expire, or see a DISCOVER it thinks is a new client. Watch the lease CSV throughout.

---

## Mental Model: DORA Revisited

You know the four-packet handshake. What matters here is where the client MAC appears:

- **DISCOVER** — client broadcasts, fills `chaddr` with its MAC
- **OFFER** — server responds to `chaddr`, uses it to select subnet/pool
- **REQUEST** — client retransmits `chaddr` to confirm
- **ACK** — server binds the lease to that `chaddr` and records it

With bonding, the "client" is `bond0`. The MAC in `chaddr` is whatever `bond0`'s address register currently says. You're not testing whether bonding works — you're testing what `bond0` looks like from Kea's perspective in each mode.

---

## Mode-by-Mode Breakdown

| Mode | Name | MAC Kea sees | Gotcha |
|------|------|--------------|--------|
| 0 | balance-rr | First slave MAC | Round-robins frames — switch must handle or packets arrive out of order |
| 1 | active-backup | Active slave MAC, pinned at bond creation | Failover does NOT change bond0's MAC by default — Kea stays clean |
| 2 | balance-xor | XOR-selected slave (deterministic) | Which slave wins depends on XOR hash policy — can be surprising |
| 3 | broadcast | First slave MAC, but all slaves TX | Kea may see duplicate DISCOVERs — it ignores dupes for the same `xid`, but watch for double-OFFER edge cases |
| 4 | 802.3ad | Bond's own permanent MAC (LACP) | Needs a real LACP peer — a plain Linux bridge won't do it. Skip or fake it. |
| 5 | balance-tlb | Current TX slave's MAC (rotates adaptively) | TLB rotates TX slave based on load — if it rotates mid-DORA, OFFER and REQUEST disagree |
| 6 | balance-alb | Per-slave MAC (ALB rewrites ARP source per slave) | Each slave answers ARPs with its own MAC — Kea will likely create 2+ leases |

> ⚠️ Modes 5 and 6 are where things get genuinely weird. Budget extra time. Mode 6 may fool Kea into thinking you have multiple clients — you're not imagining it if you see two leases.

---

## The Three Things That Will Confuse You

### 1. bond0's MAC is not always what you think

Run this before every test:

```bash
cat /sys/class/net/bond0/address
cat /sys/class/net/bond0/bonding/active_slave
```

In mode 6 (ALB), the address above is the "primary" MAC but slaves may respond to ARP with different MACs. The real test is what appears in tcpdump on the Kea side:

```bash
tcpdump -i eth0 -e -n port 67 or port 68
```

The `-e` flag shows Ethernet frame headers. In mode 6, the MAC in the Ethernet header and in `chaddr` may differ — that's the ALB rewrite.

### 2. Kea's lease file is the ground truth

Don't trust `ip addr show`. Don't trust `dhclient` logs alone. The canonical answer to "what did the DHCP server think happened" is:

```bash
cat /var/lib/kea/kea-leases4.csv
```

Columns that matter: `address`, `hwaddr` (the MAC Kea bound to), `expire`, `state`. A second lease appearing for what should be one client is not a Kea bug — your bond presented a different MAC. Expected in modes 5 and 6.

### 3. Failover and lease retention in mode 1

When you bring down the active slave in mode 1:

- `bond0`'s MAC does **not** change — it's pinned to the primary slave's MAC at creation, not the active slave
- The new active slave starts TX-ing under the same bond MAC
- From Kea's perspective, the client went quiet for a moment and came back — no new DISCOVER
- `dhclient` may or may not RENEW depending on T1 timer state

Where this breaks: if you destroyed and recreated `bond0` with the backup slave as primary, the MAC will differ and Kea treats it as a new client. Test failover *within* an existing bond, not teardown/recreate.

---

## What to Watch on Each Side

**Kea side — run these before each mode test:**

```bash
# Terminal 1: live DHCP packets with MACs
tcpdump -i eth0 -e -n port 67 or port 68

# Terminal 2: live lease table
watch -n2 cat /var/lib/kea/kea-leases4.csv

# Terminal 3: Kea control socket
echo '{"command":"lease4-get-all"}' | socat - UNIX-CONNECT:/run/kea/kea4-ctrl-socket
```

**DUT side — after each mode setup:**

```bash
ip link show bond0
cat /sys/class/net/bond0/address
cat /sys/class/net/bond0/bonding/active_slave
dhclient -v bond0
ip addr show bond0
```

---

## Edge Cases Worth Hitting

**Failover mid-handshake (mode 1)** — bring down the active slave between DISCOVER and ACK. Does `dhclient` retry? Does the MAC in REQUEST match the one in DISCOVER? Kea may still have the OFFER buffered.

**Short lease + bond flap (modes 1 and 5)** — set `valid-lifetime: 60` in Kea, then flap a slave during RENEW. This is where you're most likely to see lease exhaustion or stale entries.

**Mode 6 ARP storm** — bring up `bond0` in mode 6 and count how many distinct `hwaddr` entries appear in Kea's lease table. With 2 slaves you'll likely see 2 leases. Expected behavior — document it, don't fight it.

**Runtime mode change** — you can't change bonding mode without destroying and recreating `bond0`. Don't try. Always `ip link del bond0` between tests. Residual state from mode 6's ARP table rewrite can poison subsequent results.

> ⚠️ Between every test: `ip link del bond0`, flush dhclient leases (`rm /var/lib/dhcp/dhclient.leases`), and delete the old Kea lease by MAC via the control socket. Otherwise you're testing renewal behavior, not initial acquisition.

---

## Recommended Test Order

Go from simplest to most chaotic:

1. Mode 1 (active-backup) — baseline, most predictable
2. Mode 0 (balance-rr) — simple, confirm switch handles round-robin
3. Mode 2 (balance-xor) — deterministic, verify XOR hash policy
4. Mode 3 (broadcast) — check duplicate DISCOVER handling
5. Mode 5 (balance-tlb) — watch for mid-handshake MAC rotation
6. Mode 6 (balance-alb) — multiple leases expected, confirm count
7. Mode 4 (802.3ad) — only if you can fake an LACP peer, otherwise skip

---

## Quick Reference

| Command | Purpose |
|---------|---------|
| `ip link add bond0 type bond mode <mode>` | Create bond |
| `ip link set eth0 master bond0` | Add slave |
| `ip link set bond0 up && dhclient -v bond0` | Bring up and acquire DHCP |
| `cat /sys/class/net/bond0/address` | Check bond MAC |
| `cat /sys/class/net/bond0/bonding/active_slave` | Check active slave |
| `ip link set eth0 down` | Simulate failover |
| `ip link del bond0` | Teardown |
| `rm /var/lib/dhcp/dhclient.leases` | Clear dhclient lease cache |
| `tcpdump -i eth0 -e -n port 67 or port 68` | Sniff DHCP with MACs |
| `watch -n2 cat /var/lib/kea/kea-leases4.csv` | Watch Kea leases live |

---

> The real goal isn't finding bugs — it's understanding exactly what Kea sees for each bonding mode. Once you have that mental map, you can reason about any DHCP failure in production without guessing.