# P-BOX OS

<p align="center">
  <img src="https://img.shields.io/badge/版本-1.0.3-blue" alt="版本">
  <img src="https://img.shields.io/badge/平台-AMD64%20%7C%20ARM64%20%7C%20ARMhf-green" alt="平台">
  <img src="https://img.shields.io/badge/基于-Debian%2012-orange" alt="基于">
  <img src="https://img.shields.io/badge/许可证-MIT-brightgreen" alt="许可证">
</p>

**P-BOX OS** 是一个轻量级、预配置的操作系统镜像，专为网络代理和路由管理设计。基于 Debian 12 (Bookworm) 构建，提供直观的 Web 控制面板，支持 **mihomo (Clash.Meta)** 和 **sing-box** 代理核心。

---

## 🚀 一键安装

### Linux / macOS

```bash
curl -fsSL https://raw.githubusercontent.com/p-box2025/P-BOX-OS/main/install.sh | bash
```

### 手动下载

从 [Releases](https://github.com/p-box2025/P-BOX-OS/releases/latest) 下载：

| 架构 | 文件 | 适用平台 |
|------|------|----------|
| AMD64 (x86_64) | `pbox-os-amd64-*.img.gz` | PC、服务器、虚拟机 |
| ARM64 (aarch64) | `pbox-os-arm64-*.img.gz` | 树莓派4/5、R4S、R5S |
| ARMhf (armv7) | `pbox-os-armhf-*.img.gz` | 树莓派3、R2S |

---

## 💿 一键部署

下载后，使用智能部署脚本：

```bash
# Linux/macOS
chmod +x deploy-vm.sh
./deploy-vm.sh

# Windows
双击 deploy-vm.bat
```

### 支持的平台

| 平台 | 版本 | 磁盘格式 |
|------|------|----------|
| **Proxmox VE** | 6.x - 9.x | raw/qcow2 |
| **VMware ESXi** | 6.5 - 8.x | vmdk |
| **VMware Workstation** | 14 - 17 | vmdk |
| **VirtualBox** | 5.x - 7.2 | vdi |
| **Hyper-V** | 2016 - 2025 | vhdx |

### 默认虚拟机配置

| 配置项 | 默认值 |
|--------|--------|
| CPU 核心 | 4 |
| 内存 | 2048 MB |
| 启动模式 | BIOS (传统) |

---

## 🔑 默认凭据

| 服务 | 用户名 | 密码 |
|------|--------|------|
| SSH | `root` | `pbox123` |
| Web 面板 | - | `pbox123` |

> ⚠️ **安全提示**：首次登录后请立即修改默认密码！

---

## 🌐 访问方式

系统启动后：

1. **获取 IP** - 系统自动通过 DHCP 获取 IP 地址
2. **SSH 登录** - `ssh root@<设备IP>` (密码: `pbox123`)
3. **终端菜单** - 输入 `pbox` 打开交互式管理菜单
4. **Web 面板** - 浏览器打开 `https://<设备IP>`

---

## 📦 手动安装

### 写入物理磁盘

```bash
# Linux/macOS
gunzip -c pbox-os-amd64-*.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

# Windows: 使用 balenaEtcher、Rufus 或 Win32DiskImager
```

### Proxmox VE (手动)

```bash
# 解压
gunzip pbox-os-amd64-*.img.gz

# 创建虚拟机并导入磁盘
qm create 100 --name pbox --memory 2048 --cores 4 --net0 virtio,bridge=vmbr0
qm importdisk 100 pbox-os-amd64-*.img local-lvm --format raw
qm set 100 --scsi0 local-lvm:vm-100-disk-0 --boot order=scsi0
qm start 100
```

### VMware ESXi (手动)

```bash
# 转换为 VMDK
gunzip pbox-os-amd64-*.img.gz
qemu-img convert -f raw -O vmdk pbox-os-amd64-*.img pbox.vmdk

# 上传到 ESXi 数据存储并通过 Web UI 创建虚拟机
```

### VirtualBox (手动)

```bash
# 转换为 VDI
gunzip pbox-os-amd64-*.img.gz
VBoxManage convertfromraw pbox-os-amd64-*.img pbox.vdi --format VDI

# 在 VirtualBox 中使用该 VDI 文件创建虚拟机
```

### Hyper-V (手动)

```powershell
# 转换为 VHDX (需要 qemu-img)
qemu-img convert -f raw -O vhdx pbox-os-amd64-*.img pbox.vhdx

# 创建虚拟机
New-VM -Name "pbox" -MemoryStartupBytes 2GB -Generation 1 -VHDPath "pbox.vhdx"
Set-VMProcessor -VMName "pbox" -Count 4
Start-VM -Name "pbox"
```

### 树莓派 / ARM 设备

1. 下载对应设备的 `.img.gz` 文件
2. 使用 [Raspberry Pi Imager](https://www.raspberrypi.com/software/) 或 [balenaEtcher](https://www.balena.io/etcher/)
3. 写入 SD 卡 (建议 16GB+)
4. 插入 SD 卡并开机
5. 通过网线连接

---

## ✨ 功能特性

- 🌐 **Web 控制面板** - 现代化响应式界面
- 🚀 **多核心支持** - mihomo (Clash.Meta) 和 sing-box
- 🔄 **订阅管理** - 自动更新代理订阅
- 📊 **流量监控** - 实时连接统计
- 🌍 **GeoIP 规则** - 内置 GeoIP 数据库和规则集
- 🔒 **安全默认** - 预配置防火墙和 SSL
- ⚡ **BBR 加速** - TCP BBR 拥塞控制
- 🔧 **一键部署** - 智能部署脚本

---

## 📁 目录结构

```
/opt/pbox/
├── bin/           # 代理核心二进制文件
├── configs/       # 配置文件
├── data/          # 运行时数据和日志
├── geoip/         # GeoIP 数据库
├── rulesets/      # 代理规则集
└── web/           # Web 面板文件
```

---

## ❓ 常见问题

### 无法访问 Web 面板

```bash
# 检查服务状态
systemctl status pbox
systemctl status nginx

# 重启服务
systemctl restart pbox nginx
```

### 网络不通

```bash
# 检查网络配置
ip addr
ip route

# 重启网络
systemctl restart networking
```

### 查看日志

```bash
# 查看 P-BOX 日志
journalctl -u pbox -f

# 查看系统日志
dmesg | tail -50
```

---

## 📜 许可证

本项目基于 **MIT 许可证** 开源。

---

## 🔗 链接

- **GitHub**: https://github.com/p-box2025/P-BOX-OS
- **发布页**: https://github.com/p-box2025/P-BOX-OS/releases
- **Telegram**: https://t.me/+8d9PNOt-w6BkNzU1

---

<p align="center">Made with ❤️ by P-BOX Team</p>
