#!/usr/bin/env bash
# =============================================================================
# dhcp_load_test.sh — Concurrent Multi-Namespace DHCP Load Tester
#
# Spins up N network namespaces per interface/VLAN simultaneously, each running
# a real DHCP client that acquires, holds, and renews leases — simulating a
# realistic pool of active clients rather than one-at-a-time sequential tests.
#
# Usage:
#   sudo ./dhcp_load_test.sh [OPTIONS]
#
# Options:
#   -i IFACE[.VLAN],...   Interfaces/VLANs to test (default: eth0)
#   -n COUNT              Namespaces (clients) per interface (default: 10)
#   -d SECONDS            Test duration in seconds (default: 120)
#   -r SECONDS            Renewal interval in seconds (default: 30)
#   -c SECONDS            Client acquire concurrency batch size (default: 5)
#   -t SECONDS            Per-client acquire timeout (default: 15)
#   -l FILE               Log file path (default: /tmp/dhcp_load_test.log)
#   -s                    Show live stats dashboard
#   -k                    Kill any previous test run and clean up
#   -h                    Show this help
#
# Requirements:
#   dhclient OR udhcpc, iproute2 (ip), vconfig or ip link (for VLANs), bash 4+
# =============================================================================

set -euo pipefail

# ── Defaults ──────────────────────────────────────────────────────────────────
INTERFACES="eth0"
NS_PER_IFACE=10
DURATION=120
RENEW_INTERVAL=30
BATCH_SIZE=5
ACQUIRE_TIMEOUT=15
LOG_FILE="/tmp/dhcp_load_test.log"
SHOW_STATS=false
KILL_PREV=false
STATE_DIR="/tmp/dhcp_load_test_state"
DHCP_CLIENT=""          # auto-detected
SCRIPT_PID=$$

# ── Colour codes ──────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

# ── Logging ───────────────────────────────────────────────────────────────────
log() {
    local level="$1"; shift
    local ts; ts=$(date '+%H:%M:%S')
    local line="[$ts][$level] $*"
    echo "$line" >> "$LOG_FILE"
    case "$level" in
        INFO)  echo -e "${CYAN}${line}${RESET}" ;;
        OK)    echo -e "${GREEN}${line}${RESET}" ;;
        WARN)  echo -e "${YELLOW}${line}${RESET}" ;;
        ERROR) echo -e "${RED}${line}${RESET}" ;;
        STAT)  echo -e "${BOLD}${line}${RESET}" ;;
    esac
}

die() { log ERROR "$*"; exit 1; }

# ── Usage ─────────────────────────────────────────────────────────────────────
usage() {
    grep '^#' "$0" | grep -v '#!/' | sed 's/^# \{0,2\}//'
    exit 0
}

# ── Arg parsing ───────────────────────────────────────────────────────────────
while getopts "i:n:d:r:c:t:l:skh" opt; do
    case "$opt" in
        i) INTERFACES="$OPTARG" ;;
        n) NS_PER_IFACE="$OPTARG" ;;
        d) DURATION="$OPTARG" ;;
        r) RENEW_INTERVAL="$OPTARG" ;;
        c) BATCH_SIZE="$OPTARG" ;;
        t) ACQUIRE_TIMEOUT="$OPTARG" ;;
        l) LOG_FILE="$OPTARG" ;;
        s) SHOW_STATS=true ;;
        k) KILL_PREV=true ;;
        h) usage ;;
        *) die "Unknown option. Use -h for help." ;;
    esac
done

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -eq 0 ]] || die "Must run as root (needs namespace + veth creation)"

# ── Kill previous run ─────────────────────────────────────────────────────────
kill_previous() {
    log WARN "Killing previous test run and cleaning up..."
    # Kill tracked pids
    if [[ -f "${STATE_DIR}/pids" ]]; then
        while read -r pid; do
            kill "$pid" 2>/dev/null || true
        done < "${STATE_DIR}/pids"
    fi
    # Remove all namespaces created by us
    ip netns list 2>/dev/null | grep '^dhcptest_' | awk '{print $1}' | while read -r ns; do
        ip netns del "$ns" 2>/dev/null || true
    done
    # Remove veth pairs (they disappear with the namespace)
    rm -rf "$STATE_DIR"
    log OK "Cleanup done."
}

if $KILL_PREV; then
    kill_previous
    exit 0
fi

# ── Detect DHCP client ────────────────────────────────────────────────────────
detect_dhcp_client() {
    if command -v dhclient &>/dev/null; then
        DHCP_CLIENT="dhclient"
    elif command -v udhcpc &>/dev/null; then
        DHCP_CLIENT="udhcpc"
    else
        die "No DHCP client found. Install dhclient (isc-dhcp-client) or udhcpc (busybox)."
    fi
    log INFO "DHCP client: ${DHCP_CLIENT}"
}

# ── Shared state ──────────────────────────────────────────────────────────────
mkdir -p "$STATE_DIR"/{leases,pids,status}
: > "$STATE_DIR/pids"
declare -A COUNTERS  # per-iface: acquired, failed, renewed, released

init_counters() {
    local iface="$1"
    echo 0 > "${STATE_DIR}/status/${iface}_acquired"
    echo 0 > "${STATE_DIR}/status/${iface}_failed"
    echo 0 > "${STATE_DIR}/status/${iface}_renewed"
    echo 0 > "${STATE_DIR}/status/${iface}_released"
}

counter_inc() {
    local key="$1"
    local file="${STATE_DIR}/status/${key}"
    local val; val=$(cat "$file" 2>/dev/null || echo 0)
    echo $((val + 1)) > "$file"
}

counter_get() {
    cat "${STATE_DIR}/status/${1}" 2>/dev/null || echo 0
}

# ── VLAN setup ────────────────────────────────────────────────────────────────
ensure_vlan_iface() {
    local base_iface="$1"
    local vlan_id="$2"
    local vlan_iface="${base_iface}.${vlan_id}"

    if ! ip link show "$vlan_iface" &>/dev/null; then
        log INFO "Creating VLAN interface: ${vlan_iface}"
        ip link add link "$base_iface" name "$vlan_iface" type vlan id "$vlan_id"
        ip link set "$vlan_iface" up
    fi
    echo "$vlan_iface"
}

# ── Namespace + veth setup ────────────────────────────────────────────────────
create_namespace() {
    local ns="$1"       # e.g. dhcptest_eth0_003
    local veth_h="$2"   # host side veth, e.g. veth_eth0_003
    local veth_ns="$3"  # ns side veth,   e.g. vpeer_eth0_003
    local bridge="$4"   # bridge to attach host side to

    # Create namespace
    ip netns add "$ns" 2>/dev/null || true

    # Create veth pair
    ip link add "$veth_h" type veth peer name "$veth_ns" 2>/dev/null || true

    # Move peer into namespace
    ip link set "$veth_ns" netns "$ns"

    # Attach host side to bridge (connect client to network segment)
    ip link set "$veth_h" master "$bridge" 2>/dev/null || \
        ip link set "$veth_h" up   # if no bridge, bring it up directly

    ip link set "$veth_h" up

    # Bring up loopback + veth inside namespace
    ip netns exec "$ns" ip link set lo up
    ip netns exec "$ns" ip link set "$veth_ns" up

    # Unique MAC per namespace to ensure the server sees distinct clients
    local mac
    mac=$(printf '52:54:00:%02x:%02x:%02x' \
        $((RANDOM % 256)) $((RANDOM % 256)) $((RANDOM % 256)))
    ip netns exec "$ns" ip link set "$veth_ns" address "$mac"

    log INFO "NS ${ns}: created (mac=${mac}, veth=${veth_h}<->${veth_ns})"
}

destroy_namespace() {
    local ns="$1"
    local veth_h="$2"

    ip netns del "$ns" 2>/dev/null || true
    ip link del "$veth_h" 2>/dev/null || true
}

# ── DHCP acquire (run inside namespace) ──────────────────────────────────────
run_dhclient_in_ns() {
    local ns="$1"
    local iface_ns="$2"   # veth name inside the namespace
    local lease_file="${STATE_DIR}/leases/${ns}.lease"
    local pid_file="${STATE_DIR}/leases/${ns}.pid"

    case "$DHCP_CLIENT" in
        dhclient)
            ip netns exec "$ns" dhclient \
                -v \
                -timeout "$ACQUIRE_TIMEOUT" \
                -lf "$lease_file" \
                -pf "$pid_file" \
                "$iface_ns" \
                >> "${STATE_DIR}/leases/${ns}.log" 2>&1
            ;;
        udhcpc)
            ip netns exec "$ns" udhcpc \
                -i "$iface_ns" \
                -n \
                -T "$ACQUIRE_TIMEOUT" \
                -t 3 \
                -x hostname:"client-${ns}" \
                -p "$pid_file" \
                -q \
                >> "${STATE_DIR}/leases/${ns}.log" 2>&1
            ;;
    esac
}

# ── Renewal loop (background, long-running) ───────────────────────────────────
renewal_loop() {
    local ns="$1"
    local iface_ns="$2"
    local iface_key="$3"
    local end_time="$4"
    local pid_file="${STATE_DIR}/leases/${ns}.pid"

    while [[ $(date +%s) -lt $end_time ]]; do
        sleep "$RENEW_INTERVAL"
        [[ $(date +%s) -ge $end_time ]] && break

        if [[ "$DHCP_CLIENT" == "dhclient" && -f "$pid_file" ]]; then
            local dpid; dpid=$(cat "$pid_file" 2>/dev/null || echo "")
            if [[ -n "$dpid" ]] && kill -0 "$dpid" 2>/dev/null; then
                # Send SIGUSR1 to trigger renew
                kill -USR1 "$dpid" 2>/dev/null && {
                    counter_inc "${iface_key}_renewed"
                    log INFO "NS ${ns}: lease renewal triggered (dhclient pid=${dpid})"
                }
            else
                # dhclient exited — re-acquire
                log WARN "NS ${ns}: dhclient gone, re-acquiring..."
                if run_dhclient_in_ns "$ns" "$iface_ns"; then
                    counter_inc "${iface_key}_renewed"
                fi
            fi
        elif [[ "$DHCP_CLIENT" == "udhcpc" ]]; then
            # udhcpc is fire-and-forget; re-run it to renew
            if run_dhclient_in_ns "$ns" "$iface_ns"; then
                counter_inc "${iface_key}_renewed"
                log INFO "NS ${ns}: lease renewed (udhcpc)"
            fi
        fi
    done
}

# ── Single client lifecycle ───────────────────────────────────────────────────
client_lifecycle() {
    local ns="$1"
    local veth_h="$2"
    local veth_ns="$3"
    local bridge="$4"
    local iface_key="$5"
    local end_time="$6"

    create_namespace "$ns" "$veth_h" "$veth_ns" "$bridge"

    # Acquire lease
    if run_dhclient_in_ns "$ns" "$veth_ns"; then
        counter_inc "${iface_key}_acquired"
        log OK "NS ${ns}: lease ACQUIRED"

        # Extract IP for display
        local ip
        ip=$(ip netns exec "$ns" ip -4 addr show "$veth_ns" 2>/dev/null \
             | awk '/inet /{print $2}' | head -1 || echo "?")
        echo "$ip" > "${STATE_DIR}/leases/${ns}.ip"
        log OK "NS ${ns}: IP=${ip}"

        # Hold and renew until test ends
        renewal_loop "$ns" "$veth_ns" "$iface_key" "$end_time"

        # Release lease gracefully
        case "$DHCP_CLIENT" in
            dhclient)
                ip netns exec "$ns" dhclient -r "$veth_ns" \
                    >> "${STATE_DIR}/leases/${ns}.log" 2>&1 || true
                ;;
            udhcpc)
                local pid_file="${STATE_DIR}/leases/${ns}.pid"
                [[ -f "$pid_file" ]] && kill -USR2 "$(cat "$pid_file")" 2>/dev/null || true
                ;;
        esac
        counter_inc "${iface_key}_released"
        log INFO "NS ${ns}: lease RELEASED"
    else
        counter_inc "${iface_key}_failed"
        log WARN "NS ${ns}: acquire FAILED (timeout or no server)"
    fi

    destroy_namespace "$ns" "$veth_h"
}

# ── Bridge creation (one per interface) ──────────────────────────────────────
ensure_bridge() {
    local iface="$1"
    local bridge="br_dhcptest_${iface//[^a-zA-Z0-9]/_}"

    if ! ip link show "$bridge" &>/dev/null; then
        ip link add name "$bridge" type bridge 2>/dev/null || true
        ip link set "$iface" master "$bridge" 2>/dev/null || true
        ip link set "$bridge" up
        log INFO "Bridge ${bridge} created, ${iface} attached"
    fi
    echo "$bridge"
}

# ── Stats display ─────────────────────────────────────────────────────────────
show_dashboard() {
    local ifaces=("$@")
    local end_time; end_time=$(cat "${STATE_DIR}/end_time")

    while [[ $(date +%s) -lt $end_time ]]; do
        clear
        local now; now=$(date +%s)
        local remaining=$(( end_time - now ))

        echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
        echo -e "${BOLD}║         DHCP LOAD TEST — Live Dashboard              ║${RESET}"
        echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
        printf "${BOLD}  Time remaining: %02d:%02d  |  Clients/iface: %d${RESET}\n" \
            $((remaining/60)) $((remaining%60)) "$NS_PER_IFACE"
        echo ""
        printf "${BOLD}  %-18s %8s %8s %8s %8s${RESET}\n" \
            "Interface" "Acquired" "Failed" "Renewed" "Released"
        echo "  ──────────────────────────────────────────────────────"

        local total_acq=0 total_fail=0 total_ren=0 total_rel=0
        for iface in "${ifaces[@]}"; do
            local key="${iface//[^a-zA-Z0-9]/_}"
            local acq; acq=$(counter_get "${key}_acquired")
            local fail; fail=$(counter_get "${key}_failed")
            local ren;  ren=$(counter_get "${key}_renewed")
            local rel;  rel=$(counter_get "${key}_released")
            printf "  %-18s ${GREEN}%8s${RESET} ${RED}%8s${RESET} ${CYAN}%8s${RESET} ${YELLOW}%8s${RESET}\n" \
                "$iface" "$acq" "$fail" "$ren" "$rel"
            total_acq=$((total_acq + acq))
            total_fail=$((total_fail + fail))
            total_ren=$((total_ren + ren))
            total_rel=$((total_rel + rel))
        done

        echo "  ──────────────────────────────────────────────────────"
        printf "  %-18s ${GREEN}%8s${RESET} ${RED}%8s${RESET} ${CYAN}%8s${RESET} ${YELLOW}%8s${RESET}\n" \
            "TOTAL" "$total_acq" "$total_fail" "$total_ren" "$total_rel"
        echo ""

        # Active leases
        local active
        active=$(ls "${STATE_DIR}/leases/"*.ip 2>/dev/null | wc -l || echo 0)
        echo -e "  Active leases holding: ${GREEN}${active}${RESET}"
        echo ""
        echo -e "  Log: ${LOG_FILE}   |   State: ${STATE_DIR}"
        sleep 2
    done
}

# ── Cleanup trap ──────────────────────────────────────────────────────────────
cleanup() {
    log WARN "Caught signal — cleaning up all namespaces..."
    jobs -p | xargs -r kill 2>/dev/null || true

    ip netns list 2>/dev/null | grep '^dhcptest_' | awk '{print $1}' | while read -r ns; do
        ip netns del "$ns" 2>/dev/null || true
    done
    # Remove bridges we created
    ip link list type bridge 2>/dev/null | grep 'br_dhcptest_' | awk -F: '{print $2}' \
        | tr -d ' ' | while read -r br; do
        ip link del "$br" 2>/dev/null || true
    done

    log OK "Cleanup complete."
}
trap cleanup INT TERM EXIT

# ═════════════════════════════════════════════════════════════════════════════
# MAIN
# ═════════════════════════════════════════════════════════════════════════════
detect_dhcp_client

IFS=',' read -ra IFACE_LIST <<< "$INTERFACES"

log STAT "═══════════════════════════════════════════════════"
log STAT " DHCP Load Test starting"
log STAT " Interfaces : ${INTERFACES}"
log STAT " Clients    : ${NS_PER_IFACE} per interface"
log STAT " Duration   : ${DURATION}s"
log STAT " Renew every: ${RENEW_INTERVAL}s"
log STAT " Batch size : ${BATCH_SIZE} concurrent spawns"
log STAT " DHCP client: ${DHCP_CLIENT}"
log STAT "═══════════════════════════════════════════════════"

END_TIME=$(( $(date +%s) + DURATION ))
echo "$END_TIME" > "${STATE_DIR}/end_time"

# ── Per-interface setup + concurrent client spawn ─────────────────────────────
ALL_IFACE_KEYS=()

for RAW_IFACE in "${IFACE_LIST[@]}"; do
    RAW_IFACE="${RAW_IFACE// /}"   # trim whitespace

    # Resolve VLAN if specified (e.g. eth0.100)
    if [[ "$RAW_IFACE" == *.* ]]; then
        BASE="${RAW_IFACE%%.*}"
        VID="${RAW_IFACE##*.}"
        IFACE=$(ensure_vlan_iface "$BASE" "$VID")
    else
        IFACE="$RAW_IFACE"
        ip link show "$IFACE" &>/dev/null || die "Interface ${IFACE} not found"
        ip link set "$IFACE" up
    fi

    IFACE_KEY="${IFACE//[^a-zA-Z0-9]/_}"
    ALL_IFACE_KEYS+=("$IFACE")
    init_counters "$IFACE_KEY"

    BRIDGE=$(ensure_bridge "$IFACE")

    log INFO "Spawning ${NS_PER_IFACE} client namespaces on ${IFACE} (bridge: ${BRIDGE})"

    BATCH_JOBS=()

    for (( idx=1; idx<=NS_PER_IFACE; idx++ )); do
        NS_NAME="dhcptest_${IFACE_KEY}_$(printf '%03d' "$idx")"
        VETH_H="veth_${IFACE_KEY}_$(printf '%03d' "$idx")"
        VETH_NS="vpeer_${IFACE_KEY}_$(printf '%03d' "$idx")"

        # Truncate names to kernel 15-char limit
        VETH_H="${VETH_H:0:15}"
        VETH_NS="${VETH_NS:0:15}"

        (
            client_lifecycle \
                "$NS_NAME" "$VETH_H" "$VETH_NS" "$BRIDGE" \
                "$IFACE_KEY" "$END_TIME"
        ) &

        local_pid=$!
        echo "$local_pid" >> "${STATE_DIR}/pids"
        BATCH_JOBS+=("$local_pid")

        # Throttle: wait for batch to avoid flooding the DHCP server
        if (( idx % BATCH_SIZE == 0 )); then
            log INFO "[${IFACE}] Batch of ${BATCH_SIZE} spawned — waiting for acquire phase..."
            # Give the current batch a moment to start their DISCOVER before next wave
            sleep 1
        fi
    done

    log OK "[${IFACE}] All ${NS_PER_IFACE} clients launched"
done

# ── Optional live dashboard ───────────────────────────────────────────────────
if $SHOW_STATS; then
    show_dashboard "${ALL_IFACE_KEYS[@]}" &
    DASH_PID=$!
    echo "$DASH_PID" >> "${STATE_DIR}/pids"
fi

# ── Wait for all client jobs to finish ───────────────────────────────────────
log INFO "Waiting for all clients to complete their lifecycle (up to ${DURATION}s)..."
wait

# ── Final summary ─────────────────────────────────────────────────────────────
$SHOW_STATS && kill "$DASH_PID" 2>/dev/null || true

echo ""
log STAT "═══════════════════════════════════════════════════"
log STAT " FINAL RESULTS"
log STAT "═══════════════════════════════════════════════════"

GRAND_ACQ=0; GRAND_FAIL=0; GRAND_REN=0; GRAND_REL=0

for IFACE in "${ALL_IFACE_KEYS[@]}"; do
    KEY="${IFACE//[^a-zA-Z0-9]/_}"
    ACQ=$(counter_get "${KEY}_acquired")
    FAIL=$(counter_get "${KEY}_failed")
    REN=$(counter_get "${KEY}_renewed")
    REL=$(counter_get "${KEY}_released")
    TOTAL=$(( ACQ + FAIL ))
    [[ $TOTAL -eq 0 ]] && PCT=0 || PCT=$(( ACQ * 100 / TOTAL ))

    log STAT " ${IFACE}: acquired=${ACQ} failed=${FAIL} renewed=${REN} released=${REL} success=${PCT}%"

    GRAND_ACQ=$(( GRAND_ACQ + ACQ ))
    GRAND_FAIL=$(( GRAND_FAIL + FAIL ))
    GRAND_REN=$(( GRAND_REN + REN ))
    GRAND_REL=$(( GRAND_REL + REL ))
done

GRAND_TOTAL=$(( GRAND_ACQ + GRAND_FAIL ))
[[ $GRAND_TOTAL -eq 0 ]] && GRAND_PCT=0 || GRAND_PCT=$(( GRAND_ACQ * 100 / GRAND_TOTAL ))

log STAT "───────────────────────────────────────────────────"
log STAT " TOTAL: acquired=${GRAND_ACQ} failed=${GRAND_FAIL} renewed=${GRAND_REN} released=${GRAND_REL}"
log STAT " Overall success rate: ${GRAND_PCT}%"
log STAT "═══════════════════════════════════════════════════"
log INFO "Full logs: ${LOG_FILE}"
log INFO "Lease details: ${STATE_DIR}/leases/"