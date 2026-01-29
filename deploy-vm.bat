@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

:: ============================================================
:: P-BOX OS 一键部署脚本 (Windows)
:: 支持: PVE, ESXi, VMware Workstation, VirtualBox, Hyper-V
:: ============================================================

title P-BOX OS 一键部署脚本 v2.0

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║          P-BOX OS 一键部署脚本 v2.0                        ║
echo ║          支持 PVE / ESXi / VMware / VirtualBox / Hyper-V   ║
echo ╚════════════════════════════════════════════════════════════╝
echo.

:: 获取脚本所在目录
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

:: ==================== 查找镜像文件 ====================
:find_image
echo [INFO] 查找镜像文件...
echo.

set "IMAGE_FILE="
set "IMAGE_COUNT=0"
set "LAST_IMAGE="

for %%f in ("%SCRIPT_DIR%\*.img.gz") do (
    set /a IMAGE_COUNT+=1
    set "LAST_IMAGE=%%f"
    echo   !IMAGE_COUNT!. %%~nxf
)

if %IMAGE_COUNT% equ 0 (
    echo [ERROR] 未找到镜像文件 (*.img.gz)
    echo 请确保镜像文件与此脚本在同一目录: %SCRIPT_DIR%
    pause
    exit /b 1
)

if %IMAGE_COUNT% equ 1 (
    set "IMAGE_FILE=%LAST_IMAGE%"
    echo.
    echo [OK] 已选择: %LAST_IMAGE%
) else (
    echo.
    set /p "IMG_CHOICE=请选择 [1-%IMAGE_COUNT%]: "
    
    set "IDX=0"
    for %%f in ("%SCRIPT_DIR%\*.img.gz") do (
        set /a IDX+=1
        if "!IDX!"=="!IMG_CHOICE!" set "IMAGE_FILE=%%f"
    )
    
    if not defined IMAGE_FILE (
        echo [ERROR] 无效选择
        pause
        exit /b 1
    )
    echo [OK] 已选择: !IMAGE_FILE!
)

echo.

:: ==================== 选择虚拟化平台 ====================
:select_platform
echo 请选择虚拟化平台:
echo.
echo   1. Proxmox VE (PVE 6.x-8.x)
echo   2. VMware ESXi (6.5-8.x)
echo   3. VMware Workstation (本地)
echo   4. VirtualBox (本地)
echo   5. Hyper-V (本地)
echo.

:platform_input
set /p "PLATFORM_CHOICE=请选择 [1-5]: "

if "%PLATFORM_CHOICE%"=="1" (
    set "PLATFORM=pve"
    goto :check_ssh
)
if "%PLATFORM_CHOICE%"=="2" (
    set "PLATFORM=esxi"
    goto :check_ssh
)
if "%PLATFORM_CHOICE%"=="3" (
    set "PLATFORM=vmware"
    goto :deploy_vmware
)
if "%PLATFORM_CHOICE%"=="4" (
    set "PLATFORM=virtualbox"
    goto :deploy_virtualbox
)
if "%PLATFORM_CHOICE%"=="5" (
    set "PLATFORM=hyperv"
    goto :deploy_hyperv
)

echo [WARN] 无效选择，请输入 1-5
goto :platform_input

:: ==================== 检查 SSH ====================
:check_ssh
where ssh >nul 2>&1
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] 需要 SSH 客户端
    echo Windows 10 1809+ 自带 OpenSSH，请在"设置 - 应用 - 可选功能"中启用
    pause
    exit /b 1
)

:: ==================== 输入连接信息 ====================
:input_remote_info
echo.
echo 请输入虚拟化主机连接信息:
echo.

set /p "HOST_IP=主机 IP 地址: "
if "%HOST_IP%"=="" (
    echo [ERROR] IP 地址不能为空
    pause
    exit /b 1
)

set /p "SSH_PORT=SSH 端口 [22]: "
if "%SSH_PORT%"=="" set "SSH_PORT=22"

set /p "SSH_USER=用户名 [root]: "
if "%SSH_USER%"=="" set "SSH_USER=root"

set /p "SSH_PASS=密码: "
if "%SSH_PASS%"=="" (
    echo [ERROR] 密码不能为空
    pause
    exit /b 1
)

echo.
echo [INFO] 测试连接...
echo.
echo 注意: Windows 需要手动输入密码确认连接
echo.

if "%PLATFORM%"=="pve" goto :deploy_pve
if "%PLATFORM%"=="esxi" goto :deploy_esxi

:: ==================== PVE 部署 ====================
:deploy_pve
echo.
echo === Proxmox VE 部署 ===
echo.

set /p "VM_ID=虚拟机 ID [100]: "
if "%VM_ID%"=="" set "VM_ID=100"

set /p "VM_NAME=虚拟机名称 [pbox]: "
if "%VM_NAME%"=="" set "VM_NAME=pbox"

set /p "VM_CORES=CPU 核心数 [4]: "
if "%VM_CORES%"=="" set "VM_CORES=4"

set /p "VM_MEMORY=内存大小 MB [2048]: "
if "%VM_MEMORY%"=="" set "VM_MEMORY=2048"

set /p "STORAGE=存储池 [local-lvm]: "
if "%STORAGE%"=="" set "STORAGE=local-lvm"

echo.
echo 启动模式:
echo   1. BIOS (兼容性好) [默认]
echo   2. UEFI (需要 OVMF)
set /p "BOOT_MODE=请选择 [1-2]: "
if "%BOOT_MODE%"=="2" (
    set "BIOS_TYPE=ovmf"
) else (
    set "BIOS_TYPE=seabios"
)

echo.
echo [INFO] 开始部署...
echo.

:: 解压镜像
echo [INFO] 解压镜像...
set "TEMP_IMG=%TEMP%\pbox-os-%RANDOM%.img"

powershell -Command "& { try { $fs = [System.IO.File]::OpenRead('%IMAGE_FILE%'); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $out = [System.IO.File]::Create('%TEMP_IMG%'); $gz.CopyTo($out); $gz.Close(); $out.Close(); $fs.Close(); Write-Host '[OK] 解压完成' } catch { Write-Host '[ERROR] 解压失败:' $_.Exception.Message; exit 1 } }"

if not exist "%TEMP_IMG%" (
    echo [ERROR] 解压失败
    pause
    exit /b 1
)

:: 上传到 PVE
echo [INFO] 上传镜像到 PVE (需要输入密码)...
scp -o StrictHostKeyChecking=no -P %SSH_PORT% "%TEMP_IMG%" %SSH_USER%@%HOST_IP%:/tmp/pbox-os.img

if %errorlevel% neq 0 (
    echo [ERROR] 上传失败
    del "%TEMP_IMG%" 2>nul
    pause
    exit /b 1
)

del "%TEMP_IMG%" 2>nul

:: 创建 VM (通过 SSH)
echo [INFO] 创建虚拟机 (需要输入密码)...
ssh -o StrictHostKeyChecking=no -p %SSH_PORT% %SSH_USER%@%HOST_IP% "qm destroy %VM_ID% --purge 2>/dev/null; if [ '%BIOS_TYPE%' = 'ovmf' ]; then qm create %VM_ID% --name %VM_NAME% --memory %VM_MEMORY% --cores %VM_CORES% --net0 virtio,bridge=vmbr0 --bios ovmf --machine q35 --ostype l26 && qm set %VM_ID% --efidisk0 %STORAGE%:1,efitype=4m,pre-enrolled-keys=0; else qm create %VM_ID% --name %VM_NAME% --memory %VM_MEMORY% --cores %VM_CORES% --net0 virtio,bridge=vmbr0 --bios seabios --ostype l26; fi && qm importdisk %VM_ID% /tmp/pbox-os.img %STORAGE% --format raw && DISK=$(qm config %VM_ID% | grep unused0 | cut -d: -f2 | tr -d ' ') && qm set %VM_ID% --scsi0 $DISK --scsihw virtio-scsi-pci --boot order=scsi0 --agent enabled=1 && rm -f /tmp/pbox-os.img && qm start %VM_ID% && echo 'VM started successfully'"

echo.
echo [OK] 部署完成!
goto :show_access_info

:: ==================== ESXi 部署 ====================
:deploy_esxi
echo.
echo === VMware ESXi 部署 ===
echo.
echo [WARN] ESXi 部署需要 qemu-img 进行格式转换
echo 请确保已安装 QEMU for Windows
echo 下载地址: https://qemu.weilnetz.de/w64/
echo.

where qemu-img >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] 未找到 qemu-img
    echo 请从 https://qemu.weilnetz.de/w64/ 下载安装 QEMU
    pause
    exit /b 1
)

set /p "VM_NAME=虚拟机名称 [pbox]: "
if "%VM_NAME%"=="" set "VM_NAME=pbox"

set /p "VM_CORES=CPU 核心数 [4]: "
if "%VM_CORES%"=="" set "VM_CORES=4"

set /p "VM_MEMORY=内存大小 MB [2048]: "
if "%VM_MEMORY%"=="" set "VM_MEMORY=2048"

set /p "DATASTORE=数据存储 [datastore1]: "
if "%DATASTORE%"=="" set "DATASTORE=datastore1"

echo.
echo [INFO] 开始部署...

:: 解压镜像
echo [INFO] 解压镜像...
set "TEMP_IMG=%TEMP%\pbox-os-%RANDOM%.img"
set "TEMP_VMDK=%TEMP%\pbox-os-%RANDOM%.vmdk"

powershell -Command "& { $fs = [System.IO.File]::OpenRead('%IMAGE_FILE%'); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $out = [System.IO.File]::Create('%TEMP_IMG%'); $gz.CopyTo($out); $gz.Close(); $out.Close(); $fs.Close() }"

:: 转换为 VMDK
echo [INFO] 转换为 VMDK 格式...
qemu-img convert -f raw -O vmdk -o adapter_type=lsilogic,subformat=monolithicSparse "%TEMP_IMG%" "%TEMP_VMDK%"
del "%TEMP_IMG%" 2>nul

:: 上传
echo [INFO] 上传 VMDK 到 ESXi...
scp -o StrictHostKeyChecking=no -P %SSH_PORT% "%TEMP_VMDK%" %SSH_USER%@%HOST_IP%:/vmfs/volumes/%DATASTORE%/pbox-temp.vmdk
del "%TEMP_VMDK%" 2>nul

:: 创建 VM
echo [INFO] 创建虚拟机...
ssh -o StrictHostKeyChecking=no -p %SSH_PORT% %SSH_USER%@%HOST_IP% "mkdir -p /vmfs/volumes/%DATASTORE%/%VM_NAME% && mv /vmfs/volumes/%DATASTORE%/pbox-temp.vmdk /vmfs/volumes/%DATASTORE%/%VM_NAME%/%VM_NAME%.vmdk"

echo.
echo [OK] VMDK 已上传到 ESXi
echo 请在 ESXi Web 控制台中手动创建虚拟机并使用此 VMDK
goto :show_access_info

:: ==================== VMware Workstation 部署 ====================
:deploy_vmware
echo.
echo === VMware Workstation 部署 ===
echo.

where qemu-img >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] 需要 qemu-img 工具
    echo 请从 https://qemu.weilnetz.de/w64/ 下载安装 QEMU
    pause
    exit /b 1
)

set /p "VM_PATH=虚拟机保存路径: "
if "%VM_PATH%"=="" (
    echo [ERROR] 路径不能为空
    pause
    exit /b 1
)

set /p "VM_NAME=虚拟机名称 [pbox]: "
if "%VM_NAME%"=="" set "VM_NAME=pbox"

set /p "VM_CORES=CPU 核心数 [4]: "
if "%VM_CORES%"=="" set "VM_CORES=4"

set /p "VM_MEMORY=内存大小 MB [2048]: "
if "%VM_MEMORY%"=="" set "VM_MEMORY=2048"

set "VM_DIR=%VM_PATH%\%VM_NAME%"
if not exist "%VM_DIR%" mkdir "%VM_DIR%"

echo.
echo [INFO] 开始部署...

:: 解压镜像
echo [INFO] 解压镜像...
set "TEMP_IMG=%TEMP%\pbox-os-%RANDOM%.img"

powershell -Command "& { $fs = [System.IO.File]::OpenRead('%IMAGE_FILE%'); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $out = [System.IO.File]::Create('%TEMP_IMG%'); $gz.CopyTo($out); $gz.Close(); $out.Close(); $fs.Close() }"

:: 转换为 VMDK
echo [INFO] 转换为 VMDK 格式...
qemu-img convert -f raw -O vmdk -o adapter_type=lsilogic "%TEMP_IMG%" "%VM_DIR%\%VM_NAME%.vmdk"
del "%TEMP_IMG%" 2>nul

:: 创建 VMX 文件
echo [INFO] 创建虚拟机配置...
(
echo .encoding = "UTF-8"
echo config.version = "8"
echo virtualHW.version = "16"
echo displayName = "%VM_NAME%"
echo guestOS = "debian10-64"
echo memSize = "%VM_MEMORY%"
echo numvcpus = "%VM_CORES%"
echo scsi0.present = "TRUE"
echo scsi0.virtualDev = "lsilogic"
echo scsi0:0.present = "TRUE"
echo scsi0:0.fileName = "%VM_NAME%.vmdk"
echo ethernet0.present = "TRUE"
echo ethernet0.virtualDev = "e1000"
echo ethernet0.connectionType = "nat"
echo ethernet0.addressType = "generated"
echo ethernet0.startConnected = "TRUE"
echo tools.syncTime = "TRUE"
echo firmware = "bios"
) > "%VM_DIR%\%VM_NAME%.vmx"

echo.
echo [OK] 部署完成!
echo.
echo 虚拟机文件: %VM_DIR%\%VM_NAME%.vmx
echo.
echo 请在 VMware Workstation 中: 文件 - 打开 - 选择此文件
goto :show_access_info

:: ==================== VirtualBox 部署 ====================
:deploy_virtualbox
echo.
echo === VirtualBox 部署 ===
echo.

set /p "VM_NAME=虚拟机名称 [pbox]: "
if "%VM_NAME%"=="" set "VM_NAME=pbox"

set /p "VM_CORES=CPU 核心数 [4]: "
if "%VM_CORES%"=="" set "VM_CORES=4"

set /p "VM_MEMORY=内存大小 MB [2048]: "
if "%VM_MEMORY%"=="" set "VM_MEMORY=2048"

echo.
echo [INFO] 开始部署...

:: 解压镜像
echo [INFO] 解压镜像...
set "TEMP_IMG=%TEMP%\pbox-os-%RANDOM%.img"
set "TEMP_VDI=%TEMP%\pbox-os-%RANDOM%.vdi"

powershell -Command "& { $fs = [System.IO.File]::OpenRead('%IMAGE_FILE%'); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $out = [System.IO.File]::Create('%TEMP_IMG%'); $gz.CopyTo($out); $gz.Close(); $out.Close(); $fs.Close() }"

:: 转换为 VDI
echo [INFO] 转换为 VDI 格式...

where VBoxManage >nul 2>&1
if %errorlevel% equ 0 (
    VBoxManage convertfromraw "%TEMP_IMG%" "%TEMP_VDI%" --format VDI
    del "%TEMP_IMG%" 2>nul
    
    :: 删除已存在的 VM
    VBoxManage unregistervm "%VM_NAME%" --delete 2>nul
    
    :: 创建 VM
    echo [INFO] 创建虚拟机...
    VBoxManage createvm --name "%VM_NAME%" --ostype "Debian_64" --register
    VBoxManage modifyvm "%VM_NAME%" --memory %VM_MEMORY% --cpus %VM_CORES% --nic1 nat --audio none --firmware bios
    VBoxManage storagectl "%VM_NAME%" --name "SATA" --add sata --controller IntelAhci --portcount 1
    
    :: 获取 VM 目录
    for /f "tokens=2 delims==" %%a in ('VBoxManage showvminfo "%VM_NAME%" --machinereadable ^| findstr "CfgFile"') do set "VM_CFG=%%~a"
    for %%i in ("%VM_CFG%") do set "VM_DIR=%%~dpi"
    
    move "%TEMP_VDI%" "%VM_DIR%%VM_NAME%.vdi" >nul
    
    VBoxManage storageattach "%VM_NAME%" --storagectl "SATA" --port 0 --device 0 --type hdd --medium "%VM_DIR%%VM_NAME%.vdi"
    
    :: 启动 VM
    echo [INFO] 启动虚拟机...
    VBoxManage startvm "%VM_NAME%" --type headless
    
    echo.
    echo [OK] 部署完成!
) else (
    where qemu-img >nul 2>&1
    if %errorlevel% equ 0 (
        qemu-img convert -f raw -O vdi "%TEMP_IMG%" "%TEMP_VDI%"
        del "%TEMP_IMG%" 2>nul
        echo.
        echo [OK] VDI 文件已创建: %TEMP_VDI%
        echo.
        echo 请在 VirtualBox 中手动创建虚拟机并使用此磁盘
    ) else (
        echo [ERROR] 需要 VBoxManage 或 qemu-img
        del "%TEMP_IMG%" 2>nul
        pause
        exit /b 1
    )
)

goto :show_access_info

:: ==================== Hyper-V 部署 ====================
:deploy_hyperv
echo.
echo === Hyper-V 部署 ===
echo.

:: 检查管理员权限
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo [WARN] Hyper-V 部署需要管理员权限
    echo 请右键"以管理员身份运行"此脚本
    echo.
)

where qemu-img >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] 需要 qemu-img 工具
    echo 请从 https://qemu.weilnetz.de/w64/ 下载安装 QEMU
    pause
    exit /b 1
)

set /p "VM_NAME=虚拟机名称 [pbox]: "
if "%VM_NAME%"=="" set "VM_NAME=pbox"

set /p "VM_CORES=CPU 核心数 [4]: "
if "%VM_CORES%"=="" set "VM_CORES=4"

set /p "VM_MEMORY=内存大小 MB [2048]: "
if "%VM_MEMORY%"=="" set "VM_MEMORY=2048"

set /p "VM_PATH=VHDX 保存路径 [C:\Hyper-V]: "
if "%VM_PATH%"=="" set "VM_PATH=C:\Hyper-V"

if not exist "%VM_PATH%" mkdir "%VM_PATH%"

echo.
echo [INFO] 开始部署...

:: 解压镜像
echo [INFO] 解压镜像...
set "TEMP_IMG=%TEMP%\pbox-os-%RANDOM%.img"

powershell -Command "& { $fs = [System.IO.File]::OpenRead('%IMAGE_FILE%'); $gz = New-Object System.IO.Compression.GZipStream($fs, [System.IO.Compression.CompressionMode]::Decompress); $out = [System.IO.File]::Create('%TEMP_IMG%'); $gz.CopyTo($out); $gz.Close(); $out.Close(); $fs.Close() }"

:: 转换为 VHDX
echo [INFO] 转换为 VHDX 格式...
qemu-img convert -f raw -O vhdx -o subformat=dynamic "%TEMP_IMG%" "%VM_PATH%\%VM_NAME%.vhdx"
del "%TEMP_IMG%" 2>nul

echo.
echo [OK] VHDX 文件已创建: %VM_PATH%\%VM_NAME%.vhdx
echo.

:: 尝试自动创建 Hyper-V VM
echo [INFO] 创建 Hyper-V 虚拟机...

powershell -Command "& { try { Remove-VM -Name '%VM_NAME%' -Force -ErrorAction SilentlyContinue; New-VM -Name '%VM_NAME%' -MemoryStartupBytes %VM_MEMORY%MB -Generation 1 -VHDPath '%VM_PATH%\%VM_NAME%.vhdx' -ErrorAction Stop; Set-VMProcessor -VMName '%VM_NAME%' -Count %VM_CORES%; $switch = Get-VMSwitch | Where-Object { $_.SwitchType -eq 'External' } | Select-Object -First 1; if ($switch) { Connect-VMNetworkAdapter -VMName '%VM_NAME%' -SwitchName $switch.Name } else { $defSwitch = Get-VMSwitch -Name 'Default Switch' -ErrorAction SilentlyContinue; if ($defSwitch) { Connect-VMNetworkAdapter -VMName '%VM_NAME%' -SwitchName 'Default Switch' } }; Start-VM -Name '%VM_NAME%'; Write-Host '[OK] Hyper-V 虚拟机已创建并启动' } catch { Write-Host '[ERROR]' $_.Exception.Message; Write-Host '请手动创建虚拟机' } }"

goto :show_access_info

:: ==================== 显示访问信息 ====================
:show_access_info
echo.
echo === 访问信息 ===
echo.
echo   SSH: ssh root@^<VM_IP^>
echo   密码: pbox123
echo   Web 面板: https://^<VM_IP^>
echo   终端菜单: 输入 pbox
echo.
echo ════════════════════════════════════════
echo   P-BOX OS 部署完成！
echo ════════════════════════════════════════
echo.
pause
exit /b 0
