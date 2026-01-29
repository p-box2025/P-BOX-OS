# P-BOX OS

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.0.3-blue" alt="Version">
  <img src="https://img.shields.io/badge/Platform-AMD64%20%7C%20ARM64%20%7C%20ARMhf-green" alt="Platform">
  <img src="https://img.shields.io/badge/Base-Debian%2012-orange" alt="Base">
  <img src="https://img.shields.io/badge/License-MIT-brightgreen" alt="License">
</p>

**P-BOX OS** is a lightweight, pre-configured operating system image designed for network proxy and routing management. Built on Debian 12 (Bookworm), it provides an intuitive web-based control panel for managing proxy services including **mihomo (Clash.Meta)** and **sing-box**.

---

## 🚀 Quick Install

### One-Line Install (Linux/macOS)

```bash
curl -fsSL https://raw.githubusercontent.com/p-box2025/P-BOX-OS/main/install.sh | bash
```

### Manual Download

Download from [Releases](https://github.com/p-box2025/P-BOX-OS/releases/latest):

| Architecture | File | Platform |
|--------------|------|----------|
| AMD64 (x86_64) | `pbox-os-amd64-*.img.gz` | PC, Server, VM |
| ARM64 (aarch64) | `pbox-os-arm64-*.img.gz` | RPi 4/5, R4S, R5S |
| ARMhf (armv7) | `pbox-os-armhf-*.img.gz` | RPi 3, R2S |

---

## 💿 One-Click Deploy

After downloading, use the smart deployment script:

```bash
# Linux/macOS
chmod +x deploy-vm.sh
./deploy-vm.sh

# Windows
# Double-click deploy-vm.bat
```

### Supported Platforms

| Platform | Version | Disk Format |
|----------|---------|-------------|
| **Proxmox VE** | 6.x - 9.x | raw/qcow2 |
| **VMware ESXi** | 6.5 - 8.x | vmdk |
| **VMware Workstation** | 14 - 17 | vmdk |
| **VirtualBox** | 5.x - 7.2 | vdi |
| **Hyper-V** | 2016 - 2025 | vhdx |

### Default VM Settings

| Setting | Default |
|---------|---------|
| CPU Cores | 4 |
| Memory | 2048 MB |
| Boot Mode | BIOS (Legacy) |

---

## 🔑 Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| SSH | `root` | `pbox123` |
| Web Panel | - | `pbox123` |

> ⚠️ **Security Notice**: Please change the default password after first login!

---

## 🌐 Access

After the VM boots:

1. **Get IP Address** - The system automatically obtains an IP via DHCP
2. **SSH Login** - `ssh root@<device-ip>` (password: `pbox123`)
3. **Terminal Menu** - Type `pbox` to open the interactive management menu
4. **Web Panel** - Open `https://<device-ip>` in your browser

---

## 📦 Manual Installation

### Write to Physical Disk

```bash
# Linux/macOS
gunzip -c pbox-os-amd64-*.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

# Windows: Use balenaEtcher, Rufus, or Win32DiskImager
```

### Proxmox VE (Manual)

```bash
# Decompress
gunzip pbox-os-amd64-*.img.gz

# Create VM and import disk
qm create 100 --name pbox --memory 2048 --cores 4 --net0 virtio,bridge=vmbr0
qm importdisk 100 pbox-os-amd64-*.img local-lvm --format raw
qm set 100 --scsi0 local-lvm:vm-100-disk-0 --boot order=scsi0
qm start 100
```

### VMware ESXi (Manual)

```bash
# Convert to VMDK
gunzip pbox-os-amd64-*.img.gz
qemu-img convert -f raw -O vmdk pbox-os-amd64-*.img pbox.vmdk

# Upload to ESXi datastore and create VM via web UI
```

### VirtualBox (Manual)

```bash
# Convert to VDI
gunzip pbox-os-amd64-*.img.gz
VBoxManage convertfromraw pbox-os-amd64-*.img pbox.vdi --format VDI

# Create VM in VirtualBox using the VDI file
```

### Hyper-V (Manual)

```powershell
# Convert to VHDX (requires qemu-img)
qemu-img convert -f raw -O vhdx pbox-os-amd64-*.img pbox.vhdx

# Create VM
New-VM -Name "pbox" -MemoryStartupBytes 2GB -Generation 1 -VHDPath "pbox.vhdx"
Set-VMProcessor -VMName "pbox" -Count 4
Start-VM -Name "pbox"
```

### Raspberry Pi / ARM Devices

1. Download the appropriate `.img.gz` for your device
2. Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or [balenaEtcher](https://www.balena.io/etcher/)
3. Write to SD card (16GB+ recommended)
4. Insert SD card and power on
5. Connect via Ethernet

---

## ✨ Features

- 🌐 **Web Control Panel** - Modern, responsive web UI
- 🚀 **Multi-Core Support** - mihomo (Clash.Meta) and sing-box
- 🔄 **Subscription Management** - Auto-update proxy subscriptions
- 📊 **Traffic Monitoring** - Real-time connection statistics
- 🌍 **GeoIP & Rules** - Built-in GeoIP database and rule sets
- 🔒 **Secure by Default** - Pre-configured firewall and SSL
- ⚡ **BBR Enabled** - TCP BBR congestion control
- 🔧 **Easy Deployment** - One-click deployment scripts

---

## 📁 File Structure

```
/opt/pbox/
├── bin/           # Proxy core binaries
├── configs/       # Configuration files
├── data/          # Runtime data and logs
├── geoip/         # GeoIP databases
├── rulesets/      # Proxy rule sets
└── web/           # Web panel files
```

---

## ❓ Troubleshooting

### Cannot access web panel

```bash
# Check services
systemctl status pbox
systemctl status nginx

# Restart services
systemctl restart pbox nginx
```

### Network not working

```bash
# Check network
ip addr
ip route

# Restart networking
systemctl restart networking
```

### Check logs

```bash
# View P-BOX logs
journalctl -u pbox -f

# View system logs
dmesg | tail -50
```

---

## 📜 License

This project is licensed under the **MIT License**.

---

## 🔗 Links

- **GitHub**: https://github.com/p-box2025/P-BOX-OS
- **Releases**: https://github.com/p-box2025/P-BOX-OS/releases
- **Telegram**: https://t.me/+8d9PNOt-w6BkNzU1

---

<p align="center">Made with ❤️ by P-BOX Team</p>
