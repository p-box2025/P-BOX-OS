#!/bin/bash
# ============================================================
# P-BOX OS 一键下载脚本
# 自动下载最新版本镜像和部署脚本
# ============================================================

# 不使用 set -e，手动处理错误
set -o pipefail

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# 配置
REPO="p-box2025/P-BOX-OS"
API_URL="https://api.github.com/repos/${REPO}/releases/latest"
FALLBACK_VERSION="v1.0.3"
MAX_RETRIES=3
TIMEOUT=30

# 日志函数
log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }

echo -e "${CYAN}"
echo "╔════════════════════════════════════════════════════════════╗"
echo "║          P-BOX OS 一键下载脚本 v2.0                         ║"
echo "║          自动下载最新版本镜像和部署脚本                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# 检测架构
detect_arch() {
    local arch=$(uname -m)
    case "$arch" in
        x86_64|amd64)
            echo "amd64"
            ;;
        aarch64|arm64)
            echo "arm64"
            ;;
        armv7l|armhf|armv7)
            echo "armhf"
            ;;
        *)
            log_warn "未知架构: $arch，默认使用 amd64"
            echo "amd64"
            ;;
    esac
}

# HTTP 请求函数（支持 curl 和 wget）
http_get() {
    local url="$1"
    local output="$2"
    local retry=0
    
    while [[ $retry -lt $MAX_RETRIES ]]; do
        if [[ -n "$output" ]]; then
            # 下载文件
            if command -v curl &>/dev/null; then
                curl -fSL --connect-timeout $TIMEOUT --retry 2 --progress-bar -o "$output" "$url" 2>&1 && return 0
            elif command -v wget &>/dev/null; then
                wget --timeout=$TIMEOUT --tries=2 --show-progress -O "$output" "$url" 2>&1 && return 0
            fi
        else
            # 获取内容
            if command -v curl &>/dev/null; then
                curl -fsSL --connect-timeout $TIMEOUT "$url" 2>/dev/null && return 0
            elif command -v wget &>/dev/null; then
                wget -qO- --timeout=$TIMEOUT "$url" 2>/dev/null && return 0
            fi
        fi
        
        retry=$((retry + 1))
        [[ $retry -lt $MAX_RETRIES ]] && sleep 2
    done
    
    return 1
}

# 获取最新版本
get_latest_version() {
    log_info "获取最新版本信息..."
    
    local release_info
    release_info=$(http_get "$API_URL")
    
    if [[ -z "$release_info" ]]; then
        log_warn "无法访问 GitHub API (可能已达到限速)"
        echo "$FALLBACK_VERSION"
        return
    fi
    
    # 检查是否是 API 限速错误
    if echo "$release_info" | grep -q "API rate limit"; then
        log_warn "GitHub API 限速，使用默认版本"
        echo "$FALLBACK_VERSION"
        return
    fi
    
    # 解析版本号
    local version
    version=$(echo "$release_info" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    
    if [[ -z "$version" ]]; then
        log_warn "无法解析版本号，使用默认版本"
        echo "$FALLBACK_VERSION"
        return
    fi
    
    echo "$version"
}

# 下载文件
download_file() {
    local url="$1"
    local filename="$2"
    local desc="$3"
    
    log_info "下载: ${desc:-$filename}"
    
    if ! http_get "$url" "$filename"; then
        return 1
    fi
    
    # 验证文件
    if [[ ! -f "$filename" ]]; then
        return 1
    fi
    
    local filesize=$(stat -f%z "$filename" 2>/dev/null || stat -c%s "$filename" 2>/dev/null || echo "0")
    
    # 检查是否下载到 HTML 错误页面 (小于 1KB 的可能是错误页面)
    if [[ "$filesize" -lt 1000 ]]; then
        if head -c 100 "$filename" 2>/dev/null | grep -qi "<!doctype\|<html\|not found\|404"; then
            log_warn "下载到错误页面，文件无效"
            rm -f "$filename"
            return 1
        fi
    fi
    
    # 对于镜像文件，检查大小是否合理 (至少 10MB)
    if [[ "$filename" == *.img.gz ]] && [[ "$filesize" -lt 10000000 ]]; then
        log_warn "镜像文件过小 ($(($filesize/1024/1024))MB)，可能下载失败"
        rm -f "$filename"
        return 1
    fi
    
    local size_human=$(echo "$filesize" | awk '{
        if ($1 >= 1073741824) printf "%.1f GB", $1/1073741824
        else if ($1 >= 1048576) printf "%.1f MB", $1/1048576
        else if ($1 >= 1024) printf "%.1f KB", $1/1024
        else printf "%d B", $1
    }')
    
    log_success "${filename} (${size_human})"
    return 0
}

# 主流程
main() {
    # 检查依赖
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        log_error "需要 curl 或 wget"
        echo "安装方法:"
        echo "  macOS:  brew install curl"
        echo "  Ubuntu: sudo apt install curl"
        echo "  CentOS: sudo yum install curl"
        exit 1
    fi
    
    # 检测架构
    ARCH_NAME=$(detect_arch)
    log_success "检测到架构: ${ARCH_NAME}"
    echo ""
    
    # 获取版本
    VERSION=$(get_latest_version)
    log_success "目标版本: ${VERSION}"
    echo ""
    
    # 创建下载目录
    DOWNLOAD_DIR="pbox-os-${VERSION}"
    
    if [[ -d "$DOWNLOAD_DIR" ]]; then
        log_warn "目录已存在: $DOWNLOAD_DIR"
        read -p "是否覆盖? [y/N]: " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log_info "已取消"
            exit 0
        fi
        rm -rf "$DOWNLOAD_DIR"
    fi
    
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    log_info "下载目录: $(pwd)"
    echo ""
    
    # 构建 URL
    BASE_URL="https://github.com/${REPO}/releases/download/${VERSION}"
    RAW_URL="https://raw.githubusercontent.com/${REPO}/main"
    
    # 尝试的镜像文件名列表
    local img_files=(
        "pbox-os-${ARCH_NAME}-${VERSION}.img.gz"
        "pbox-os-${ARCH_NAME}.img.gz"
        "pbox-os-amd64-${VERSION}.img.gz"
        "pbox-os-amd64.img.gz"
    )
    
    # 下载镜像
    echo -e "${CYAN}[1/3] 下载镜像文件...${NC}"
    local img_downloaded=false
    for img_file in "${img_files[@]}"; do
        if download_file "${BASE_URL}/${img_file}" "$img_file" "镜像 $img_file"; then
            img_downloaded=true
            break
        fi
    done
    
    if [[ "$img_downloaded" != "true" ]]; then
        log_error "镜像下载失败"
        echo ""
        echo "请手动下载: https://github.com/${REPO}/releases"
        exit 1
    fi
    
    # 下载部署脚本
    echo ""
    echo -e "${CYAN}[2/3] 下载部署脚本 (Linux/macOS)...${NC}"
    if download_file "${RAW_URL}/deploy-vm.sh" "deploy-vm.sh" "deploy-vm.sh"; then
        chmod +x deploy-vm.sh
    else
        log_warn "deploy-vm.sh 下载失败，跳过"
    fi
    
    echo ""
    echo -e "${CYAN}[3/3] 下载部署脚本 (Windows)...${NC}"
    download_file "${RAW_URL}/deploy-vm.bat" "deploy-vm.bat" "deploy-vm.bat" || \
        log_warn "deploy-vm.bat 下载失败，跳过"
    
    # 创建 README
    cat > README.txt << 'READMEEOF'
P-BOX OS 部署指南
================

一、快速部署（推荐）
------------------
Linux/macOS: ./deploy-vm.sh
Windows:     双击 deploy-vm.bat

二、默认凭据
----------
SSH 用户名: root
SSH 密码:   pbox123
Web 面板:   https://<设备IP>

三、支持平台
----------
- Proxmox VE (6.x - 9.x)
- VMware ESXi (6.5 - 8.x)
- VMware Workstation / Fusion (14 - 17)
- VirtualBox (5.x - 7.2)
- Hyper-V (Server 2016 - 2025)

四、更多信息
----------
GitHub:   https://github.com/p-box2025/P-BOX-OS
Telegram: https://t.me/+8d9PNOt-w6BkNzU1
READMEEOF
    
    # 显示结果
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  下载完成！${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "下载目录: $(pwd)"
    echo ""
    ls -lh
    echo ""
    echo -e "${CYAN}下一步:${NC}"
    echo "  cd $(pwd)"
    echo "  ./deploy-vm.sh"
    echo ""
    echo -e "${CYAN}默认凭据:${NC}"
    echo "  SSH: root / pbox123"
    echo "  Web: https://<设备IP>"
    echo ""
}

main "$@"
