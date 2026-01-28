# P-BOX OS

<p align="center">
  <img src="https://img.shields.io/badge/Version-1.0.0-blue.svg" alt="Version">
  <img src="https://img.shields.io/badge/Platform-x86__64%20|%20ARM64%20|%20ARMhf-green.svg" alt="Platform">
  <img src="https://img.shields.io/badge/Base-Debian%2012-red.svg" alt="Base">
  <img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="License">
</p>

**P-BOX OS** is a lightweight, pre-configured operating system image designed for network proxy and routing management. Built on Debian 12 (Bookworm), it provides an intuitive web-based control panel for managing proxy services including **mihomo (Clash.Meta)** and **sing-box**.

---

## ✨ Features

- 🌐 **Web Control Panel** - Modern, responsive web UI for easy management
- 🚀 **Multi-Core Support** - Supports mihomo (Clash.Meta) and sing-box proxy cores
- 🔄 **Subscription Management** - Auto-update proxy subscriptions
- 📊 **Traffic Monitoring** - Real-time connection and traffic statistics
- 🌍 **GeoIP & Rules** - Built-in GeoIP database and rule sets
- 🔒 **Secure by Default** - Pre-configured firewall and SSL certificates
- ⚡ **BBR Enabled** - TCP BBR congestion control for better performance
- 🔧 **Easy Deployment** - Ready-to-use images for multiple platforms

---

## 📦 Supported Platforms

### x86_64 / AMD64
| Format | Description | Use Case |
|--------|-------------|----------|
| `.img.gz` | Raw disk image (compressed) | Physical machines, generic VMs |
| `.qcow2` | QEMU Copy-On-Write | Proxmox VE, KVM, QEMU |
| `.vmdk` | VMware Virtual Disk | VMware ESXi, Workstation, Fusion |
| `.vdi` | VirtualBox Disk Image | Oracle VirtualBox |
| `.vhdx` | Hyper-V Virtual Disk | Microsoft Hyper-V |
| `.ova` | Open Virtual Appliance | VMware, VirtualBox (import) |
| `.iso` | Live/Install ISO | ESXi, bare metal installation |

### ARM64 / AArch64
| Device | Format | Notes |
|--------|--------|-------|
| Generic ARM64 | `.img.gz` | For generic ARM64 servers/VMs |
| Raspberry Pi 4 | `.img.gz` | Tested on RPi 4B |
| Raspberry Pi 5 | `.img.gz` | Tested on RPi 5 |
| FriendlyElec R4S | `.img.gz` | NanoPi R4S |
| FriendlyElec R5S | `.img.gz` | NanoPi R5S |
| Phicomm N1 | `.img.gz` | S905D based |

### ARMhf / ARM32
| Device | Format | Notes |
|--------|--------|-------|
| Raspberry Pi 3 | `.img.gz` | RPi 3B/3B+ |
| FriendlyElec R2S | `.img.gz` | NanoPi R2S |

---

## 🚀 Quick Start

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| SSH | `root` | `pbox123` |
| Web Panel | - | `pbox123` |

> ⚠️ **Security Notice**: Please change the default password after first login!

### Web Panel Access

After booting, access the web panel at:
```
https://<device-ip>
```

---

## 💿 Installation Guide

### Method 1: Write to Disk (Recommended)

#### Linux / macOS
```bash
# Decompress and write to disk
gunzip -c pbox-os-*.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

# Sync and safely remove
sync
```

#### Windows
Use one of the following tools:
- [balenaEtcher](https://www.balena.io/etcher/) (Recommended)
- [Rufus](https://rufus.ie/)
- [Win32DiskImager](https://sourceforge.net/projects/win32diskimager/)

### Method 2: Convert to VM Format

#### Proxmox VE (PVE)
```bash
# Decompress
gunzip pbox-os-*.img.gz

# Import to VM
qm importdisk <VMID> pbox-os-*.img local-lvm

# Or convert to qcow2 first
qemu-img convert -f raw -O qcow2 pbox-os-*.img pbox-os.qcow2
```

#### VMware ESXi
```bash
# Convert to VMDK
gunzip pbox-os-*.img.gz
qemu-img convert -f raw -O vmdk pbox-os-*.img pbox-os.vmdk

# Upload to ESXi datastore via web UI or SCP
scp pbox-os.vmdk root@esxi-host:/vmfs/volumes/datastore1/
```

#### VirtualBox
```bash
# Convert to VDI
gunzip pbox-os-*.img.gz
qemu-img convert -f raw -O vdi pbox-os-*.img pbox-os.vdi

# Or use VBoxManage
VBoxManage convertfromraw pbox-os-*.img pbox-os.vdi --format VDI
```

#### Hyper-V
```bash
# Convert to VHDX
gunzip pbox-os-*.img.gz
qemu-img convert -f raw -O vhdx pbox-os-*.img pbox-os.vhdx
```

### Method 3: Device-Specific Instructions

#### Raspberry Pi 3/4/5
1. Download the appropriate `.img.gz` file
2. Use [Raspberry Pi Imager](https://www.raspberrypi.com/software/) or balenaEtcher
3. Write to SD card (16GB+ recommended)
4. Insert SD card and power on

#### FriendlyElec R2S/R4S/R5S
1. Download the appropriate `.img.gz` file
2. Write to TF/SD card using balenaEtcher
3. Insert card and power on
4. Connect via Ethernet

#### Phicomm N1
1. First, boot into Armbian from USB
2. Write P-BOX image to USB drive
3. Use `armbian-install` to flash to eMMC (optional)

---

## 🔧 Post-Installation

### 1. Change Default Password
```bash
passwd root
```

### 2. Configure Network
Edit `/etc/network/interfaces` or use the web panel.

### 3. Access Web Panel
Open `https://<device-ip>` in your browser.

### 4. Import Subscription
1. Go to "Subscriptions" in web panel
2. Add your proxy subscription URL
3. Click "Update" to fetch nodes

---

## 📁 File Structure

```
/opt/pbox/
├── bin/                 # Proxy core binaries (mihomo, sing-box)
├── configs/             # Configuration files
├── data/                # Runtime data and logs
├── geoip/               # GeoIP databases
├── rulesets/            # Proxy rule sets
└── web/                 # Web panel files

/etc/pbox/
└── config.json          # Main configuration
```

---

## 🔐 Security Recommendations

1. **Change default password immediately**
2. **Enable firewall rules** for your network
3. **Use HTTPS** for web panel access
4. **Regular updates** - Keep the system updated
5. **Backup configurations** before major changes

---

## ❓ Troubleshooting

### Cannot access web panel
```bash
# Check if services are running
systemctl status pbox
systemctl status nginx

# Restart services
systemctl restart pbox
systemctl restart nginx
```

### Network not working
```bash
# Check network configuration
ip addr
ip route

# Restart networking
systemctl restart networking
```

### Proxy not working
```bash
# Check proxy core logs
journalctl -u pbox -f

# Test configuration
/opt/pbox/bin/mihomo -t -f /opt/pbox/configs/config.yaml
```

---

## 📄 Changelog

### v1.0.0 (2026-01-28)
- Initial release
- Support for x86_64, ARM64, ARMhf architectures
- Web control panel
- mihomo and sing-box support
- GeoIP and rule sets included

---

## 📜 License

This project is licensed under the MIT License.

---

## 🔗 Links

- [GitHub Repository](https://github.com/pbox-project/pbox-os)
- [Documentation](https://docs.pbox.dev)
- [Telegram Group](https://t.me/pbox2026)

---

<p align="center">
  Made with ❤️ by P-BOX Team
</p>
