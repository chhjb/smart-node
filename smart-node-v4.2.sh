#!/bin/bash
# ============================================================
# 智能内存检测 + 交互式 VLESS + REALITY 节点脚本
# v4.2  支持一键自更新
#
# 对照参考：233boy/Xray、mack-a/v2ray-agent、reality-ezpz、
#          nokey、oldfriendme/xrayREALITY、官方 Xray-install
# 特别优化：64MB / 128MB / 256MB 超低内存小鸡
#
# 官方仓库 / 自更新地址：
#   https://github.com/chhjb/smart-node
#   https://raw.githubusercontent.com/chhjb/smart-node/main/smart-node.sh
#
# 一键安装/更新：
#   bash <(curl -fsSL https://raw.githubusercontent.com/chhjb/smart-node/main/smart-node.sh)
#
# v4.2 主要升级：
#   1. 新增「更新本脚本」功能，支持多镜像自动下载覆盖
#   2. 一键安装/更新命令标准化
#   3. 保留 v4.1 全部优化（OOM 保护、配置备份、自检、导出等）
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"
INFO_FILE="${CONFIG_DIR}/node.info"
BACKUP_DIR="${CONFIG_DIR}/backup"
XRAY_BIN="/usr/local/bin/xray"
SCRIPT_VERSION="4.2"
# 自更新主地址（可改）
SCRIPT_RAW_URL="https://raw.githubusercontent.com/chhjb/smart-node/main/smart-node.sh"
SCRIPT_RAW_MIRRORS=(
    "https://raw.githubusercontent.com/chhjb/smart-node/main/smart-node.sh"
    "https://ghfast.top/https://raw.githubusercontent.com/chhjb/smart-node/main/smart-node.sh"
    "https://mirror.ghproxy.com/https://raw.githubusercontent.com/chhjb/smart-node/main/smart-node.sh"
    "https://cdn.jsdelivr.net/gh/chhjb/smart-node@main/smart-node.sh"
)

# 运行时缓存
_CACHE_TOTAL_MEM=""
_CACHE_AVAIL_MEM=""
_CACHE_IP=""
_CACHE_IP_TS=0

# 常用 REALITY 伪装目标（2025-2026 实测较稳定，优先高流量站点）
DEST_LIST=(
    "www.microsoft.com:443"
    "www.cloudflare.com:443"
    "www.apple.com:443"
    "www.amazon.com:443"
    "www.samsung.com:443"
    "www.intel.com:443"
    "www.nvidia.com:443"
    "addons.mozilla.org:443"
    "www.lovelive-anime.jp:443"
    "gateway.icloud.com:443"
    "www.bing.com:443"
    "dl.google.com:443"
    "www.sony.com:443"
)

info()    { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $1"; }
error()   { echo -e "${RED}[ERROR]${NC} $1"; }
success() { echo -e "${GREEN}[OK]${NC} $1"; }
title()   { echo -e "${CYAN}$1${NC}"; }

[[ $EUID -ne 0 ]] && { error "请使用 root 用户运行"; exit 1; }

# ======================== 系统与内存检测 ========================
get_total_mem() {
    if [[ -n $_CACHE_TOTAL_MEM ]]; then
        echo "$_CACHE_TOTAL_MEM"
        return
    fi
    _CACHE_TOTAL_MEM=$(free -m | awk '/^Mem:/{print $2; exit}')
    echo "${_CACHE_TOTAL_MEM:-0}"
}

get_available_mem() {
    if [[ -n $_CACHE_AVAIL_MEM ]]; then
        echo "$_CACHE_AVAIL_MEM"
        return
    fi
    local t a
    read -r t a < <(free -m | awk '/^Mem:/{ avail=$7; if(avail==""||avail==0) avail=$4; print $2, avail; exit }')
    _CACHE_TOTAL_MEM=${t:-0}
    _CACHE_AVAIL_MEM=${a:-0}
    echo "$_CACHE_AVAIL_MEM"
}

refresh_mem_cache() {
    _CACHE_TOTAL_MEM=""
    _CACHE_AVAIL_MEM=""
    get_available_mem >/dev/null
}

has_systemd() {
    command -v systemctl >/dev/null 2>&1 && [[ -d /run/systemd/system ]]
}

systemd_supports_memory_max() {
    systemctl --version 2>/dev/null | head -1 | grep -qE 'systemd (2[4-9][0-9]|[3-9][0-9]{2,})' && return 0
    mkdir -p /tmp/smart-node-test 2>/dev/null
    echo -e "[Service]\nMemoryMax=50M" > /tmp/smart-node-test/test.service 2>/dev/null
    if systemd-analyze verify /tmp/smart-node-test/test.service >/dev/null 2>&1; then
        rm -rf /tmp/smart-node-test
        return 0
    fi
    rm -rf /tmp/smart-node-test
    return 1
}

# 简单内存压力提示
get_mem_pressure_hint() {
    local total avail used_pct
    total=$(get_total_mem)
    avail=$(get_available_mem)
    (( total == 0 )) && { echo "未知"; return; }
    used_pct=$(( (total - avail) * 100 / total ))
    if (( used_pct >= 90 )); then
        echo -e "${RED}极高 (${used_pct}%)${NC}"
    elif (( used_pct >= 75 )); then
        echo -e "${YELLOW}偏高 (${used_pct}%)${NC}"
    else
        echo -e "${GREEN}正常 (${used_pct}%)${NC}"
    fi
}

detect_and_recommend() {
    [[ $1 == "refresh" ]] && refresh_mem_cache
    TOTAL_MEM=$(get_total_mem)
    AVAIL_MEM=$(get_available_mem)
    local swap_total disk_free_mb arch has_bbr_mod heavy_hint port443_busy existing_xray

    swap_total=$(free -m | awk '/^Swap:/{print $2}')
    disk_free_mb=$(df -m / 2>/dev/null | awk 'NR==2{print $4}')
    arch=$(uname -m)
    existing_xray=0
    [[ -x $XRAY_BIN ]] && existing_xray=1
    port443_busy=0
    check_port_free 443 || port443_busy=1

    has_bbr_mod=0
    if [[ -f /proc/sys/net/ipv4/tcp_congestion_control ]] && \
       grep -qw bbr /proc/sys/net/ipv4/tcp_available_congestion_control 2>/dev/null; then
        has_bbr_mod=1
    fi

    heavy_hint=""
    if [[ -r /proc ]]; then
        heavy_hint=$(ps -eo comm= 2>/dev/null | grep -E '^(docker|dockerd|containerd|nginx|apache2|httpd|mysqld|mysql|mariadb|postgres|redis-server|mongod|caddy|traefik|java|php-fpm)$' | sort -u | tr '\n' ' ')
    fi

    echo
    title "========== 智能环境检测 =========="
    echo -e "架构        : ${YELLOW}${arch}${NC}"
    echo -e "总内存      : ${YELLOW}${TOTAL_MEM} MB${NC}"
    echo -e "当前可用    : ${YELLOW}${AVAIL_MEM} MB${NC}"
    echo -e "内存压力    : $(get_mem_pressure_hint)"
    echo -e "已有 Swap   : ${YELLOW}${swap_total:-0} MB${NC}"
    echo -e "磁盘剩余    : ${YELLOW}${disk_free_mb:-?} MB${NC}"
    echo -e "systemd     : $(has_systemd && echo 有 || echo 无)"
    echo -e "BBR 可用    : $([[ $has_bbr_mod -eq 1 ]] && echo 是 || echo 否/未知)"
    echo -e "443 端口    : $([[ $port443_busy -eq 1 ]] && echo -e "${RED}已被占用${NC}" || echo 空闲)"
    echo -e "已装 Xray   : $([[ $existing_xray -eq 1 ]] && echo 是 || echo 否)"
    if [[ -n $heavy_hint ]]; then
        echo -e "重进程占用  : ${RED}${heavy_hint}${NC}"
    else
        echo -e "重进程占用  : 未发现常见重服务"
    fi
    echo

    local effective=$TOTAL_MEM
    if (( AVAIL_MEM > 0 && AVAIL_MEM < TOTAL_MEM / 3 && AVAIL_MEM < 80 )); then
        if (( TOTAL_MEM < 100 )); then
            effective=$TOTAL_MEM
        else
            effective=90
        fi
    fi
    if [[ -n $heavy_hint ]] && (( TOTAL_MEM <= 512 )); then
        if (( effective > 50 )); then
            effective=$(( effective - 40 ))
        fi
    fi

    if (( effective <= 80 )); then
        LEVEL="extreme"
        RECOMMEND="极限模式 REALITY（大 Swap + MemoryMax=45M + TasksMax + OOM 保护 + 高位端口）"
        COLOR=$RED
        ADVICE="64MB 级极度危险。务必关掉其它服务；优先高位端口；仅跑本节点。"
        SMART_PORT_HINT="high"
        SMART_SWAP=384
        SMART_MEM_MAX="45M"
        SMART_MEM_HIGH="35M"
        SMART_TASKS_MAX="32"
        SMART_CPU_QUOTA="60%"
        SMART_OOM_SCORE="500"
        SMART_BBR=0
    elif (( effective <= 180 )); then
        LEVEL="ultra-low"
        RECOMMEND="超轻量 REALITY（256MB Swap + MemoryMax=70M）"
        COLOR=$RED
        ADVICE="只跑单节点，不要装面板 / Docker / 监控。"
        SMART_PORT_HINT="prefer443"
        SMART_SWAP=256
        SMART_MEM_MAX="70M"
        SMART_MEM_HIGH="55M"
        SMART_TASKS_MAX="48"
        SMART_CPU_QUOTA=""
        SMART_OOM_SCORE="300"
        SMART_BBR=0
    elif (( effective <= 400 )); then
        LEVEL="low"
        RECOMMEND="轻量 REALITY（按磁盘调整 Swap + MemoryMax=100M）"
        COLOR=$YELLOW
        ADVICE="推荐本脚本轻量模式，可顺带开 BBR（若内核支持）。"
        SMART_PORT_HINT="prefer443"
        SMART_SWAP=512
        SMART_MEM_MAX="100M"
        SMART_MEM_HIGH="80M"
        SMART_TASKS_MAX=""
        SMART_CPU_QUOTA=""
        SMART_OOM_SCORE=""
        SMART_BBR=1
    elif (( effective <= 900 )); then
        LEVEL="medium"
        RECOMMEND="标准 REALITY（轻度 Swap，可选内存限制）"
        COLOR=$GREEN
        ADVICE="内存较充足，建议启用 BBR。"
        SMART_PORT_HINT="prefer443"
        SMART_SWAP=256
        SMART_MEM_MAX=""
        SMART_MEM_HIGH=""
        SMART_TASKS_MAX=""
        SMART_CPU_QUOTA=""
        SMART_OOM_SCORE=""
        SMART_BBR=1
    else
        LEVEL="high"
        RECOMMEND="完整功能 REALITY（可不建 Swap）"
        COLOR=$GREEN
        ADVICE="内存充足，可按需扩展。"
        SMART_PORT_HINT="prefer443"
        SMART_SWAP=0
        SMART_MEM_MAX=""
        SMART_MEM_HIGH=""
        SMART_TASKS_MAX=""
        SMART_CPU_QUOTA=""
        SMART_OOM_SCORE=""
        SMART_BBR=1
    fi

    if (( SMART_SWAP > 0 && disk_free_mb > 0 )); then
        local max_by_disk=$(( disk_free_mb - 100 ))
        (( max_by_disk < 64 )) && max_by_disk=0
        if (( max_by_disk < SMART_SWAP )); then
            if (( max_by_disk >= 64 )); then
                SMART_SWAP=$max_by_disk
                ADVICE="${ADVICE}（磁盘紧张，Swap 已自动降为 ${SMART_SWAP}MB）"
            else
                SMART_SWAP=0
                ADVICE="${ADVICE}（磁盘过小，已跳过 Swap）"
            fi
        fi
    fi
    if (( swap_total >= SMART_SWAP && SMART_SWAP > 0 )); then
        SMART_SWAP=0
        ADVICE="${ADVICE}（已有 Swap，跳过新建）"
    fi

    if [[ $port443_busy -eq 1 ]]; then
        SMART_PORT_HINT="high"
        ADVICE="${ADVICE}；443 已被占用，将推荐高位端口"
    fi
    if [[ $LEVEL == "extreme" ]]; then
        SMART_PORT_HINT="high"
    fi

    if [[ -n $heavy_hint ]] && [[ $LEVEL == "extreme" || $LEVEL == "ultra-low" || $LEVEL == "low" ]]; then
        ADVICE="${ADVICE}；检测到重进程 [${heavy_hint}]，强烈建议先停掉再装"
    fi

    if [[ -n $SMART_MEM_MAX ]] && ! systemd_supports_memory_max; then
        ADVICE="${ADVICE}；当前 systemd 可能不支持 MemoryMax，将自动降级"
        SMART_MEM_MAX=""
        SMART_MEM_HIGH=""
    fi

    echo -e "推荐方案    : ${COLOR}${RECOMMEND}${NC}"
    echo -e "智能参数    : Swap=${SMART_SWAP}MB  MemoryMax=${SMART_MEM_MAX:-无限制}  端口策略=${SMART_PORT_HINT}"
    [[ -n $SMART_TASKS_MAX || -n $SMART_CPU_QUOTA || -n $SMART_OOM_SCORE ]] && \
        echo -e "             TasksMax=${SMART_TASKS_MAX:-无}  CPUQuota=${SMART_CPU_QUOTA:-无}  OOMScore=${SMART_OOM_SCORE:-默认}"
    echo -e "建议        : ${ADVICE}"
    echo -e "${CYAN}=================================${NC}"
    echo
}

smart_route_advice() {
    detect_and_recommend
    echo
    title "========== 智能分流建议 =========="
    case $LEVEL in
        extreme|ultra-low)
            echo -e "${RED}环境判定：超低内存小鸡${NC}"
            echo "建议路径："
            echo "  → 仅使用本脚本「智能安装」（选项 1）"
            echo "  → 不要安装 233boy / mack-a / 面板 / Docker"
            echo "  → 关掉其它服务后再装"
            echo
            echo "原因：全功能脚本会拉依赖、多协议、证书，极易 OOM。"
            ;;
        low)
            echo -e "${YELLOW}环境判定：偏紧内存${NC}"
            echo "建议路径："
            echo "  → 优先本脚本轻量 REALITY（选项 1）"
            echo "  → 若必须多协议，请先升级到 ≥512MB 再考虑其它脚本"
            ;;
        medium|high)
            echo -e "${GREEN}环境判定：内存相对充足${NC}"
            echo "可选路径："
            echo "  1) 本脚本：单节点 REALITY，干净轻量（推荐只需要一个节点时）"
            echo "  2) 全功能脚本：多协议 / 多用户 / 证书（需你确认后才会下载执行）"
            echo
            echo "说明：本入口不会自动偷跑第三方脚本，必须你手动确认。"
            ;;
    esac
    echo -e "${CYAN}=================================${NC}"
    echo
}

run_full_script_menu() {
    echo
    title "========== 全功能脚本引导（需确认） =========="
    echo -e "${YELLOW}警告：以下为第三方脚本，代码不由本脚本维护。${NC}"
    echo "请自行确认来源与风险后再继续。"
    echo
    echo "  1) 233boy/Xray（多配置管理，较常用）"
    echo "  2) mack-a/v2ray-agent（八合一，较重）"
    echo "  3) 取消，返回"
    echo
    read -p "请选择 [1-3]: " fs
    case $fs in
        1)
            echo
            warn "即将执行 233boy 官方安装命令（需联网）"
            read -p "确认执行？(y/N): " c
            [[ $c != "y" && $c != "Y" ]] && return
            bash <(wget -qO- -o- https://github.com/233boy/Xray/raw/main/install.sh)
            ;;
        2)
            echo
            warn "即将执行 mack-a 安装（会写入 /root/install.sh，体积较大）"
            read -p "确认执行？(y/N): " c
            [[ $c != "y" && $c != "Y" ]] && return
            wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh
            ;;
        *)
            info "已取消"
            ;;
    esac
}

# ======================== 工具函数 ========================
get_ip() {
    local now
    now=$(date +%s 2>/dev/null || echo 0)
    if [[ -n $_CACHE_IP && -n $_CACHE_IP_TS ]] && (( now - _CACHE_IP_TS < 600 )); then
        echo "$_CACHE_IP"
        return
    fi
    local ip="" url
    for url in "ip.sb" "ifconfig.me" "icanhazip.com" "api.ipify.org" "ipinfo.io/ip"; do
        ip=$(curl -s4 --connect-timeout 3 --max-time 6 "https://$url" 2>/dev/null | tr -d '[:space:]')
        [[ $ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] && break
        ip=""
    done
    [[ -z $ip ]] && ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    _CACHE_IP=$ip
    _CACHE_IP_TS=$now
    echo "$ip"
}

check_port_free() {
    local port=$1
    if command -v ss >/dev/null 2>&1; then
        ! ss -tuln 2>/dev/null | grep -qE "[:.]${port}[[:space:]]"
    elif command -v netstat >/dev/null 2>&1; then
        ! netstat -tuln 2>/dev/null | grep -qE "[:.]${port}[[:space:]]"
    else
        return 0
    fi
}

# 配置备份
backup_config() {
    [[ ! -f $CONFIG_FILE ]] && return 0
    mkdir -p "$BACKUP_DIR"
    local ts
    ts=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo "unknown")
    cp -f "$CONFIG_FILE" "${BACKUP_DIR}/config.${ts}.json" 2>/dev/null || true
    [[ -f $INFO_FILE ]] && cp -f "$INFO_FILE" "${BACKUP_DIR}/node.${ts}.info" 2>/dev/null || true
    # 只保留最近 5 份
    ls -1t "${BACKUP_DIR}"/config.*.json 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null || true
    ls -1t "${BACKUP_DIR}"/node.*.info 2>/dev/null | tail -n +6 | xargs -r rm -f 2>/dev/null || true
}

create_swap() {
    local size=${1:-256}
    if swapon --show 2>/dev/null | grep -q .; then
        info "已存在 Swap，跳过创建"
        return 0
    fi
    local avail_kb
    avail_kb=$(df -k / | awk 'NR==2{print $4}')
    if (( avail_kb < (size + 80) * 1024 )); then
        warn "磁盘剩余约 $((avail_kb/1024))MB，不足以安全创建 ${size}MB Swap"
        return 1
    fi
    info "创建 ${size}MB Swap..."
    rm -f /swapfile
    if ! fallocate -l ${size}M /swapfile 2>/dev/null; then
        dd if=/dev/zero of=/swapfile bs=1M count=${size} status=none 2>/dev/null || {
            error "创建 Swap 文件失败"; return 1
        }
    fi
    chmod 600 /swapfile
    mkswap /swapfile >/dev/null 2>&1 || { rm -f /swapfile; error "mkswap 失败"; return 1; }
    swapon /swapfile 2>/dev/null || { rm -f /swapfile; error "启用 Swap 失败"; return 1; }
    grep -q '/swapfile' /etc/fstab 2>/dev/null || echo '/swapfile none swap sw 0 0' >> /etc/fstab
    sysctl -w vm.swappiness=10 >/dev/null 2>&1 || true
    sysctl -w vm.dirty_ratio=10 >/dev/null 2>&1 || true
    sysctl -w vm.dirty_background_ratio=5 >/dev/null 2>&1 || true
    success "Swap 创建完成（${size}MB）"
}

install_deps() {
    local need=0
    command -v curl >/dev/null 2>&1 || need=1
    command -v unzip >/dev/null 2>&1 || need=1
    command -v openssl >/dev/null 2>&1 || need=1
    if (( need == 0 )); then
        info "依赖已满足，跳过安装"
        return 0
    fi
    info "安装最小依赖..."
    if command -v apt-get >/dev/null 2>&1; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -y -qq >/dev/null 2>&1
        apt-get install -y -qq curl unzip openssl ca-certificates --no-install-recommends >/dev/null 2>&1
    elif command -v dnf >/dev/null 2>&1; then
        dnf install -y -q curl unzip openssl ca-certificates >/dev/null 2>&1
    elif command -v yum >/dev/null 2>&1; then
        yum install -y -q curl unzip openssl ca-certificates >/dev/null 2>&1
    else
        error "不支持的包管理器"; return 1
    fi
    success "依赖安装完成"
}

install_xray() {
    if [[ -x $XRAY_BIN ]] && $XRAY_BIN version >/dev/null 2>&1; then
        info "Xray 已存在且可用: $($XRAY_BIN version 2>/dev/null | head -1)"
        return 0
    fi
    [[ -x $XRAY_BIN ]] && rm -f $XRAY_BIN

    local ARCH XARCH
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)   XARCH="64" ;;
        aarch64|arm64)  XARCH="arm64-v8a" ;;
        armv7l|armv7)   XARCH="arm32-v7a" ;;
        *) error "不支持架构: $ARCH"; return 1 ;;
    esac

    info "下载 Xray-linux-${XARCH} ..."
    local filename="Xray-linux-${XARCH}.zip"
    # 优先级：直连 → 多个代理镜像（适配国内/不稳定网络）
    local urls=(
        "https://github.com/XTLS/Xray-core/releases/latest/download/${filename}"
        "https://ghfast.top/https://github.com/XTLS/Xray-core/releases/latest/download/${filename}"
        "https://mirror.ghproxy.com/https://github.com/XTLS/Xray-core/releases/latest/download/${filename}"
        "https://ghproxy.net/https://github.com/XTLS/Xray-core/releases/latest/download/${filename}"
        "https://cdn.jsdelivr.net/gh/XTLS/Xray-core@latest/${filename}"
        "https://download.fastgit.org/XTLS/Xray-core/releases/latest/download/${filename}"
    )
    local tmp="/tmp/xray_dl_$$.zip"
    local ok=0
    for url in "${urls[@]}"; do
        if curl -fsSL --connect-timeout 10 --max-time 120 -o "$tmp" "$url" --retry 2 --retry-delay 2 2>/dev/null; then
            ok=1; break
        fi
        warn "镜像失败，尝试下一个..."
    done
    if (( ok == 0 )); then
        error "所有下载源均失败，请检查网络或手动下载"
        return 1
    fi
    local fsize
    fsize=$(wc -c < "$tmp" 2>/dev/null || echo 0)
    if (( fsize < 1000000 )); then
        error "下载文件异常（过小，可能是错误页），大小: $fsize 字节"
        rm -f "$tmp"
        return 1
    fi

    unzip -o -q "$tmp" xray -d /tmp 2>/dev/null || {
        error "解压失败"; rm -f "$tmp"; return 1
    }
    mv -f /tmp/xray "$XRAY_BIN"
    chmod +x "$XRAY_BIN"
    rm -f "$tmp" /tmp/geoip.dat /tmp/geosite.dat 2>/dev/null

    if ! $XRAY_BIN version >/dev/null 2>&1; then
        error "Xray 二进制无法执行"; return 1
    fi
    success "Xray 安装完成: $($XRAY_BIN version 2>/dev/null | head -1)"
}

generate_keys() {
    local output
    output=$($XRAY_BIN x25519 2>/dev/null)
    if [[ -z $output ]]; then
        error "xray x25519 执行失败"; return 1
    fi

    PRIVATE_KEY=$(echo "$output" | grep -iE '^[[:space:]]*Private(Key)?[[:space:]]*:' | head -1 | sed -E 's/^[^:]*:[[:space:]]*//;s/[[:space:]]*$//')
    PUBLIC_KEY=$(echo "$output" | grep -iE '^[[:space:]]*(Password \(PublicKey\)|Password|Public[[:space:]]*key|PublicKey)[[:space:]]*:' | head -1 | sed -E 's/^[^:]*:[[:space:]]*//;s/[[:space:]]*$//')

    if [[ -z $PRIVATE_KEY || -z $PUBLIC_KEY ]]; then
        PRIVATE_KEY=$(echo "$output" | awk -F': ' '/[Pp]rivate/{print $2; exit}' | tr -d '[:space:]')
        PUBLIC_KEY=$(echo "$output" | awk -F': ' '/[Pp]ublic|[Pp]assword/{print $2; exit}' | tr -d '[:space:]')
    fi

    if [[ -z $PRIVATE_KEY || -z $PUBLIC_KEY ]]; then
        error "密钥解析失败，原始输出："
        echo "$output"
        return 1
    fi
    return 0
}

write_config() {
    local uuid=$1 port=$2 private_key=$3 short_id=$4 dest=${5:-"www.microsoft.com:443"}
    local sni=${dest%%:*}
    local loglevel=${FEAT_LOGLEVEL:-none}
    local listen=${FEAT_LISTEN:-"0.0.0.0"}
    mkdir -p "$CONFIG_DIR"

    local clients_json="" seen="|" u
    for u in $uuid $EXTRA_UUIDS; do
        [[ -z $u ]] && continue
        [[ $seen == *"|$u|"* ]] && continue
        seen="${seen}${u}|"
        [[ -n $clients_json ]] && clients_json="${clients_json},"
        clients_json="${clients_json}
          {
            \"id\": \"${u}\",
            \"flow\": \"xtls-rprx-vision\"
          }"
    done
    if [[ -z $clients_json ]]; then
        error "无有效 UUID，无法写配置"; return 1
    fi

    local short_json="\"${short_id}\""
    if [[ -n ${FEAT_SHORT2:-} ]]; then
        short_json="${short_json}, \"${FEAT_SHORT2}\""
    fi

    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "loglevel": "${loglevel}"
  },
  "inbounds": [
    {
      "listen": "${listen}",
      "port": ${port},
      "protocol": "vless",
      "settings": {
        "clients": [
${clients_json}
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
            ${short_json}
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
    local mem_max="${1:-}"
    local mem_high="${2:-}"
    local tasks_max="${SMART_TASKS_MAX:-}"
    local cpu_quota="${SMART_CPU_QUOTA:-}"
    local oom_score="${SMART_OOM_SCORE:-}"

    mkdir -p /etc/systemd/system

    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Xray Service (smart-node v${SCRIPT_VERSION})
Documentation=https://github.com/XTLS/Xray-core
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Type=simple
User=root
Group=root
ExecStart=${XRAY_BIN} run -c ${CONFIG_FILE}
Restart=on-failure
RestartSec=3
LimitNOFILE=1048576
EOF

    if [[ -n $mem_max ]] && systemd_supports_memory_max; then
        echo "MemoryMax=${mem_max}" >> "$SERVICE_FILE"
        [[ -n $mem_high ]] && echo "MemoryHigh=${mem_high}" >> "$SERVICE_FILE"
    fi

    [[ -n $tasks_max ]] && echo "TasksMax=${tasks_max}" >> "$SERVICE_FILE"
    [[ -n $cpu_quota ]] && echo "CPUQuota=${cpu_quota}" >> "$SERVICE_FILE"
    # OOMScoreAdjust 范围 -1000~1000，正值更容易被杀，极端档用较高值保护系统
    [[ -n $oom_score ]] && echo "OOMScoreAdjust=${oom_score}" >> "$SERVICE_FILE"

    cat >> "$SERVICE_FILE" << EOF
# Hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
SystemCallArchitectures=native
CapabilityBoundingSet=CAP_NET_BIND_SERVICE CAP_NET_ADMIN
AmbientCapabilities=CAP_NET_BIND_SERVICE CAP_NET_ADMIN

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload 2>/dev/null || true
}

select_features() {
    FEAT_LOGLEVEL="none"
    FEAT_LISTEN="0.0.0.0"
    FEAT_SHORT2=""
    EXTRA_UUIDS=""
    FEAT_MULTI_USER=0
    FEAT_IPV6=0
    FEAT_EXTRA_SHORT=0
    FEAT_LOG=0

    echo
    title "========== 智能功能选择 =========="
    echo "根据当前档位 [${LEVEL}]，可开启的功能如下（已自动勾选推荐项）："
    echo

    case $LEVEL in
        extreme|ultra-low)
            echo -e "  ${GREEN}[必选]${NC} VLESS + REALITY + Vision（轻量核心）"
            echo -e "  ${RED}[锁定]${NC} 多用户 / IPv6 / 详细日志 —— 内存不足，已禁用"
            echo -e "  ${GREEN}[自动]${NC} loglevel=none，监听 0.0.0.0"
            FEAT_LOGLEVEL="none"
            FEAT_LISTEN="0.0.0.0"
            ;;
        low)
            echo -e "  ${GREEN}[必选]${NC} VLESS + REALITY + Vision"
            echo "  可选："
            echo "    a) 额外 1 个用户（多 UUID）"
            echo "    b) 备用 shortId"
            read -p "输入要开启的项（如 a / ab，直接回车=仅核心）: " picks
            [[ $picks == *a* ]] && FEAT_MULTI_USER=1
            [[ $picks == *b* ]] && FEAT_EXTRA_SHORT=1
            FEAT_LOGLEVEL="none"
            ;;
        medium|high)
            echo -e "  ${GREEN}[必选]${NC} VLESS + REALITY + Vision"
            echo "  可选（可多选，如 abcd）："
            echo "    a) 多用户（额外 1～3 个 UUID）"
            echo "    b) 备用 shortId"
            echo "    c) （预留）IPv6 相关 — 当前版本仍监听 0.0.0.0"
            echo "    d) 打开 warning 日志（排障用，略增资源占用）"
            read -p "输入要开启的项（直接回车=仅核心+推荐）: " picks
            if [[ -z $picks ]]; then
                read -p "是否至少预留多用户能力（生成 1 个备用 UUID）？(y/N): " mu
                [[ $mu == "y" || $mu == "Y" ]] && FEAT_MULTI_USER=1
            else
                [[ $picks == *a* ]] && FEAT_MULTI_USER=1
                [[ $picks == *b* ]] && FEAT_EXTRA_SHORT=1
                [[ $picks == *c* ]] && FEAT_IPV6=1
                [[ $picks == *d* ]] && FEAT_LOG=1
            fi
            [[ $FEAT_LOG -eq 1 ]] && FEAT_LOGLEVEL="warning" || FEAT_LOGLEVEL="none"
            [[ $FEAT_IPV6 -eq 1 ]] && FEAT_LISTEN="0.0.0.0"
            ;;
    esac

    if [[ $FEAT_MULTI_USER -eq 1 ]]; then
        local n=1
        if [[ $LEVEL == "medium" || $LEVEL == "high" ]]; then
            read -p "额外用户数量 1-3 [1]: " n
            n=${n:-1}
            (( n < 1 )) && n=1
            (( n > 3 )) && n=3
        fi
        local i=0 extra=""
        while (( i < n )); do
            local nu
            nu=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
            [[ -z $nu ]] && nu=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
            extra="${extra} ${nu}"
            i=$((i + 1))
        done
        EXTRA_UUIDS=$(echo $extra)
        info "已生成额外 UUID: $EXTRA_UUIDS"
    fi

    if [[ $FEAT_EXTRA_SHORT -eq 1 ]]; then
        FEAT_SHORT2=$(openssl rand -hex 4 2>/dev/null || echo "a1b2c3d4")
        FEAT_SHORT2=$(echo "$FEAT_SHORT2" | tr -cd '0-9a-f' | cut -c1-8)
        (( ${#FEAT_SHORT2} % 2 == 1 )) && FEAT_SHORT2="${FEAT_SHORT2:0:$((${#FEAT_SHORT2}-1))}"
        info "备用 shortId: $FEAT_SHORT2"
    fi

    echo
    info "功能摘要: log=${FEAT_LOGLEVEL} multi_user=${FEAT_MULTI_USER} short2=${FEAT_SHORT2:-无}"
    echo -e "${CYAN}=================================${NC}"
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
EXTRA_UUIDS=${EXTRA_UUIDS:-}
FEAT_SHORT2=${FEAT_SHORT2:-}
FEAT_LOGLEVEL=${FEAT_LOGLEVEL:-none}
FEAT_LISTEN=${FEAT_LISTEN:-0.0.0.0}
EOF
}

load_info() {
    UUID=""; PORT=""; PRIVATE_KEY=""; PUBLIC_KEY=""; SHORT_ID=""
    SERVER_IP=""; LEVEL=""; DEST=""
    EXTRA_UUIDS=""; FEAT_SHORT2=""; FEAT_LOGLEVEL="none"; FEAT_LISTEN="0.0.0.0"
    [[ -f $INFO_FILE ]] || return
    while IFS= read -r line || [[ -n $line ]]; do
        [[ -z $line || $line == \#* ]] && continue
        k="${line%%=*}"
        v="${line#*=}"
        case "$k" in
            UUID) UUID="$v" ;;
            PORT) PORT="$v" ;;
            PRIVATE_KEY) PRIVATE_KEY="$v" ;;
            PUBLIC_KEY) PUBLIC_KEY="$v" ;;
            SHORT_ID) SHORT_ID="$v" ;;
            SERVER_IP) SERVER_IP="$v" ;;
            LEVEL) LEVEL="$v" ;;
            DEST) DEST="$v" ;;
            EXTRA_UUIDS) EXTRA_UUIDS="$v" ;;
            FEAT_SHORT2) FEAT_SHORT2="$v" ;;
            FEAT_LOGLEVEL) FEAT_LOGLEVEL="$v" ;;
            FEAT_LISTEN) FEAT_LISTEN="$v" ;;
        esac
    done < "$INFO_FILE"
}

_make_link() {
    local uid=$1
    local ip=${SERVER_IP:-$(get_ip)}
    local sni=${DEST%%:*}
    local sid=${SHORT_ID}
    echo "vless://${uid}@${ip}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${sid}&type=tcp&headerType=none#Smart-${LEVEL}"
}

show_client_snippets() {
    local ip=${SERVER_IP:-$(get_ip)}
    local sni=${DEST%%:*}
    local name="Smart-${LEVEL}"

    echo
    title "---------- Clash Meta 片段 ----------"
    cat << EOF
- name: "${name}"
  type: vless
  server: ${ip}
  port: ${PORT}
  uuid: ${UUID}
  network: tcp
  tls: true
  udp: true
  flow: xtls-rprx-vision
  servername: ${sni}
  client-fingerprint: chrome
  reality-opts:
    public-key: ${PUBLIC_KEY}
    short-id: ${SHORT_ID}
EOF

    echo
    title "---------- sing-box 出站片段 ----------"
    cat << EOF
{
  "type": "vless",
  "tag": "${name}",
  "server": "${ip}",
  "server_port": ${PORT},
  "uuid": "${UUID}",
  "flow": "xtls-rprx-vision",
  "tls": {
    "enabled": true,
    "server_name": "${sni}",
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    },
    "reality": {
      "enabled": true,
      "public_key": "${PUBLIC_KEY}",
      "short_id": "${SHORT_ID}"
    }
  }
}
EOF
    echo
}

# 可选二维码（仅当已安装 qrencode）
show_qrcode_if_available() {
    local link=$1
    if command -v qrencode >/dev/null 2>&1; then
        echo
        title "---------- 终端二维码（可选） ----------"
        qrencode -t ANSIUTF8 "$link" 2>/dev/null || qrencode -t UTF8 "$link" 2>/dev/null || true
        echo
    fi
}

show_link() {
    load_info
    if [[ -z $UUID ]]; then
        warn "尚未安装节点"; return
    fi
    local ip=${SERVER_IP:-$(get_ip)}
    local main_link
    main_link=$(_make_link "$UUID")
    echo
    title "========== 节点信息 =========="
    echo "服务器 IP : $ip"
    echo "端口      : $PORT"
    echo "主 UUID   : $UUID"
    if [[ -n $EXTRA_UUIDS ]]; then
        echo "额外 UUID : $EXTRA_UUIDS"
    fi
    echo "PublicKey : $PUBLIC_KEY"
    echo "ShortID   : $SHORT_ID"
    [[ -n $FEAT_SHORT2 ]] && echo "备用SID  : $FEAT_SHORT2"
    echo "伪装目标  : ${DEST:-www.microsoft.com:443}"
    echo "安装模式  : $LEVEL"
    echo "日志级别  : ${FEAT_LOGLEVEL:-none}"
    echo "脚本版本  : v${SCRIPT_VERSION}"
    echo
    echo -e "${YELLOW}分享链接：${NC}"
    echo "$main_link"
    local u
    for u in $EXTRA_UUIDS; do
        [[ -z $u ]] && continue
        echo
        echo "$(_make_link "$u")"
    done
    show_client_snippets
    show_qrcode_if_available "$main_link"
    echo -e "${CYAN}==============================${NC}"
}

# 导出完整信息到文件
export_node_info() {
    load_info
    [[ -z $UUID ]] && { warn "尚未安装节点"; return; }
    local out="/root/smart-node-export-$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "========== Smart-Node 导出 =========="
        echo "导出时间: $(date)"
        echo "脚本版本: v${SCRIPT_VERSION}"
        echo
        show_link
        echo
        echo "========== 原始 config.json =========="
        cat "$CONFIG_FILE" 2>/dev/null || echo "(无配置文件)"
    } > "$out" 2>&1
    success "已导出到: $out"
    echo "可用 scp 下载或 cat 查看。"
}

add_user() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    if [[ $LEVEL == "extreme" || $LEVEL == "ultra-low" ]]; then
        error "当前档位内存过低，不建议增加用户"
        return
    fi
    if [[ -z $LEVEL ]]; then
        local tm
        tm=$(get_total_mem)
        if (( tm <= 180 )); then
            error "检测到内存约 ${tm}MB，不建议增加用户"
            return
        fi
    fi
    local count
    count=$(echo "$UUID $EXTRA_UUIDS" | wc -w)
    if (( count >= 5 )); then
        error "用户数已达上限（5）"; return
    fi
    local nu
    if [[ -x $XRAY_BIN ]]; then
        nu=$($XRAY_BIN uuid 2>/dev/null)
    fi
    [[ -z $nu ]] && nu=$(cat /proc/sys/kernel/random/uuid 2>/dev/null)
    [[ -z $nu ]] && nu=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
    [[ -z $nu ]] && { error "生成 UUID 失败"; return; }
    backup_config
    EXTRA_UUIDS=$(echo $EXTRA_UUIDS $nu | xargs)
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}" || return
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    if has_systemd; then
        systemctl restart xray 2>/dev/null || true
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
    fi
    success "已添加用户: $nu"
    show_link
}

enable_bbr() {
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        info "BBR 已启用"; return
    fi
    info "尝试启用 BBR..."
    modprobe tcp_bbr 2>/dev/null || true
    if ! grep -q "tcp_congestion_control=bbr" /etc/sysctl.conf 2>/dev/null; then
        cat >> /etc/sysctl.conf << EOF

# BBR by smart-node
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
EOF
    fi
    sysctl -p >/dev/null 2>&1 || true
    if sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
        success "BBR 已启用"
    else
        warn "BBR 启用失败（内核不支持），不影响节点使用"
    fi
}

# 一键系统参数小优化（低内存友好）
optimize_sysctl() {
    info "应用低内存友好 sysctl 参数..."
    cat >> /etc/sysctl.conf << EOF

# smart-node low-mem optimize
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.vfs_cache_pressure=50
net.core.default_qdisc=fq
net.ipv4.tcp_congestion_control=bbr
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_slow_start_after_idle=0
EOF
    # 去重
    awk '!seen[$0]++' /etc/sysctl.conf > /tmp/sysctl.tmp && mv /tmp/sysctl.tmp /etc/sysctl.conf
    sysctl -p >/dev/null 2>&1 || true
    success "sysctl 优化已应用（已去重）"
}

open_firewall() {
    local port=$1
    if command -v ufw >/dev/null 2>&1; then
        ufw allow ${port}/tcp >/dev/null 2>&1 || true
        ufw reload >/dev/null 2>&1 || true
    elif command -v firewall-cmd >/dev/null 2>&1; then
        firewall-cmd --permanent --add-port=${port}/tcp >/dev/null 2>&1 || true
        firewall-cmd --reload >/dev/null 2>&1 || true
    elif command -v nft >/dev/null 2>&1; then
        nft add rule inet filter input tcp dport $port accept 2>/dev/null || true
    else
        iptables -C INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null || \
        iptables -I INPUT -p tcp --dport $port -j ACCEPT 2>/dev/null || true
    fi
}

# 简易连通性自检
self_check() {
    load_info
    echo
    title "========== 简易自检 =========="
    if [[ -z $UUID ]]; then
        warn "尚未安装节点"
        return
    fi

    # 1. 进程/服务
    if has_systemd; then
        if systemctl is-active --quiet xray; then
            success "systemd 服务: 运行中"
        else
            error "systemd 服务: 未运行"
            systemctl status xray --no-pager -l 2>/dev/null | head -15
        fi
    else
        if pgrep -f "$XRAY_BIN" >/dev/null; then
            success "进程: 存在"
        else
            error "进程: 未发现"
        fi
    fi

    # 2. 端口监听
    if check_port_free $PORT; then
        error "端口 $PORT: 未监听（异常）"
    else
        success "端口 $PORT: 正在监听"
    fi

    # 3. 配置校验
    if $XRAY_BIN run -c "$CONFIG_FILE" -test >/dev/null 2>&1; then
        success "配置文件: 校验通过"
    else
        warn "配置文件: 校验未通过或旧版 xray 不支持 -test"
    fi

    # 4. 内存占用
    local rss
    rss=$(ps -o rss= -C xray 2>/dev/null | awk '{s+=$1} END{print s+0}')
    if (( rss > 0 )); then
        info "Xray RSS: $((rss/1024)) MB"
    fi

    # 5. 提示
    echo
    warn "本自检仅检查本机状态。最终连通性请用客户端测试。"
    warn "云厂商请确认安全组已放行 TCP $PORT"
    echo -e "${CYAN}=================================${NC}"
}

show_recent_logs() {
    if has_systemd; then
        echo
        title "---------- 最近 30 行日志 ----------"
        journalctl -u xray -n 30 --no-pager 2>/dev/null || warn "无法获取日志"
    else
        warn "非 systemd 环境，无 journal 日志。可用 ps / free 查看状态。"
    fi
}

# ======================== 安装主逻辑 ========================
install_node() {
    detect_and_recommend

    if [[ -f $INFO_FILE ]]; then
        warn "检测到已存在节点配置"
        read -p "是否覆盖重装？(y/N): " overwrite
        [[ $overwrite != "y" && $overwrite != "Y" ]] && return
        backup_config
    fi

    if [[ $LEVEL == "extreme" ]]; then
        echo -e "${RED}警告：64MB 级别内存非常极限，Xray 仍可能因 OOM 被杀。${NC}"
        echo -e "${RED}请确保已关闭所有不必要进程，并准备好较大 Swap。${NC}"
        echo
    fi

    if [[ $LEVEL == "medium" || $LEVEL == "high" ]]; then
        echo -e "${CYAN}提示：当前内存较充足。若你需要多协议/多用户/证书，可选菜单「14」引导全功能脚本。${NC}"
        echo -e "${CYAN}若只要一个轻量 REALITY 节点，继续用本脚本即可。${NC}"
        echo
    elif [[ $LEVEL == "extreme" || $LEVEL == "ultra-low" ]]; then
        echo -e "${RED}提示：当前为超低内存，已锁定本脚本轻量路径，不建议换其它一键脚本。${NC}"
        echo
    fi

    read -p "是否按本脚本推荐方案继续安装？(Y/n): " confirm
    [[ $confirm == "n" || $confirm == "N" ]] && return

    echo
    info "开始安装（模式: $LEVEL）..."

    local MEM_MAX="${SMART_MEM_MAX:-}" MEM_HIGH="${SMART_MEM_HIGH:-}"
    local SWAP_SIZE=${SMART_SWAP:-256}
    local DEFAULT_PORT=443

    if [[ ${SMART_PORT_HINT:-prefer443} == "high" ]]; then
        DEFAULT_PORT=$((20000 + RANDOM % 40000))
        local try=0
        while ! check_port_free $DEFAULT_PORT && (( try < 20 )); do
            DEFAULT_PORT=$((20000 + RANDOM % 40000))
            try=$((try + 1))
        done
    elif ! check_port_free 443; then
        DEFAULT_PORT=$((20000 + RANDOM % 40000))
        info "443 不可用，自动改用高位端口 $DEFAULT_PORT"
    fi

    if (( SWAP_SIZE > 0 )); then
        create_swap $SWAP_SIZE || warn "Swap 创建失败，继续尝试（风险较高）"
    fi

    install_deps || return
    install_xray || return

    if command -v uuidgen >/dev/null 2>&1; then
        UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    else
        UUID=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
    fi
    [[ -z $UUID ]] && UUID=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')

    PORT=$DEFAULT_PORT
    if [[ ${SMART_PORT_HINT:-} == "high" ]]; then
        info "智能推荐高位端口: $PORT（443 占用或极限内存）"
        read -p "直接回车使用推荐，或输入自定义端口: " custom_port
        [[ -n $custom_port ]] && PORT=$custom_port
    else
        read -p "请输入端口（直接回车使用推荐 $DEFAULT_PORT）: " custom_port
        [[ -n $custom_port ]] && PORT=$custom_port
    fi
    if ! [[ $PORT =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        error "端口无效"; return
    fi
    if ! check_port_free $PORT; then
        warn "端口 $PORT 似乎已被占用，仍将继续（请自行确认）"
    fi

    SHORT_ID=$(openssl rand -hex 8 2>/dev/null || od -An -tx1 -N8 /dev/urandom 2>/dev/null | tr -d ' \n' | tr 'A-F' 'a-f')
    [[ -z $SHORT_ID || ${#SHORT_ID} -lt 2 ]] && SHORT_ID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null | tr -d '-' | cut -c1-16)
    SHORT_ID=$(echo "$SHORT_ID" | tr -cd '0-9a-f' | cut -c1-16)
    (( ${#SHORT_ID} % 2 == 1 )) && SHORT_ID="${SHORT_ID:0:$((${#SHORT_ID}-1))}"
    [[ ${#SHORT_ID} -lt 2 ]] && SHORT_ID="a1b2c3d4"
    generate_keys || return
    SERVER_IP=$(get_ip)

    echo
    title "选择 REALITY 伪装目标（dest）："
    local i=1
    for d in "${DEST_LIST[@]}"; do
        echo "  $i) $d"
        i=$((i+1))
    done
    echo "  0) 自定义"
    read -p "请选择 [1-${#DEST_LIST[@]}，直接回车默认 1]: " dest_choice
    if [[ -z $dest_choice || $dest_choice == "1" ]]; then
        DEST="${DEST_LIST[0]}"
    elif [[ $dest_choice == "0" ]]; then
        read -p "请输入 dest（格式 host 或 host:443）: " DEST
        [[ -z $DEST ]] && DEST="${DEST_LIST[0]}"
        [[ "$DEST" != *:* ]] && DEST="${DEST}:443"
    elif [[ $dest_choice =~ ^[0-9]+$ ]] && (( dest_choice >= 1 && dest_choice <= ${#DEST_LIST[@]} )); then
        DEST="${DEST_LIST[$((dest_choice-1))]}"
    else
        DEST="${DEST_LIST[0]}"
    fi
    info "使用伪装目标: $DEST"

    select_features

    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "$DEST"
    if [[ ! -s $CONFIG_FILE ]]; then
        error "配置文件写入失败"; return 1
    fi

    if $XRAY_BIN run -c "$CONFIG_FILE" -test >/dev/null 2>&1; then
        info "配置校验通过"
    else
        warn "配置测试未通过，仍将尝试启动"
        $XRAY_BIN run -c "$CONFIG_FILE" -test 2>&1 | head -20 || true
    fi

    write_service "$MEM_MAX" "$MEM_HIGH"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "$DEST"

    open_firewall $PORT

    if [[ ${SMART_BBR:-0} -eq 1 ]]; then
        enable_bbr
    fi

    if has_systemd; then
        systemctl enable xray >/dev/null 2>&1
        systemctl restart xray
        sleep 2
        if systemctl is-active --quiet xray; then
            success "安装成功！当前模式：$LEVEL"
        else
            error "systemd 启动失败"
            echo "请执行: journalctl -u xray -n 30 --no-pager"
            return 1
        fi
    else
        warn "未检测到 systemd，尝试直接后台运行"
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
        sleep 1
        if pgrep -f "$XRAY_BIN" >/dev/null; then
            success "已后台启动"
        else
            error "启动失败"; return 1
        fi
    fi

    refresh_mem_cache
    local rss
    rss=$(ps -o rss= -C xray 2>/dev/null | awk '{s+=$1} END{print s+0}')
    if (( rss > 0 )); then
        info "当前 Xray 进程内存占用约: $((rss/1024)) MB"
    fi
    show_link
    echo
    free -m
    if [[ $LEVEL == "extreme" || $LEVEL == "ultra-low" ]]; then
        echo
        warn "低内存小鸡请定期 free -m 观察，必要时 systemctl restart xray"
        warn "排查 OOM: dmesg | grep -iE 'out of memory|killed process'"
    fi
    echo
    title "---------- 安装后检查清单 ----------"
    echo "1. 云厂商安全组 / 防火墙放行 TCP 端口 $PORT"
    echo "2. 用客户端导入分享链接测试连通性"
    echo "3. 低内存机器建议执行菜单「16」做系统参数优化"
    echo "4. 出问题可用菜单「10」自检 或「11」看日志"
    echo -e "${CYAN}=====================================${NC}"
}

change_port() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    read -p "请输入新端口 (当前: $PORT): " new_port
    [[ -z $new_port ]] && return
    if ! [[ $new_port =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
        error "端口无效"; return
    fi
    check_port_free $new_port || warn "端口 $new_port 似乎已被占用"
    backup_config
    PORT=$new_port
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    open_firewall $PORT
    if has_systemd; then
        systemctl restart xray 2>/dev/null || true
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
    fi
    success "端口已修改为 $PORT"
    show_link
}

change_uuid() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    backup_config
    UUID=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16 | sed "s/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/")
    [[ -z $UUID ]] && { error "生成 UUID 失败"; return; }
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    if has_systemd; then
        systemctl restart xray 2>/dev/null || true
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
    fi
    success "UUID 已重新生成"
    show_link
}

regenerate_keys() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    echo
    warn "重新生成密钥后，所有客户端都需要更新 PublicKey 才能连接"
    read -p "确认重新生成？(y/N): " c
    [[ $c != "y" && $c != "Y" ]] && return
    backup_config
    generate_keys || return
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    if has_systemd; then
        systemctl restart xray 2>/dev/null || true
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
    fi
    success "密钥已重新生成"
    show_link
}

change_shortid() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    echo
    echo "当前 ShortID: $SHORT_ID"
    read -p "输入新 ShortID（空则自动生成，长度偶数，最长16位十六进制）: " new_sid
    if [[ -z $new_sid ]]; then
        new_sid=$(openssl rand -hex 8 2>/dev/null | tr -cd '0-9a-f' | cut -c1-16)
    fi
    new_sid=$(echo "$new_sid" | tr -cd '0-9a-f' | cut -c1-16)
    (( ${#new_sid} % 2 == 1 )) && new_sid="${new_sid:0:$((${#new_sid}-1))}"
    [[ ${#new_sid} -lt 2 ]] && { error "ShortID 无效"; return; }
    backup_config
    SHORT_ID=$new_sid
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    if has_systemd; then
        systemctl restart xray 2>/dev/null || true
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
    fi
    success "ShortID 已修改为 $SHORT_ID"
    show_link
}

change_dest() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    echo
    title "选择新的伪装目标："
    local i=1
    for d in "${DEST_LIST[@]}"; do
        echo "  $i) $d"
        i=$((i+1))
    done
    echo "  0) 自定义"
    read -p "请选择: " choice
    if [[ $choice == "0" ]]; then
        read -p "输入 dest (host 或 host:port): " DEST
        [[ -n $DEST && "$DEST" != *:* ]] && DEST="${DEST}:443"
    elif [[ $choice =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#DEST_LIST[@]} )); then
        DEST="${DEST_LIST[$((choice-1))]}"
    else
        return
    fi
    [[ -z $DEST ]] && return
    backup_config
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "$DEST"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "$DEST"
    if has_systemd; then
        systemctl restart xray 2>/dev/null || true
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
    fi
    success "伪装目标已修改为 $DEST"
    show_link
}

restart_xray() {
    if has_systemd; then
        systemctl restart xray
        sleep 1
        if systemctl is-active --quiet xray; then
            success "重启成功"
        else
            error "重启失败，请查看 journalctl -u xray -n 20"
            return
        fi
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
        success "已重新后台启动"
    fi
    local rss
    rss=$(ps -o rss= -C xray 2>/dev/null | awk '{s+=$1} END{print s+0}')
    (( rss > 0 )) && info "当前内存占用约: $((rss/1024)) MB"
}

status_xray() {
    refresh_mem_cache
    echo
    if has_systemd; then
        systemctl status xray --no-pager -l 2>/dev/null || warn "服务未安装"
    else
        pgrep -af xray || warn "未发现 xray 进程"
    fi
    echo
    title "----- 内存与 Swap -----"
    free -m
    echo
    swapon --show 2>/dev/null || true
    echo
    local rss
    rss=$(ps -o rss= -C xray 2>/dev/null | awk '{s+=$1} END{print s+0}')
    if (( rss > 0 )); then
        info "Xray 进程实际 RSS: $((rss/1024)) MB"
    else
        warn "未发现 xray 进程"
    fi
    echo
    echo -e "内存压力提示: $(get_mem_pressure_hint)"
}

update_xray() {
    info "更新 Xray 到最新版..."
    local bak=""
    if [[ -x $XRAY_BIN ]]; then
        bak="${XRAY_BIN}.bak"
        cp -f "$XRAY_BIN" "$bak" 2>/dev/null || true
    fi
    rm -f $XRAY_BIN
    if ! install_xray; then
        if [[ -n $bak && -f $bak ]]; then
            mv -f "$bak" "$XRAY_BIN"
            chmod +x "$XRAY_BIN"
            warn "更新失败，已恢复旧版本"
        fi
        return 1
    fi
    rm -f "${XRAY_BIN}.bak" 2>/dev/null || true
    if has_systemd; then
        systemctl restart xray 2>/dev/null || true
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        [[ -f $CONFIG_FILE ]] && nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
    fi
    success "更新完成"
}

uninstall_node() {
    echo
    title "========== 彻底还原（完全清理） =========="
    echo "将会清理本脚本产生的全部痕迹："
    echo "  1. 停止并删除 xray 服务"
    echo "  2. 删除配置目录 /usr/local/etc/xray"
    echo "  3. 删除程序 /usr/local/bin/xray"
    echo "  4. 强制结束所有 xray 进程"
    echo "  5. 清理临时文件"
    echo "  6. 可选：删除 Swap + 还原相关 sysctl"
    echo "  7. 可选：删除配置备份"
    echo
    read -p "确认彻底还原到未安装状态？(y/N): " confirm
    [[ $confirm != "y" && $confirm != "Y" ]] && return

    info "开始彻底清理..."

    systemctl stop xray 2>/dev/null || true
    systemctl disable xray 2>/dev/null || true
    pkill -9 -f "/usr/local/bin/xray" 2>/dev/null || true
    pkill -9 xray 2>/dev/null || true

    rm -f /etc/systemd/system/xray.service
    rm -f /etc/systemd/system/multi-user.target.wants/xray.service 2>/dev/null || true
    systemctl daemon-reload 2>/dev/null || true
    systemctl reset-failed xray 2>/dev/null || true

    rm -rf /usr/local/etc/xray
    rm -f /usr/local/bin/xray

    rm -f /tmp/xray*.zip /tmp/xray /tmp/xray_dl_*.zip 2>/dev/null || true

    success "服务、配置、程序已全部删除"

    echo
    read -p "是否删除本脚本创建的 Swap 文件？(y/N): " del_swap
    if [[ $del_swap == "y" || $del_swap == "Y" ]]; then
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
        sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null || true
        success "Swap 已删除"
    else
        info "已保留 Swap"
    fi

    echo
    read -p "是否尝试还原 sysctl 中本脚本添加的相关行？(y/N): " del_sysctl
    if [[ $del_sysctl == "y" || $del_sysctl == "Y" ]]; then
        if [[ -f /etc/sysctl.conf ]]; then
            sed -i '/# BBR by smart-node/d' /etc/sysctl.conf 2>/dev/null || true
            sed -i '/# smart-node low-mem optimize/d' /etc/sysctl.conf 2>/dev/null || true
            sed -i '/net.core.default_qdisc=fq/d' /etc/sysctl.conf 2>/dev/null || true
            sed -i '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf 2>/dev/null || true
            sed -i '/vm.swappiness=10/d' /etc/sysctl.conf 2>/dev/null || true
            sed -i '/vm.dirty_ratio=10/d' /etc/sysctl.conf 2>/dev/null || true
            sed -i '/vm.dirty_background_ratio=5/d' /etc/sysctl.conf 2>/dev/null || true
            sed -i '/vm.vfs_cache_pressure=50/d' /etc/sysctl.conf 2>/dev/null || true
            sed -i '/net.ipv4.tcp_fastopen=3/d' /etc/sysctl.conf 2>/dev/null || true
            sed -i '/net.ipv4.tcp_slow_start_after_idle=0/d' /etc/sysctl.conf 2>/dev/null || true
            sysctl -p >/dev/null 2>&1 || true
            success "已尝试清理相关 sysctl 条目"
        fi
    else
        info "已保留 sysctl 设置"
    fi

    echo
    title "========== 清理完成 =========="
    echo "系统已尽量还原到运行本脚本之前的状态。"
    echo
    echo "自检命令（应全部显示不存在）："
    echo "  systemctl status xray"
    echo "  ls /usr/local/bin/xray"
    echo "  ls /usr/local/etc/xray"
    echo
    info "如本地有 smart-node 脚本文件，可手动执行: rm -f smart-node*.sh"
}

# ======================== 脚本自更新 ========================
update_script() {
    echo
    title "========== 更新本脚本 =========="
    echo "当前版本: v${SCRIPT_VERSION}"
    echo "更新地址: ${SCRIPT_RAW_URL}"
    echo
    echo -e "${YELLOW}注意：会覆盖当前脚本文件，节点配置与 Xray 不会受影响。${NC}"
    read -p "确认更新？(y/N): " c
    [[ $c != "y" && $c != "Y" ]] && { info "已取消"; return; }

    # 定位当前脚本路径
    local self
    self=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")
    if [[ ! -f $self ]]; then
        # 通过进程或常见位置兜底
        self="/root/smart-node.sh"
        warn "无法自动定位当前脚本，将尝试写入 $self"
    fi

    local tmp="/tmp/smart-node-update-$$.sh"
    local ok=0 url
    info "正在下载最新版本..."
    for url in "${SCRIPT_RAW_MIRRORS[@]}"; do
        if curl -fsSL --connect-timeout 8 --max-time 60 -o "$tmp" "$url" --retry 2 --retry-delay 1 2>/dev/null; then
            # 简单校验：必须是 bash 脚本且包含版本标识
            if head -1 "$tmp" | grep -q '^#!' && grep -q 'SCRIPT_VERSION=' "$tmp"; then
                ok=1
                info "下载成功（来源: $url）"
                break
            fi
        fi
        warn "镜像失败，尝试下一个..."
    done

    if (( ok == 0 )); then
        error "所有下载源均失败，请检查网络后重试"
        rm -f "$tmp"
        return 1
    fi

    # 提取新版本号提示
    local new_ver
    new_ver=$(grep -m1 'SCRIPT_VERSION=' "$tmp" | sed -E 's/.*SCRIPT_VERSION="([^"]+)".*/\1/')
    [[ -n $new_ver ]] && echo "新版本: v${new_ver}"

    chmod +x "$tmp"
    # 覆盖自身
    if cp -f "$tmp" "$self" 2>/dev/null; then
        chmod +x "$self"
        rm -f "$tmp"
        success "脚本已更新到最新版"
        echo
        echo -e "${GREEN}请重新运行脚本以加载新版本：${NC}"
        echo "  bash $self"
        echo "或直接："
        echo "  bash <(curl -fsSL ${SCRIPT_RAW_URL})"
        echo
        read -p "按回车退出当前进程..." 
        exit 0
    else
        error "写入失败，请检查权限。临时文件保留在: $tmp"
        return 1
    fi
}

show_menu() {
    clear
    local mem
    mem=$(get_total_mem)
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  智能内存检测 REALITY 节点脚本  v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}  多方位优化 · 支持一键自更新 · 低内存友好${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "  当前总内存: ${YELLOW}${mem} MB${NC}   压力: $(get_mem_pressure_hint)"
    echo
    echo "  【安装与核心】"
    echo "  1. 智能安装节点（检测环境 + 按档开启功能）"
    echo "  2. 查看节点信息 / 分享链接 / 客户端片段 / 二维码"
    echo "  3. 导出完整节点信息到文件"
    echo
    echo "  【日常管理】"
    echo "  4. 修改端口"
    echo "  5. 重新生成主 UUID"
    echo "  6. 修改伪装目标 (dest/SNI)"
    echo "  7. 重新生成 REALITY 密钥"
    echo "  8. 修改 ShortID"
    echo "  9. 添加用户（多 UUID，受内存档位限制）"
    echo
    echo "  【运维与诊断】"
    echo " 10. 简易连通性自检"
    echo " 11. 查看最近日志"
    echo " 12. 重启服务"
    echo " 13. 查看运行状态 + 内存"
    echo " 14. 启用 BBR"
    echo " 15. 更新 Xray 内核"
    echo " 16. 一键系统参数优化（低内存友好）"
    echo
    echo "  【高级】"
    echo " 17. 智能分流建议"
    echo " 18. 全功能脚本引导（第三方，需确认）"
    echo " 19. 彻底还原（完全清理）"
    echo " 20. 更新本脚本（自更新）"
    echo
    echo "  0. 退出"
    echo
    echo -e "${BLUE}================================================${NC}"
}

while true; do
    show_menu
    read -p "请输入选项 [0-20]: " choice
    case $choice in
        1)  install_node ;;
        2)  show_link ;;
        3)  export_node_info ;;
        4)  change_port ;;
        5)  change_uuid ;;
        6)  change_dest ;;
        7)  regenerate_keys ;;
        8)  change_shortid ;;
        9)  add_user ;;
        10) self_check ;;
        11) show_recent_logs ;;
        12) restart_xray ;;
        13) status_xray ;;
        14) enable_bbr ;;
        15) update_xray ;;
        16) optimize_sysctl ;;
        17) smart_route_advice; read -p "按回车返回..." ;;
        18) run_full_script_menu ;;
        19) uninstall_node ;;
        20) update_script ;;
        0)  echo "退出"; exit 0 ;;
        *)  warn "无效选项" ;;
    esac
    echo
    read -p "按回车键返回菜单..."
done
