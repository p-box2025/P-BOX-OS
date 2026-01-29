#!/bin/bash
# ============================================================
# P-BOX OS 一键部署脚本 (Linux/macOS)
# 支持: PVE (6.x-8.x), ESXi (6.5-8.x), VMware Workstation (14-17), 
#       VirtualBox (5.x-7.x), Hyper-V (2016-2022/Win10/11)
# ============================================================

# 严格模式
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# 全局变量
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IMAGE_FILE=""
TEMP_FILES=()
PLATFORM=""
DISK_FORMAT=""

# 清理函数
cleanup() {
    for file in "${TEMP_FILES[@]}"; do
        [[ -f "$file" ]] && rm -f "$file"
    done
}
trap cleanup EXIT

# 日志函数
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          P-BOX OS 一键部署脚本 v2.0                        ║"
echo "║          支持 PVE / ESXi / VMware / VirtualBox / Hyper-V   ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# ==================== 检查依赖 ====================
check_dependencies() {
    local missing=()
    
    # sshpass 仅远程部署需要，这里只检查基础依赖
    command -v gzip &>/dev/null || missing+=("gzip")
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "缺少依赖: ${missing[*]}"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "请运行: brew install ${missing[*]}"
        else
            echo "请运行: sudo apt install ${missing[*]}"
        fi
        exit 1
    fi
}

# ==================== 智能查找镜像文件 ====================
find_image() {
    log_info "查找镜像文件..."
    
    # 使用 nullglob 避免无匹配时返回模式本身
    shopt -s nullglob
    local gz_files=("$SCRIPT_DIR"/*.img.gz)
    shopt -u nullglob
    
    if [[ ${#gz_files[@]} -eq 0 ]]; then
        log_error "未找到镜像文件 (*.img.gz)"
        echo "请确保镜像文件与此脚本在同一目录: $SCRIPT_DIR"
        exit 1
    fi
    
    echo ""
    if [[ ${#gz_files[@]} -eq 1 ]]; then
        IMAGE_FILE="${gz_files[0]}"
        log_success "找到镜像: $(basename "$IMAGE_FILE")"
    else
        echo -e "${YELLOW}找到多个镜像文件:${NC}"
        echo ""
        for i in "${!gz_files[@]}"; do
            local filename=$(basename "${gz_files[$i]}")
            local filesize=$(du -h "${gz_files[$i]}" 2>/dev/null | cut -f1)
            echo "  $((i+1)). $filename ($filesize)"
        done
        echo ""
        
        while true; do
            read -p "请选择 [1-${#gz_files[@]}]: " choice
            if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#gz_files[@]} ]]; then
                IMAGE_FILE="${gz_files[$((choice-1))]}"
                break
            else
                log_warn "无效选择，请输入 1-${#gz_files[@]} 之间的数字"
            fi
        done
        log_success "已选择: $(basename "$IMAGE_FILE")"
    fi
}

# ==================== 选择虚拟化平台 ====================
select_platform() {
    echo ""
    echo -e "${CYAN}请选择虚拟化平台:${NC}"
    echo ""
    echo "  1. Proxmox VE (PVE 6.x-8.x)"
    echo "  2. VMware ESXi (6.5-8.x)"
    echo "  3. VMware Workstation / Fusion (本地)"
    echo "  4. VirtualBox (本地)"
    echo "  5. Hyper-V (本地/远程)"
    echo ""
    
    while true; do
        read -p "请选择 [1-5]: " platform_choice
        case $platform_choice in
            1) PLATFORM="pve"; DISK_FORMAT="raw"; break ;;
            2) PLATFORM="esxi"; DISK_FORMAT="vmdk"; break ;;
            3) PLATFORM="vmware"; DISK_FORMAT="vmdk"; break ;;
            4) PLATFORM="virtualbox"; DISK_FORMAT="vdi"; break ;;
            5) PLATFORM="hyperv"; DISK_FORMAT="vhdx"; break ;;
            *) log_warn "无效选择，请输入 1-5" ;;
        esac
    done
    
    log_success "已选择: $PLATFORM (磁盘格式: $DISK_FORMAT)"
}

# ==================== 检查远程部署依赖 ====================
check_remote_dependencies() {
    if ! command -v sshpass &>/dev/null; then
        log_error "远程部署需要 sshpass"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "请运行: brew install hudochenkov/sshpass/sshpass"
        else
            echo "请运行: sudo apt install sshpass"
        fi
        exit 1
    fi
}

# ==================== 输入连接信息 ====================
input_connection_info() {
    check_remote_dependencies
    
    echo ""
    echo -e "${CYAN}请输入虚拟化主机连接信息:${NC}"
    echo ""
    
    read -p "主机 IP 地址: " HOST_IP
    if [[ -z "$HOST_IP" ]]; then
        log_error "IP 地址不能为空"
        exit 1
    fi
    
    read -p "SSH 端口 [22]: " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    
    read -p "用户名 [root]: " SSH_USER
    SSH_USER=${SSH_USER:-root}
    
    read -sp "密码: " SSH_PASS
    echo ""
    
    if [[ -z "$SSH_PASS" ]]; then
        log_error "密码不能为空"
        exit 1
    fi
    
    echo ""
    log_info "测试连接..."
    
    if sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=no -p "$SSH_PORT" "${SSH_USER}@${HOST_IP}" "echo ok" &>/dev/null; then
        log_success "连接成功"
    else
        log_error "连接失败，请检查 IP、端口、用户名和密码"
        exit 1
    fi
}

# ==================== SSH/SCP 封装 ====================
ssh_cmd() {
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=30 -p "$SSH_PORT" "${SSH_USER}@${HOST_IP}" "$@"
}

scp_cmd() {
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no -P "$SSH_PORT" "$@"
}

# ==================== 解压镜像 ====================
decompress_image() {
    local output_file="$1"
    
    log_info "解压镜像 ($(du -h "$IMAGE_FILE" | cut -f1))..."
    
    if ! gunzip -c "$IMAGE_FILE" > "$output_file"; then
        log_error "解压失败"
        exit 1
    fi
    
    TEMP_FILES+=("$output_file")
    log_success "解压完成 ($(du -h "$output_file" | cut -f1))"
}

# ==================== 检查 qemu-img ====================
check_qemu_img() {
    if ! command -v qemu-img &>/dev/null; then
        log_error "需要 qemu-img 来转换磁盘格式"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "请运行: brew install qemu"
        else
            echo "请运行: sudo apt install qemu-utils"
        fi
        exit 1
    fi
}

# ==================== PVE 部署 ====================
deploy_pve() {
    echo ""
    echo -e "${CYAN}=== Proxmox VE 部署 ===${NC}"
    echo ""
    
    # 获取参数
    read -p "虚拟机 ID [100]: " VM_ID
    VM_ID=${VM_ID:-100}
    
    # 验证 VM_ID 是数字
    if ! [[ "$VM_ID" =~ ^[0-9]+$ ]]; then
        log_error "虚拟机 ID 必须是数字"
        exit 1
    fi
    
    read -p "虚拟机名称 [pbox]: " VM_NAME
    VM_NAME=${VM_NAME:-pbox}
    # 清理名称中的特殊字符
    VM_NAME=$(echo "$VM_NAME" | tr -cd '[:alnum:]-_')
    
    read -p "CPU 核心数 [4]: " VM_CORES
    VM_CORES=${VM_CORES:-4}
    
    read -p "内存大小 MB [2048]: " VM_MEMORY
    VM_MEMORY=${VM_MEMORY:-2048}
    
    read -p "存储池 [local-lvm]: " STORAGE
    STORAGE=${STORAGE:-local-lvm}
    
    echo ""
    echo -e "${YELLOW}启动模式:${NC}"
    echo "  1. BIOS (传统模式，兼容性最好) [默认]"
    echo "  2. UEFI (需要 OVMF 支持)"
    read -p "请选择 [1-2]: " boot_mode
    
    local BIOS_TYPE="seabios"
    [[ "$boot_mode" == "2" ]] && BIOS_TYPE="ovmf"
    
    echo ""
    log_info "开始部署..."
    
    # 解压镜像
    local TEMP_IMG="/tmp/pbox-os-$$.img"
    decompress_image "$TEMP_IMG"
    
    # 上传到 PVE
    log_info "上传镜像到 PVE ($(du -h "$TEMP_IMG" | cut -f1))..."
    scp_cmd "$TEMP_IMG" "${SSH_USER}@${HOST_IP}:/tmp/pbox-os.img"
    rm -f "$TEMP_IMG"
    
    # 在 PVE 上创建 VM (兼容 PVE 6.x-9.x)
    log_info "创建虚拟机..."
    ssh_cmd "bash -s" "$VM_ID" "$VM_NAME" "$VM_MEMORY" "$VM_CORES" "$BIOS_TYPE" "$STORAGE" << 'PVECREATE'
set -e
VM_ID="$1"
VM_NAME="$2"
VM_MEMORY="$3"
VM_CORES="$4"
BIOS_TYPE="$5"
STORAGE="$6"

# 检测 PVE 版本 (支持 6.x-9.x)
PVE_VER=$(pveversion 2>/dev/null | grep -oE 'pve-manager/[0-9]+' | cut -d'/' -f2 || echo "8")
echo "PVE 版本: $PVE_VER"

# 选择 SCSI 控制器
if [[ "$PVE_VER" -ge 7 ]]; then
    SCSI_HW="virtio-scsi-single"
else
    SCSI_HW="virtio-scsi-pci"
fi

# 删除已存在的 VM（静默）
qm destroy $VM_ID --purge 2>/dev/null || true
sleep 1

# 创建 VM
if [[ "$BIOS_TYPE" == "ovmf" ]]; then
    qm create $VM_ID --name "$VM_NAME" --memory $VM_MEMORY --cores $VM_CORES \
        --net0 virtio,bridge=vmbr0 \
        --bios ovmf \
        --machine q35 \
        --ostype l26
    
    # 创建 EFI 磁盘
    qm set $VM_ID --efidisk0 ${STORAGE}:1,efitype=4m,pre-enrolled-keys=0
else
    qm create $VM_ID --name "$VM_NAME" --memory $VM_MEMORY --cores $VM_CORES \
        --net0 virtio,bridge=vmbr0 \
        --bios seabios \
        --ostype l26
fi

# PVE 7+/8+/9+ 支持 q35 芯片组
if [[ "$PVE_VER" -ge 7 ]] && [[ "$BIOS_TYPE" != "ovmf" ]]; then
    qm set $VM_ID --machine q35 2>/dev/null || true
fi

# 导入磁盘
echo "导入磁盘..."
qm importdisk $VM_ID /tmp/pbox-os.img $STORAGE --format raw

# 获取导入的磁盘名称并挂载
DISK_NAME=$(qm config $VM_ID | grep "unused0" | cut -d: -f2 | tr -d ' ')
if [[ -n "$DISK_NAME" ]]; then
    # PVE 7+ 支持 iothread
    if [[ "$PVE_VER" -ge 7 ]]; then
        qm set $VM_ID --scsi0 ${DISK_NAME},iothread=1
    else
        qm set $VM_ID --scsi0 ${DISK_NAME}
    fi
    qm set $VM_ID --scsihw $SCSI_HW
    qm set $VM_ID --boot order=scsi0
fi

# 启用 QEMU Guest Agent
qm set $VM_ID --agent enabled=1

# 清理临时文件
rm -f /tmp/pbox-os.img

echo "虚拟机创建完成 (PVE $PVE_VER)"
PVECREATE

    # 启动 VM
    log_info "启动虚拟机..."
    ssh_cmd "qm start $VM_ID"
    
    log_success "部署完成!"
    echo ""
    log_info "等待虚拟机启动并获取 IP 地址 (约30秒)..."
    sleep 30
    
    # 尝试获取 IP 地址（需要 qemu-guest-agent）
    # 兼容 PVE 6.x-9.x: qm guest / qm agent / qm guest cmd
    local VM_IP=""
    VM_IP=$(ssh_cmd "bash -s" "$VM_ID" << 'GETIP'
VMID="$1"
result=$(qm guest "$VMID" network-get-interfaces 2>/dev/null) || \
result=$(qm agent "$VMID" network-get-interfaces 2>/dev/null) || \
result=$(qm guest cmd "$VMID" network-get-interfaces 2>/dev/null) || true
if [[ -n "$result" ]]; then
    echo "$result" | tr ',' '\n' | grep '"ip-address"' | grep -v 'ip-address-type' | \
        sed 's/.*"ip-address"[[:space:]]*:[[:space:]]*"\([0-9.]*\)".*/\1/' | \
        grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | grep -v '^127\.' | head -1
fi
GETIP
    ) 2>/dev/null || echo ""
    VM_IP=$(echo "$VM_IP" | tr -d '[:space:]')
    
    echo ""
    if [[ -n "$VM_IP" ]]; then
        log_success "虚拟机 IP: $VM_IP"
    else
        log_warn "无法自动获取 IP (需要 qemu-guest-agent)"
        echo "  请在 PVE 控制台查看虚拟机 IP"
    fi
    
    show_access_info
}

# ==================== ESXi 部署 ====================
deploy_esxi() {
    echo ""
    echo -e "${CYAN}=== VMware ESXi 部署 ===${NC}"
    echo ""
    
    check_qemu_img
    
    read -p "虚拟机名称 [pbox]: " VM_NAME
    VM_NAME=${VM_NAME:-pbox}
    VM_NAME=$(echo "$VM_NAME" | tr -cd '[:alnum:]-_')
    
    read -p "CPU 核心数 [4]: " VM_CORES
    VM_CORES=${VM_CORES:-4}
    
    read -p "内存大小 MB [2048]: " VM_MEMORY
    VM_MEMORY=${VM_MEMORY:-2048}
    
    read -p "数据存储 [datastore1]: " DATASTORE
    DATASTORE=${DATASTORE:-datastore1}
    
    echo ""
    log_info "开始部署..."
    
    # 解压镜像
    local TEMP_IMG="/tmp/pbox-os-$$.img"
    local TEMP_VMDK="/tmp/pbox-os-$$.vmdk"
    
    decompress_image "$TEMP_IMG"
    
    # 转换为 ESXi 兼容的 VMDK (monolithicSparse 格式)
    log_info "转换为 VMDK 格式..."
    qemu-img convert -f raw -O vmdk -o adapter_type=lsilogic,subformat=monolithicSparse "$TEMP_IMG" "$TEMP_VMDK"
    TEMP_FILES+=("$TEMP_VMDK")
    rm -f "$TEMP_IMG"
    
    log_success "转换完成 ($(du -h "$TEMP_VMDK" | cut -f1))"
    
    # 上传到 ESXi
    log_info "上传 VMDK 到 ESXi..."
    scp_cmd "$TEMP_VMDK" "${SSH_USER}@${HOST_IP}:/vmfs/volumes/${DATASTORE}/pbox-os-temp.vmdk"
    rm -f "$TEMP_VMDK"
    
    # 创建 VM
    log_info "创建虚拟机..."
    ssh_cmd sh << EOF
set -e

VM_DIR="/vmfs/volumes/${DATASTORE}/${VM_NAME}"

# 删除已存在的 VM
if [ -d "\$VM_DIR" ]; then
    # 尝试注销并删除
    VMID=\$(vim-cmd vmsvc/getallvms 2>/dev/null | grep "${VM_NAME}" | awk '{print \$1}')
    [ -n "\$VMID" ] && vim-cmd vmsvc/unregister \$VMID 2>/dev/null || true
    rm -rf "\$VM_DIR"
fi

mkdir -p "\$VM_DIR"

# 移动并转换 VMDK 为 ESXi 原生格式
vmkfstools -i "/vmfs/volumes/${DATASTORE}/pbox-os-temp.vmdk" "\$VM_DIR/${VM_NAME}.vmdk" -d thin 2>/dev/null || \
    mv "/vmfs/volumes/${DATASTORE}/pbox-os-temp.vmdk" "\$VM_DIR/${VM_NAME}.vmdk"
rm -f "/vmfs/volumes/${DATASTORE}/pbox-os-temp.vmdk"

# 创建 VMX 配置文件 (兼容 ESXi 6.5+)
cat > "\$VM_DIR/${VM_NAME}.vmx" << 'VMXEND'
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "14"
pciBridge0.present = "TRUE"
pciBridge4.present = "TRUE"
pciBridge4.virtualDev = "pcieRootPort"
pciBridge4.functions = "8"
vmci0.present = "TRUE"
displayName = "${VM_NAME}"
guestOS = "debian10-64"
memSize = "${VM_MEMORY}"
numvcpus = "${VM_CORES}"
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "${VM_NAME}.vmdk"
ethernet0.present = "TRUE"
ethernet0.virtualDev = "vmxnet3"
ethernet0.networkName = "VM Network"
ethernet0.addressType = "generated"
ethernet0.startConnected = "TRUE"
tools.syncTime = "TRUE"
firmware = "bios"
VMXEND

# 替换变量 (ESXi shell 不支持 heredoc 变量展开)
sed -i "s/\${VM_NAME}/${VM_NAME}/g" "\$VM_DIR/${VM_NAME}.vmx"
sed -i "s/\${VM_MEMORY}/${VM_MEMORY}/g" "\$VM_DIR/${VM_NAME}.vmx"
sed -i "s/\${VM_CORES}/${VM_CORES}/g" "\$VM_DIR/${VM_NAME}.vmx"

# 注册 VM
vim-cmd solo/registervm "\$VM_DIR/${VM_NAME}.vmx"

echo "虚拟机创建完成"
EOF

    # 启动 VM
    log_info "启动虚拟机..."
    ssh_cmd sh << EOF
VMID=\$(vim-cmd vmsvc/getallvms | grep "${VM_NAME}" | awk '{print \$1}')
if [ -n "\$VMID" ]; then
    vim-cmd vmsvc/power.on \$VMID
    echo "虚拟机已启动 (VMID: \$VMID)"
else
    echo "警告: 未找到虚拟机"
fi
EOF

    log_success "部署完成!"
    show_access_info
}

# ==================== VMware Workstation 部署 ====================
deploy_vmware() {
    echo ""
    echo -e "${CYAN}=== VMware Workstation / Fusion 部署 ===${NC}"
    echo ""
    
    check_qemu_img
    
    read -p "虚拟机保存路径: " VM_PATH
    if [[ -z "$VM_PATH" ]]; then
        log_error "路径不能为空"
        exit 1
    fi
    
    # 展开 ~ 路径
    VM_PATH="${VM_PATH/#\~/$HOME}"
    
    read -p "虚拟机名称 [pbox]: " VM_NAME
    VM_NAME=${VM_NAME:-pbox}
    VM_NAME=$(echo "$VM_NAME" | tr -cd '[:alnum:]-_')
    
    read -p "CPU 核心数 [4]: " VM_CORES
    VM_CORES=${VM_CORES:-4}
    
    read -p "内存大小 MB [2048]: " VM_MEMORY
    VM_MEMORY=${VM_MEMORY:-2048}
    
    local VM_DIR="$VM_PATH/$VM_NAME"
    mkdir -p "$VM_DIR"
    
    echo ""
    log_info "开始部署..."
    
    # 解压镜像
    local TEMP_IMG="/tmp/pbox-os-$$.img"
    decompress_image "$TEMP_IMG"
    
    # 转换为 VMDK (Workstation 兼容格式)
    log_info "转换为 VMDK 格式..."
    qemu-img convert -f raw -O vmdk -o adapter_type=lsilogic "$TEMP_IMG" "$VM_DIR/${VM_NAME}.vmdk"
    rm -f "$TEMP_IMG"
    
    log_success "转换完成"
    
    # 创建 VMX 文件 (兼容 Workstation 14+)
    log_info "创建虚拟机配置..."
    cat > "$VM_DIR/${VM_NAME}.vmx" << EOF
.encoding = "UTF-8"
config.version = "8"
virtualHW.version = "16"
displayName = "${VM_NAME}"
guestOS = "debian10-64"
memSize = "${VM_MEMORY}"
numvcpus = "${VM_CORES}"
scsi0.present = "TRUE"
scsi0.virtualDev = "lsilogic"
scsi0:0.present = "TRUE"
scsi0:0.fileName = "${VM_NAME}.vmdk"
ethernet0.present = "TRUE"
ethernet0.virtualDev = "e1000"
ethernet0.connectionType = "nat"
ethernet0.addressType = "generated"
ethernet0.startConnected = "TRUE"
usb.present = "TRUE"
sound.present = "FALSE"
tools.syncTime = "TRUE"
firmware = "bios"
EOF

    log_success "部署完成!"
    echo ""
    echo "虚拟机文件: $VM_DIR/${VM_NAME}.vmx"
    echo ""
    echo "请在 VMware Workstation/Fusion 中:"
    echo "  文件 → 打开 → 选择 ${VM_NAME}.vmx"
    
    show_access_info
}

# ==================== VirtualBox 部署 ====================
deploy_virtualbox() {
    echo ""
    echo -e "${CYAN}=== VirtualBox 部署 ===${NC}"
    echo ""
    
    read -p "虚拟机名称 [pbox]: " VM_NAME
    VM_NAME=${VM_NAME:-pbox}
    VM_NAME=$(echo "$VM_NAME" | tr -cd '[:alnum:]-_')
    
    read -p "CPU 核心数 [4]: " VM_CORES
    VM_CORES=${VM_CORES:-4}
    
    read -p "内存大小 MB [2048]: " VM_MEMORY
    VM_MEMORY=${VM_MEMORY:-2048}
    
    echo ""
    log_info "开始部署..."
    
    # 解压镜像
    local TEMP_IMG="/tmp/pbox-os-$$.img"
    local TEMP_VDI="/tmp/pbox-os-$$.vdi"
    
    decompress_image "$TEMP_IMG"
    
    # 转换为 VDI
    log_info "转换为 VDI 格式..."
    if command -v VBoxManage &>/dev/null; then
        VBoxManage convertfromraw "$TEMP_IMG" "$TEMP_VDI" --format VDI
    elif command -v qemu-img &>/dev/null; then
        qemu-img convert -f raw -O vdi "$TEMP_IMG" "$TEMP_VDI"
    else
        log_error "需要 VBoxManage 或 qemu-img"
        rm -f "$TEMP_IMG"
        exit 1
    fi
    TEMP_FILES+=("$TEMP_VDI")
    rm -f "$TEMP_IMG"
    
    log_success "转换完成"
    
    # 使用 VBoxManage 创建 VM
    if command -v VBoxManage &>/dev/null; then
        log_info "创建虚拟机..."
        
        # 删除已存在的同名 VM
        VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true
        
        # 创建 VM (兼容 VirtualBox 5.x+)
        VBoxManage createvm --name "$VM_NAME" --ostype "Debian_64" --register
        
        # 配置 VM
        VBoxManage modifyvm "$VM_NAME" \
            --memory "$VM_MEMORY" \
            --cpus "$VM_CORES" \
            --nic1 nat \
            --audio none \
            --firmware bios \
            --boot1 disk \
            --boot2 none \
            --boot3 none \
            --boot4 none
        
        # 添加存储控制器
        VBoxManage storagectl "$VM_NAME" --name "SATA" --add sata --controller IntelAhci --portcount 1
        
        # 获取 VM 目录并移动 VDI
        local VM_DIR
        VM_DIR=$(VBoxManage showvminfo "$VM_NAME" --machinereadable | grep "CfgFile" | cut -d'"' -f2 | xargs dirname)
        mv "$TEMP_VDI" "$VM_DIR/${VM_NAME}.vdi"
        
        # 挂载磁盘
        VBoxManage storageattach "$VM_NAME" \
            --storagectl "SATA" \
            --port 0 \
            --device 0 \
            --type hdd \
            --medium "$VM_DIR/${VM_NAME}.vdi"
        
        # 启动 VM
        log_info "启动虚拟机..."
        VBoxManage startvm "$VM_NAME" --type headless
        
        log_success "部署完成!"
    else
        log_warn "VBoxManage 未找到，请手动导入"
        echo ""
        echo "VDI 文件: $TEMP_VDI"
        echo ""
        echo "手动导入步骤:"
        echo "  1. 打开 VirtualBox"
        echo "  2. 新建 → 名称: $VM_NAME, 类型: Linux, 版本: Debian (64-bit)"
        echo "  3. 内存: ${VM_MEMORY}MB, CPU: ${VM_CORES} 核"
        echo "  4. 使用现有虚拟硬盘文件 → 选择上述 VDI 文件"
    fi
    
    show_access_info
}

# ==================== Hyper-V 部署 ====================
deploy_hyperv() {
    echo ""
    echo -e "${CYAN}=== Hyper-V 部署 ===${NC}"
    echo ""
    
    check_qemu_img
    
    read -p "虚拟机名称 [pbox]: " VM_NAME
    VM_NAME=${VM_NAME:-pbox}
    VM_NAME=$(echo "$VM_NAME" | tr -cd '[:alnum:]-_')
    
    read -p "CPU 核心数 [4]: " VM_CORES
    VM_CORES=${VM_CORES:-4}
    
    read -p "内存大小 MB [2048]: " VM_MEMORY
    VM_MEMORY=${VM_MEMORY:-2048}
    
    read -p "VHDX 保存路径: " VM_PATH
    if [[ -z "$VM_PATH" ]]; then
        log_error "路径不能为空"
        exit 1
    fi
    
    VM_PATH="${VM_PATH/#\~/$HOME}"
    mkdir -p "$VM_PATH"
    
    echo ""
    log_info "开始部署..."
    
    # 解压镜像
    local TEMP_IMG="/tmp/pbox-os-$$.img"
    decompress_image "$TEMP_IMG"
    
    # 转换为 VHDX
    log_info "转换为 VHDX 格式..."
    qemu-img convert -f raw -O vhdx -o subformat=dynamic "$TEMP_IMG" "$VM_PATH/${VM_NAME}.vhdx"
    rm -f "$TEMP_IMG"
    
    log_success "转换完成"
    echo ""
    echo -e "${GREEN}VHDX 文件: $VM_PATH/${VM_NAME}.vhdx${NC}"
    echo ""
    echo -e "${YELLOW}请在 Windows PowerShell (管理员) 中执行:${NC}"
    echo ""
    
    # Generation 1 不需要 Set-VMFirmware
    cat << EOF
# 创建虚拟机 (Generation 1 = BIOS 模式)
New-VM -Name "${VM_NAME}" -MemoryStartupBytes ${VM_MEMORY}MB -Generation 1 -VHDPath "${VM_PATH}/${VM_NAME}.vhdx"

# 设置 CPU
Set-VMProcessor -VMName "${VM_NAME}" -Count ${VM_CORES}

# 连接网络 (使用默认交换机)
\$switch = Get-VMSwitch | Where-Object { \$_.SwitchType -eq 'External' } | Select-Object -First 1
if (\$switch) {
    Connect-VMNetworkAdapter -VMName "${VM_NAME}" -SwitchName \$switch.Name
} else {
    Connect-VMNetworkAdapter -VMName "${VM_NAME}" -SwitchName "Default Switch"
}

# 启动虚拟机
Start-VM -Name "${VM_NAME}"
EOF
    
    echo ""
    show_access_info
}

# ==================== 显示访问信息 ====================
show_access_info() {
    echo ""
    echo -e "${CYAN}=== 访问信息 ===${NC}"
    echo "  SSH: ssh root@<VM_IP>"
    echo "  密码: pbox123"
    echo "  Web 面板: https://<VM_IP>"
    echo "  终端菜单: 输入 pbox"
}

# ==================== 主流程 ====================
main() {
    check_dependencies
    find_image
    select_platform
    
    # 远程部署需要连接信息
    if [[ "$PLATFORM" == "pve" ]] || [[ "$PLATFORM" == "esxi" ]]; then
        input_connection_info
    fi
    
    case $PLATFORM in
        pve) deploy_pve ;;
        esxi) deploy_esxi ;;
        vmware) deploy_vmware ;;
        virtualbox) deploy_virtualbox ;;
        hyperv) deploy_hyperv ;;
    esac
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════${NC}"
    echo -e "${GREEN}  P-BOX OS 部署完成！${NC}"
    echo -e "${GREEN}════════════════════════════════════════${NC}"
}

main "$@"
