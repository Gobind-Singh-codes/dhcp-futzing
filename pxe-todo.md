

# Lightweight PXE Booting with Alpine Linux & Windows 11

This guide demonstrates how to set up a high-performance Network Boot (PXE) environment using **HTTP instead of TFTP**. By leveraging `libvirt` and `iPXE`, we eliminate the need for complex infrastructure, using only a Python web server to deliver OS images.

## 🚀 Overview
*   **Linux Setup:** Ultra-fast, RAM-disk based Alpine Linux installation.
*   **Windows 11 Setup:** UEFI + TPM 2.0 compliant network installation.
*   **Infrastructure:** Libvirt (KVM), Python3 HTTP Server, and iPXE firmware.

---

## 📋 Prerequisites
Ensure your host machine has the necessary tools:
```bash
# Ubuntu/Debian
sudo apt install libvirt-daemon-system virt-manager virt-install python3 samba swtpm ovmf
```
*   User must be in the `libvirt` group.
*   A working directory: `mkdir -p ~/pxe-lab && cd ~/pxe-lab`

---

## 🛠️ Step 1: Configure the Network (The "Magic")
Libvirt’s default bridge can serve the iPXE boot script URL directly via DHCP.

1.  **Edit the default network:**
    `virsh net-edit default`

2.  **Update the `<dhcp>` section:**
    Add the `bootp` line. This tells any VM to look for its boot instructions at your host's IP.
    ```xml
    <ip address='192.168.122.1' netmask='255.255.255.0'>
      <dhcp>
        <range start='192.168.122.2' end='192.168.122.254'/>
        <!-- This line enables HTTP booting -->
        <bootp file='http://192.168.122.1:8000/boot.ipxe'/>
      </dhcp>
    </ip>
    ```

3.  **Apply changes:**
    ```bash
    virsh net-destroy default
    virsh net-start default
    ```

---

## 🏔️ Scenario A: Alpine Linux (Fastest Setup)
Alpine is ideal for testing because the entire OS fits in a small RAM disk.

### 1. Download Netboot Files
```bash
cd ~/pxe-lab
wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-netboot-3.19.1-x86_64.tar.gz
tar -xvf alpine-netboot-3.19.1-x86_64.tar.gz
```

### 2. Create the iPXE Script
This script tells the VM where to find the kernel over HTTP.
```bash
cat <<EOF > ~/pxe-lab/boot.ipxe
#!ipxe
set base-url http://192.168.122.1:8000
kernel \${base-url}/boot/vmlinuz-virt console=ttyS0 ip=dhcp alpine_repo=https://dl-cdn.alpinelinux.org/alpine/v3.19/main modloop=\${base-url}/boot/modloop-virt quiet
initrd \${base-url}/boot/initramfs-virt
boot
EOF
```

### 3. Launch Alpine
1.  **Start Server:** `python3 -m http.server 8000` (Leave this running).
2.  **Launch VM:**
    ```bash
    virt-install --pxe --network network=default --name alpine-test \
                 --memory 1024 --vcpus 1 --disk size=5 --nographics \
                 --boot menu=on,useserial=on
    ```

---

## 🪟 Scenario B: Windows 11 (Advanced Setup)
Windows requires UEFI, TPM, and a multi-stage boot (HTTP for the loader, SMB for the large image).

### 1. Prepare Infrastructure
You will need a Windows 11 ISO and the [VirtIO Drivers](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso).

```bash
mkdir -p ~/pxe-lab/win11 ~/pxe-lab/virtio
# Mount and copy ISO contents to ~/pxe-lab/win11/
# Download 'wimboot' (the iPXE helper for Windows)
wget https://github.com/ipxe/wimboot/releases/latest/download/wimboot -O ~/pxe-lab/wimboot
```

### 2. Configure Samba (SMB) Share
Windows Setup requires an SMB share to access `install.wim`. 
Add this to `/etc/samba/smb.conf`:
```ini
[install]
   path = /home/YOUR_USER/pxe-lab/win11
   browseable = yes
   read only = yes
   guest ok = yes
```
`sudo systemctl restart smbd`

### 3. Update the iPXE Script for Windows
Overhead the existing `boot.ipxe` with Windows instructions:
```bash
cat <<EOF > ~/pxe-lab/boot.ipxe
#!ipxe
set base-url http://192.168.122.1:8000
kernel \${base-url}/wimboot
initrd \${base-url}/win11/boot/bcd          BCD
initrd \${base-url}/win11/boot/boot.sdi      boot.sdi
initrd \${base-url}/win11/sources/boot.wim  boot.wim
boot
EOF
```

### 4. Launch Windows 11 VM
```bash
virt-install \
  --name win11-pxe \
  --boot loader=/usr/share/OVMF/OVMF_CODE.fd,loader_ro=yes,loader_type=pflash \
  --machine q35 --tpm backend.version=2.0,model=tpm-tis \
  --memory 4096 --vcpus 2 --disk size=64,bus=virtio \
  --network network=default,model=virtio --pxe \
  --os-variant win11 --graphics spice
```

### 5. Finalize inside WinPE
Once the installer boots to the language screen:
1.  Press **Shift + F10**.
2.  Type the following to mount the network drive and load drivers:
    ```cmd
    wpeinit
    net use Z: \\192.168.122.1\install /user:guest
    drvload Z:\virtio\viostor\w11\amd64\viostor.inf
    Z:\setup.exe
    ```

---

## 💡 Pro-Tips for Seemless Usage

| Feature | Tip |
| :--- | :--- |
| **Automation** | Add an `autounattend.xml` to the Windows share root for a "Zero-Touch" install. |
| **Persistence** | For Alpine, add `apkovl=http://.../answers.tar.gz` to the kernel line to automate config. |
| **Clean Up** | Use `virsh destroy <name> && virsh undefine <name> --remove-all-storage` to reset. |
| **Performance** | Always use `virtio` for disk and network models to ensure maximum throughput. |

--- 

