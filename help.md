---

# 📑 Dossier: Enterprise PXE & Provisioning Lab
**Subject:** Orchestrating Multi-OS Booting and VoIP Provisioning in Isolated Environments.

---

## 🏗️ Phase 1: The Foundation (Network Layer)
In an isolated environment, your Kea server acts as the "Source of Truth." 

### 1. The Static Anchor (`systemd-networkd`)
Instead of relying on Libvirt’s management, we use a manual `.network` configuration to bind the Kea server.
*   **The Goal:** A predictable, dual-stack environment.
*   **The Trap:** Avoid "RA Flapping." If Libvirt and your VM both send Router Advertisements (RAs), PXE clients will hang.
*   **Recommendation:** Set `Managed=no` in your RA section unless you are specifically testing DHCPv6. Let IPv4 handle the heavy lifting while IPv6 provides connectivity.

### 2. Service Synchronization
Kea must wait for the network. In your SystemD unit, ensure `After=network-online.target` is set to prevent Kea from crashing if it tries to bind to an interface that isn't ready yet.

---

## 🧠 Phase 2: The Orchestration (DHCP Logic)
The "Magic" of modern PXE isn't the file transfer; it's the **Client Classification** in Kea.

### 1. The iPXE Handshake (Chainloading)
Modern NICs are "dumb." iPXE is "smart." We use a two-stage boot to gain HTTP capabilities:
*   **Stage 1 (UEFI):** Client identifies as `HTTPClient` (Option 60). Kea sends `ipxe.efi`.
*   **Stage 2 (iPXE):** Client identifies as `iPXE` (Option 77). Kea sends the final `boot.ipxe` script.

### 2. The Protocols (Option 66 & 67)
*   **Legacy (TFTP):** Best for Stage 1 (tiny files, universal compatibility).
*   **Modern (HTTP):** Best for Stage 2 (massive OS images, high speed). 
*   **Kea Tip:** Always provide the full URL (e.g., `http://192.168.22.1/boot.ipxe`) in Option 67 to bypass the limitations of TFTP-centric Option 66.

---

## 🏔️ Phase 3: The Payload (OS Specifics)

### 1. Alpine Linux (The Speedster)
*   **Method:** Pure RAM-disk.
*   **Workflow:** iPXE fetches the `vmlinuz` (kernel) and `initramfs` via HTTP. The OS runs entirely in memory, making it the perfect "test-fire" for your PXE logic.

### 2. Windows 11 (The Heavyweight)
*   **Complexity:** Requires UEFI, TPM 2.0, and VirtIO drivers.
*   **The SMB Bridge:** Windows Setup (WinPE) cannot easily stream the 5GB `install.wim` over HTTP. It expects an SMB share. Your lab must host a Samba share to "finalize" the install.

---

## 📞 Phase 4: Beyond the OS (VoIP Simulation)
You can simulate an entire office of IP Phones without buying hardware.

*   **The Simulation:** Use a tiny Alpine VM. Tell its DHCP client to "lie" about its identity:
    *   `udhcpc -V "Cisco Systems, Inc. IP Phone CP-8841"`
*   **The Kea Response:** Use a client-class matching `Option 60` to send back **Option 150** (Cisco TFTP) or **Option 43**. 
*   **Why Simulation is Better:** You can `tcpdump` the virtual bridge and see exactly how the phone requests its XML configuration—something that is physically difficult to do with a locked-down hardware phone.

---

## ⚠️ Phase 5: Critical Shortfalls (The "Watch-Outs")

| Shortfall | Impact | Mitigation |
| :--- | :--- | :--- |
| **DHCPv6 Priority** | UEFI might wait 60s for an IPv6 PXE reply. | Set `RouterPreference=low` in your `.network` file. |
| **MTU Mismatch** | Large files (Windows `.wim`) hang during transfer. | Ensure host bridge and VM NIC both use MTU 1500. |
| **Socket Binding** | Kea fails to start if the interface isn't up. | Use `systemd-networkd-wait-online.service`. |
| **SMB Credentials** | WinPE `net use` fails on isolated networks. | Use `guest ok = yes` in Samba for the install share. |

---

## 🚀 Final Summary for the Architect
When you move to **Relay behavior (v4/v6)**:
1.  **Relay Agent Information (Option 82):** Kea will start seeing `circuit-id` and `remote-id`. You can use these to assign different OS images based on *which virtual switch port* the VM is plugged into.
2.  **Shared Subnets:** Kea allows you to define a `shared-network` where multiple subnets exist on one relay link—critical for multi-tenant lab testing.
3.  **The Goal:** You are moving from "Static PXE" (one file for everyone) to "Dynamic Provisioning" (different files based on MAC, Vendor, or Port).

**Next Step:** Once your Relay lab is stable, try to make Kea hand out different `boot.ipxe` scripts based on the **Relay Agent's IP address**.