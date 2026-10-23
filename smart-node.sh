#!/bin/bash
# ============================================================
# 智能内存检测 + 交互式 VLESS + REALITY 节点脚本
# v5.2.1  检修：固定隧道提示区分 Quick、rm 引号、停止进程匹配
# v5.2.0  全方位审计打磨：修 load_info 误清映射口、安装校验、菜单与文案体验
# v5.1.7  支持先填面板已映射端口，脚本优先采用；并自动探测疑似已映射口
# v5.1.6  NAT 小鸡默认需面板映射：文案与引导对齐；REALITY 明确「选口+去映射」
# v5.1.5  深度审计：端口探测加速/逻辑修正、交互与残留提示打磨
# v5.1.4  REALITY 自动选用本机空闲的常用/易放行端口，减少面板再映射
# v5.1.3  多轮审计修：接入方式误入 REALITY、状态/命名隧道、残留提示
# v5.1.2  一键清干净全部下载物 + 交互全中文
# v5.1.1  交互优化 + 增强一键删除 + CLI 无交互卸载
# v5.1.0  全方位优化：固定隧道 / 沿用 UUID / 防火墙补回 / Alpine sed / 查漏补缺
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
#
# v5.0.0 修复与增强（本次大修）：
#   [Bug] 内存检测在 Alpine/BusyBox 上误读（free 无 available 列 → 可用内存判 0，
#         进而把 2GB 机器判成 64MB 极限机，错配 MemoryMax=45M 把 Xray 卡死）
#         → 改为优先读 /proc/meminfo(MemAvailable)，free 仅兜底
#   [Bug] 无 free 命令的机器总内存判 0 → 直接落入 extreme 档 → 已修
#   [Bug] 可用内存 <80MB 即判 extreme（不看总内存）→ 已改为按总量+可用综合判定
#   [Bug] 重装时 purge_all 把脚本自己和备份目录一起删了 → 已保留
#   [Bug] 彻底还原执行 swapoff -a 会关掉用户自己的全部 Swap → 只关 /swapfile
#   [Bug] 自更新用 cp 覆盖正在运行的脚本，会读到半截文件导致脚本崩 → 改 mv 原子替换
#   [Bug] Argo 域名解析用 head -1，进程重连后拿到旧域名 → 改 tail -1
#   [Bug] Argo 域名从日志恢复后不写回 node.info，下次又丢 → 已自动写回
#   [Bug] 改端口/UUID/密钥/ShortID 写配置失败仍继续重启 → 全部补中断
#   [Bug] cloudflared 默认走 QUIC，部分 VPS 上 UDP 不通直接建不起隧道
#         → 增加 http2 / IPv4 自动回退，失败逐级降级并给出人话原因
#   [Bug] 无 ss/netstat 时端口检测恒定返回"空闲"→ 改读 /proc/net/tcp 兜底
#   [Bug] sysctl 优化只整行去重，同键不同值会叠加 → 改为按 key 去重
#   [Bug] 保活脚本可能拉起多份进程 → 加单实例锁 + 域名变化回写
#   [新] 菜单新增「刷新 Argo 域名」，域名变了不用重装
#   [新] 重装时可选沿用原 UUID / WS 路径，客户端不用重新导入
#   [新] 非交互 stdin（curl | bash）时自动切到 /dev/tty 读输入
#   [新] 非 bash 启动（sh xxx.sh）自动用 bash 重启自己
#   [新] 菜单与输出针对手机屏幕精简，关键信息置顶
#   [新] Xray 配置校验失败时不再盲启动，直接给原因
#
# v5.1.0 修复与增强：
#   [Bug] 补回 open_firewall（v5.0 回归丢失，REALITY 安装/改端口会 command not found）
#   [Bug] 「重装沿用 UUID/路径」此前只是重启，现真正支持重装时复用
#   [Bug] Alpine BusyBox sed -i 无后缀失败 → 统一 safe_sed / 临时文件替换
#   [Bug] purge_all 重装时 crontab 过滤过宽（误伤用户其它 xray 相关任务）
#   [Bug] require_reality 提示未含菜单 24；Argo 安装成功文案过时
#   [Bug] 有 ss/netstat 时端口检测不区分 LISTEN → 优先 /proc 的 LISTEN 判定
#   [新] Cloudflare 固定隧道（Token 命名隧道）：域名持久，进程重启不换域名
#   [新] 安装三选一：Quick Argo / 固定隧道 / REALITY
#   [新] 菜单 25 更新固定隧道 Token / 域名
#   [新] node.info 权限 600；Token 仅存本地
#   [新] 保活同时覆盖 quick / named / reality
# ============================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
# 输出不是终端时（导出文件、被重定向、cron）不要颜色码，
# 否则导出的 txt 里全是 [0;32m 这种乱码，手机上根本没法看
if [[ ! -t 1 ]]; then
    RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
fi

CONFIG_DIR="/usr/local/etc/xray"
CONFIG_FILE="${CONFIG_DIR}/config.json"
SERVICE_FILE="/etc/systemd/system/xray.service"
INFO_FILE="${CONFIG_DIR}/node.info"
BACKUP_DIR="${CONFIG_DIR}/backup"
XRAY_BIN="/usr/local/bin/xray"
CLOUDFLARED_BIN="/usr/local/bin/cloudflared"
ARGO_LOG="/tmp/cloudflared-argo.log"
XRAY_LOG="/tmp/xray-argo.log"
ARGO_PIDFILE="/tmp/smart-node-cloudflared.pid"
XRAY_PIDFILE="/tmp/smart-node-xray.pid"
NODE_MODE="argo"
# TUNNEL_TYPE: quick=临时 trycloudflare | named=固定 Token 隧道 | (reality 时为空)
TUNNEL_TYPE="quick"
CF_TOKEN=""
FIXED_HOST=""
ARGO_URL=""
WS_PATH=""
SCRIPT_VERSION="5.2.1"
SCRIPT_DATE="2026-10-23"
KEEPALIVE_HELPER="/usr/local/bin/smart-node-keepalive"
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

info()    { echo -e "${GREEN}[信息]${NC} $1"; }
warn()    { echo -e "${YELLOW}[警告]${NC} $1"; }
error()   { echo -e "${RED}[错误]${NC} $1"; }
success() { echo -e "${GREEN}[完成]${NC} $1"; }
title()   { echo -e "${CYAN}$1${NC}"; }

# ======================== 启动兼容层 ========================
# 1) 必须 bash（本脚本用到 [[ ]] / 数组 / local / (( ))，dash、ash 会直接崩）
if [[ -z ${BASH_VERSION:-} ]]; then
    if command -v bash >/dev/null 2>&1; then
        exec bash "$0" "$@"
    else
        echo "[错误] 需要 bash，本机没有。Alpine 请先执行: apk add bash"
        exit 1
    fi
fi

# 2) 非交互 stdin（典型: curl xxx | bash / bash <(curl xxx) 在某些终端下 stdin 被占）
#    此时 read 会读到脚本内容而不是用户输入，表现为"菜单自己往下跑"。
#    有 /dev/tty 就把它接过来。
if [[ ! -t 0 ]] && [[ -r /dev/tty ]]; then
    exec < /dev/tty 2>/dev/null || true
fi

# 3) clear 在部分手机 SSH / 精简系统上不存在或不支持，别让它污染输出
safe_clear() {
    command -v clear >/dev/null 2>&1 && clear 2>/dev/null
    return 0
}

# Alpine/BusyBox 兼容的 sed 原地替换（不依赖 sed -i 后缀行为）
# 用法: safe_sed 's/foo/bar/' /path/to/file
#       safe_sed '/pattern/d' /path/to/file
safe_sed() {
    local expr=$1 file=$2
    [[ -f $file ]] || return 1
    local tmp
    tmp=$(mktemp "${file}.sn.XXXXXX" 2>/dev/null || echo "${file}.sn.$$")
    if sed "$expr" "$file" > "$tmp" 2>/dev/null; then
        mv -f "$tmp" "$file"
        return 0
    fi
    rm -f "$tmp" 2>/dev/null
    return 1
}

# 多表达式删除（用于清理 sysctl/fstab 等）
safe_sed_multi() {
    local file=$1; shift
    [[ -f $file ]] || return 1
    local tmp expr
    tmp=$(mktemp "${file}.sn.XXXXXX" 2>/dev/null || echo "${file}.sn.$$")
    cp -f "$file" "$tmp" || { rm -f "$tmp"; return 1; }
    for expr in "$@"; do
        sed "$expr" "$tmp" > "${tmp}.2" 2>/dev/null || { rm -f "$tmp" "${tmp}.2"; return 1; }
        mv -f "${tmp}.2" "$tmp"
    done
    mv -f "$tmp" "$file"
    return 0
}

[[ $EUID -ne 0 ]] && { error "请使用 root 用户运行"; exit 1; }

# ======================== 系统与内存检测 ========================

# 从 /proc/meminfo 取一个字段（单位 KB）。BusyBox / 精简系统一定有这个文件，
# 而 free 命令经常没装、或者没有 available 列，是历史误判的根源。
_meminfo_kb() {
    local key=$1
    local v
    v=$(awk -v k="$key" '$1==k":"{print $2; exit}' /proc/meminfo 2>/dev/null)
    [[ $v =~ ^[0-9]+$ ]] || v=0
    echo "$v"
}

# 总内存(MB)
get_total_mem() {
    if [[ -n $_CACHE_TOTAL_MEM ]]; then
        echo "$_CACHE_TOTAL_MEM"
        return
    fi
    local kb
    kb=$(_meminfo_kb MemTotal)
    if (( kb > 0 )); then
        _CACHE_TOTAL_MEM=$(( kb / 1024 ))
    else
        local m
        m=$(free -m 2>/dev/null | awk '/^Mem:/{print $2; exit}')
        [[ $m =~ ^[0-9]+$ ]] || m=0
        _CACHE_TOTAL_MEM=$m
    fi
    echo "${_CACHE_TOTAL_MEM:-0}"
}

# 可用内存(MB)：MemAvailable 优先；老内核没有就用 MemFree+Buffers+Cached 估算；
# 最后才退回 free 命令。绝不拿 "$4"（BusyBox 的第 4 列是 shared，常为 0）当可用。
get_available_mem() {
    if [[ -n $_CACHE_AVAIL_MEM ]]; then
        echo "$_CACHE_AVAIL_MEM"
        return
    fi
    local kb avail
    kb=$(_meminfo_kb MemTotal)
    if (( kb > 0 )); then
        avail=$(_meminfo_kb MemAvailable)
        if (( avail <= 0 )); then
            avail=$(( $(_meminfo_kb MemFree) + $(_meminfo_kb Buffers) + $(_meminfo_kb Cached) ))
        fi
        _CACHE_TOTAL_MEM=$(( kb / 1024 ))
        _CACHE_AVAIL_MEM=$(( avail / 1024 ))
    else
        local t
        t=$(free -m 2>/dev/null | awk '/^Mem:/{print $2; exit}')
        [[ $t =~ ^[0-9]+$ ]] || t=0
        _CACHE_TOTAL_MEM=$t
        # 连 meminfo 都读不到的环境下没法精确判断，按总量一半保守估
        _CACHE_AVAIL_MEM=$(( t / 2 ))
    fi
    echo "${_CACHE_AVAIL_MEM:-0}"
}

# 已有 Swap(MB)
get_swap_total_mem() {
    local kb
    kb=$(_meminfo_kb SwapTotal)
    if (( kb > 0 )); then
        echo $(( kb / 1024 )); return
    fi
    awk '/^SwapTotal:/{printf "%d", $2/1024}' /proc/meminfo 2>/dev/null || echo 0
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
        warn "当前是隧道模式（Argo/固定隧道），此功能仅 REALITY 可用"
        warn "请使用：菜单 2 看链接 / 14 重启 / 24 刷新域名 / 25 改固定隧道 / 1 重装 / 21 彻底清理"
        return 1
    fi
    return 0
}

# 是否隧道类模式（quick 临时 或 named 固定）
is_tunnel_mode() {
    [[ ${NODE_MODE:-} == "argo" ]]
}

is_named_tunnel() {
    load_info 2>/dev/null || true
    [[ ${NODE_MODE:-} == "argo" && ${TUNNEL_TYPE:-quick} == "named" ]]
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

    swap_total=$(get_swap_total_mem)
    [[ -z $swap_total ]] && swap_total=0
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

    # 档位按「总内存」定，不要按「当前可用」杀档：
    # 以前只要可用 <80MB 就把整机当成 64MB 极限机（2G 机器跑着别的东西也会中招），
    # 结果给它套 MemoryMax=45M，Xray 被 systemd 反复杀，表现为"节点时好时坏"。
    local effective=$TOTAL_MEM
    if (( TOTAL_MEM <= 0 )); then
        effective=256   # 读不到总内存时按中低配处理，宁可保守也别误判成极限
    elif (( TOTAL_MEM < 256 && AVAIL_MEM > 0 && AVAIL_MEM < TOTAL_MEM / 2 )); then
        # 内存本来就小、且已被占掉一半以上，才按可用量降档
        effective=$(( AVAIL_MEM + TOTAL_MEM / 4 ))
        (( effective < 48 )) && effective=48
    fi
    if [[ -n $heavy_hint ]] && (( effective <= 512 )); then
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

    # 总内存够大但可用被吃光：这是"别的进程占着"，不是机器小，单独提示
    if (( TOTAL_MEM >= 512 && AVAIL_MEM > 0 && AVAIL_MEM < 96 )); then
        ADVICE="${ADVICE}；注意：总内存 ${TOTAL_MEM}MB 但可用仅剩 ${AVAIL_MEM}MB，先停掉占内存的进程再装"
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

# 读内核表判断某端口是否在监听（十六进制比对，不依赖 ss/netstat）
_port_listening() {
    local port=$1 hex f
    [[ $port =~ ^[0-9]+$ ]] || return 1
    # 10# 前缀：避免 0443 这种被当成八进制
    hex=$(printf '%04X' "$((10#$port))" 2>/dev/null) || return 1
    for f in /proc/net/tcp /proc/net/tcp6; do
        [[ -r $f ]] || continue
        # 只看 LISTEN(0A)。不筛状态的话，本机随便一条外连占用的临时端口
        # （Linux 默认 32768-60999）会被当成"端口被占用"，安装时白换端口。
        if awk -v hex="$hex" '
                NR>1 && $4=="0A" && substr($2, length($2)-3) == hex { found=1 }
                END { exit(found?0:1) }
            ' "$f" 2>/dev/null; then
            return 0
        fi
    done
    return 1
}

check_port_free() {
    local port=$1
    [[ $port =~ ^[0-9]+$ ]] || return 0
    # 优先 /proc LISTEN 判定，避免把已建立连接的临时端口误判为占用
    if _port_listening "$port"; then
        return 1
    fi
    if command -v ss >/dev/null 2>&1; then
        # -l 只看监听
        ss -tln 2>/dev/null | grep -qE "[:.]${port}[[:space:]]" && return 1
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tln 2>/dev/null | grep -qE "[:.]${port}[[:space:]]" && return 1
    fi
    return 0
}

# NAT 小鸡常见可映射端口（自动探测时的候选池）
PREFERRED_PORTS=(
    443 80 8080 8443
    2053 2083 2087 2096
    2052 2082 2086 2095 8880
    8444 8888 9000 9443
    10000 10443 18080 18443
)

# 用户在面板已映射、安装前填入的端口（空格分隔），优先使用
USER_MAPPED_PORTS=()

# 探测公网是否已能打到本机该端口（NAT 回流，仅作参考）
# 返回 0=可能已映射  1=不确定
_probe_public_port() {
    local port=$1 ip out ec
    ip=${_CACHE_IP:-$(get_ip)}
    [[ -z $ip || -z $port ]] && return 1
    if command -v timeout >/dev/null 2>&1; then
        out=$(timeout 1 bash -c "echo >/dev/tcp/${ip}/${port}" 2>&1)
        ec=$?
    else
        out=$(bash -c "echo >/dev/tcp/${ip}/${port}" 2>&1)
        ec=$?
    fi
    if (( ec == 0 )); then
        return 0
    fi
    if echo "$out" | grep -qiE 'refused|reset|连接被拒绝'; then
        return 0
    fi
    return 1
}

# 解析用户输入的端口列表 → USER_MAPPED_PORTS（去重、合法、尽量本机可绑）
parse_user_mapped_ports() {
    local raw=$1
    USER_MAPPED_PORTS=()
    [[ -z $raw ]] && return 0
    local p seen="|"
    for p in $raw; do
        p=$(echo "$p" | tr -d '[:space:],;，、')
        [[ $p =~ ^[0-9]+$ ]] || continue
        (( p < 1 || p > 65535 )) && continue
        [[ $seen == *"|$p|"* ]] && continue
        seen="${seen}${p}|"
        USER_MAPPED_PORTS+=("$p")
    done
}

# 安装前询问：你已在面板映射了哪些口？
ask_user_mapped_ports() {
    USER_MAPPED_PORTS=()
    echo
    title "---------- 已映射端口（可先填） ----------"
    echo "若你已在 NAT 面板随机映射了几个端口，请填在下面（空格分隔）。"
    echo "脚本会优先用这些口搭 REALITY；本机已被占用的会跳过并提示。"
    echo "直接回车 = 不填，改为自动探测常用口是否像已映射。"
    echo
    read -p "已映射端口（例: 23456 34567 443）: " _ump
    parse_user_mapped_ports "${_ump:-}"
    if (( ${#USER_MAPPED_PORTS[@]} > 0 )); then
        local ok=() bad=() p
        for p in "${USER_MAPPED_PORTS[@]}"; do
            if check_port_free "$p"; then
                ok+=("$p")
            else
                bad+=("$p")
            fi
        done
        USER_MAPPED_PORTS=("${ok[@]}")
        if (( ${#ok[@]} > 0 )); then
            success "将优先使用本机空闲且你已声明映射的端口: ${ok[*]}"
        fi
        if (( ${#bad[@]} > 0 )); then
            warn "这些口本机已被占用，已跳过: ${bad[*]}"
        fi
        if (( ${#USER_MAPPED_PORTS[@]} == 0 )); then
            warn "声明的端口均不可用，将改为自动探测/推荐"
        fi
    else
        info "未填写，将自动探测常用口是否像已映射"
    fi
    echo -e "${CYAN}----------------------------------------------${NC}"
}

scan_usable_ports() {
    CANDIDATE_PORTS=()
    MAPPED_PORTS=()
    local p n=0
    get_ip >/dev/null

    # 1) 用户声明的已映射口（本机空闲）→ 最高优先级
    for p in "${USER_MAPPED_PORTS[@]}"; do
        check_port_free "$p" || continue
        CANDIDATE_PORTS+=("$p")
        MAPPED_PORTS+=("$p")
    done

    # 2) 常用口本机空闲
    for p in "${PREFERRED_PORTS[@]}"; do
        check_port_free "$p" || continue
        local dup=0 q
        for q in "${CANDIDATE_PORTS[@]}"; do
            [[ $q == "$p" ]] && dup=1 && break
        done
        (( dup )) && continue
        CANDIDATE_PORTS+=("$p")
    done

    # 3) 对「尚未标为已映射」的候选做少量公网探测
    for p in "${CANDIDATE_PORTS[@]}"; do
        (( n >= 8 )) && break
        local already=0 q
        for q in "${MAPPED_PORTS[@]}"; do
            [[ $q == "$p" ]] && already=1 && break
        done
        (( already )) && continue
        if _probe_public_port "$p"; then
            MAPPED_PORTS+=("$p")
        fi
        n=$((n + 1))
    done
}

auto_select_port() {
    AUTO_PORT=""
    AUTO_PORT_HINT=""
    scan_usable_ports

    # 优先：用户声明或探测像已映射
    if (( ${#MAPPED_PORTS[@]} > 0 )); then
        AUTO_PORT=${MAPPED_PORTS[0]}
        # 是否来自用户声明
        local from_user=0 p
        for p in "${USER_MAPPED_PORTS[@]}"; do
            [[ $p == "$AUTO_PORT" ]] && from_user=1 && break
        done
        if (( from_user )); then
            AUTO_PORT_HINT="你在面板声明已映射，优先使用"
        else
            AUTO_PORT_HINT="自动探测像已映射，优先使用（建议在面板再确认）"
        fi
        return 0
    fi
    if (( ${#CANDIDATE_PORTS[@]} > 0 )); then
        local prefer p
        for prefer in 443 80 8080 8443 2053 2083 2087 2096; do
            for p in "${CANDIDATE_PORTS[@]}"; do
                if [[ $p == "$prefer" ]]; then
                    AUTO_PORT=$p
                    AUTO_PORT_HINT="本机空闲，装完请在面板映射 TCP ${p}"
                    return 0
                fi
            done
        done
        AUTO_PORT=${CANDIDATE_PORTS[0]}
        AUTO_PORT_HINT="本机空闲，装完请在面板映射 TCP ${AUTO_PORT}"
        return 0
    fi

    local try=0
    AUTO_PORT=$((20000 + RANDOM % 40000))
    while ! check_port_free "$AUTO_PORT" && (( try < 30 )); do
        AUTO_PORT=$((20000 + RANDOM % 40000))
        try=$((try + 1))
    done
    AUTO_PORT_HINT="已选高位口，装完必须在面板映射 TCP ${AUTO_PORT}"
    return 0
}

pick_listen_port() {
    local suggested=$1
    # 若还没问过已映射口，先问一次
    if [[ ${USER_MAPPED_ASKED:-0} -ne 1 ]]; then
        ask_user_mapped_ports
        USER_MAPPED_ASKED=1
    fi
    info "正在匹配可用端口…"
    auto_select_port
    [[ -n $suggested ]] && AUTO_PORT=$suggested

    echo
    title "---------- REALITY 监听端口 ----------"
    warn "NAT 小鸡：REALITY 依赖面板端口映射；Argo/固定隧道不需要映射。"
    if (( ${#USER_MAPPED_PORTS[@]} > 0 )); then
        echo -e "  你声明已映射: ${GREEN}${USER_MAPPED_PORTS[*]}${NC}"
    fi
    if (( ${#MAPPED_PORTS[@]} > 0 )); then
        echo -e "  优先采用（声明/探测）: ${GREEN}${MAPPED_PORTS[*]}${NC}"
    fi
    if (( ${#CANDIDATE_PORTS[@]} > 0 )); then
        local show=("${CANDIDATE_PORTS[@]:0:12}")
        echo "  本机空闲候选: ${show[*]}"
    fi
    echo -e "  将使用: ${YELLOW}${AUTO_PORT}${NC}  — ${AUTO_PORT_HINT}"
    echo
    read -p "回车使用 ${AUTO_PORT}，或输入其它端口: " custom_port
    custom_port=$(echo "${custom_port:-}" | tr -d '[:space:]')
    if [[ -n $custom_port ]]; then
        if ! [[ $custom_port =~ ^[0-9]+$ ]] || (( custom_port < 1 || custom_port > 65535 )); then
            error "端口无效，改用 ${AUTO_PORT}"
        else
            AUTO_PORT=$custom_port
            AUTO_PORT_HINT="用户指定"
        fi
    fi
    if ! check_port_free "$AUTO_PORT"; then
        warn "端口 $AUTO_PORT 本机似乎已被占用，仍将继续"
    fi
    echo
    # 若选用的口已在「已映射」列表，弱化警告；否则强调去映射
    local mapped=0 p
    for p in "${MAPPED_PORTS[@]}" "${USER_MAPPED_PORTS[@]}"; do
        [[ $p == "$AUTO_PORT" ]] && mapped=1 && break
    done
    if (( mapped )); then
        info "已选 ${AUTO_PORT}（按你的声明/探测，应已在面板映射）。装完用客户端测一下即可。"
    else
        echo -e "${YELLOW}请到面板确认端口映射：${NC} 外网端口 → 内网 ${YELLOW}${AUTO_PORT}${NC}/TCP"
    fi
    echo -e "${CYAN}----------------------------------------------${NC}"
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
    local cur_swap
    cur_swap=$(get_swap_total_mem 2>/dev/null || echo 0)
    if (( cur_swap > 0 )); then
        info "已存在 Swap（约 ${cur_swap}MB），跳过创建"
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
    [[ -x $XRAY_BIN ]] && rm -f "$XRAY_BIN"

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

# 从日志里取最新的 trycloudflare 域名。
# 注意用 tail -1：cloudflared 在边缘重建时会打印新域名，
# 老版本取 head -1 会一直拿到最早的旧域名，表现为"链接能看不能用"。
_argo_parse_url() {
    local f=${1:-$ARGO_LOG}
    [[ -f $f ]] || return 1
    grep -oE 'https://[a-zA-Z0-9][a-zA-Z0-9.-]*\.trycloudflare\.com' "$f" 2>/dev/null | tail -n 1
}

# 停掉本脚本拉起的 Argo 进程（按 pidfile + 精确路径，不误伤别家 xray/cloudflared）
stop_argo_stack() {
    local quiet=${1:-} p f
    for f in "$ARGO_PIDFILE" "$XRAY_PIDFILE"; do
        [[ -f $f ]] || continue
        p=$(cat "$f" 2>/dev/null)
        [[ $p =~ ^[0-9]+$ ]] && kill "$p" 2>/dev/null
        rm -f "$f"
    done
    pkill -f "$XRAY_BIN" 2>/dev/null || true
    pkill -f "$CLOUDFLARED_BIN" 2>/dev/null || true
    pkill -f "cloudflared tunnel" 2>/dev/null || true
    sleep 1
    [[ $quiet == quiet ]] || info "已停止 Argo 进程"
    return 0
}

# 把日志里的最新域名写回 node.info。进程重连换了域名时，
# 菜单 2 / 自检 / 订阅都能立刻看到新链接，不用重装。
# 返回: 0=域名已更新 1=拿不到域名 2=没变化
refresh_argo_url() {
    local quiet=${1:-} cur new
    load_info
    [[ ${NODE_MODE:-} == "argo" ]] || return 1
    cur=${ARGO_URL:-}
    new=$(_argo_parse_url "$ARGO_LOG")
    new=${new#https://}
    [[ -z $new ]] && return 1
    if [[ $new == "$cur" ]]; then
        ARGO_URL=$new
        return 2
    fi
    ARGO_URL=$new
    if [[ -f $INFO_FILE ]]; then
        if grep -q '^ARGO_URL=' "$INFO_FILE" 2>/dev/null; then
            safe_sed "s|^ARGO_URL=.*|ARGO_URL=${new}|" "$INFO_FILE" 2>/dev/null || true
        else
            echo "ARGO_URL=${new}" >> "$INFO_FILE"
        fi
    fi
    if [[ $quiet != quiet ]]; then
        [[ -n $cur ]] && warn "Argo 域名已变化：${cur} → ${new}" || success "已获取 Argo 域名: ${new}"
        warn "域名变了客户端必须重新导入链接（菜单 2）"
    fi
    return 0
}

start_argo_stack() {
    local port=$1
    ARGO_PIDFILE="/tmp/smart-node-cloudflared.pid"
    XRAY_PIDFILE="/tmp/smart-node-xray.pid"

    stop_argo_stack quiet
    sleep 1

    # 1) 先上 Xray（只监听 127.0.0.1）
    nohup "$XRAY_BIN" run -c "$CONFIG_FILE" >"$XRAY_LOG" 2>&1 &
    echo $! > "$XRAY_PIDFILE"
    sleep 1
    if ! proc_alive "$XRAY_BIN" && ! _port_listening "$port"; then
        error "Xray 启动失败，日志最后几行："
        tail -15 "$XRAY_LOG" 2>/dev/null || true
        return 1
    fi

    # 2) 再上隧道。默认 QUIC，但很多 VPS 的 UDP 出不去，
    #    这时 cloudflared 会一直卡在 "Initial connection"，
    #    所以必须能自动降级到 http2 / 强制 IPv4，而不是死等 30 秒报失败。
    local tries attempt label opts i url has_eip=0
    # 老版本 cloudflared 没有 --edge-ip-version，先探测再用，否则这一档会直接报参数错
    if $CLOUDFLARED_BIN tunnel --help 2>&1 | grep -q -- '--edge-ip-version'; then
        has_eip=1
    fi
    tries=(
        "quic|--protocol quic"
        "http2|--protocol http2"
    )
    (( has_eip == 1 )) && tries+=("http2+ipv4|--protocol http2 --edge-ip-version 4")
    for attempt in "${tries[@]}"; do
        label=${attempt%%|*}
        opts=${attempt#*|}
        : > "$ARGO_LOG"
        info "启动隧道（传输方式: ${label}）..."
        # shellcheck disable=SC2086
        nohup $CLOUDFLARED_BIN tunnel --url "http://127.0.0.1:${port}" --no-autoupdate $opts >"$ARGO_LOG" 2>&1 &
        echo $! > "$ARGO_PIDFILE"
        url=""
        for i in $(seq 1 22); do
            sleep 1
            url=$(_argo_parse_url "$ARGO_LOG")
            [[ -n $url ]] && break
            # 进程已经退出就别傻等
            if ! kill -0 "$(cat "$ARGO_PIDFILE" 2>/dev/null)" 2>/dev/null; then
                break
            fi
        done
        if [[ -n $url ]]; then
            ARGO_URL=${url#https://}
            success "隧道已建立（${label}）: $ARGO_URL"
            return 0
        fi
        warn "传输方式 ${label} 未能建立，换下一种重试..."
        kill "$(cat "$ARGO_PIDFILE" 2>/dev/null)" 2>/dev/null || true
        rm -f "$ARGO_PIDFILE"
        sleep 1
    done

    error "隧道建立失败，日志最后几行："
    tail -20 "$ARGO_LOG" 2>/dev/null || true
    error "常见原因：本机 UDP/443 与 7844 出不去（换 http2 也不行就是机房封锁）"
    error "         或 Cloudflare 免费隧道临时不可用，过几分钟再试"
    return 1
}

# ---------- 固定隧道（Cloudflare Named Tunnel + Token）----------
# 用户在 Zero Trust 控制台创建隧道并配置 Public Hostname → http://127.0.0.1:PORT
# 脚本只负责：本机 VLESS-WS + cloudflared tunnel run --token
# 域名由用户在 CF 绑定，进程重启不会变。

start_named_stack() {
    local port=$1 token=$2
    ARGO_PIDFILE="/tmp/smart-node-cloudflared.pid"
    XRAY_PIDFILE="/tmp/smart-node-xray.pid"

    [[ -z $token ]] && { error "缺少 Cloudflare Tunnel Token"; return 1; }
    stop_argo_stack quiet
    sleep 1

    nohup "$XRAY_BIN" run -c "$CONFIG_FILE" >"$XRAY_LOG" 2>&1 &
    echo $! > "$XRAY_PIDFILE"
    sleep 1
    if ! proc_alive "$XRAY_BIN" && ! _port_listening "$port"; then
        error "Xray 启动失败，日志最后几行："
        tail -15 "$XRAY_LOG" 2>/dev/null || true
        return 1
    fi

    : > "$ARGO_LOG"
    info "启动固定隧道（cloudflared tunnel run --token）..."
    # Token 模式不走 --url，由 CF 控制台配置的 Public Hostname 决定域名
    nohup "$CLOUDFLARED_BIN" tunnel --no-autoupdate run --token "$token" >"$ARGO_LOG" 2>&1 &
    echo $! > "$ARGO_PIDFILE"

    local i ok=0
    for i in $(seq 1 20); do
        sleep 1
        if ! kill -0 "$(cat "$ARGO_PIDFILE" 2>/dev/null)" 2>/dev/null; then
            break
        fi
        # 常见成功特征：Registered tunnel connection / Connection registered
        if grep -qiE 'Registered tunnel connection|Connection registered|Tunnel is running|Connected to' "$ARGO_LOG" 2>/dev/null; then
            ok=1
            break
        fi
        # 明确失败
        if grep -qiE 'Unauthorized|invalid token|failed to|Unable to call' "$ARGO_LOG" 2>/dev/null; then
            break
        fi
    done

    if (( ok == 1 )) || proc_alive "$CLOUDFLARED_BIN"; then
        if (( ok == 1 )); then
            success "固定隧道已连接"
        else
            warn "cloudflared 进程在跑，但未捕获到注册成功日志，请菜单 13 看日志确认"
        fi
        return 0
    fi

    error "固定隧道启动失败，日志最后几行："
    tail -25 "$ARGO_LOG" 2>/dev/null || true
    error "请检查：Token 是否完整、是否从 Zero Trust → Networks → Tunnels 复制"
    error "         Public Hostname 是否指向 http://127.0.0.1:${port}"
    return 1
}

# 更新固定隧道 Token / 域名（菜单 25）
update_named_tunnel() {
    load_info
    if [[ ${NODE_MODE:-} != "argo" ]]; then
        warn "当前不是隧道模式"
        return
    fi
    echo
    title "========== 固定隧道设置 =========="
    echo "当前类型: ${TUNNEL_TYPE:-quick}"
    echo "当前域名: ${FIXED_HOST:-${ARGO_URL:-（空）}}"
    [[ -n $CF_TOKEN ]] && echo "Token   : 已保存（${#CF_TOKEN} 字符，仅显示长度）" || echo "Token   : 未设置"
    echo
    echo "  1) 配置/更新固定隧道（Token + 域名）并重启"
    echo "  2) 仅修改展示域名（不重跑隧道）"
    echo "  3) 从固定隧道退回 Quick 临时隧道（需重装更干净）"
    echo "  0) 取消"
    read -p "选择: " c
    case $c in
        1)
            echo
            info "在 Cloudflare Zero Trust → Networks → Tunnels 创建隧道，"
            info "安装方式选 Token，复制整段 Token；并添加 Public Hostname"
            info "指向 http://127.0.0.1:${PORT:-本机端口}"
            echo
            read -p "粘贴 Tunnel Token: " new_token
            new_token=$(echo "$new_token" | tr -d '[:space:]')
            [[ -z $new_token ]] && { error "Token 为空"; return; }
            read -p "固定域名（如 node.example.com，用于生成链接）: " new_host
            new_host=$(echo "$new_host" | tr -d '[:space:]' | sed 's|^https\\?://||;s|/$||')
            [[ -z $new_host ]] && { error "域名为空"; return; }
            CF_TOKEN=$new_token
            FIXED_HOST=$new_host
            ARGO_URL=$new_host
            TUNNEL_TYPE="named"
            NODE_MODE="argo"
            if [[ ! -s $CONFIG_FILE ]]; then
                write_config_argo "$UUID" "$PORT" "${WS_PATH:-/argo}" || return
            fi
            start_named_stack "$PORT" "$CF_TOKEN" || return
            save_info "$UUID" "$PORT" "" "" "" "${SERVER_IP:-$(get_ip)}" "${LEVEL:-argo}" ""
            success "固定隧道已更新"
            show_link
            ;;
        2)
            read -p "新展示域名: " new_host
            new_host=$(echo "$new_host" | tr -d '[:space:]' | sed 's|^https\\?://||;s|/$||')
            [[ -z $new_host ]] && return
            FIXED_HOST=$new_host
            ARGO_URL=$new_host
            TUNNEL_TYPE=${TUNNEL_TYPE:-named}
            save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "$DEST"
            success "展示域名已改为 $new_host"
            show_link
            ;;
        3)
            warn "退回 Quick 需重新安装更干净。建议菜单 1 重装并选 Quick。"
            ;;
        *) info "已取消" ;;
    esac
}

# path 仅保留安全字符，链接里用原 path（客户端一般支持 /path）
build_argo_link() {
    local uid=${1:-$UUID} host=${2:-$ARGO_URL} path=${3:-$WS_PATH}
    host=${host#https://}
    host=${host#http://}
    host=${host%%/*}
    [[ -z $host ]] && return 1
    [[ -z $uid ]] && return 1
    [[ -z $path ]] && path="/argo"
    [[ $path == /* ]] || path="/$path"
    echo "vless://${uid}@${host}:443?encryption=none&security=tls&type=ws&host=${host}&path=${path}&sni=${host}&fp=chrome#智能隧道-${host%%.*}"
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
    mkdir -p "$CONFIG_DIR"
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
TUNNEL_TYPE=${TUNNEL_TYPE:-quick}
CF_TOKEN=${CF_TOKEN:-}
FIXED_HOST=${FIXED_HOST:-}
ARGO_URL=${ARGO_URL:-}
WS_PATH=${WS_PATH:-}
EOF
    chmod 600 "$INFO_FILE" 2>/dev/null || true
}

load_info() {
    UUID=""; PORT=""; PRIVATE_KEY=""; PUBLIC_KEY=""; SHORT_ID=""
    SERVER_IP=""; LEVEL=""; DEST=""
    EXTRA_UUIDS=""; FEAT_SHORT2=""; FEAT_LOGLEVEL="none"; FEAT_LISTEN="0.0.0.0"
    FEAT_EMPTY_SID=0; FEAT_BLOCK_PRIVATE=0; FEAT_BLOCK_BT=0
    NODE_MODE="reality"; TUNNEL_TYPE="quick"; CF_TOKEN=""; FIXED_HOST=""
    ARGO_URL=""; WS_PATH=""
    # USER_MAPPED_* 为安装会话变量，不在此清空（否则改端口/多次 load 会丢）
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
            TUNNEL_TYPE) TUNNEL_TYPE="$v" ;;
            CF_TOKEN) CF_TOKEN="$v" ;;
            FIXED_HOST) FIXED_HOST="$v" ;;
            ARGO_URL) ARGO_URL="$v" ;;
            WS_PATH) WS_PATH="$v" ;;
        esac
    done < "$INFO_FILE"
    # 兼容：有 FIXED_HOST 但未写 TUNNEL_TYPE 时视为 named
    if [[ -n $FIXED_HOST && -n $CF_TOKEN && ${TUNNEL_TYPE:-quick} == "quick" ]]; then
        TUNNEL_TYPE="named"
    fi
    # named 时展示域名优先用 FIXED_HOST
    if [[ ${TUNNEL_TYPE:-} == "named" && -n $FIXED_HOST ]]; then
        ARGO_URL=${ARGO_URL:-$FIXED_HOST}
    fi
}

_make_link() {
    local uid=$1
    local ip=${SERVER_IP:-$(get_ip)}
    local _dest=${DEST:-www.microsoft.com:443}
    local sni=${_dest%%:*}
    local sid=${SHORT_ID}
    echo "vless://${uid}@${ip}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${PUBLIC_KEY}&sid=${sid}&type=tcp&headerType=none#智能-${LEVEL:-node}"
}

show_client_snippets() {
    local ip=${SERVER_IP:-$(get_ip)}
    local _dest=${DEST:-www.microsoft.com:443}
    local sni=${_dest%%:*}
    local name="Smart-${LEVEL}"
    local sid=${SHORT_ID}

    # Argo：VLESS+WS+TLS，无 flow/REALITY
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        local host=${ARGO_URL}
        local path=${WS_PATH:-/argo}
        [[ $path == /* ]] || path="/$path"
        [[ -z $host ]] && host=$( _argo_parse_url "$ARGO_LOG" | sed "s|^https://||" )
        name="智能隧道"
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
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            ARGO_URL=${FIXED_HOST:-$ARGO_URL}
        else
            # Quick：域名丢了 / 进程重连换过域名 → 从日志恢复并写回
            refresh_argo_url quiet >/dev/null 2>&1 || true
            load_info
        fi
        if [[ -z $ARGO_URL ]]; then
            error "无有效隧道域名"
            if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
                error "固定隧道请菜单 25 配置域名，或菜单 14 重启"
            else
                error "先看菜单 15 确认 cloudflared 是否运行，再菜单 14 重启"
            fi
            return
        fi
        main_link=$(build_argo_link "$UUID" "$ARGO_URL" "$WS_PATH")
        if [[ -z $main_link ]]; then
            error "链接生成失败（域名/路径异常），请菜单 14 重启隧道后重试"
            return
        fi
        echo
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            title "========== 固定隧道节点信息 =========="
        else
            title "========== Argo Quick 节点信息 =========="
        fi
        echo "域名      : $ARGO_URL"
        echo "本机端口  : $PORT (仅 127.0.0.1)"
        echo "WS Path   : $WS_PATH"
        echo "主 UUID   : $UUID"
        echo "脚本版本  : v${SCRIPT_VERSION} (${SCRIPT_DATE})"
        echo
        echo -e "${YELLOW}分享链接（复制这一整行）：${NC}"
        echo "$main_link"
        echo
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            echo -e "${YELLOW}提示：固定隧道域名由 Cloudflare 控制台决定，进程重启一般不变。${NC}"
        else
            echo -e "${YELLOW}提示：Quick 隧道在机器重启/进程被杀后域名可能变化，变了需重新导入链接。${NC}"
        fi
        show_client_snippets
        show_qrcode_if_available "$main_link"
        echo -e "${CYAN}===================================${NC}"
        return
    fi

    main_link=$(_make_link "$UUID")
    warn "NAT 小鸡请确认面板已映射：外网 → 本机 TCP ${PORT}"
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
        echo "========== 智能节点 导出 =========="
        echo "导出时间: $(date)"
        echo "脚本版本: v${SCRIPT_VERSION}"
        echo
        show_link
        echo
        echo "========== 原始 config.json =========="
        cat "$CONFIG_FILE" 2>/dev/null || echo "(无配置文件)"
    } 2>&1 | sed "s/$(printf '\033')\[[0-9;]*m//g" > "$out"
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
    if ! restart_node_service; then
        error "服务重启失败，配置已保存，先用菜单 13 看日志再菜单 14 重试"
        return 1
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
    if ! restart_node_service; then
        error "服务重启失败，配置已保存，先用菜单 13 看日志再菜单 14 重试"
        return 1
    fi
    success "已删除用户: $target"
    show_link
}

# 订阅式导出：多链接 base64（常见客户端可直接导入）
export_subscription() {
    load_info
    [[ -z $UUID ]] && { warn "尚未安装节点"; return; }
    local links="" u
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        if [[ -z $ARGO_URL ]]; then
            refresh_argo_url quiet >/dev/null 2>&1 || true
            load_info
        fi
        [[ -z $ARGO_URL ]] && { error "无 Argo 域名，请先菜单 14 重启隧道"; return; }
        links=$(build_argo_link "$UUID" "$ARGO_URL" "$WS_PATH")
        [[ -z $links ]] && { error "链接生成失败，请菜单 24 刷新域名后重试"; return 1; }
    else
        links=$(_make_link "$UUID")
        for u in $EXTRA_UUIDS; do
            [[ -z $u ]] && continue
            links="${links}
$(_make_link "$u")"
        done
    fi
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
    local tmp
    tmp=$(mktemp /tmp/sysctl-smart-node.XXXXXX 2>/dev/null || echo /tmp/sysctl-smart-node.$$)
    [[ -z $tmp ]] && { error "无法创建临时文件"; return 1; }

    # 以前只做"整行去重"，同一个键不同值会一直叠加（sysctl 以最后一次为准，
    # 文件越写越长还看不懂）。这里按 key 去重：先删掉同名键，再写我们的。
    local keys=" vm.swappiness vm.dirty_ratio vm.dirty_background_ratio vm.vfs_cache_pressure net.core.default_qdisc net.ipv4.tcp_congestion_control net.ipv4.tcp_fastopen net.ipv4.tcp_slow_start_after_idle "
    {
        awk -v keys="$keys" '
            /^[[:space:]]*# smart-node low-mem optimize/ { next }
            /^[[:space:]]*#/ { print; next }
            NF==0 { print; next }
            {
                line=$0
                sub(/^[[:space:]]+/,"",line)
                eq=index(line,"=")
                if (eq>0) {
                    k=substr(line,1,eq-1)
                    if (index(keys, " " k " ")>0) next
                }
                print
            }' "$conf" 2>/dev/null
        cat << 'EOF'

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
    } > "$tmp" 2>/dev/null

    if [[ -s $tmp ]]; then
        cp -f "$conf" "${conf}.smart-node.bak" 2>/dev/null || true
        mv -f "$tmp" "$conf"
    else
        rm -f "$tmp"
        warn "sysctl 写入失败，已跳过（原文件未改动）"
        return 1
    fi
    sysctl -p >/dev/null 2>&1 || true
    success "sysctl 优化已应用（同键已去重，备份: ${conf}.smart-node.bak）"
}

# 尝试放行本机防火墙端口（REALITY 用；Argo/固定隧道不需要）
open_firewall() {
    local port=$1
    [[ $port =~ ^[0-9]+$ ]] || return 0
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
    return 0
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
            refresh_argo_url >/dev/null 2>&1 || true
            load_info
            [[ -n $ARGO_URL ]] && info "已恢复域名: $ARGO_URL" || error "无法恢复域名，请菜单 14 重启隧道"
        fi
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            info "固定隧道域名: ${FIXED_HOST:-$ARGO_URL}"
            info "请确认 CF Public Hostname → http://127.0.0.1:${PORT}"
        elif [[ -n $ARGO_URL ]]; then
            local _live
            _live=$(_argo_parse_url "$ARGO_LOG" | sed "s|^https://||")
            if [[ -n $_live && $_live != "$ARGO_URL" ]]; then
                warn "注意：隧道当前实际域名是 $_live，与配置里的 $ARGO_URL 不一致"
                warn "请菜单 2 复制最新链接重新导入客户端"
            fi
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
    if [[ -z $PORT ]]; then
        warn "配置里没有端口，跳过监听检查（建议菜单 1 重装）"
    elif check_port_free $PORT; then
        error "端口 $PORT: 未监听（异常）"
    else
        success "端口 $PORT: 正在监听"
        local _pref=0 _p
        for _p in 443 80 8080 8443 2053 2083 2087 2096; do
            [[ $_p == "$PORT" ]] && _pref=1 && break
        done
        if (( _pref )); then
            info "请确认面板已映射 TCP $PORT；NAT 小鸡未映射则外网必不通"
        else
            warn "请确认小鸡面板已映射 TCP $PORT（NAT 入站必做）"
        fi
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
    if [[ -f /tmp/smart-node-argo-domain.log ]]; then
        echo "--- 域名变更记录 ---"
        tail -n 10 /tmp/smart-node-argo-domain.log 2>/dev/null || true
    fi
    if [[ ! -f $XRAY_LOG && ! -f $ARGO_LOG ]] && ! has_systemd; then
        warn "无日志文件。可用: ps | grep -E 'xray|cloudflared'"
    fi
}

# ======================== 安装主逻辑 ========================
# ---------- 隧道安装（Quick 临时 / Named 固定）----------
install_node_argo() {
    local mode=${1:-quick}   # quick | named
    local reuse_uuid=${2:-}  # 非空则沿用
    local reuse_path=${3:-}

    echo
    if [[ $mode == "named" ]]; then
        info "开始安装（Cloudflare 固定隧道）..."
        info "特点：域名持久；需在 CF 控制台配置 Public Hostname → 本机端口"
    else
        info "开始安装（Argo Quick 临时隧道）..."
        info "特点：一路回车、免开端口；进程重建后域名会变（挂保活 + 菜单 24）"
    fi

    if (( ${SMART_SWAP:-0} > 0 )); then
        create_swap "${SMART_SWAP}" || warn "Swap 创建失败，继续"
    fi

    install_deps || return 1
    install_xray || return 1
    install_cloudflared || return 1

    if [[ -n $reuse_uuid ]]; then
        UUID=$reuse_uuid
        info "沿用原 UUID: $UUID"
    else
        if command -v uuidgen >/dev/null 2>&1; then
            UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
        else
            UUID=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
        fi
        [[ -z $UUID ]] && UUID=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
    fi

    PORT=$((30000 + RANDOM % 20000))
    local try=0
    while ! check_port_free $PORT && (( try < 30 )); do
        PORT=$((30000 + RANDOM % 20000))
        try=$((try + 1))
    done

    if [[ -n $reuse_path ]]; then
        WS_PATH=$reuse_path
        info "沿用原路径: $WS_PATH"
    else
        WS_PATH="/$(openssl rand -hex 8 2>/dev/null || echo argo$((RANDOM % 99999)))$(openssl rand -hex 4 2>/dev/null || echo x)"
    fi
    PRIVATE_KEY=""; PUBLIC_KEY=""; SHORT_ID=""
    DEST=""
    SERVER_IP=$(get_ip)
    LEVEL="argo"
    NODE_MODE="argo"
    TUNNEL_TYPE=$mode
    # named 时可能已从重装「沿用」预填 CF_TOKEN / FIXED_HOST，勿无条件清空
    if [[ $mode != "named" ]]; then
        CF_TOKEN=""
        FIXED_HOST=""
        ARGO_URL=""
    else
        ARGO_URL=${FIXED_HOST:-$ARGO_URL}
    fi

    if [[ $mode == "named" ]]; then
        echo
        title "---------- 固定隧道配置 ----------"
        echo "步骤简述："
        echo "  1. 打开 Cloudflare Zero Trust → Networks → Tunnels → Create"
        echo "  2. 安装方式选「Token」，复制 Token"
        echo "  3. 给隧道添加 Public Hostname："
        echo "       Subdomain/Domain → 你的域名"
        echo "       Service → http://127.0.0.1:<下面将分配的本机端口>"
        echo "  4. 把 Token 和域名填到下面"
        echo
        local _tok_in _host_in
        if [[ -n $CF_TOKEN ]]; then
            echo "已有 Token（${#CF_TOKEN} 字符），直接回车沿用，或粘贴新 Token："
        fi
        read -p "Tunnel Token: " _tok_in
        _tok_in=$(echo "$_tok_in" | tr -d '[:space:]')
        [[ -n $_tok_in ]] && CF_TOKEN=$_tok_in
        [[ -z $CF_TOKEN ]] && { error "Token 不能为空"; return 1; }
        if [[ -n $FIXED_HOST ]]; then
            echo "已有域名: $FIXED_HOST ，直接回车沿用："
        fi
        read -p "固定域名（如 node.example.com）: " _host_in
        _host_in=$(echo "$_host_in" | tr -d '[:space:]' | sed 's|^https\?://||;s|/$||')
        [[ -n $_host_in ]] && FIXED_HOST=$_host_in
        [[ -z $FIXED_HOST ]] && { error "域名不能为空"; return 1; }
        ARGO_URL=$FIXED_HOST
        info "本机回源端口将是: $PORT（请在 CF Public Hostname 填 http://127.0.0.1:$PORT）"
        read -p "已在控制台配好 Public Hostname？(Y/n): " okh
        [[ $okh == "n" || $okh == "N" ]] && warn "稍后可在控制台补配；现在仍会启动隧道进程"
    fi

    write_config_argo "$UUID" "$PORT" "$WS_PATH" || return 1
    if $XRAY_BIN run -c "$CONFIG_FILE" -test >/dev/null 2>&1; then
        info "配置校验通过"
    else
        error "配置校验失败，已停止安装（不启动坏配置）。原始报错："
        $XRAY_BIN run -c "$CONFIG_FILE" -test 2>&1 | head -15 || true
        error "如果反复失败：先菜单 21 彻底清理，再重新安装"
        return 1
    fi

    if [[ $mode == "named" ]]; then
        start_named_stack "$PORT" "$CF_TOKEN" || return 1
    else
        start_argo_stack "$PORT" || return 1
    fi

    save_info "$UUID" "$PORT" "" "" "" "$SERVER_IP" "argo" ""
    success "隧道节点安装完成！类型: $mode"
    echo
    if [[ $mode == "named" ]]; then
        echo -e "${GREEN}固定域名: ${FIXED_HOST}${NC}"
        echo -e "${YELLOW}请确认 CF 控制台 Public Hostname → http://127.0.0.1:${PORT}${NC}"
        echo -e "${YELLOW}建议菜单 23 安装保活，重启后隧道会自动拉起且域名不变。${NC}"
    else
        echo -e "${YELLOW}临时域名会随进程重建而变。建议：菜单 23 保活 + 变了用菜单 24 刷新。${NC}"
    fi
    show_link
}

install_node() {
    detect_and_recommend refresh

    local REUSE_UUID="" REUSE_PATH="" REUSE_TOKEN="" REUSE_HOST="" REUSE_TTYPE=""
    if [[ -f $INFO_FILE ]] || [[ -x $XRAY_BIN ]] || proc_alive 'xray|cloudflared'; then
        warn "检测到已有节点 / Xray / 隧道残留"
        # 先读旧配置，供「沿用」选项使用
        load_info
        local _old_uuid=$UUID _old_path=$WS_PATH _old_token=$CF_TOKEN _old_host=$FIXED_HOST _old_tt=$TUNNEL_TYPE
        echo "  1) 彻底清理后重装（新 UUID，客户端需重新导入）"
        echo "  2) 仅重启服务（配置不动，链接不变）"
        echo "  3) 清理后重装，但沿用原 UUID/路径（客户端一般不用改）"
        echo "  0) 取消"
        read -p "选择 [0-3，回车=2]: " overwrite
        overwrite=${overwrite:-2}
        case $overwrite in
            2)
                restart_xray || warn "重启未完全成功，可菜单 12 自检或选 1 清理重装"
                return
                ;;
            0) return ;;
            1|3) ;;
            *) return ;;
        esac
        if [[ $overwrite == "3" ]]; then
            REUSE_UUID=$_old_uuid
            REUSE_PATH=$_old_path
            REUSE_TOKEN=$_old_token
            REUSE_HOST=$_old_host
            REUSE_TTYPE=$_old_tt
            info "将沿用 UUID=${REUSE_UUID:-空} 路径=${REUSE_PATH:-空}"
        fi
        backup_config 2>/dev/null || true
        _PURGE_SELF=0
        purge_all quiet
        sleep 1
        info "清理完成，开始安装（旧配置已备份到 ${BACKUP_DIR}）"
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

    echo
    title "接入方式（NAT 小鸡推荐 1 或 2，回车=1）:"
    echo "  1) Argo Quick  临时域名 · 不需面板端口映射 · 一路回车 【默认】"
    echo "  2) 固定隧道    Cloudflare Token · 域名持久 · 不需端口映射"
    echo "  3) REALITY     直连 · 可先填你已映射的端口，脚本优先用它们"
    read -p "选择 [1/2/3]: " mode_choice
    mode_choice=${mode_choice:-1}
    mode_choice=$(echo "$mode_choice" | tr -d '[:space:]')
    case $mode_choice in
        1|"")
            NODE_MODE="argo"
            install_node_argo quick "$REUSE_UUID" "$REUSE_PATH"
            return
            ;;
        2)
            NODE_MODE="argo"
            [[ -n $REUSE_TOKEN ]] && CF_TOKEN=$REUSE_TOKEN
            [[ -n $REUSE_HOST ]] && FIXED_HOST=$REUSE_HOST
            install_node_argo named "$REUSE_UUID" "$REUSE_PATH"
            return
            ;;
        3)
            NODE_MODE="reality"
            ;;
        *)
            warn "无效选择，已取消"
            return
            ;;
    esac
    echo
    info "开始安装 REALITY 直连（档位: $LEVEL）..."
    warn "NAT 小鸡：装完后必须在面板把该端口映射进来，否则外网连不上。"

    local MEM_MAX="${SMART_MEM_MAX:-}" MEM_HIGH="${SMART_MEM_HIGH:-}"
    local SWAP_SIZE=${SMART_SWAP:-256}

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

    # 自动选本机空闲的常用/疑似已映射端口，尽量不用去面板再映射
    pick_listen_port
    PORT=$AUTO_PORT
    if ! [[ $PORT =~ ^[0-9]+$ ]] || (( PORT < 1 || PORT > 65535 )); then
        error "端口无效"; return
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

    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "$DEST" || {
        error "配置文件写入失败"; return 1
    }
    if [[ ! -s $CONFIG_FILE ]]; then
        error "配置文件写入失败"; return 1
    fi

    if $XRAY_BIN run -c "$CONFIG_FILE" -test >/dev/null 2>&1; then
        info "配置校验通过"
    else
        error "配置校验失败，已停止安装（不启动坏配置）。原始报错："
        $XRAY_BIN run -c "$CONFIG_FILE" -test 2>&1 | head -20 || true
        error "常见原因：私钥格式不对 / dest 非法 / 端口被占。可菜单 21 清理后重装"
        return 1
    fi

    write_service "$MEM_MAX" "$MEM_HIGH"
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "$DEST"

    open_firewall $PORT

    if [[ ${SMART_BBR:-0} -eq 1 ]]; then
        enable_bbr
    fi

    if has_systemd; then
        systemctl enable xray >/dev/null 2>&1
        if restart_node_service; then
            success "安装成功！当前模式：$LEVEL"
        else
            error "服务启动失败，看这几行就知道原因："
            journalctl -u xray -n 20 --no-pager 2>/dev/null | tail -20 || true
            return 1
        fi
    else
        warn "未检测到 systemd，改用 nohup 后台运行（需菜单 23 保活）"
        if restart_node_service; then
            success "已后台启动"
        else
            error "启动失败，日志最后几行："
            tail -10 "$XRAY_LOG" 2>/dev/null || true
            return 1
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
    echo "内存: 总 $(get_total_mem)MB / 可用 $(get_available_mem)MB / Swap $(get_swap_total_mem)MB"
    if [[ $LEVEL == "extreme" || $LEVEL == "ultra-low" ]]; then
        echo
        warn "低内存小鸡请定期 free -m 观察，必要时 systemctl restart xray"
        warn "排查 OOM: dmesg | grep -iE 'out of memory|killed process'"
    fi
    echo
    title "---------- 安装后检查清单 ----------"
    echo "1. NAT 小鸡请在面板映射：外网端口 → 本机 TCP $PORT（未映射则外网不通）"
    echo "2. 用客户端导入分享链接测试连通性"
    echo "3. 低内存机器建议执行菜单「16」做系统参数优化"
    echo "4. 出问题可用菜单「12」自检 或「13」看日志"
    echo -e "${CYAN}=====================================${NC}"
}

# 统一的重启入口：改完配置用它，并真实回报结果（不再无脑 restart 后不检查）
restart_node_service() {
    if has_systemd; then
        systemctl restart xray 2>/dev/null || true
        sleep 1
        if systemctl is-active --quiet xray 2>/dev/null; then
            return 0
        fi
        return 1
    fi
    pkill -f "$XRAY_BIN" 2>/dev/null || true
    sleep 1
    nohup "$XRAY_BIN" run -c "$CONFIG_FILE" >"$XRAY_LOG" 2>&1 &
    echo $! > "$XRAY_PIDFILE" 2>/dev/null || true
    sleep 1
    proc_alive "$XRAY_BIN" && return 0
    [[ -n ${PORT:-} ]] && _port_listening "$PORT" && return 0
    return 1
}

change_port() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    require_reality || return
    local old_port=$PORT
    echo "当前端口: $PORT"
    # 改端口时允许重新填写已映射口
    USER_MAPPED_ASKED=0
    pick_listen_port
    local new_port=$AUTO_PORT
    [[ -z $new_port ]] && return
    if ! [[ $new_port =~ ^[0-9]+$ ]] || (( new_port < 1 || new_port > 65535 )); then
        error "端口无效"; return
    fi
    [[ $new_port == "$old_port" ]] && { info "端口未变化"; return; }
    check_port_free $new_port || warn "端口 $new_port 似乎已被占用"
    backup_config
    PORT=$new_port
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}" || {
        error "写配置失败，已保留原端口 $old_port"; PORT=$old_port; return 1
    }
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    open_firewall $PORT
    if ! restart_node_service; then
        error "Xray 重启失败，先用菜单 13 看日志；配置已保存，可改回端口 $old_port"
        return 1
    fi
    success "端口已改为 $PORT，请同步修改面板端口映射"
    show_link
}

change_uuid() {
    load_info
    [[ -z $UUID ]] && { warn "请先安装节点"; return; }
    require_reality || return
    backup_config
    UUID=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16 | sed "s/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/")
    [[ -z $UUID ]] && { error "生成 UUID 失败"; return; }
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}" || {
        error "写配置失败，已保留原配置"; return 1
    }
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    if ! restart_node_service; then
        error "服务重启失败，配置已保存，先用菜单 13 看日志再菜单 14 重试"
        return 1
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
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}" || {
        error "写配置失败，已保留原配置"; return 1
    }
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    if ! restart_node_service; then
        error "服务重启失败，配置已保存，先用菜单 13 看日志再菜单 14 重试"
        return 1
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
    write_config "$UUID" "$PORT" "$PRIVATE_KEY" "$SHORT_ID" "${DEST:-www.microsoft.com:443}" || {
        error "写配置失败，已保留原配置"; return 1
    }
    save_info "$UUID" "$PORT" "$PRIVATE_KEY" "$PUBLIC_KEY" "$SHORT_ID" "$SERVER_IP" "$LEVEL" "${DEST:-www.microsoft.com:443}"
    if ! restart_node_service; then
        error "服务重启失败，配置已保存，先用菜单 13 看日志再菜单 14 重试"
        return 1
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
    if ! restart_node_service; then
        error "服务重启失败，配置已保存，先用菜单 13 看日志再菜单 14 重试"
        return 1
    fi
    success "伪装目标已修改为 $DEST"
    show_link
}

restart_xray() {
    load_info
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        info "重启隧道栈（Xray + cloudflared）..."
        if [[ -z $PORT ]]; then
            error "缺少配置，请重新安装"; return
        fi
        [[ -z $WS_PATH ]] && WS_PATH="/argo"
        if [[ ! -s $CONFIG_FILE ]]; then
            write_config_argo "$UUID" "$PORT" "$WS_PATH" || return
        fi
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            [[ -z $CF_TOKEN ]] && { error "固定隧道缺少 Token，请菜单 25 重新配置"; return; }
            start_named_stack "$PORT" "$CF_TOKEN" || return
            ARGO_URL=${FIXED_HOST:-$ARGO_URL}
            save_info "$UUID" "$PORT" "" "" "" "${SERVER_IP:-$(get_ip)}" "argo" ""
            success "固定隧道已重启（域名不变: ${ARGO_URL}）"
        else
            start_argo_stack "$PORT" || return
            save_info "$UUID" "$PORT" "" "" "" "${SERVER_IP:-$(get_ip)}" "argo" ""
            success "Quick 隧道已重启（临时域名可能已变，请菜单 2 看最新链接）"
        fi
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
        if restart_node_service; then
            success "已后台重启"
        else
            error "启动失败，日志最后几行："
            tail -10 "$XRAY_LOG" 2>/dev/null || true
        fi
    fi
}

status_xray() {
    refresh_mem_cache
    load_info
    echo
    title "----- 服务状态 -----"
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            echo "模式: 固定隧道（Token）  域名: ${FIXED_HOST:-$ARGO_URL}"
        else
            echo "模式: Argo Quick 临时隧道（免端口）"
        fi
        proc_alive "$XRAY_BIN" && success "xray: 运行中" || error "xray: 未运行（菜单 14 重启）"
        proc_alive "cloudflared" && success "cloudflared: 运行中" || error "cloudflared: 未运行（菜单 14 重启）"
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            echo "当前域名: ${FIXED_HOST:-$ARGO_URL}"
            [[ -n $PORT ]] && echo "回源地址: http://127.0.0.1:${PORT}（须与 CF 控制台一致）"
        else
            refresh_argo_url quiet >/dev/null 2>&1 || true
            load_info
            [[ -n $ARGO_URL ]] && echo "当前域名: $ARGO_URL"
        fi
        if [[ -n $PORT ]]; then
            _port_listening "$PORT" && success "本机端口 ${PORT}: 监听中" || error "本机端口 ${PORT}: 未监听"
        fi
    elif has_systemd; then
        systemctl is-active --quiet xray 2>/dev/null && success "systemd 服务: 运行中" || error "systemd 服务: 未运行"
        [[ -n $PORT ]] && { _port_listening "$PORT" && success "端口 ${PORT}: 监听中" || error "端口 ${PORT}: 未监听"; }
    else
        proc_alive "$XRAY_BIN" && success "xray: 运行中" || warn "xray: 未发现"
        [[ -n $PORT ]] && { _port_listening "$PORT" && success "端口 ${PORT}: 监听中" || warn "端口 ${PORT}: 未监听"; }
    fi

    echo
    title "----- 版本 -----"
    if [[ -x $XRAY_BIN ]]; then
        echo "Xray        : $($XRAY_BIN version 2>/dev/null | head -n 1)"
    else
        echo "Xray        : 未安装"
    fi
    if [[ -x $CLOUDFLARED_BIN ]]; then
        echo "cloudflared : $($CLOUDFLARED_BIN --version 2>/dev/null | head -n 1)"
    fi
    echo "脚本        : v${SCRIPT_VERSION} (${SCRIPT_DATE})"

    echo
    title "----- 内存 -----"
    local t_mem a_mem s_mem rss
    t_mem=$(get_total_mem); a_mem=$(get_available_mem); s_mem=$(get_swap_total_mem)
    echo "总量 ${t_mem}MB / 可用 ${a_mem}MB / Swap ${s_mem}MB"
    rss=$(ps -o rss= -C xray 2>/dev/null | awk '{s+=$1} END{print s+0}')
    [[ -z $rss ]] && rss=0
    if (( rss > 0 )); then
        echo "Xray 实际占用约 $(( rss / 1024 )) MB"
    fi
    echo -e "内存压力: $(get_mem_pressure_hint)"
}

update_xray() {
    info "更新 Xray 到最新版..."
    local bak=""
    if [[ -x $XRAY_BIN ]]; then
        bak="${XRAY_BIN}.bak"
        cp -f "$XRAY_BIN" "$bak" 2>/dev/null || true
    fi
    rm -f "$XRAY_BIN"
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
    elif ! restart_node_service; then
        error "内核已更新，但服务没起来，先用菜单 13 看日志"
        return 1
    fi
    success "更新完成"
}

# 彻底清理本脚本留下的一切（可静默，供重装调用）
# $1 = quiet 时不交互、不删 Swap/sysctl
purge_all() {
    local quiet=${1:-}
    [[ $quiet == quiet ]] || info "正在清理本脚本产生的全部内容..."

    local _old_port=""
    if [[ -f $INFO_FILE ]]; then
        _old_port=$(grep -m1 '^PORT=' "$INFO_FILE" 2>/dev/null | cut -d= -f2-)
    fi

    # ---- 1. 服务 ----
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop xray cloudflared 2>/dev/null || true
        systemctl disable xray cloudflared 2>/dev/null || true
    fi
    if command -v rc-service >/dev/null 2>&1; then
        rc-service xray stop 2>/dev/null || true
        rc-update del xray 2>/dev/null || true
        rc-service cloudflared stop 2>/dev/null || true
        rc-update del cloudflared 2>/dev/null || true
    fi

    # ---- 2. 按 pidfile 结束进程 ----
    local p f
    for f in \
        "${ARGO_PIDFILE:-/tmp/smart-node-cloudflared.pid}" \
        "${XRAY_PIDFILE:-/tmp/smart-node-xray.pid}" \
        /tmp/smart-node-cloudflared.pid \
        /tmp/smart-node-xray.pid
    do
        [[ -f $f ]] || continue
        p=$(cat "$f" 2>/dev/null)
        [[ $p =~ ^[0-9]+$ ]] && kill -9 "$p" 2>/dev/null || true
        rm -f "$f"
    done

    # ---- 3. 多轮杀进程 ----
    local _i
    for _i in 1 2 3 4 5; do
        pkill -9 -f "/usr/local/bin/xray" 2>/dev/null || true
        pkill -9 -f "xray run" 2>/dev/null || true
        pkill -9 -f "/usr/local/bin/cloudflared" 2>/dev/null || true
        pkill -9 -f "cloudflared tunnel" 2>/dev/null || true
        pkill -9 -f "cloudflared" 2>/dev/null || true
        pkill -9 -x xray 2>/dev/null || true
        pkill -9 -x cloudflared 2>/dev/null || true
        pkill -9 -f "smart-node-keepalive" 2>/dev/null || true
        ps 2>/dev/null | grep -E '[x]ray|[c]loudflared|[s]mart-node-keepalive' | awk '{print $1}' | while read -r pid; do
            [[ -n $pid ]] && kill -9 "$pid" 2>/dev/null || true
        done
        if [[ -n $_old_port && $_old_port =~ ^[0-9]+$ ]]; then
            command -v fuser >/dev/null 2>&1 && fuser -k "${_old_port}/tcp" 2>/dev/null || true
        fi
        sleep 0.3
    done

    # ---- 4. systemd / OpenRC 单元 ----
    rm -f /etc/systemd/system/xray.service \
          /etc/systemd/system/cloudflared.service \
          /etc/systemd/system/multi-user.target.wants/xray.service \
          /etc/systemd/system/multi-user.target.wants/cloudflared.service \
          /etc/init.d/xray /etc/init.d/cloudflared 2>/dev/null || true
    if command -v systemctl >/dev/null 2>&1; then
        systemctl daemon-reload 2>/dev/null || true
        systemctl reset-failed xray 2>/dev/null || true
        systemctl reset-failed cloudflared 2>/dev/null || true
    fi

    # ---- 5. 下载的二进制（本脚本安装路径）----
    rm -f /usr/local/bin/xray /usr/local/bin/xray.bak \
          /usr/local/bin/cloudflared \
          /usr/local/bin/smart-node-keepalive \
          /usr/bin/xray /usr/bin/cloudflared \
          /bin/xray /bin/cloudflared \
          /opt/xray /opt/cloudflared \
          /root/xray /root/cloudflared /root/xray.zip \
          /root/Xray-linux-*.zip \
          /tmp/xray /tmp/cloudflared 2>/dev/null || true

    # ---- 6. 配置目录（重装 quiet 时先挪走 backup 再放回）----
    local _bk=""
    if [[ $quiet == quiet && -d ${BACKUP_DIR:-/usr/local/etc/xray/backup} ]] && \
       compgen -G "${BACKUP_DIR}/*" >/dev/null 2>&1; then
        _bk="/tmp/.sn-bk-$$"
        rm -rf "$_bk" 2>/dev/null || true
        mkdir -p "$_bk" 2>/dev/null && cp -rf "$BACKUP_DIR"/. "$_bk"/ 2>/dev/null || _bk=""
    fi
    rm -rf /usr/local/etc/xray \
           /etc/xray \
           /usr/local/share/xray \
           /root/.cloudflared \
           /etc/cloudflared \
           /var/log/xray \
           /var/log/cloudflared 2>/dev/null || true

    # ---- 7. 下载缓存 / 临时包 / 日志 / 锁 / 导出 ----
    # install_xray / install_cloudflared / 自更新 产生的临时文件
    rm -f /tmp/xray_dl_* /tmp/cf_dl_* /tmp/xray*.zip \
          /tmp/smart-node-update-*.sh /tmp/smart-node-update-$$.sh \
          /tmp/smart-node*.sh /tmp/h.sh /tmp/t.json \
          /tmp/xray-argo.log /tmp/cloudflared-argo.log /tmp/xray.log \
          /tmp/smart-node-keepalive.lock /tmp/smart-node-argo-domain.log \
          /tmp/smart-node-cloudflared.pid /tmp/smart-node-xray.pid \
          /tmp/geoip.dat /tmp/geosite.dat \
          /tmp/sysctl-smart-node.* 2>/dev/null || true
    rm -rf /tmp/smart-node-test /tmp/.sn-bk-* 2>/dev/null || true
    # 通配再扫一轮 /tmp
    rm -f /tmp/xray* /tmp/cloudflared* /tmp/cf_dl_* /tmp/smart-node* 2>/dev/null || true
    # 用户目录导出
    rm -f /root/smart-node-export-*.txt \
          /root/smart-node-sub-*.txt \
          /root/v2ray.txt /root/xray.txt 2>/dev/null || true
    # 解压残留
    rm -f /tmp/LICENSE /tmp/README.md 2>/dev/null || true

    # 彻底还原时删脚本自身与发布包
    if [[ ${_PURGE_SELF:-0} -eq 1 ]]; then
        rm -f /root/smart-node.sh \
              /root/smart-node-v*.sh \
              /root/smart-node-*.zip \
              /root/smart-node*.zip 2>/dev/null || true
        # 当前若以文件方式运行且在 /root 外，不强制删 $0（可能是用户拷贝）
        local self
        self=$(readlink -f "$0" 2>/dev/null || echo "")
        if [[ -n $self && $self == /root/*smart-node* ]]; then
            rm -f "$self" 2>/dev/null || true
        fi
    fi

    if [[ -n $_bk && -d $_bk ]]; then
        mkdir -p "${BACKUP_DIR:-/usr/local/etc/xray/backup}" 2>/dev/null || true
        cp -rf "$_bk"/. "${BACKUP_DIR}/" 2>/dev/null || true
        rm -rf "$_bk" 2>/dev/null || true
    fi

    # ---- 8. crontab 保活 ----
    if command -v crontab >/dev/null 2>&1; then
        local ct
        ct=$(crontab -l 2>/dev/null || true)
        if [[ -n $ct && $quiet != quiet ]]; then
            echo "$ct" | grep -vE 'smart-node-keepalive|/usr/local/bin/smart-node-keepalive' | crontab - 2>/dev/null || true
        fi
    fi

    # ---- 9. rc.local ----
    if [[ -f /etc/rc.local ]]; then
        safe_sed '/xray run/d' /etc/rc.local 2>/dev/null || true
        safe_sed '/cloudflared tunnel/d' /etc/rc.local 2>/dev/null || true
        safe_sed '/smart-node/d' /etc/rc.local 2>/dev/null || true
    fi

    # ---- 10. 清空运行时变量 ----
    UUID=""; PORT=""; PRIVATE_KEY=""; PUBLIC_KEY=""; SHORT_ID=""
    SERVER_IP=""; LEVEL=""; DEST=""; EXTRA_UUIDS=""
    NODE_MODE="argo"; TUNNEL_TYPE="quick"; CF_TOKEN=""; FIXED_HOST=""
    ARGO_URL=""; WS_PATH=""
    FEAT_SHORT2=""; FEAT_LOGLEVEL="none"; FEAT_LISTEN="0.0.0.0"
    FEAT_EMPTY_SID=0; FEAT_BLOCK_PRIVATE=0; FEAT_BLOCK_BT=0
    USER_MAPPED_PORTS=(); USER_MAPPED_ASKED=0

    [[ $quiet == quiet ]] || success "进程、二进制、配置、下载缓存与临时文件已清理"
}

# 一键删除：清掉本脚本下载/安装/生成的全部内容
uninstall_node() {
    local force=${1:-}
    [[ ${SMART_NODE_FORCE:-0} == "1" ]] && force=force

    echo
    title "========== 一键清理（本脚本全部痕迹） =========="
    echo "将删除本脚本运行期间下载、安装、生成的内容，包括："
    echo "  · Xray / cloudflared 进程与占用端口"
    echo "  · 已下载的二进制（/usr/local/bin 等）"
    echo "  · 配置目录、备份、日志、导出/订阅文件"
    echo "  · 下载临时包（/tmp 下 xray、cloudflared、更新脚本等）"
    echo "  · systemd/OpenRC、crontab 保活、rc.local 相关行"
    echo "  · 本脚本创建的 /swapfile 与相关系统参数"
    echo "  · 脚本文件自身（/root/smart-node*）"
    echo
    echo -e "${YELLOW}不会动：其它软件、你自己的 Swap、非本脚本的定时任务${NC}"
    echo

    if [[ $force != force ]]; then
        echo "请选择："
        echo "  1) 一键彻底清理（推荐）"
        echo "  2) 仅停止进程（保留配置与程序，方便重装）"
        echo "  0) 取消"
        read -p "请选择 [0-2，直接回车=1]: " uc
        uc=${uc:-1}
        case $uc in
            0) info "已取消"; return ;;
            2)
                info "正在停止进程..."
                stop_argo_stack quiet 2>/dev/null || true
                has_systemd && systemctl stop xray 2>/dev/null || true
                pkill -f "${XRAY_BIN:-xray}" 2>/dev/null || true
                pkill -f "${CLOUDFLARED_BIN:-cloudflared}" 2>/dev/null || true
                success "已停止。配置仍在 ${CONFIG_DIR:-/usr/local/etc/xray}，可用菜单 14 再启动"
                return
                ;;
            1) ;;
            *) info "已取消"; return ;;
        esac
        echo
        warn "危险操作：请输入大写 YES 确认彻底清理"
        read -p "请输入 YES 后回车: " confirm
        [[ $confirm == "YES" ]] || { info "已取消（未输入 YES）"; return; }
    else
        info "强制模式：跳过确认，直接彻底清理"
    fi

    info "开始彻底清理..."
    _PURGE_SELF=1
    purge_all

    if [[ -f /swapfile ]]; then
        swapoff /swapfile 2>/dev/null || true
        rm -f /swapfile
        success "已删除本脚本创建的 /swapfile"
    fi
    local _other_swap
    _other_swap=$(get_swap_total_mem 2>/dev/null || echo 0)
    if (( _other_swap > 0 )); then
        info "检测到其它 Swap 约 ${_other_swap}MB，已保留未动"
    fi
    [[ -f /etc/fstab ]] && safe_sed '/\/swapfile/d' /etc/fstab 2>/dev/null || true

    if [[ -f /etc/sysctl.conf ]]; then
        safe_sed '/# BBR by smart-node/d' /etc/sysctl.conf 2>/dev/null || true
        safe_sed '/# smart-node low-mem optimize/d' /etc/sysctl.conf 2>/dev/null || true
        safe_sed '/net.core.default_qdisc=fq/d' /etc/sysctl.conf 2>/dev/null || true
        safe_sed '/net.ipv4.tcp_congestion_control=bbr/d' /etc/sysctl.conf 2>/dev/null || true
        safe_sed '/vm.swappiness=10/d' /etc/sysctl.conf 2>/dev/null || true
        safe_sed '/vm.dirty_ratio=10/d' /etc/sysctl.conf 2>/dev/null || true
        safe_sed '/vm.dirty_background_ratio=5/d' /etc/sysctl.conf 2>/dev/null || true
        safe_sed '/vm.vfs_cache_pressure=50/d' /etc/sysctl.conf 2>/dev/null || true
        safe_sed '/net.ipv4.tcp_fastopen=3/d' /etc/sysctl.conf 2>/dev/null || true
        safe_sed '/net.ipv4.tcp_slow_start_after_idle=0/d' /etc/sysctl.conf 2>/dev/null || true
        sysctl -p >/dev/null 2>&1 || true
        success "已清理本脚本写入的系统参数"
    fi
    rm -f /etc/sysctl.d/99-smart-node.conf 2>/dev/null || true

    pkill -9 -f xray 2>/dev/null || true
    pkill -9 -f cloudflared 2>/dev/null || true

    echo
    title "========== 清理完成 · 残留检查 =========="
    local left=0
    echo -n "进程: "
    if ps 2>/dev/null | grep -qE '[x]ray|[c]loudflared'; then
        echo -e "${RED}仍有残留${NC}"
        ps 2>/dev/null | grep -E '[x]ray|[c]loudflared' || true
        left=1
    else
        echo "无"
    fi
    echo -n "二进制: "
    local bins=""
    for f in /usr/local/bin/xray /usr/local/bin/cloudflared /usr/local/bin/smart-node-keepalive; do
        [[ -e $f ]] && bins="$bins $f"
    done
    if [[ -n $bins ]]; then
        echo -e "${RED}残留$bins${NC}"
        left=1
    else
        echo "无"
    fi
    echo -n "配置目录: "
    if [[ -d /usr/local/etc/xray ]]; then
        echo -e "${YELLOW}仍存在 /usr/local/etc/xray${NC}"
        left=1
    else
        echo "无"
    fi
    echo -n "定时保活: "
    if crontab -l 2>/dev/null | grep -q smart-node-keepalive; then
        echo -e "${YELLOW}仍有${NC}"
        left=1
    else
        echo "无"
    fi
    echo -n "临时下载: "
    local tmp_left
    tmp_left=$(ls /tmp/xray_dl_* /tmp/cf_dl_* /tmp/smart-node-update-* 2>/dev/null | head -3)
    if [[ -n $tmp_left ]]; then
        echo -e "${YELLOW}仍有（已尽量删除）${NC}"
        left=1
    else
        echo "无"
    fi
    echo
    if (( left == 0 )); then
        success "一键清理完成，本脚本相关内容已全部清除。"
    else
        warn "仍有少量残留，可再执行："
        echo "  bash smart-node.sh 清理 --强制"
        echo "  或: rm -rf /usr/local/etc/xray /usr/local/bin/xray /usr/local/bin/cloudflared"
    fi
    _PURGE_SELF=0
    echo -e "${CYAN}=====================================${NC}"
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
    # 必须用 mv 原子替换（rename 换 inode）。bash 是边读边执行脚本的，
    # 直接 cp 覆盖正在运行的文件会让它读到半截内容，脚本当场崩掉。
    local newf="${self}.new.$$"
    if cp -f "$tmp" "$newf" 2>/dev/null && mv -f "$newf" "$self" 2>/dev/null; then
        chmod +x "$self" 2>/dev/null || true
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
_write_keepalive_helper() {
    cat > "$KEEPALIVE_HELPER" << 'KEEP'
#!/bin/sh
# smart-node keepalive v5.1 — 覆盖 quick / named / reality
INFO="/usr/local/etc/xray/node.info"
CFG="/usr/local/etc/xray/config.json"
XRAY="/usr/local/bin/xray"
CF="/usr/local/bin/cloudflared"
LOG_CF="/tmp/cloudflared-argo.log"
LOG_X="/tmp/xray-argo.log"
LOCK="/tmp/smart-node-keepalive.lock"
DLOGF="/tmp/smart-node-argo-domain.log"

[ -f "$INFO" ] || exit 0

if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK" 2>/dev/null || exit 0
  flock -n 9 || exit 0
else
  if [ -f "$LOCK" ]; then
    old=$(cat "$LOCK" 2>/dev/null)
    [ -n "$old" ] && kill -0 "$old" 2>/dev/null && exit 0
  fi
  echo $$ > "$LOCK" 2>/dev/null
  trap 'rm -f "$LOCK" 2>/dev/null' EXIT
fi

MODE=$(grep -m1 '^NODE_MODE=' "$INFO" 2>/dev/null | cut -d= -f2-)
PORT=$(grep -m1 '^PORT=' "$INFO" 2>/dev/null | cut -d= -f2-)
TTYPE=$(grep -m1 '^TUNNEL_TYPE=' "$INFO" 2>/dev/null | cut -d= -f2-)
TOKEN=$(grep -m1 '^CF_TOKEN=' "$INFO" 2>/dev/null | cut -d= -f2-)
FHOST=$(grep -m1 '^FIXED_HOST=' "$INFO" 2>/dev/null | cut -d= -f2-)
[ -z "$PORT" ] && PORT=30000
MODE=${MODE:-reality}
TTYPE=${TTYPE:-quick}
[ -x "$XRAY" ] || exit 0
[ -f "$CFG" ] || exit 0

alive_xray() {
  command -v pgrep >/dev/null 2>&1 && pgrep -f "$XRAY" >/dev/null 2>&1 && return 0
  ps 2>/dev/null | grep -v grep | grep -q '[x]ray run' && return 0
  return 1
}
alive_cf() {
  command -v pgrep >/dev/null 2>&1 && pgrep -f "$CF" >/dev/null 2>&1 && return 0
  ps 2>/dev/null | grep -v grep | grep -q '[c]loudflared' && return 0
  return 1
}
cf_url() {
  grep -oE 'https://[a-zA-Z0-9][a-zA-Z0-9.-]*\.trycloudflare\.com' "$LOG_CF" 2>/dev/null | tail -n 1 | sed 's|^https://||'
}

start_cf_quick() {
  EIP=""
  "$CF" tunnel --help 2>&1 | grep -q -- '--edge-ip-version' && EIP="--edge-ip-version 4"
  : > "$LOG_CF" 2>/dev/null
  nohup "$CF" tunnel --url "http://127.0.0.1:${PORT}" --no-autoupdate --protocol quic >"$LOG_CF" 2>&1 &
  i=0
  while [ $i -lt 10 ]; do
    sleep 1
    [ -n "$(cf_url)" ] && return 0
    i=$((i+1))
  done
  pkill -f "$CF tunnel" 2>/dev/null
  sleep 1
  : > "$LOG_CF" 2>/dev/null
  nohup "$CF" tunnel --url "http://127.0.0.1:${PORT}" --no-autoupdate --protocol http2 $EIP >"$LOG_CF" 2>&1 &
  i=0
  while [ $i -lt 12 ]; do
    sleep 1
    [ -n "$(cf_url)" ] && return 0
    i=$((i+1))
  done
  return 1
}

start_cf_named() {
  [ -n "$TOKEN" ] || return 1
  : > "$LOG_CF" 2>/dev/null
  nohup "$CF" tunnel --no-autoupdate run --token "$TOKEN" >"$LOG_CF" 2>&1 &
  i=0
  while [ $i -lt 15 ]; do
    sleep 1
    if grep -qiE 'Registered tunnel connection|Connection registered|Connected to' "$LOG_CF" 2>/dev/null; then
      return 0
    fi
    command -v pgrep >/dev/null 2>&1 && pgrep -f "$CF" >/dev/null 2>&1 && [ $i -gt 5 ] && return 0
    i=$((i+1))
  done
  alive_cf && return 0
  return 1
}

if [ "$MODE" = "argo" ]; then
  if ! alive_xray; then
    nohup "$XRAY" run -c "$CFG" >"$LOG_X" 2>&1 &
    sleep 2
  fi
  if ! alive_cf; then
    if [ "$TTYPE" = "named" ]; then
      start_cf_named >/dev/null 2>&1
    else
      start_cf_quick >/dev/null 2>&1
    fi
  fi
  # Quick 才需要域名回写；named 用 FIXED_HOST
  if [ "$TTYPE" != "named" ]; then
    NEW_URL=$(cf_url)
    if [ -n "$NEW_URL" ]; then
      CUR_URL=$(grep -m1 '^ARGO_URL=' "$INFO" 2>/dev/null | cut -d= -f2-)
      if [ "$NEW_URL" != "$CUR_URL" ]; then
        if grep -q '^ARGO_URL=' "$INFO" 2>/dev/null; then
          tmp="${INFO}.sn.$$"
          sed "s|^ARGO_URL=.*|ARGO_URL=${NEW_URL}|" "$INFO" > "$tmp" 2>/dev/null && mv -f "$tmp" "$INFO"
        else
          echo "ARGO_URL=${NEW_URL}" >> "$INFO" 2>/dev/null
        fi
        echo "$(date '+%Y-%m-%d %H:%M:%S') argo domain -> ${NEW_URL}" >> "$DLOGF" 2>/dev/null
      fi
    fi
  fi
else
  if ! alive_xray; then
    nohup "$XRAY" run -c "$CFG" >"$LOG_X" 2>&1 &
  fi
fi
exit 0
KEEP
    chmod +x "$KEEPALIVE_HELPER" 2>/dev/null || true
}

setup_keepalive() {
    echo
    title "========== crontab 保活 =========="
    if has_systemd; then
        info "已有 systemd，一般不需要 crontab 保活"
        read -p "仍要安装？(y/N): " c
        [[ $c != "y" && $c != "Y" ]] && return
    fi
    if ! command -v crontab >/dev/null 2>&1; then
        error "系统没有 crontab（Alpine 先执行: apk add dcron && rc-update add dcron default）"
        return
    fi
    load_info
    local marker="# smart-node-keepalive"
    local line="*/2 * * * * ${KEEPALIVE_HELPER} ${marker}"

    _write_keepalive_helper

    echo "保活脚本: ${KEEPALIVE_HELPER}"
    echo "crontab : 每 2 分钟检查一次"
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        echo
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            info "固定隧道：进程保活即可，域名由 CF 控制台决定，不会变"
        else
            warn "Quick 隧道：进程能保活；隧道重建后域名会变"
            warn "脚本会把新域名写回 node.info，回来跑菜单 2 / 24 即可"
        fi
    fi
    echo
    echo "  1) 安装/更新保活"
    echo "  2) 立即跑一次（测试用）"
    echo "  3) 移除保活"
    echo "  0) 取消"
    read -p "选择: " k
    local ct
    ct=$(crontab -l 2>/dev/null | grep -v 'smart-node-keepalive' || true)
    case $k in
        1)
            (echo "$ct"; echo "$line") | crontab - 2>/dev/null
            if crontab -l 2>/dev/null | grep -q 'smart-node-keepalive'; then
                success "已安装 crontab 保活（每 2 分钟）"
            else
                error "写入 crontab 失败，请手动执行: crontab -e"
            fi
            ;;
        2)
            info "手动执行一次保活脚本..."
            sh "$KEEPALIVE_HELPER" && success "执行完成（无输出即正常）"
            ;;
        3)
            echo "$ct" | crontab - 2>/dev/null
            rm -f "$KEEPALIVE_HELPER"
            success "已移除保活"
            ;;
        *) info "已取消" ;;
    esac
}

show_menu() {
    safe_clear
    local mem st dom="" tlabel=""
    mem=$(get_total_mem)
    st="未安装"

    if [[ -f $INFO_FILE ]]; then
        load_info
        if [[ ${NODE_MODE:-reality} == "argo" ]]; then
            if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
                tlabel="固定隧道"
            else
                tlabel="Argo Quick"
            fi
            if proc_alive "$CLOUDFLARED_BIN" && proc_alive "$XRAY_BIN"; then
                st="${GREEN}${tlabel} 运行中${NC}"
            elif proc_alive "$CLOUDFLARED_BIN"; then
                st="${YELLOW}隧道在跑 / Xray 未运行${NC}"
            else
                st="${RED}${tlabel} 未运行${NC}"
            fi
            if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
                dom=${FIXED_HOST:-$ARGO_URL}
            else
                [[ -n $ARGO_URL ]] && dom=$ARGO_URL
            fi
        else
            st="${GREEN}REALITY${NC} 端口 ${PORT:-?}"
        fi
    fi

    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} 智能节点 v${SCRIPT_VERSION}${NC}  ${YELLOW}${mem}MB${NC} 压力:$(get_mem_pressure_hint)"
    echo -e " 状态: ${st}"
    [[ -n $dom ]] && echo -e " 域名: ${YELLOW}${dom}${NC}"
    echo -e "${BLUE}================================${NC}"
    echo " 【核心】"
    echo "  1. 安装节点（NAT 推荐 Argo/固定隧道）"
    echo "  2. 看链接 / 客户端配置 / 二维码"
    echo "  3. 导出完整信息到文件"
    echo "  4. 导出 Base64 订阅"
    echo
    echo " 【REALITY 专用】"
    echo "  5. 改端口     6. 换 UUID    7. 换伪装目标"
    echo "  8. 换密钥     9. 改 ShortID"
    echo " 10. 加用户    11. 删用户"
    echo
    echo " 【运维】"
    echo " 12. 自检（进程/端口/配置/dest）"
    echo " 13. 看日志    14. 重启服务"
    echo " 15. 运行状态  16. 开 BBR"
    echo " 17. 更新内核  18. 系统参数优化"
    echo " 19. 分流建议  20. 第三方脚本引导"
    echo
    echo " 【维护】"
    echo " 21. 一键清理全部（命令: 清理 --强制）"
    echo " 22. 更新本脚本"
    echo " 23. crontab 保活（无 systemd 必备）"
    echo " 24. 刷新 Quick 域名"
    echo " 25. 固定隧道 Token / 域名"
    echo
    echo "  0. 退出"
    echo -e "${BLUE}================================${NC}"
}

# ======================== CLI 入口（可无交互） ========================
# 用法:
#   bash smart-node.sh                  # 交互菜单
#   bash smart-node.sh uninstall        # 一键删除（需输入 YES）
#   bash smart-node.sh uninstall --force
#   bash smart-node.sh purge --force    # 同上
#   bash smart-node.sh status
#   bash smart-node.sh link
#   bash smart-node.sh restart
cli_main() {
    local cmd=${1:-} force=0
    shift || true
    local a
    for a in "$@"; do
        case $a in
            --force|-f|force|强制|--强制) force=1; SMART_NODE_FORCE=1 ;;
        esac
    done
    case $cmd in
        uninstall|purge|remove|delete|清理|卸载|删除|--uninstall|--purge)
            if (( force )); then
                uninstall_node force
            else
                uninstall_node
            fi
            exit 0
            ;;
        status|--status|状态)
            status_xray
            exit 0
            ;;
        link|url|show|--link|链接)
            show_link
            exit 0
            ;;
        restart|--restart|重启)
            restart_xray
            exit 0
            ;;
        help|-h|--help|帮助)
            echo "智能节点脚本 v${SCRIPT_VERSION}"
            echo "用法："
            echo "  bash smart-node.sh              进入中文交互菜单"
            echo "  bash smart-node.sh 清理         一键清理本脚本全部内容（需输入 YES）"
            echo "  bash smart-node.sh 清理 --强制  无确认直接清理"
            echo "  bash smart-node.sh 状态         查看运行状态"
            echo "  bash smart-node.sh 链接         显示分享链接"
            echo "  bash smart-node.sh 重启         重启服务"
            echo "  bash smart-node.sh 帮助         显示本说明"
            echo
            echo "英文别名同样可用: uninstall / purge / status / link / restart"
            exit 0
            ;;
        "")
            return 0
            ;;
        *)
            return 0
            ;;
    esac
}

if [[ ${1:-} != "" ]]; then
    cli_main "$@"
    # cli_main 在处理完会 exit；未识别则继续进菜单
fi

while true; do
    show_menu
    read -p "请输入选项 [0-25]: " choice
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
        19) smart_route_advice ;;
        20) run_full_script_menu ;;
        21) uninstall_node ;;
        22) update_script ;;
        23) setup_keepalive ;;
        24)
            load_info
            if [[ ${NODE_MODE:-} != "argo" ]]; then
                warn "当前不是隧道模式"
            elif [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
                info "当前是固定隧道，域名由 CF 控制台决定，不会从日志刷新"
                info "改域名请用菜单 25；或到 Cloudflare 改 Public Hostname"
                [[ -n ${FIXED_HOST:-$ARGO_URL} ]] && echo "当前域名: ${FIXED_HOST:-$ARGO_URL}"
            else
                info "从隧道日志读取最新 Quick 域名..."
                refresh_argo_url
                case $? in
                    0) success "域名已更新" ;;
                    2) info "域名没变，还是 ${ARGO_URL:-（空）}" ;;
                    *) warn "日志里没有可用域名，隧道可能没在跑 → 先菜单 15 看状态，再菜单 14 重启" ;;
                esac
                show_link
            fi
            ;;
        25) update_named_tunnel ;;
        0)  echo "已退出"; exit 0 ;;
        "") warn "请输入选项数字" ;;
        *)  warn "无效选项，请输入 0–25" ;;
    esac
    echo
    read -p "按回车返回菜单…" _
done
