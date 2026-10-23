#!/bin/bash
# ============================================================
# 智能内存检测 + 交互式 VLESS + REALITY 节点脚本
# v4.5.0  对齐主流脚本查漏补缺
#
# 对照参考：233boy/Xray、mack-a/v2ray-agent、reality-ezpz、
#          官方 Xray-install、XTLS REALITY 文档
# 特别优化：64MB / 128MB / 256MB 超低内存小鸡
#
# 官方仓库 / 自更新地址：
#   https://github.com/chhjb/smart-node
#   https://raw.githubusercontent.com/chhjb/smart-node/main/smart-node.sh
#
# 一键安装/更新：
#   bash <(curl -fsSL https://raw.githubusercontent.com/chhjb/smart-node/main/smart-node.sh)
#
# v4.3 主要升级（对照主流脚本查漏补缺）：
#   1. 伪装目标列表去 Cloudflare（官方警告：CF 站易被扫成开放代理）
#   2. 新增 learn.microsoft.com 等更稳 dest；安装前探测 dest 可达性
#   3. sniffing 启用 routeOnly（对齐 233boy REALITY 实践）
#   4. 可选轻量路由：屏蔽私网 + BitTorrent（无 geo 文件，低内存友好）
#   5. serverNames 自动补充合理别名；shortIds 可选空串兼容
#   6. freedom 出站 UseIPv4；自检增加 dest TLS 探测
#   7. 订阅式多链接导出（base64）；删除用户
#   8. 继承 v4.2.1 全部修复（密钥解析、JSON 注入、自更新等）
#
# v4.3.1 打磨：
#   - 修复 BT 屏蔽规则双引号被 bash 剥掉导致 JSON 损坏
#   - 私网屏蔽固定纯 CIDR，不再依赖 geoip.dat
#   - 修改 dest 时同样做可达性探测
#   - backup 清理兼容非 GNU xargs
#   - 密钥写入 JSON 前做字符白名单
#
# v4.3.2：
#   - 支持 Alpine apk 包管理（帕斯云等轻量机）
#   - BusyBox df 无 -m 时磁盘检测回退
#   - 未知包管理器但已有 curl/openssl 时不硬失败
#
# v4.3.3：
#   - 修复 freedom domainStrategy：PreferIPv4 → UseIPv4（Xray 合法值）
#
# v4.4.0：
#   - 默认 Argo 梭哈模式（Cloudflare 快速隧道）：一路回车、免开端口
#   - 可选 REALITY 直连（需面板放行端口）
#
# v4.4.1：
#   - 覆盖重装 / 彻底还原：清理 xray+cloudflared+配置+临时文件+端口占用
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"
INFO_FILE="${CONFIG_DIR}/node.info"
BACKUP_DIR="${CONFIG_DIR}/backup"
XRAY_BIN="/usr/local/bin/xray"
CLOUDFLARED_BIN="/usr/local/bin/cloudflared"
ARGO_LOG="/tmp/cloudflared-argo.log"
XRAY_LOG="/tmp/xray-argo.log"
NODE_MODE="argo"
ARGO_URL=""
WS_PATH=""
SCRIPT_VERSION="4.5.0"
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

# 常用 REALITY 伪装目标（2025-2026）
# 原则：TLS1.3 + 高可用 + 非纯 CF 免费 CDN（官方警告 CF 易被滥用成开放代理）
# 参考：233boy 已从默认列表移除 cloudflare；社区推荐 learn.microsoft / apple / nvidia
DEST_LIST=(
    "www.microsoft.com:443"
    "learn.microsoft.com:443"
    "www.apple.com:443"
    "www.nvidia.com:443"
    "www.intel.com:443"
    "www.samsung.com:443"
    "www.amazon.com:443"
    "www.sony.com:443"
    "www.bing.com:443"
    "dl.google.com:443"
    "addons.mozilla.org:443"
    "gateway.icloud.com:443"
    "www.lovelive-anime.jp:443"
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

# 进程是否在跑（兼容无 pgrep 的 Alpine/BusyBox）
proc_alive() {
    local pat=$1
    if command -v pgrep >/dev/null 2>&1; then
        pgrep -f "$pat" >/dev/null 2>&1 && return 0
    fi
    ps 2>/dev/null | grep -v grep | grep -qE "$pat" && return 0
    return 1
}

# Argo 模式下禁止 REALITY 专用操作
require_reality() {
    load_info
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        warn "当前为 Argo 梭哈模式，该操作仅适用于 REALITY 直连"
        warn "请使用：菜单 2 看链接 / 14 重启隧道 / 1 重装 / 21 彻底清理"
        return 1
    fi
    return 0
}



systemd_supports_memory_max() {
    systemctl --version 2>/dev/null | head -n 1 | grep -qE 'systemd (2[4-9][0-9]|[3-9][0-9]{2,})' && return 0
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

    swap_total=$(free -m 2>/dev/null | awk '/^Swap:/{print $2}')
    # BusyBox df 常不支持 -m，先试 -m 再回退 -k
    disk_free_mb=$(df -m / 2>/dev/null | awk 'NR==2{print $4}')
    if [[ -z $disk_free_mb || ! $disk_free_mb =~ ^[0-9]+$ ]]; then
        disk_free_mb=$(df -k / 2>/dev/null | awk 'NR==2{print int($4/1024)}')
    fi
    [[ -z $disk_free_mb || ! $disk_free_mb =~ ^[0-9]+$ ]] && disk_free_mb=0
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
    # 只保留最近 5 份（不用 xargs -r，兼容非 GNU）
    local f
    while IFS= read -r f; do
        [[ -n $f ]] && rm -f "$f"
    done < <(ls -1t "${BACKUP_DIR}"/config.*.json 2>/dev/null | tail -n +6)
    while IFS= read -r f; do
        [[ -n $f ]] && rm -f "$f"
    done < <(ls -1t "${BACKUP_DIR}"/node.*.info 2>/dev/null | tail -n +6)
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
    # 若残留 /swapfile（未启用），先尝试 swapoff 再删除
    if [[ -f /swapfile ]]; then
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
    fi
    if ! fallocate -l ${size}M /swapfile 2>/dev/null; then
        # status=none 为 GNU dd；兼容 BusyBox / 旧版 dd
        if ! dd if=/dev/zero of=/swapfile bs=1M count=${size} status=none 2>/dev/null; then
            dd if=/dev/zero of=/swapfile bs=1M count=${size} 2>/dev/null || {
                error "创建 Swap 文件失败"; rm -f /swapfile; return 1
            }
        fi
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
    elif command -v apk >/dev/null 2>&1; then
        # Alpine / 帕斯云轻量机等
        apk update -q >/dev/null 2>&1 || true
        apk add --no-cache curl unzip openssl ca-certificates >/dev/null 2>&1
    elif command -v pacman >/dev/null 2>&1; then
        pacman -Sy --noconfirm curl unzip openssl ca-certificates >/dev/null 2>&1
    else
        # 包管理器未知：若核心命令已有则继续，否则失败
        if command -v curl >/dev/null 2>&1 && command -v openssl >/dev/null 2>&1; then
            warn "未知包管理器，但 curl/openssl 可用，跳过依赖安装"
            command -v unzip >/dev/null 2>&1 || warn "缺少 unzip，下载 Xray 时可能失败"
            return 0
        fi
        error "不支持的包管理器（需要 apt/dnf/yum/apk 之一，或已预装 curl+openssl）"
        return 1
    fi
    if ! command -v curl >/dev/null 2>&1 || ! command -v openssl >/dev/null 2>&1; then
        error "依赖安装后仍缺少 curl/openssl"; return 1
    fi
    success "依赖安装完成"
}

install_xray() {
    if [[ -x $XRAY_BIN ]] && $XRAY_BIN version >/dev/null 2>&1; then
        info "Xray 已存在且可用: $($XRAY_BIN version 2>/dev/null | head -n 1)"
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
    # 注意：jsdelivr 的 gh@ 路径无法正确拉取 GitHub Releases 二进制，已移除
    local urls=(
        "https://github.com/XTLS/Xray-core/releases/latest/download/${filename}"
        "https://ghfast.top/https://github.com/XTLS/Xray-core/releases/latest/download/${filename}"
        "https://mirror.ghproxy.com/https://github.com/XTLS/Xray-core/releases/latest/download/${filename}"
        "https://ghproxy.net/https://github.com/XTLS/Xray-core/releases/latest/download/${filename}"
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
    success "Xray 安装完成: $($XRAY_BIN version 2>/dev/null | head -n 1)"
}

install_cloudflared() {
    if [[ -x $CLOUDFLARED_BIN ]] && $CLOUDFLARED_BIN --version >/dev/null 2>&1; then
        info "cloudflared 已存在: $($CLOUDFLARED_BIN --version 2>/dev/null | head -n1)"
        return 0
    fi
    local ARCH bin
    ARCH=$(uname -m)
    case $ARCH in
        x86_64|amd64)  bin="cloudflared-linux-amd64" ;;
        aarch64|arm64) bin="cloudflared-linux-arm64" ;;
        armv7l|armv7)  bin="cloudflared-linux-arm" ;;
        *) error "不支持架构: $ARCH"; return 1 ;;
    esac
    info "下载 cloudflared ($bin) ..."
    local urls=(
        "https://github.com/cloudflare/cloudflared/releases/latest/download/${bin}"
        "https://ghfast.top/https://github.com/cloudflare/cloudflared/releases/latest/download/${bin}"
        "https://mirror.ghproxy.com/https://github.com/cloudflare/cloudflared/releases/latest/download/${bin}"
    )
    local tmp="/tmp/cf_dl_$$" ok=0 url
    for url in "${urls[@]}"; do
        if curl -fsSL --connect-timeout 10 --max-time 120 -o "$tmp" "$url" --retry 2 2>/dev/null; then
            ok=1; break
        fi
        warn "镜像失败，尝试下一个..."
    done
    (( ok == 0 )) && { error "cloudflared 下载失败"; return 1; }
    local fsize; fsize=$(wc -c < "$tmp" 2>/dev/null || echo 0)
    (( fsize < 5000000 )) && { error "cloudflared 文件异常($fsize)"; rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$CLOUDFLARED_BIN"
    chmod +x "$CLOUDFLARED_BIN"
    success "cloudflared 安装完成"
}

write_config_argo() {
    local uuid=$1 port=$2 path=$3
    uuid=$(echo "$uuid" | tr -cd '0-9a-fA-F-')
    path=$(echo "$path" | tr -cd 'A-Za-z0-9/_-')
    [[ -z $path ]] && path="/argo"
    [[ $path == /* ]] || path="/$path"
    [[ -z $uuid ]] && { error "UUID 无效"; return 1; }
    if ! [[ $port =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        error "端口无效"; return 1
    fi
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
{
  "log": { "loglevel": "none" },
  "inbounds": [
    {
      "listen": "127.0.0.1",
      "port": ${port},
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "${uuid}", "email": "argo" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "${path}" }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {},
      "streamSettings": {
        "sockopt": { "domainStrategy": "UseIPv4" }
      }
    }
  ]
}
EOF
}

start_argo_stack() {
    local port=$1
    pkill -f "$XRAY_BIN" 2>/dev/null || true
    pkill -f "cloudflared" 2>/dev/null || true
    sleep 1
    nohup $XRAY_BIN run -c "$CONFIG_FILE" >"$XRAY_LOG" 2>&1 &
    sleep 1
    if ! pgrep -f "$XRAY_BIN" >/dev/null 2>&1 && ! ps 2>/dev/null | grep -q '[x]ray'; then
        error "Xray 启动失败，见 $XRAY_LOG"
        tail -15 "$XRAY_LOG" 2>/dev/null || true
        return 1
    fi
    : > "$ARGO_LOG"
    nohup $CLOUDFLARED_BIN tunnel --url "http://127.0.0.1:${port}" --no-autoupdate >"$ARGO_LOG" 2>&1 &
    info "等待 Cloudflare 分配临时域名（约 15 秒）..."
    local i url=""
    for i in $(seq 1 30); do
        sleep 1
        url=$(grep -oE 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com' "$ARGO_LOG" 2>/dev/null | head -1)
        [[ -n $url ]] && break
    done
    if [[ -z $url ]]; then
        error "未拿到 trycloudflare.com 域名，日志:"
        tail -30 "$ARGO_LOG" 2>/dev/null || true
        return 1
    fi
    ARGO_URL=${url#https://}
    success "隧道已建立: $ARGO_URL"
    return 0
}

# path 仅保留安全字符，链接里用原 path（客户端一般支持 /path）
build_argo_link() {
    local uid=${1:-$UUID} host=${2:-$ARGO_URL} path=${3:-$WS_PATH}
    [[ -z $path ]] && path="/argo"
    [[ $path == /* ]] || path="/$path"
    echo "vless://${uid}@${host}:443?encryption=none&security=tls&type=ws&host=${host}&path=${path}&sni=${host}&fp=chrome#Smart-Argo"
}

generate_keys() {
    local output line key val
    output=$($XRAY_BIN x25519 2>/dev/null)
    if [[ -z $output ]]; then
        error "xray x25519 执行失败"; return 1
    fi

    PRIVATE_KEY=""
    PUBLIC_KEY=""
    # 兼容多种历史/当前输出格式：
    #   Private key: / Public key:
    #   PrivateKey: / Password (PublicKey):
    #   PrivateKey: / Password: / Hash32:   （Password = 公钥）
    while IFS= read -r line || [[ -n $line ]]; do
        key=$(echo "$line" | sed -E 's/^[[:space:]]*//;s/[[:space:]]*:.*//' | tr 'A-Z' 'a-z')
        val=$(echo "$line" | sed -E 's/^[^:]*:[[:space:]]*//;s/[[:space:]]*$//')
        [[ -z $val ]] && continue
        case "$key" in
            privatekey|"private key")
                PRIVATE_KEY=$val
                ;;
            "password (publickey)"|password|publickey|"public key")
                PUBLIC_KEY=$val
                ;;
            hash32)
                # Hash32 不是公钥，跳过
                ;;
        esac
    done <<< "$output"

    # 兜底：按行序取（第一行私钥，第二行公钥/Password）
    if [[ -z $PRIVATE_KEY || -z $PUBLIC_KEY ]]; then
        PRIVATE_KEY=$(echo "$output" | awk -F': *' 'BEGIN{IGNORECASE=1} /private/{print $2; exit}' | tr -d '[:space:]')
        PUBLIC_KEY=$(echo "$output" | awk -F': *' 'BEGIN{IGNORECASE=1} /password|public/{print $2; exit}' | tr -d '[:space:]')
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
    # 防止自定义 dest/SNI 注入破坏 JSON（引号、反斜杠、控制字符）
    dest=$(echo "$dest" | tr -d '\r\n\t"\\' | tr -cd '[:alnum:]._:-')
    # 只保留 host 或 host:port 形态
    if [[ $dest =~ ^([A-Za-z0-9._-]+)(:([0-9]{1,5}))?$ ]]; then
        local dhost=${BASH_REMATCH[1]}
        local dport=${BASH_REMATCH[3]:-443}
        (( dport < 1 || dport > 65535 )) && dport=443
        dest="${dhost}:${dport}"
    else
        dest="www.microsoft.com:443"
    fi
    # UUID / 密钥仅保留安全字符，避免破坏 JSON
    uuid=$(echo "$uuid" | tr -cd '0-9a-fA-F-')
    private_key=$(echo "$private_key" | tr -cd 'A-Za-z0-9+/=_-')
    if [[ -z $uuid || -z $private_key ]]; then
        error "UUID 或私钥无效，拒绝写配置"; return 1
    fi
    if ! [[ $port =~ ^[0-9]+$ ]] || (( port < 1 || port > 65535 )); then
        error "端口无效: $port"; return 1
    fi
    local sni=${dest%%:*}
    local loglevel=${FEAT_LOGLEVEL:-none}
    local listen=${FEAT_LISTEN:-"0.0.0.0"}
    # loglevel 白名单
    case $loglevel in
        none|error|warning|info|debug) ;;
        *) loglevel="none" ;;
    esac
    case $listen in
        0.0.0.0|127.0.0.1|::|::0) ;;
        *) listen="0.0.0.0" ;;
    esac
    mkdir -p "$CONFIG_DIR"

    local clients_json="" seen="|" u
    for u in $uuid $EXTRA_UUIDS; do
        u=$(echo "$u" | tr -cd '0-9a-fA-F-')
        [[ -z $u || ${#u} -lt 8 ]] && continue
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

    short_id=$(echo "$short_id" | tr -cd '0-9a-fA-F')
    (( ${#short_id} % 2 == 1 )) && short_id="${short_id:0:$((${#short_id}-1))}"
    [[ ${#short_id} -lt 2 ]] && short_id="a1b2c3d4"
    local short_json="\"${short_id}\""
    if [[ -n ${FEAT_SHORT2:-} ]]; then
        local s2
        s2=$(echo "$FEAT_SHORT2" | tr -cd '0-9a-fA-F')
        (( ${#s2} % 2 == 1 )) && s2="${s2:0:$((${#s2}-1))}"
        [[ ${#s2} -ge 2 ]] && short_json="${short_json}, \"${s2}\""
    fi
    # 可选空 shortId：兼容不带 sid 的旧客户端（过渡用）
    if [[ ${FEAT_EMPTY_SID:-0} -eq 1 ]]; then
        short_json="\"\", ${short_json}"
    fi

    # serverNames：主 SNI + 合理别名（无通配符）
    local names_json="\"${sni}\""
    case $sni in
        www.*)
            local bare=${sni#www.}
            [[ -n $bare && $bare != "$sni" ]] && names_json="${names_json}, \"${bare}\""
            ;;
        learn.microsoft.com)
            names_json="${names_json}, \"www.microsoft.com\""
            ;;
    esac

    # 轻量路由（纯 CIDR / 协议名，不依赖 geoip.dat，适合小鸡）
    local routing_json="" outbound_block=""
    if [[ ${FEAT_BLOCK_PRIVATE:-0} -eq 1 || ${FEAT_BLOCK_BT:-0} -eq 1 ]]; then
        outbound_block='
    {
      "protocol": "blackhole",
      "tag": "block"
    }'
        local rules=""
        # 全程用单引号拼接，避免双引号把 JSON 键值剥掉（曾导致 BT 规则无效）
        if [[ ${FEAT_BLOCK_PRIVATE:-0} -eq 1 ]]; then
            rules='
        {
          "type": "field",
          "ip": ["0.0.0.0/8","10.0.0.0/8","127.0.0.0/8","169.254.0.0/16","172.16.0.0/12","192.168.0.0/16","::1/128","fc00::/7","fe80::/10"],
          "outboundTag": "block"
        }'
        fi
        if [[ ${FEAT_BLOCK_BT:-0} -eq 1 ]]; then
            [[ -n $rules ]] && rules="${rules},"
            rules="${rules}"'
        {
          "type": "field",
          "protocol": ["bittorrent"],
          "outboundTag": "block"
        }'
        fi
        routing_json='
  "routing": {
    "domainStrategy": "AsIs",
    "rules": [
'"${rules}"'
    ]
  },'
    fi

    cat > "$CONFIG_FILE" << EOF
{
  "log": {
    "loglevel": "${loglevel}"
  },${routing_json}
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
          "target": "${dest}",
          "xver": 0,
          "serverNames": [
            ${names_json}
          ],
          "privateKey": "${private_key}",
          "shortIds": [
            ${short_json}
          ]
        }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "routeOnly": true
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "tag": "direct",
      "settings": {},
      "streamSettings": {
        "sockopt": {
          "domainStrategy": "UseIPv4"
        }
      }
    }${outbound_block:+,}
${outbound_block}
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
    FEAT_EMPTY_SID=0
    FEAT_BLOCK_PRIVATE=0
    FEAT_BLOCK_BT=0

    echo
    title "========== 智能功能选择 =========="
    echo "根据当前档位 [${LEVEL}]，可开启的功能如下（已自动勾选推荐项）："
    echo

    case $LEVEL in
        extreme|ultra-low)
            echo -e "  ${GREEN}[必选]${NC} VLESS + REALITY + Vision（轻量核心）"
            echo -e "  ${RED}[锁定]${NC} 多用户 / 详细日志 / 路由规则 —— 内存不足，已禁用"
            echo -e "  ${GREEN}[自动]${NC} loglevel=none，routeOnly sniffing，UseIPv4"
            FEAT_LOGLEVEL="none"
            FEAT_LISTEN="0.0.0.0"
            ;;
        low)
            echo -e "  ${GREEN}[必选]${NC} VLESS + REALITY + Vision"
            echo "  可选："
            echo "    a) 额外 1 个用户（多 UUID）"
            echo "    b) 备用 shortId"
            echo "    e) 允许空 shortId（兼容旧客户端）"
            echo "    p) 屏蔽私网回环（防 SSRF/误扫）"
            read -p "输入要开启的项（如 a / abep，直接回车=仅核心）: " picks
            [[ $picks == *a* ]] && FEAT_MULTI_USER=1
            [[ $picks == *b* ]] && FEAT_EXTRA_SHORT=1
            [[ $picks == *e* ]] && FEAT_EMPTY_SID=1
            [[ $picks == *p* ]] && FEAT_BLOCK_PRIVATE=1
            FEAT_LOGLEVEL="none"
            ;;
        medium|high)
            echo -e "  ${GREEN}[必选]${NC} VLESS + REALITY + Vision"
            echo "  可选（可多选，如 abdep）："
            echo "    a) 多用户（额外 1～3 个 UUID）"
            echo "    b) 备用 shortId"
            echo "    d) 打开 warning 日志（排障用）"
            echo "    e) 允许空 shortId（兼容旧客户端）"
            echo "    p) 屏蔽私网回环"
            echo "    t) 屏蔽 BitTorrent"
            read -p "输入要开启的项（直接回车=仅核心+推荐）: " picks
            if [[ -z $picks ]]; then
                read -p "是否至少预留多用户能力（生成 1 个备用 UUID）？(y/N): " mu
                [[ $mu == "y" || $mu == "Y" ]] && FEAT_MULTI_USER=1
            else
                [[ $picks == *a* ]] && FEAT_MULTI_USER=1
                [[ $picks == *b* ]] && FEAT_EXTRA_SHORT=1
                [[ $picks == *d* ]] && FEAT_LOG=1
                [[ $picks == *e* ]] && FEAT_EMPTY_SID=1
                [[ $picks == *p* ]] && FEAT_BLOCK_PRIVATE=1
                [[ $picks == *t* ]] && FEAT_BLOCK_BT=1
            fi
            [[ $FEAT_LOG -eq 1 ]] && FEAT_LOGLEVEL="warning" || FEAT_LOGLEVEL="none"
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
    info "功能摘要: log=${FEAT_LOGLEVEL} multi=${FEAT_MULTI_USER} short2=${FEAT_SHORT2:-无} empty_sid=${FEAT_EMPTY_SID} block_priv=${FEAT_BLOCK_PRIVATE} block_bt=${FEAT_BLOCK_BT}"
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
FEAT_EMPTY_SID=${FEAT_EMPTY_SID:-0}
FEAT_BLOCK_PRIVATE=${FEAT_BLOCK_PRIVATE:-0}
FEAT_BLOCK_BT=${FEAT_BLOCK_BT:-0}
NODE_MODE=${NODE_MODE:-reality}
ARGO_URL=${ARGO_URL:-}
WS_PATH=${WS_PATH:-}
EOF
}

load_info() {
    UUID=""; PORT=""; PRIVATE_KEY=""; PUBLIC_KEY=""; SHORT_ID=""
    SERVER_IP=""; LEVEL=""; DEST=""
    EXTRA_UUIDS=""; FEAT_SHORT2=""; FEAT_LOGLEVEL="none"; FEAT_LISTEN="0.0.0.0"
    FEAT_EMPTY_SID=0; FEAT_BLOCK_PRIVATE=0; FEAT_BLOCK_BT=0
    NODE_MODE="reality"; ARGO_URL=""; WS_PATH=""
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
            FEAT_EMPTY_SID) FEAT_EMPTY_SID="$v" ;;
            FEAT_BLOCK_PRIVATE) FEAT_BLOCK_PRIVATE="$v" ;;
            FEAT_BLOCK_BT) FEAT_BLOCK_BT="$v" ;;
            NODE_MODE) NODE_MODE="$v" ;;
            ARGO_URL) ARGO_URL="$v" ;;
            WS_PATH) WS_PATH="$v" ;;
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
    local sid=${SHORT_ID}

    # Argo：VLESS+WS+TLS，无 flow/REALITY
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        local host=${ARGO_URL}
        local path=${WS_PATH:-/argo}
        [[ $path == /* ]] || path="/$path"
        [[ -z $host ]] && host=$(grep -oE '[a-zA-Z0-9.-]+\.trycloudflare\.com' "$ARGO_LOG" 2>/dev/null | head -1)
        name="Smart-Argo"
        echo
        title "---------- Clash Meta 片段（Argo） ----------"
        cat << EOF
- name: "${name}"
  type: vless
  server: ${host}
  port: 443
  uuid: ${UUID}
  network: ws
  tls: true
  udp: true
  servername: ${host}
  client-fingerprint: chrome
  ws-opts:
    path: "${path}"
    headers:
      Host: ${host}
EOF
        echo
        title "---------- sing-box 出站片段（Argo） ----------"
        cat << EOF
{
  "type": "vless",
  "tag": "${name}",
  "server": "${host}",
  "server_port": 443,
  "uuid": "${UUID}",
  "tls": {
    "enabled": true,
    "server_name": "${host}",
    "utls": { "enabled": true, "fingerprint": "chrome" }
  },
  "transport": {
    "type": "ws",
    "path": "${path}",
    "headers": { "Host": "${host}" }
  }
}
EOF
        return
    fi

    echo
    title "---------- Clash Meta 片段（主 UUID） ----------"
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
    short-id: ${sid}
EOF
    local u i=1
    for u in $EXTRA_UUIDS; do
        [[ -z $u ]] && continue
        i=$((i + 1))
        cat << EOF
- name: "${name}-${i}"
  type: vless
  server: ${ip}
  port: ${PORT}
  uuid: ${u}
  network: tcp
  tls: true
  udp: true
  flow: xtls-rprx-vision
  servername: ${sni}
  client-fingerprint: chrome
  reality-opts:
    public-key: ${PUBLIC_KEY}
    short-id: ${sid}
EOF
    done
    [[ -n $FEAT_SHORT2 ]] && echo "# 备用 short-id 可用: ${FEAT_SHORT2}"

    echo
    title "---------- sing-box 出站片段（主 UUID） ----------"
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
      "short_id": "${sid}"
    }
  }
}
EOF
    [[ -n $FEAT_SHORT2 ]] && echo "# 备用 short_id 可用: ${FEAT_SHORT2}"
    if [[ -n $EXTRA_UUIDS ]]; then
        echo "# 额外 UUID（复制上方片段并替换 uuid 即可）: $EXTRA_UUIDS"
    fi
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

    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        if [[ -z $ARGO_URL ]]; then
            warn "Argo 域名丢失，尝试从日志恢复..."
            ARGO_URL=$(grep -oE '[a-zA-Z0-9.-]+\.trycloudflare\.com' "$ARGO_LOG" 2>/dev/null | head -1)
        fi
        if [[ -z $ARGO_URL ]]; then
            error "无有效 Argo 域名，请重新安装（菜单 1）或重启服务（菜单 14）"
            return
        fi
        main_link=$(build_argo_link "$UUID" "$ARGO_URL" "$WS_PATH")
        echo
        title "========== Argo 节点信息 =========="
        echo "模式      : Argo 梭哈（Cloudflare 快速隧道）"
        echo "域名      : $ARGO_URL"
        echo "本机端口  : $PORT (仅 127.0.0.1)"
        echo "WS Path   : $WS_PATH"
        echo "主 UUID   : $UUID"
        echo "脚本版本  : v${SCRIPT_VERSION}"
        echo
        echo -e "${YELLOW}分享链接：${NC}"
        echo "$main_link"
        echo
        echo -e "${YELLOW}提示：机器重启或进程被杀后域名会变，需重新安装/重启隧道。${NC}"
        show_client_snippets
        show_qrcode_if_available "$main_link"
        echo -e "${CYAN}===================================${NC}"
        return
    fi

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
    require_reality || return
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

remove_user() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    require_reality || return
    echo
    title "---------- 当前用户 ----------"
    echo "  1) [主] $UUID"
    local i=2 u
    for u in $EXTRA_UUIDS; do
        [[ -z $u ]] && continue
        echo "  $i) $u"
        i=$((i + 1))
    done
    if (( i == 2 )); then
        warn "仅有主用户，无法删除（可重装或改主 UUID）"
        return
    fi
    read -p "输入要删除的序号（不能删主用户 1）: " idx
    [[ -z $idx || $idx == "1" ]] && { warn "已取消或不可删主用户"; return; }
    if ! [[ $idx =~ ^[0-9]+$ ]] || (( idx < 2 || idx >= i )); then
        error "序号无效"; return
    fi
    local target pos=2 new_extra=""
    for u in $EXTRA_UUIDS; do
        [[ -z $u ]] && continue
        if (( pos == idx )); then
            target=$u
        else
            new_extra="${new_extra} ${u}"
        fi
        pos=$((pos + 1))
    done
    [[ -z $target ]] && { error "未找到对应用户"; return; }
    backup_config
    EXTRA_UUIDS=$(echo $new_extra)
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}" || return
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    if has_systemd; then
        systemctl restart xray 2>/dev/null || true
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
    fi
    success "已删除用户: $target"
    show_link
}

# 订阅式导出：多链接 base64（常见客户端可直接导入）
export_subscription() {
    load_info
    [[ -z $UUID ]] && { warn "尚未安装节点"; return; }
    local links="" u
    links=$(_make_link "$UUID")
    for u in $EXTRA_UUIDS; do
        [[ -z $u ]] && continue
        links="${links}
$(_make_link "$u")"
    done
    local b64 out
    if command -v base64 >/dev/null 2>&1; then
        b64=$(printf '%s\n' "$links" | base64 -w0 2>/dev/null || printf '%s\n' "$links" | base64 | tr -d '\n')
    else
        warn "系统无 base64 命令，仅输出明文链接"
        echo "$links"
        return
    fi
    out="/root/smart-node-sub-$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "# smart-node subscription v${SCRIPT_VERSION}"
        echo "# 明文链接："
        echo "$links"
        echo
        echo "# Base64 订阅内容（可导入支持 subscription 的客户端）："
        echo "$b64"
    } > "$out"
    success "已导出: $out"
    echo
    title "---------- Base64 订阅（可复制） ----------"
    echo "$b64"
    echo -e "${CYAN}=========================================${NC}"
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
    local conf="/etc/sysctl.conf"
    [[ -f $conf ]] || touch "$conf"
    # 先追加到临时文件，再与原文件合并去重后原子替换，避免中断损坏
    local tmp
    tmp=$(mktemp /tmp/sysctl-smart-node.XXXXXX 2>/dev/null || echo /tmp/sysctl-smart-node.$$)
    {
        cat "$conf" 2>/dev/null
        cat << EOF

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
    } | awk 'NF==0{if(!blank++){print}; next} {blank=0} !seen[$0]++' > "$tmp"
    if [[ -s $tmp ]]; then
        cp -f "$conf" "${conf}.smart-node.bak" 2>/dev/null || true
        mv -f "$tmp" "$conf"
    else
        rm -f "$tmp"
        warn "sysctl 合并失败，已跳过写入"
        return 1
    fi
    sysctl -p >/dev/null 2>&1 || true
    success "sysctl 优化已应用（已去重，备份: ${conf}.smart-node.bak）"
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

# 探测 REALITY dest 是否从本机可达（TLS 握手）
probe_dest() {
    local dest=${1:-}
    [[ -z $dest ]] && return 1
    local host=${dest%%:*}
    local port=${dest##*:}
    [[ $host == "$dest" ]] && port=443
    # 优先 openssl，其次 bash /dev/tcp；timeout 可能不存在
    if command -v openssl >/dev/null 2>&1; then
        if command -v timeout >/dev/null 2>&1; then
            if timeout 5 openssl s_client -connect "${host}:${port}" -servername "$host" </dev/null 2>/dev/null | grep -qiE 'Protocol|Verify return code'; then
                return 0
            fi
        else
            if openssl s_client -connect "${host}:${port}" -servername "$host" -brief </dev/null 2>/dev/null | head -n 5 | grep -qiE 'Protocol|CONNECTION'; then
                return 0
            fi
        fi
        return 1
    fi
    if command -v timeout >/dev/null 2>&1; then
        timeout 4 bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null && return 0
    else
        bash -c "echo >/dev/tcp/${host}/${port}" 2>/dev/null && return 0
    fi
    return 1
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

    echo "模式: ${NODE_MODE:-reality}  档位: ${LEVEL:-?}"

    # 1. 进程/服务
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        if proc_alive "xray"; then
            success "Xray 进程: 运行中"
        else
            error "Xray 进程: 未运行（菜单 14 重启）"
        fi
        if proc_alive "cloudflared"; then
            success "cloudflared: 运行中"
        else
            error "cloudflared: 未运行（菜单 14 重启）"
        fi
        if [[ -n $ARGO_URL ]]; then
            info "Argo 域名: $ARGO_URL"
        else
            warn "无 ARGO_URL，尝试从日志恢复"
            ARGO_URL=$(grep -oE '[a-zA-Z0-9.-]+\.trycloudflare\.com' "$ARGO_LOG" 2>/dev/null | head -1)
            [[ -n $ARGO_URL ]] && info "恢复域名: $ARGO_URL" || error "无法恢复域名，请重装"
        fi
        echo
        warn "Argo 模式无需放行本机端口；最终请用客户端测链接"
        echo -e "${CYAN}=================================${NC}"
        return
    fi

    if has_systemd; then
        if systemctl is-active --quiet xray; then
            success "systemd 服务: 运行中"
        else
            error "systemd 服务: 未运行"
            systemctl status xray --no-pager -l 2>/dev/null | head -n 15
        fi
    else
        if proc_alive "xray"; then
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

    # 4. dest 可达性（REALITY 回落目标）
    local dest=${DEST:-www.microsoft.com:443}
    if probe_dest "$dest"; then
        success "伪装目标 dest 可达: $dest"
    else
        warn "伪装目标 dest 探测失败: $dest（可能导致 REALITY 握手异常，建议换 dest）"
    fi

    # 5. 内存占用
    local rss
    rss=$(ps -o rss= -C xray 2>/dev/null | awk '{s+=$1} END{print s+0}')
    if (( rss > 0 )); then
        info "Xray RSS: $((rss/1024)) MB"
    fi

    # 6. 提示
    echo
    warn "本自检仅检查本机状态。最终连通性请用客户端测试。"
    warn "云厂商请确认安全组已放行 TCP $PORT"
    echo -e "${CYAN}=================================${NC}"
}

show_recent_logs() {
    echo
    title "---------- 最近日志 ----------"
    if has_systemd; then
        journalctl -u xray -n 30 --no-pager 2>/dev/null || warn "无 journal 日志"
    fi
    if [[ -f $XRAY_LOG ]]; then
        echo "--- $XRAY_LOG ---"
        tail -n 40 "$XRAY_LOG" 2>/dev/null || true
    fi
    if [[ -f $ARGO_LOG ]]; then
        echo "--- $ARGO_LOG ---"
        tail -n 40 "$ARGO_LOG" 2>/dev/null || true
    fi
    if [[ ! -f $XRAY_LOG && ! -f $ARGO_LOG ]] && ! has_systemd; then
        warn "无日志文件。可用: ps | grep -E 'xray|cloudflared'"
    fi
}

# ======================== 安装主逻辑 ========================
# ---------- Argo 梭哈安装（默认，免开端口） ----------
install_node_argo() {
    echo
    info "开始安装（Argo 梭哈模式：Cloudflare 快速隧道）..."
    info "特点：一路回车、不需面板放行端口；重启后需重新跑脚本或菜单拉起"

    if (( ${SMART_SWAP:-0} > 0 )); then
        create_swap "${SMART_SWAP}" || warn "Swap 创建失败，继续"
    fi

    install_deps || return 1
    install_xray || return 1
    install_cloudflared || return 1

    if command -v uuidgen >/dev/null 2>&1; then
        UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
    else
        UUID=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
    fi
    [[ -z $UUID ]] && UUID=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')

    # 仅本机端口，随机高位
    PORT=$((30000 + RANDOM % 20000))
    local try=0
    while ! check_port_free $PORT && (( try < 30 )); do
        PORT=$((30000 + RANDOM % 20000))
        try=$((try + 1))
    done
    WS_PATH="/$(openssl rand -hex 8 2>/dev/null || echo argo$((RANDOM % 99999)))$(openssl rand -hex 4 2>/dev/null || echo x)"
    PRIVATE_KEY=""; PUBLIC_KEY=""; SHORT_ID=""
    DEST=""
    SERVER_IP=$(get_ip)
    LEVEL="argo"
    NODE_MODE="argo"

    write_config_argo "$UUID" "$PORT" "$WS_PATH" || return 1
    if $XRAY_BIN run -c "$CONFIG_FILE" -test >/dev/null 2>&1; then
        info "配置校验通过"
    else
        warn "配置测试未通过，仍尝试启动"
        $XRAY_BIN run -c "$CONFIG_FILE" -test 2>&1 | head -15 || true
    fi

    start_argo_stack "$PORT" || return 1
    save_info "$UUID" "$PORT" "" "" "" "$SERVER_IP" "argo" ""
    success "Argo 节点安装完成！"
    echo
    echo -e "${YELLOW}注意：临时域名在进程被杀或机器重启后会失效，需重新执行安装或菜单「14 重启」。${NC}"
    show_link
}

install_node() {
    detect_and_recommend

    if [[ -f $INFO_FILE ]] || [[ -x $XRAY_BIN ]] || proc_alive 'xray|cloudflared'; then
        warn "检测到已有节点 / Xray / 隧道残留"
        read -p "是否彻底清理后重装？(y/N): " overwrite
        [[ $overwrite != "y" && $overwrite != "Y" ]] && return
        backup_config 2>/dev/null || true
        purge_all quiet
        sleep 1
        info "清理完成，开始全新安装"
    fi

    if [[ $LEVEL == "extreme" ]]; then
        echo -e "${RED}警告：64MB 级别内存非常极限，Xray 仍可能因 OOM 被杀。${NC}"
        echo -e "${RED}请确保已关闭所有不必要进程，并准备好较大 Swap。${NC}"
        echo
    fi

    if [[ $LEVEL == "medium" || $LEVEL == "high" ]]; then
        echo -e "${CYAN}提示：当前内存较充足。若你需要多协议/多用户/证书，可选菜单「20」引导全功能脚本。${NC}"
        echo -e "${CYAN}若只要一个轻量 REALITY 节点，继续用本脚本即可。${NC}"
        echo
    elif [[ $LEVEL == "extreme" || $LEVEL == "ultra-low" ]]; then
        echo -e "${RED}提示：当前为超低内存，已锁定本脚本轻量路径，不建议换其它一键脚本。${NC}"
        echo
    fi

    read -p "是否按本脚本推荐方案继续安装？(Y/n): " confirm
    [[ $confirm == "n" || $confirm == "N" ]] && return

    echo
    title "选择接入方式（直接回车 = Argo 梭哈，推荐免费机）:"
    echo "  1) Argo 梭哈（Cloudflare 隧道，免开端口，一路回车）【默认】"
    echo "  2) REALITY 直连（需面板放行端口，更稳定持久）"
    read -p "请选择 [1/2，回车=1]: " mode_choice
    mode_choice=${mode_choice:-1}
    if [[ $mode_choice != "2" ]]; then
        NODE_MODE="argo"
        install_node_argo
        return
    fi
    NODE_MODE="reality"
    echo
    info "开始安装 REALITY 直连（档位: $LEVEL）..."

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
    info "探测 dest 可达性..."
    if probe_dest "$DEST"; then
        success "dest 可达: $DEST"
    else
        warn "dest 探测失败: $DEST（本机可能无法访问该站，REALITY 回落会异常）"
        read -p "仍继续使用该 dest？(Y/n): " keep_dest
        if [[ $keep_dest == "n" || $keep_dest == "N" ]]; then
            warn "请重新运行安装并换一个伪装目标"
            return 1
        fi
    fi

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
    echo "4. 出问题可用菜单「12」自检 或「13」看日志"
    echo -e "${CYAN}=====================================${NC}"
}

change_port() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    require_reality || return
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
    require_reality || return
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
    require_reality || return
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
    require_reality || return
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
    require_reality || return
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
    info "探测 dest 可达性..."
    if probe_dest "$DEST"; then
        success "dest 可达: $DEST"
    else
        warn "dest 探测失败: $DEST"
        read -p "仍继续使用？(Y/n): " keep_dest
        [[ $keep_dest == "n" || $keep_dest == "N" ]] && return
    fi
    backup_config
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "$DEST" || return
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
    load_info
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        info "重启 Argo 栈（Xray + cloudflared）..."
        if [[ -z $PORT ]]; then
            error "缺少配置，请重新安装"; return
        fi
        [[ -z $WS_PATH ]] && WS_PATH="/argo"
        if [[ ! -s $CONFIG_FILE ]]; then
            write_config_argo "$UUID" "$PORT" "$WS_PATH" || return
        fi
        start_argo_stack "$PORT" || return
        save_info "$UUID" "$PORT" "" "" "" "${SERVER_IP:-$(get_ip)}" "argo" ""
        success "Argo 已重启（临时域名可能已变）"
        show_link
        return
    fi
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
        sleep 1
        if pgrep -f "$XRAY_BIN" >/dev/null 2>&1 || ps 2>/dev/null | grep -q '[x]ray'; then
            success "已后台重启"
        else
            error "启动失败，请检查 $CONFIG_FILE"
        fi
    fi
}

status_xray() {
    refresh_mem_cache
    load_info
    echo
    title "----- 进程 -----"
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        echo "模式: Argo"
        proc_alive "xray" && success "xray: 运行中" || error "xray: 未运行"
        proc_alive "cloudflared" && success "cloudflared: 运行中" || error "cloudflared: 未运行"
        [[ -n $ARGO_URL ]] && echo "域名: $ARGO_URL"
    elif has_systemd; then
        systemctl status xray --no-pager -l 2>/dev/null || warn "服务未安装"
    else
        proc_alive "xray" && success "xray: 运行中" || warn "未发现 xray 进程"
        ps 2>/dev/null | grep -E '[x]ray' || true
    fi
    echo
    title "----- 监听端口 -----"
    netstat -tln 2>/dev/null || ss -tln 2>/dev/null || true
    echo
    title "----- 内存与 Swap -----"
    free -m 2>/dev/null || free
    echo
    swapon --show 2>/dev/null || true
    echo
    local rss=0
    rss=$(ps -o rss= -C xray 2>/dev/null | awk '{s+=$1} END{print s+0}')
    if [[ -z $rss || $rss == 0 ]]; then
        rss=$(ps 2>/dev/null | awk '/[x]ray/{print $6}' | head -1)
        rss=${rss:-0}
    fi
    if (( rss > 0 )); then
        # RSS 可能是 KB（ps -o rss）或已是 KB
        if (( rss > 1024 * 50 )); then
            info "Xray RSS 约 $((rss/1024)) MB"
        else
            info "Xray RSS 约 ${rss} KB"
        fi
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
    load_info
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        restart_xray
    elif has_systemd; then
        systemctl restart xray 2>/dev/null || true
    else
        pkill -f "$XRAY_BIN" 2>/dev/null || true
        [[ -f $CONFIG_FILE ]] && nohup $XRAY_BIN run -c $CONFIG_FILE >/dev/null 2>&1 &
    fi
    success "更新完成"
}

# 彻底清理本脚本留下的一切（可静默，供重装调用）
# $1 = quiet 时不交互、不删 Swap/sysctl
purge_all() {
    local quiet=${1:-}
    info "深度清理残留进程与文件..."

    # ---- 1. 服务 ----
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop xray 2>/dev/null || true
        systemctl disable xray 2>/dev/null || true
        systemctl stop cloudflared 2>/dev/null || true
        systemctl disable cloudflared 2>/dev/null || true
    fi
    # Alpine OpenRC
    if command -v rc-service >/dev/null 2>&1; then
        rc-service xray stop 2>/dev/null || true
        rc-update del xray 2>/dev/null || true
        rc-service cloudflared stop 2>/dev/null || true
    fi

    # ---- 2. 进程（多轮、多种匹配）----
    local _i
    for _i in 1 2 3; do
        pkill -9 -f "/usr/local/bin/xray" 2>/dev/null || true
        pkill -9 -f "xray run" 2>/dev/null || true
        pkill -9 -f "/usr/local/bin/cloudflared" 2>/dev/null || true
        pkill -9 -f "cloudflared tunnel" 2>/dev/null || true
        pkill -9 -f "cloudflared" 2>/dev/null || true
        # 按命令名
        pkill -9 -x xray 2>/dev/null || true
        pkill -9 -x cloudflared 2>/dev/null || true
        # busybox ps 兜底
        ps 2>/dev/null | grep -E '[x]ray|[c]loudflared' | awk '{print $1}' | while read -r pid; do
            [[ -n $pid ]] && kill -9 "$pid" 2>/dev/null || true
        done
        sleep 0.5
    done

    # ---- 3. unit / init 脚本 ----
    rm -f /etc/systemd/system/xray.service
    rm -f /etc/systemd/system/cloudflared.service
    rm -f /etc/systemd/system/multi-user.target.wants/xray.service 2>/dev/null || true
    rm -f /etc/systemd/system/multi-user.target.wants/cloudflared.service 2>/dev/null || true
    rm -f /etc/init.d/xray /etc/init.d/cloudflared 2>/dev/null || true
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload 2>/dev/null || true
        systemctl reset-failed xray 2>/dev/null || true
        systemctl reset-failed cloudflared 2>/dev/null || true
    fi

    # ---- 4. 二进制（常见路径）----
    rm -f /usr/local/bin/xray /usr/local/bin/xray.bak
    rm -f /usr/local/bin/cloudflared
    rm -f /usr/bin/xray /usr/bin/cloudflared 2>/dev/null || true
    rm -f /bin/xray /bin/cloudflared 2>/dev/null || true
    rm -f /root/xray /root/cloudflared 2>/dev/null || true
    rm -f /root/xray.zip 2>/dev/null || true

    # ---- 5. 配置目录 ----
    rm -rf /usr/local/etc/xray
    rm -rf /etc/xray 2>/dev/null || true
    rm -rf /usr/local/share/xray 2>/dev/null || true
    rm -rf /root/.cloudflared 2>/dev/null || true
    rm -rf /etc/cloudflared 2>/dev/null || true
    rm -rf /var/log/xray 2>/dev/null || true

    # ---- 6. 临时文件 / 日志 / 导出 ----
    rm -f /tmp/xray* /tmp/cf_dl_* /tmp/cloudflared* 2>/dev/null || true
    rm -f /tmp/smart-node* /tmp/h.sh /tmp/t.json 2>/dev/null || true
    rm -f /root/smart-node-export-*.txt 2>/dev/null || true
    rm -f /root/v2ray.txt /root/xray.txt 2>/dev/null || true
    # 本脚本若落在 /root
    rm -f /root/smart-node.sh /root/smart-node-v*.sh 2>/dev/null || true

    # ---- 7. crontab 里本脚本相关行 ----
    if command -v crontab >/dev/null 2>&1; then
        local ct
        ct=$(crontab -l 2>/dev/null || true)
        if [[ -n $ct ]]; then
            echo "$ct" | grep -vE 'xray|cloudflared|smart-node' | crontab - 2>/dev/null || true
            # 再清一次保活标记
            ct=$(crontab -l 2>/dev/null || true)
            echo "$ct" | grep -v 'smart-node-keepalive' | crontab - 2>/dev/null || true
        fi
    fi

    # ---- 8. rc.local 脏行（若有）----
    if [[ -f /etc/rc.local ]]; then
        sed -i '/xray run/d;/cloudflared tunnel/d;/smart-node/d' /etc/rc.local 2>/dev/null || true
    fi

    # ---- 9. 运行时变量 ----
    UUID=""; PORT=""; PRIVATE_KEY=""; PUBLIC_KEY=""; SHORT_ID=""
    SERVER_IP=""; LEVEL=""; DEST=""; EXTRA_UUIDS=""
    NODE_MODE="argo"; ARGO_URL=""; WS_PATH=""
    FEAT_SHORT2=""; FEAT_LOGLEVEL="none"; FEAT_LISTEN="0.0.0.0"
    FEAT_EMPTY_SID=0; FEAT_BLOCK_PRIVATE=0; FEAT_BLOCK_BT=0

    success "深度清理完成（进程/二进制/配置/临时文件/crontab）"
}

uninstall_node() {
    echo
    title "========== 彻底还原（完全清理） =========="
    echo "将一次性清理（确认后不再逐项询问）："
    echo "  · 全部 xray / cloudflared 进程"
    echo "  · /usr/local/bin/xray、cloudflared 及常见路径副本"
    echo "  · /usr/local/etc/xray、备份、日志、临时文件"
    echo "  · systemd/OpenRC 服务单元"
    echo "  · crontab / rc.local 中相关行"
    echo "  · 本脚本创建的 /swapfile 与 fstab 条目"
    echo "  · sysctl 中 smart-node / BBR 相关行"
    echo
    read -p "确认彻底还原？输入 y 继续 (y/N): " confirm
    [[ $confirm != "y" && $confirm != "Y" ]] && return

    info "开始彻底清理..."
    purge_all

    # Swap
    swapoff /swapfile 2>/dev/null || true
    swapoff -a 2>/dev/null || true
    # 只删本脚本常用的 /swapfile，避免误伤其它 swap 设备名
    if [[ -f /swapfile ]]; then
        rm -f /swapfile
        success "已删除 /swapfile"
    fi
    if [[ -f /etc/fstab ]]; then
        sed -i '/\/swapfile/d' /etc/fstab 2>/dev/null || true
    fi

    # sysctl 标记行
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
        success "已清理 sysctl 相关条目"
    fi
    rm -f /etc/sysctl.d/99-smart-node.conf 2>/dev/null || true

    echo
    title "========== 清理完成 =========="
    echo "残留自检（下面应为空）："
    echo "--- 进程 ---"
    ps 2>/dev/null | grep -E '[x]ray|[c]loudflared' || echo "(无)"
    echo "--- 文件 ---"
    ls /usr/local/bin/xray /usr/local/bin/cloudflared /usr/local/etc/xray 2>&1 || true
    echo "--- 端口(443) ---"
    netstat -tln 2>/dev/null | grep -E ':443|:8443' || ss -tln 2>/dev/null | grep -E ':443|:8443' || echo "(未监听)"
    echo
    success "彻底还原结束。可重新执行安装或退出脚本。"
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

    # 定位当前脚本路径（兼容 bash <(curl ...) 的 /dev/fd 场景）
    local self via_proc=0
    self=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")
    if [[ ! -f $self ]] || [[ $self == /dev/fd/* ]] || [[ $self == /proc/*/fd/* ]]; then
        via_proc=1
        if [[ -f /root/smart-node.sh ]]; then
            self="/root/smart-node.sh"
        elif [[ -f /root/smart-node-v4.2.sh ]]; then
            self="/root/smart-node-v4.2.sh"
        else
            self="/root/smart-node.sh"
        fi
        warn "当前以管道/进程替换方式运行，将写入: $self"
    fi

    local tmp="/tmp/smart-node-update-$$.sh"
    local ok=0 url
    info "正在下载最新版本..."
    for url in "${SCRIPT_RAW_MIRRORS[@]}"; do
        if curl -fsSL --connect-timeout 8 --max-time 60 -o "$tmp" "$url" --retry 2 --retry-delay 1 2>/dev/null; then
            # 简单校验：必须是 bash 脚本且包含版本标识，且体积合理
            local sz
            sz=$(wc -c < "$tmp" 2>/dev/null || echo 0)
            if head -n 1 "$tmp" | grep -q '^#!' && grep -q 'SCRIPT_VERSION=' "$tmp" && (( sz > 10000 )); then
                ok=1
                info "下载成功（来源: $url）"
                break
            fi
            rm -f "$tmp"
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
        success "脚本已更新到最新版 → $self"
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


# 无 systemd 时可选 crontab 保活（对齐免费机常用做法）
setup_keepalive() {
    echo
    title "========== crontab 保活 =========="
    if has_systemd; then
        info "已有 systemd，一般不需要 crontab 保活"
        read -p "仍要安装？(y/N): " c
        [[ $c != "y" && $c != "Y" ]] && return
    fi
    if ! command -v crontab >/dev/null 2>&1; then
        error "系统无 crontab 命令（Alpine 可: apk add cronie 或 busybox-openrc）"
        return
    fi
    load_info
    local marker="# smart-node-keepalive"
    local line
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        line="*/5 * * * * pgrep -f cloudflared >/dev/null 2>&1 || ( /usr/local/bin/xray run -c /usr/local/etc/xray/config.json >/tmp/xray-argo.log 2>&1 & /usr/local/bin/cloudflared tunnel --url http://127.0.0.1:${PORT:-30000} --no-autoupdate >/tmp/cloudflared-argo.log 2>&1 & ) ${marker}"
        # 注意：Argo 域名仍会变，保活只能拉起进程，链接需菜单14/重装刷新
        warn "Argo 保活只能保证进程在跑，临时域名变化后仍需更新客户端链接"
    else
        line="*/5 * * * * pgrep -f /usr/local/bin/xray >/dev/null 2>&1 || /usr/local/bin/xray run -c /usr/local/etc/xray/config.json >/tmp/xray.log 2>&1 & ${marker}"
    fi
    echo "将写入（每 5 分钟检查一次）："
    echo "  $line"
    echo
    echo "  1) 安装/更新保活"
    echo "  2) 移除保活"
    echo "  0) 取消"
    read -p "选择: " k
    local ct
    ct=$(crontab -l 2>/dev/null | grep -v 'smart-node-keepalive' || true)
    case $k in
        1)
            (echo "$ct"; echo "$line") | crontab -
            success "已安装 crontab 保活"
            crontab -l 2>/dev/null | grep smart-node || true
            ;;
        2)
            echo "$ct" | crontab -
            success "已移除保活"
            ;;
        *) info "已取消" ;;
    esac
}

show_menu() {
    clear
    local mem
    mem=$(get_total_mem)
    echo -e "${BLUE}================================================${NC}"
    echo -e "${BLUE}  智能内存检测 REALITY 节点脚本  v${SCRIPT_VERSION}${NC}"
    echo -e "${BLUE}  对齐主流实践 · 一键自更新 · 低内存友好${NC}"
    echo -e "${BLUE}================================================${NC}"
    echo -e "  当前总内存: ${YELLOW}${mem} MB${NC}   压力: $(get_mem_pressure_hint)"
    echo
    echo "  【安装与核心】"
    echo "  1. 智能安装节点（检测环境 + 按档开启功能）"
    echo "  2. 查看节点信息 / 分享链接 / 客户端片段 / 二维码"
    echo "  3. 导出完整节点信息到文件"
    echo "  4. 导出 Base64 订阅（多用户链接）"
    echo
    echo "  【日常管理】"
    echo "  5. 修改端口"
    echo "  6. 重新生成主 UUID"
    echo "  7. 修改伪装目标 (dest/SNI)"
    echo "  8. 重新生成 REALITY 密钥"
    echo "  9. 修改 ShortID"
    echo " 10. 添加用户（多 UUID，受内存档位限制）"
    echo " 11. 删除用户"
    echo
    echo "  【运维与诊断】"
    echo " 12. 简易连通性自检（含 dest 探测）"
    echo " 13. 查看最近日志"
    echo " 14. 重启服务"
    echo " 15. 查看运行状态 + 内存"
    echo " 16. 启用 BBR"
    echo " 17. 更新 Xray 内核"
    echo " 18. 一键系统参数优化（低内存友好）"
    echo
    echo "  【高级】"
    echo " 19. 智能分流建议"
    echo " 20. 全功能脚本引导（第三方，需确认）"
    echo " 21. 彻底还原（完全清理）"
    echo " 22. 更新本脚本（自更新）"
    echo
    echo "  0. 退出"
    echo
    echo -e "${BLUE}================================================${NC}"
}

while true; do
    show_menu
    read -p "请输入选项 [0-22]: " choice
    case $choice in
        1)  install_node ;;
        2)  show_link ;;
        3)  export_node_info ;;
        4)  export_subscription ;;
        5)  change_port ;;
        6)  change_uuid ;;
        7)  change_dest ;;
        8)  regenerate_keys ;;
        9)  change_shortid ;;
        10) add_user ;;
        11) remove_user ;;
        12) self_check ;;
        13) show_recent_logs ;;
        14) restart_xray ;;
        15) status_xray ;;
        16) enable_bbr ;;
        17) update_xray ;;
        18) optimize_sysctl ;;
        19) smart_route_advice; read -p "按回车返回..." ;;
        20) run_full_script_menu ;;
        21) uninstall_node ;;
        22) update_script ;;
        0)  echo "退出"; exit 0 ;;
        *)  warn "无效选项" ;;
    esac
    echo
    read -p "按回车键返回菜单..."
done
