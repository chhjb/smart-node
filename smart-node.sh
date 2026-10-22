#!/bin/bash
# ============================================
# 智能内存检测 + 交互式 VLESS + REALITY 节点脚本
# v2.1  深度优化版（兼容新旧 Xray x25519 输出）
# 特别优化 64MB / 128MB 超低内存小鸡
# ============================================

# 不使用 set -e，改为关键步骤手动检查，避免低内存环境误退出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"
INFO_FILE="${CONFIG_DIR}/node.info"
XRAY_BIN="/usr/local/bin/xray"
SCRIPT_VERSION="2.1"

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
title()   { echo -e "${CYAN}$1${NC}"; }

[[ $EUID -ne 0 ]] && { error "请使用 root 用户运行"; exit 1; }

# ==================== 内存检测 ====================
get_total_mem() {
    free -m | awk '/^Mem:/{print $2}'
}

get_available_mem() {
    free -m | awk '/^Mem:/{print $7}'
}

detect_and_recommend() {
    TOTAL_MEM=$(get_total_mem)
    AVAIL_MEM=$(get_available_mem)

    echo
    title "========== 内存检测结果 =========="
    echo -e "总内存      : ${YELLOW}${TOTAL_MEM} MB${NC}"
    echo -e "当前可用    : ${YELLOW}${AVAIL_MEM} MB${NC}"
    echo

    if (( TOTAL_MEM <= 80 )); then
        LEVEL="extreme"
        RECOMMEND="极限模式 REALITY（强制 384MB Swap + 内存硬限制 45M + 推荐高位端口）"
        COLOR=$RED
        ADVICE="64MB 级别极度危险！必须创建较大 Swap，关闭所有其他服务，仅跑此节点。强烈建议使用 10000+ 随机端口"
    elif (( TOTAL_MEM <= 180 )); then
        LEVEL="ultra-low"
        RECOMMEND="超轻量 REALITY（强制 256MB Swap + 内存限制 70M）"
        COLOR=$RED
        ADVICE="强烈建议只跑单节点，不要装面板/监控/Docker"
    elif (( TOTAL_MEM <= 400 )); then
        LEVEL="low"
        RECOMMEND="轻量 REALITY（创建 512MB Swap + 内存限制 100M）"
        COLOR=$YELLOW
        ADVICE="推荐使用本脚本轻量模式"
    elif (( TOTAL_MEM <= 900 )); then
        LEVEL="medium"
        RECOMMEND="标准 REALITY（轻度 Swap，不强制内存限制）"
        COLOR=$GREEN
        ADVICE="内存较充足，可使用标准配置"
    else
        LEVEL="high"
        RECOMMEND="完整功能 REALITY"
        COLOR=$GREEN
        ADVICE="内存充足，可自由扩展"
    fi

    echo -e "推荐方案    : ${COLOR}${RECOMMEND}${NC}"
    echo -e "建议        : ${ADVICE}"
    echo -e "${CYAN}=================================${NC}"
    echo
}

# ==================== 工具函数 ====================
get_ip() {
    local ip
    ip=$(curl -s4 --connect-timeout 5 ifconfig.me 2>/dev/null) || \
    ip=$(curl -s4 --connect-timeout 5 ip.sb 2>/dev/null) || \
    ip=$(curl -s4 --connect-timeout 5 icanhazip.com 2>/dev/null) || \
    ip=$(curl -s4 --connect-timeout 5 api.ipify.org 2>/dev/null)
    if [[ -z $ip ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    fi
    echo "$ip"
}

check_port() {
    local port=$1
    if command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -q ":${port} " && return 1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep -q ":${port} " && return 1
    fi
    return 0
}

create_swap() {
    local size=${1:-256}
    if swapon --show 2>/dev/null | grep -q .; then
        info "已存在 Swap，跳过创建"
        return 0
    fi

    # 检查磁盘空间（至少需要 size + 50MB）
    local avail_kb
    avail_kb=$(df / | awk 'NR==2 {print $4}')
    if (( avail_kb < (size + 50) * 1024 )); then
        warn "磁盘剩余空间不足，无法创建 ${size}MB Swap（剩余约 $((avail_kb/1024))MB）"
        return 1
    fi

    info "创建 ${size}MB Swap（这对低内存小鸡至关重要）..."
    rm -f /swapfile
    if ! fallocate -l ${size}M /swapfile 2>/dev/null; then
        if ! dd if=/dev/zero of=/swapfile bs=1M count=${size} status=none 2>/dev/null; then
            error "创建 Swap 文件失败"
            return 1
        fi
    fi
    chmod 600 /swapfile
    if ! mkswap /swapfile >/dev/null 2>&1; then
        error "mkswap 失败"
        rm -f /swapfile
        return 1
    fi
    if ! swapon /swapfile 2>/dev/null; then
        error "启用 Swap 失败"
        rm -f /swapfile
        return 1
    fi
    grep -q '/swapfile' /etc/fstab 2>/dev/null || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    # 降低 swappiness，减少不必要换入换出
    sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    success "Swap 创建完成（${size}MB）"
    return 0
}

install_deps() {
    info "安装最小依赖..."
    if command -v apt >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y -qq >/dev/null 2>&1
        apt-get install -y -qq curl unzip openssl ca-certificates --no-install-recommends >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q curl unzip openssl ca-certificates >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q curl unzip openssl ca-certificates >/dev/null 2>&1
    else
        error "不支持的系统（需要 apt/yum/dnf）"
        return 1
    fi
    success "依赖安装完成"
}

# 下载 Xray，带简单重试和校验
install_xray() {
    if [[ -x $XRAY_BIN ]]; then
        # 简单验证能否运行
        if $XRAY_BIN version >/dev/null 2>&1; then
            info "Xray 已存在且可用"
            return 0
        else
            warn "已有 Xray 二进制异常，重新下载"
            rm -f $XRAY_BIN
        fi
    fi

    info "下载 Xray（最新版）..."
    local ARCH XARCH
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64) XARCH="64" ;;
        aarch64|arm64) XARCH="arm64-v8a" ;;
        armv7l|armv7) XARCH="arm32-v7a" ;;
        *) error "不支持架构: $ARCH"; return 1 ;;
    esac

    local url="https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-${XARCH}.zip"
    local tmp="/tmp/xray_$$.zip"
    local retry=0
    while (( retry < 3 )); do
        if curl -fsSL --connect-timeout 15 --max-time 120 -o "$tmp" "$url"; then
            break
        fi
        ((retry++))
        warn "下载失败，重试 $retry/3 ..."
        sleep 2
    done
    if [[ ! -f $tmp ]]; then
        error "Xray 下载失败，请检查网络能否访问 GitHub"
        return 1
    fi

    if ! unzip -o -q "$tmp" xray -d /tmp 2>/dev/null; then
        error "解压失败"
        rm -f "$tmp"
        return 1
    fi
    mv -f /tmp/xray $XRAY_BIN
    chmod +x $XRAY_BIN
    rm -f "$tmp"

    if ! $XRAY_BIN version >/dev/null 2>&1; then
        error "Xray 二进制无法运行"
        return 1
    fi
    success "Xray 安装完成（$($XRAY_BIN version 2>/dev/null | head -1)）"
}

# ========== 关键修复：兼容新旧 x25519 输出格式 ==========
# 旧格式: Private key: / Public key:
# 新格式: PrivateKey: / Password:  或  Password (PublicKey):
generate_keys() {
    local output
    output=$($XRAY_BIN x25519 2>/dev/null)
    if [[ -z $output ]]; then
        error "生成密钥失败"
        return 1
    fi

    # 统一转小写方便匹配，但保留原始值
    PRIVATE_KEY=$(echo "$output" | grep -iE 'Private(Key)?[[:space:]]*:' | head -1 | sed -E 's/.*:[[:space:]]*//')
    # 优先匹配 Password (PublicKey) / Password / Public key / PublicKey
    PUBLIC_KEY=$(echo "$output" | grep -iE 'Password \(PublicKey\)|Password:|Public[[:space:]]*key:|PublicKey:' | head -1 | sed -E 's/.*:[[:space:]]*//')

    if [[ -z $PRIVATE_KEY || -z $PUBLIC_KEY ]]; then
        error "解析密钥失败，原始输出如下："
        echo "$output"
        return 1
    fi
    # 去掉可能的空格
    PRIVATE_KEY=$(echo "$PRIVATE_KEY" | tr -d '[:space:]')
    PUBLIC_KEY=$(echo "$PUBLIC_KEY" | tr -d '[:space:]')
    return 0
}

write_config() {
    local uuid=$1 port=$2 private_key=$3 short_id=$4 dest=${5:-"www.microsoft.com:443"}
    local sni=${dest%%:*}
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "loglevel": "none"
  },
  "inbounds": [
    {
      "listen": "0.0.0.0",
      "port": ${port},
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${uuid}",
            "flow": "xtls-rprx-vision"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "tcp",
        "security": "reality",
        "realitySettings": {
          "show": false,
          "dest": "${dest}",
          "xver": 0,
          "serverNames": [
            "${sni}"
          ],
          "privateKey": "${private_key}",
          "shortIds": [
            "${short_id}"
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"]
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct"
    }
  ]
}
EOF
}

write_service() {
    local mem_max=$1
    local mem_high=$2

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Xray Service (Smart LowMem v${SCRIPT_VERSION})
Documentation=https://github.com/XTLS/Xray-core
After=network.target nss-lookup.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
ExecStart=${XRAY_BIN} run -c ${CONFIG_FILE}
Restart=always
RestartSec=5
LimitNOFILE=1048576
OOMScoreAdjust=-800
EOF

    if [[ -n $mem_max ]]; then
        # 兼容较老 systemd（无 MemoryMax 时忽略）
        echo "MemoryMax=${mem_max}" >> "$SERVICE_FILE"
        echo "MemoryHigh=${mem_high}" >> "$SERVICE_FILE"
    fi

    cat >> "$SERVICE_FILE" << EOF

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload 2>/dev/null || true
}

save_info() {
    cat > "$INFO_FILE" << EOF
UUID=$1
PORT=$2
PRIVATE_KEY=$3
PUBLIC_KEY=$4
SHORT_ID=$5
SERVER_IP=$6
LEVEL=$7
DEST=$8
EOF
}

load_info() {
    UUID=""; PORT=""; PRIVATE_KEY=""; PUBLIC_KEY=""; SHORT_ID=""; SERVER_IP=""; LEVEL=""; DEST=""
    [[ -f $INFO_FILE ]] && source "$INFO_FILE"
}

show_link() {
    load_info
    if [[ -z $UUID ]]; then
        warn "尚未安装节点"
        return
    fi
    local ip=${SERVER_IP:-$(get_ip)}
    local sni=${DEST%%:*}
    sni=${sni:-www.microsoft.com}
    local link="vless://${UUID}@${ip}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${SHORT_ID}&type=tcp&headerType=none#Smart-Reality-${LEVEL}"
    echo
    title "========== 节点信息 =========="
    echo "服务器 IP : $ip"
    echo "端口      : $PORT"
    echo "UUID      : $UUID"
    echo "PublicKey : $PUBLIC_KEY"
    echo "ShortID   : $SHORT_ID"
    echo "伪装目标  : ${DEST:-www.microsoft.com:443}"
    echo "安装模式  : $LEVEL"
    echo
    echo -e "${YELLOW}分享链接（复制到客户端）：${NC}"
    echo "$link"
    echo -e "${CYAN}==============================${NC}"
}

enable_bbr() {
    if lsmod | grep -q bbr; then
        info "BBR 已启用"
        return
    fi
    info "尝试启用 BBR..."
    modprobe tcp_bbr 2>/dev/null || true
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        success "BBR 已启用"
    else
        warn "BBR 启用失败（可能是内核不支持），不影响节点使用"
    fi
}

# ==================== 安装逻辑 ====================
install_node() {
    detect_and_recommend

    if [[ -f $INFO_FILE ]]; then
        warn "检测到已安装节点"
        read -p "是否覆盖重装？(y/N): " overwrite
        [[ $overwrite != "y" && $overwrite != "Y" ]] && return
    fi

    if [[ $LEVEL == "extreme" ]]; then
        echo -e "${RED}警告：64MB 级别内存非常极限，Xray 仍可能因 OOM 被杀。${NC}"
        echo -e "${RED}请确保已关闭所有不必要进程，并准备好较大 Swap。${NC}"
        echo
    fi

    read -p "是否按推荐方案继续安装？(Y/n): " confirm
    [[ $confirm == "n" || $confirm == "N" ]] && return

    echo
    info "开始安装（模式: $LEVEL）..."

    local MEM_MAX="" MEM_HIGH="" SWAP_SIZE=256 DEFAULT_PORT=443

    case $LEVEL in
        extreme)
            SWAP_SIZE=384
            MEM_MAX="45M"
            MEM_HIGH="35M"
            DEFAULT_PORT=$((10000 + RANDOM % 50000))
            ;;
        ultra-low)
            SWAP_SIZE=256
            MEM_MAX="70M"
            MEM_HIGH="55M"
            ;;
        low)
            SWAP_SIZE=512
            MEM_MAX="100M"
            MEM_HIGH="80M"
            ;;
        medium)
            SWAP_SIZE=256
            ;;
        high)
            SWAP_SIZE=0
            ;;
    esac

    if (( SWAP_SIZE > 0 )); then
        create_swap $SWAP_SIZE || warn "Swap 创建失败，继续尝试安装（风险较高）"
    fi

    install_deps || return
    install_xray || return

    # 生成参数
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid 2>/dev/null)
    [[ -z $UUID ]] && UUID=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')

    # 端口选择
    PORT=$DEFAULT_PORT
    if [[ $LEVEL == "extreme" ]]; then
        info "极限模式默认使用高位端口: $PORT"
        read -p "直接回车使用 $PORT，或输入自定义端口: " custom_port
        [[ -n $custom_port ]] && PORT=$custom_port
    else
        read -p "请输入端口（直接回车使用 $DEFAULT_PORT）: " custom_port
        [[ -n $custom_port ]] && PORT=$custom_port
    fi

    if ! [[ $PORT =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        error "端口无效"
        return
    fi
    if ! check_port $PORT; then
        warn "端口 $PORT 似乎已被占用，仍将继续（请自行确认）"
    fi

    SHORT_ID=$(openssl rand -hex 4 2>/dev/null || head -c 4 /dev/urandom | xxd -p)
    generate_keys || return
    SERVER_IP=$(get_ip)
    DEST="www.microsoft.com:443"

    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "$DEST"
    write_service "$MEM_MAX" "$MEM_HIGH"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "$DEST"

    # 防火墙
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${PORT}/tcp >/dev/null 2>&1 || true
        ufw reload >/dev/null 2>&1 || true
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=${PORT}/tcp >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    else
        # 尝试 iptables
        iptables -C INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport $PORT -j ACCEPT 2>/dev/null || true
    fi

    # 可选启用 BBR（高内存或用户确认）
    if [[ $LEVEL == "medium" || $LEVEL == "high" ]]; then
        enable_bbr
    fi

    systemctl enable xray >/dev/null 2>&1
    systemctl restart xray
    sleep 2

    if systemctl is-active --quiet xray; then
        success "安装成功！当前模式：$LEVEL"
        # 显示实际进程内存
        local rss
        rss=$(ps -o rss= -C xray 2>/dev/null | awk '{sum+=$1} END{print sum}')
        if [[ -n $rss ]]; then
            info "当前 Xray 进程内存占用约: $((rss/1024)) MB"
        fi
        show_link
        echo
        free -m
        echo
        if [[ $LEVEL == "extreme" || $LEVEL == "ultra-low" ]]; then
            warn "低内存小鸡请定期执行 free -m 观察，必要时 systemctl restart xray"
            warn "如频繁被杀，可执行 dmesg | grep -i 'out of memory\\|killed process'"
        fi
    else
        error "启动失败"
        echo "请执行以下命令排查："
        echo "  journalctl -u xray -n 30 --no-pager"
        echo "  dmesg | tail -30"
        return 1
    fi
}

change_port() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    read -p "请输入新端口 (当前: $PORT): " new_port
    [[ -z $new_port ]] && return
    if ! [[ $new_port =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
        error "端口无效"; return
    fi
    if ! check_port $new_port; then
        warn "端口 $new_port 似乎已被占用"
    fi
    PORT=$new_port
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    systemctl restart xray
    success "端口已修改为 $PORT"
    show_link
}

change_uuid() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || $XRAY_BIN uuid)
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    systemctl restart xray
    success "UUID 已重新生成"
    show_link
}

change_dest() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    echo "常用伪装目标示例："
    echo "  www.microsoft.com:443"
    echo "  www.cloudflare.com:443"
    echo "  www.apple.com:443"
    echo "  www.amazon.com:443"
    echo "  www.samsung.com:443"
    read -p "请输入新的 dest（格式 host:port，当前: ${DEST:-www.microsoft.com:443}）: " new_dest
    [[ -z $new_dest ]] && return
    DEST=$new_dest
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "$DEST"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "$DEST"
    systemctl restart xray
    success "伪装目标已修改为 $DEST"
    show_link
}

restart_xray() {
    systemctl restart xray
    sleep 1
    if systemctl is-active --quiet xray; then
        success "重启成功"
        local rss
        rss=$(ps -o rss= -C xray 2>/dev/null | awk '{sum+=$1} END{print sum}')
        [[ -n $rss ]] && info "当前内存占用约: $((rss/1024)) MB"
    else
        error "重启失败，请查看 journalctl -u xray -n 20"
    fi
}

status_xray() {
    echo
    systemctl status xray --no-pager -l 2>/dev/null || warn "服务未安装或 systemd 不可用"
    echo
    title "----- 内存与 Swap -----"
    free -m
    echo
    swapon --show 2>/dev/null || true
    echo
    if pgrep -x xray >/dev/null; then
        local rss
        rss=$(ps -o rss= -C xray 2>/dev/null | awk '{sum+=$1} END{print sum}')
        info "Xray 进程实际 RSS: $((rss/1024)) MB"
    else
        warn "未发现 xray 进程"
    fi
}

uninstall_node() {
    read -p "确认卸载节点？(y/N): " confirm
    [[ $confirm != "y" && $confirm != "Y" ]] && return
    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true
    rm -f "$SERVICE_FILE"
    systemctl daemon-reload 2>/dev/null || true
    rm -rf "$CONFIG_DIR"
    # 不删除 xray 二进制，方便后续重装；如需彻底清理可手动 rm
    success "节点已卸载（Xray 二进制保留，可手动删除 /usr/local/bin/xray）"
}

# ==================== 主菜单 ====================
show_menu() {
    clear
    TOTAL_MEM=$(get_total_mem)
    echo -e "${BLUE}=========================================${NC}"
    echo -e "${BLUE}  智能内存检测节点脚本 v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}  支持 64MB / 128MB 极限小鸡 + 兼容新版 Xray${NC}"
    echo -e "${BLUE}=========================================${NC}"
    echo -e "  当前总内存: ${YELLOW}${TOTAL_MEM} MB${NC}"
    echo
    echo "  1. 智能安装节点（自动检测内存并推荐）"
    echo "  2. 查看节点信息 / 分享链接"
    echo "  3. 修改端口"
    echo "  4. 重新生成 UUID"
    echo "  5. 修改伪装目标 (dest/SNI)"
    echo "  6. 重启服务"
    echo "  7. 查看运行状态 + 内存"
    echo "  8. 仅检测内存并显示推荐"
    echo "  9. 启用 BBR（可选）"
    echo " 10. 卸载节点"
    echo "  0. 退出"
    echo
    echo -e "${BLUE}=========================================${NC}"
}

# ==================== 主循环 ====================
while true; do
    show_menu
    read -p "请输入选项 [0-10]: " choice
    case $choice in
        1) install_node ;;
        2) show_link ;;
        3) change_port ;;
        4) change_uuid ;;
        5) change_dest ;;
        6) restart_xray ;;
        7) status_xray ;;
        8) detect_and_recommend; read -p "按回车返回..." ;;
        9) enable_bbr ;;
        10) uninstall_node ;;
        0) echo "退出"; exit 0 ;;
        *) warn "无效选项" ;;
    esac
    echo
    read -p "按回车键返回菜单..."
done
