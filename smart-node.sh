#!/bin/bash
# ============================================================
# 智能内存检测 + 交互式 VLESS + REALITY 节点脚本
# v5.8.3  小机无公网IP：连接地址支持域名（SN_ADDR/SN_DOMAIN）
# v5.8.2  体验迭代：菜单状态/订阅统一/手机复制提示/装完引导
# v5.8.1  多轮审计：hy2-only安装/破损SS行/无域名链接/内存回退/保活
# v5.8.0  可选全家桶（Hy2/TUIC 等）；默认不装不跑；用户自选才启用
# v5.7.1  对照主流：订阅导出/优选IP/版本与协议提示强化
# v5.7.0  协议完全自选搭配（SN_PROTOCOLS）；未指定时兼容默认 VLESS
# v5.6.1  默认仅 VLESS(64/128)；按需装协议；区分隧道/直连；不预装附加
# v5.6.0  扩展可选 Trojan/SS；附加协议规范化；深度修 port/内存门槛
# v5.5.0  面板可选附加协议（默认关闭=极限内存）；VMess-WS 第二端口
# v5.4.4  全方位审计：端口判定/安装引导/域名探测/菜单路径提示
# v5.4.3  深度自检：进程探测/CLI误粘链接/体检提示/落盘脚本
# v5.4.2  对照主流查漏：域名墙提示/CF路径/脚本定位/面板友好
# v5.4.1  全网实践精细化：maxTimeDiff/一键体检/dest 警示
# v5.4.0  深度查漏补缺 + 实用工具箱（网络诊断/时钟/资源/端口/轻清理）
# v5.3.1  第三方脚本引导扩充（多协议+单协议）+ 文案打磨
# v5.3.0  全客户端兼容增强：Argo/REALITY 链接与片段一次性打磨
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
EXTRA_PROTOCOLS=""   # 用户自选全家桶；空=兼容默认仅 vless；未选项不装不跑
VMESS_PORT=""
VMESS_PATH=""
VMESS_UUID=""
TROJAN_PORT=""
TROJAN_PATH=""
TROJAN_PASS=""
SS_PORT=""
SS_PATH=""
SS_METHOD="aes-128-gcm"
SS_PASS=""
# 直连类（不走 CF 隧道；仅用户勾选时安装运行）
HY2_BIN="/usr/local/bin/hysteria"
HY2_CFG="${CONFIG_DIR}/hy2.yaml"
HY2_PORT=""
HY2_PASS=""
HY2_PIDFILE="/tmp/smart-node-hy2.pid"
HY2_LOG="/tmp/smart-node-hy2.log"
TUIC_BIN="/usr/local/bin/tuic-server"
TUIC_CFG="${CONFIG_DIR}/tuic.json"
TUIC_PORT=""
TUIC_PASS=""
TUIC_PIDFILE="/tmp/smart-node-tuic.pid"
TUIC_LOG="/tmp/smart-node-tuic.log"
SCRIPT_VERSION="5.8.5"
SCRIPT_DATE="2026-10-24"
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
    title "========== 第三方脚本引导（需确认） =========="
    echo -e "${YELLOW}警告：以下均为第三方脚本，代码不由本脚本维护。${NC}"
    echo "请自行确认来源与风险；低内存机器强不建议安装重型脚本。"
    echo
    local mem
    mem=$(get_total_mem 2>/dev/null || echo 0)
    if (( mem > 0 && mem <= 512 )); then
        echo -e "${RED}当前总内存约 ${mem}MB，安装多协议/面板类脚本极易 OOM。${NC}"
        echo -e "${RED}建议优先本脚本 Argo/REALITY，或升级内存后再试。${NC}"
        echo
    fi

    echo "【多协议 / 全家桶】"
    echo "  1) 233boy/Xray          — Xray 多配置，常用、相对轻"
    echo "  2) mack-a/v2ray-agent   — 八合一，功能全，较重"
    echo "  3) yonggekkk/sing-box-yg — sing-box 多协议 + 常用增强"
    echo "  4) fscarmen/sing-box    — sing-box 一键，协议较全"
    echo
    echo "【偏单协议 / 轻量】"
    echo "  5) ndatg REALITY 一键   — 纯 VLESS+REALITY，简单"
    echo "  6) 官方 Xray 安装脚本   — 只装核心，配置需自写"
    echo "  7) helloyunshu 一键     — Reality + 多协议可选"
    echo
    echo "【面板类 · 更重】"
    echo "  8) 3x-ui                — 网页面板，占资源，需 ≥1GB 更稳"
    echo
    echo "  0) 取消，返回"
    echo
    read -p "请选择 [0-8]: " fs

    _run_third_party() {
        local name=$1
        local hint=$2
        shift 2
        echo
        warn "即将执行：${name}"
        [[ -n $hint ]] && echo -e "${YELLOW}${hint}${NC}"
        read -p "确认执行？(y/N): " c
        [[ $c != "y" && $c != "Y" ]] && { info "已取消"; return; }
        "$@"
    }

    case $fs in
        1)
            _run_third_party "233boy/Xray" "相对常用，仍可能拉依赖。" \
                bash -c 'bash <(wget -qO- -o- https://github.com/233boy/Xray/raw/main/install.sh)'
            ;;
        2)
            _run_third_party "mack-a/v2ray-agent" "体积与依赖较大，低内存慎用。" \
                bash -c 'wget -P /root -N --no-check-certificate "https://raw.githubusercontent.com/mack-a/v2ray-agent/master/install.sh" && chmod 700 /root/install.sh && /root/install.sh'
            ;;
        3)
            _run_third_party "yonggekkk/sing-box-yg" "sing-box 多协议，需较好网络拉镜像。" \
                bash -c 'bash <(curl -Ls https://raw.githubusercontent.com/yonggekkk/sing-box-yg/main/sb.sh)'
            ;;
        4)
            _run_third_party "fscarmen/sing-box" "sing-box 一键，选项较多。" \
                bash -c 'bash <(wget -qO- -o- https://raw.githubusercontent.com/fscarmen/sing-box/main/sing-box.sh)'
            ;;
        5)
            _run_third_party "ndatg VLESS+REALITY" "偏单协议，相对轻量。" \
                bash -c 'wget -qO /tmp/xray-install.sh https://raw.githubusercontent.com/ndatg/xray-vless-reality-installer/main/xray-install.sh && bash /tmp/xray-install.sh'
            ;;
        6)
            _run_third_party "官方 Xray-install" "仅安装 Xray 核心，不生成节点配置。" \
                bash -c 'bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install'
            ;;
        7)
            _run_third_party "hello-yunshu/Xray_bash_onekey" "多协议可选，请按提示选择。" \
                bash -c 'bash <(curl -fsSL https://github.com/hello-yunshu/Xray_bash_onekey/releases/latest/download/install.sh)'
            ;;
        8)
            if (( mem > 0 && mem < 1024 )); then
                echo -e "${RED}内存低于 1GB，强烈不建议安装面板。${NC}"
                read -p "仍要继续？(y/N): " c
                [[ $c != "y" && $c != "Y" ]] && return
            fi
            _run_third_party "3x-ui 面板" "网页面板，占用明显高于单节点脚本。" \
                bash -c 'bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)'
            ;;
        0|"")
            info "已取消"
            ;;
        *)
            warn "无效选项"
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
    # 过滤内网/回环（很多 NAT 小机 hostname -I 只有内网）
    if [[ -z $ip ]]; then
        ip=$(hostname -I 2>/dev/null | awk '{print $1}')
        if [[ $ip =~ ^10\. || $ip =~ ^192\.168\. || $ip =~ ^172\.(1[6-9]|2[0-9]|3[0-1])\. || $ip == "127.0.0.1" ]]; then
            ip=""
        fi
    fi
    _CACHE_IP=$ip
    _CACHE_IP_TS=$now
    echo "$ip"
}

# 直连节点地址：优先用户指定（域名或公网IP），再探测公网IP
# 很多小机不给公网 IP、只给访问域名 → 用 SN_ADDR / SN_DOMAIN / SERVER_DOMAIN
get_server_addr() {
    local a
    a=${SN_ADDR:-${SN_DOMAIN:-${SN_IP:-${SERVER_DOMAIN:-${SERVER_ADDR:-}}}}}
    a=$(echo "$a" | tr -d '[:space:]')
    a=${a#https://}; a=${a#http://}; a=${a%%/*}
    if [[ -n $a ]]; then
        echo "$a"
        return
    fi
    # node.info 里若存的是域名也认
    if [[ -n ${SERVER_IP:-} ]]; then
        if [[ $SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            if [[ ! $SERVER_IP =~ ^10\. && ! $SERVER_IP =~ ^192\.168\. && $SERVER_IP != "127.0.0.1" ]]; then
                echo "$SERVER_IP"
                return
            fi
        else
            # 非纯数字 → 当作域名
            echo "$SERVER_IP"
            return
        fi
    fi
    a=$(get_ip)
    if [[ -n $a ]]; then
        echo "$a"
        return
    fi
    # 最后：固定隧道域名也可作展示（仅当用户没填直连地址时）
    a=${FIXED_HOST:-${ARGO_URL:-}}
    a=${a#https://}; a=${a#http://}; a=${a%%/*}
    echo "$a"
}

# 安装/改链时：确保有可用连接地址（IP 或域名）
ensure_server_addr() {
    local need_prompt=${1:-0} a
    a=$(get_server_addr)
    if [[ -n $a ]]; then
        SERVER_IP=$a
        return 0
    fi
    if [[ $need_prompt == "1" ]] || [[ -t 0 ]]; then
        echo
        warn "未探测到公网 IP（很多 NAT 小机只给域名不给 IP）"
        info "请填写面板提供的访问域名，或任意可达公网 IP"
        info "也可用环境变量: SN_ADDR=vps.example.com"
        read -p "服务器地址（域名或IP）: " a
        a=$(echo "$a" | tr -d '[:space:]')
        a=${a#https://}; a=${a#http://}; a=${a%%/*}
        if [[ -n $a ]]; then
            SERVER_IP=$a
            SN_ADDR=$a
            success "连接地址: $SERVER_IP"
            return 0
        fi
    fi
    warn "连接地址仍为空：直连协议链接将不完整，请稍后 SN_ADDR=域名 bash /root/smart-node.sh 地址"
    return 1
}

set_server_addr() {
    load_info
    echo
    title "========== 设置连接地址（域名/IP） =========="
    echo "用于 REALITY / Hy2 / TUIC 等直连分享链接"
    echo "当前: ${SERVER_IP:-（空）}"
    echo "说明: 无公网 IP 的小机填商家给的域名即可"
    read -p "新地址（域名或IP，回车取消）: " a
    a=$(echo "$a" | tr -d '[:space:]')
    a=${a#https://}; a=${a#http://}; a=${a%%/*}
    [[ -z $a ]] && { info "已取消"; return; }
    SERVER_IP=$a
    # 写回 node.info
    if [[ -f $INFO_FILE ]]; then
        if grep -q '^SERVER_IP=' "$INFO_FILE" 2>/dev/null; then
            safe_sed "s|^SERVER_IP=.*|SERVER_IP=$SERVER_IP|" "$INFO_FILE"
        else
            echo "SERVER_IP=$SERVER_IP" >> "$INFO_FILE"
        fi
        chmod 600 "$INFO_FILE" 2>/dev/null || true
    fi
    success "已保存连接地址: $SERVER_IP"
    show_link
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
    # 非法端口视为不可用，避免把空端口当成"空闲"
    [[ $port =~ ^[0-9]+$ ]] || return 1
    (( 10#$port >= 1 && 10#$port <= 65535 )) || return 1
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

    local extra_json="" inbounds_json=""
    if proto_has vless; then
        inbounds_json='
    {
      "listen": "127.0.0.1",
      "port": '"${port}"',
      "protocol": "vless",
      "settings": {
        "clients": [ { "id": "'"${uuid}"'", "email": "argo" } ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "'"${path}"'" }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "routeOnly": true
      }
    }'
    fi
    extra_json+=$(_argo_inbound_vmess)
    extra_json+=$(_argo_inbound_trojan)
    extra_json+=$(_argo_inbound_ss)
    # 若未选 vless，附加段开头可能带逗号，去掉
    if [[ -z $inbounds_json && -n $extra_json ]]; then
        extra_json=${extra_json#,}
        inbounds_json=$extra_json
        extra_json=""
    fi
    if [[ -z $inbounds_json && -z $extra_json ]]; then
        error "未选择任何协议（请在面板勾选或设置 SN_PROTOCOLS）"
        return 1
    fi

    cat > "$CONFIG_FILE" << EOF
{
  "log": { "loglevel": "none" },
  "inbounds": [
    ${inbounds_json}${extra_json}
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

_argo_inbound_vmess() {
    extra_has vmess || return 0
    local vm_uuid vm_port vm_path
    vm_uuid=$(echo "${VMESS_UUID:-$UUID}" | tr -cd '0-9a-fA-F-')
    vm_port=${VMESS_PORT:-}
    vm_path=$(echo "${VMESS_PATH:-/vmess}" | tr -cd 'A-Za-z0-9/_-')
    [[ $vm_path == /* ]] || vm_path="/$vm_path"
    [[ $vm_port =~ ^[0-9]+$ && -n $vm_uuid ]] || return 0
    printf '%s' ',
    {
      "listen": "127.0.0.1",
      "port": '"${vm_port}"',
      "protocol": "vmess",
      "settings": {
        "clients": [ { "id": "'"${vm_uuid}"'", "alterId": 0, "email": "vmess-argo" } ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "'"${vm_path}"'" }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "routeOnly": true
      }
    }'
}

_argo_inbound_trojan() {
    extra_has trojan || return 0
    local tp tpath tpass
    tp=${TROJAN_PORT:-}
    tpath=$(echo "${TROJAN_PATH:-/trojan}" | tr -cd 'A-Za-z0-9/_-')
    [[ $tpath == /* ]] || tpath="/$tpath"
    tpass=$(echo "${TROJAN_PASS:-$UUID}" | tr -d '\r\n"\\')
    [[ $tp =~ ^[0-9]+$ && -n $tpass ]] || return 0
    printf '%s' ',
    {
      "listen": "127.0.0.1",
      "port": '"${tp}"',
      "protocol": "trojan",
      "settings": {
        "clients": [ { "password": "'"${tpass}"'", "email": "trojan-argo" } ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "'"${tpath}"'" }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "routeOnly": true
      }
    }'
}

_argo_inbound_ss() {
    extra_has ss || return 0
    local sp spath smethod spass
    sp=${SS_PORT:-}
    spath=$(echo "${SS_PATH:-/ss}" | tr -cd 'A-Za-z0-9/_-')
    [[ $spath == /* ]] || spath="/$spath"
    smethod=${SS_METHOD:-aes-128-gcm}
    spass=$(echo "${SS_PASS:-}" | tr -d '\r\n"\\')
    [[ -z $spass ]] && return 0
    [[ $sp =~ ^[0-9]+$ ]] || return 0
    printf '%s' ',
    {
      "listen": "127.0.0.1",
      "port": '"${sp}"',
      "protocol": "shadowsocks",
      "settings": {
        "method": "'"${smethod}"'",
        "password": "'"${spass}"'",
        "network": "tcp"
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": { "path": "'"${spath}"'" }
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["http", "tls"],
        "routeOnly": true
      }
    }'
}

build_vmess_link() {
    local uid=${1:-$VMESS_UUID} host=${2:-$ARGO_URL} path=${3:-$VMESS_PATH} name=${4:-智能隧道-vmess}
    host=${host#https://}; host=${host#http://}; host=${host%%/*}
    path=$(echo "${path:-/vmess}" | tr -cd 'A-Za-z0-9/_-')
    [[ $path == /* ]] || path="/$path"
    uid=$(echo "$uid" | tr -cd '0-9a-fA-F-')
    [[ -z $uid || -z $host ]] && return 1
    name=$(echo "$name" | tr -d '"\\')
    local json b64
    json=$(printf '{"v":"2","ps":"%s","add":"%s","port":"443","id":"%s","aid":"0","scy":"auto","net":"ws","type":"none","host":"%s","path":"%s","tls":"tls","sni":"%s","fp":"chrome"}' \
        "$name" "$host" "$uid" "$host" "$path" "$host")
    if command -v base64 >/dev/null 2>&1; then
        b64=$(printf '%s' "$json" | base64 -w0 2>/dev/null || printf '%s' "$json" | base64 | tr -d '\n')
        echo "vmess://${b64}"
    else
        return 1
    fi
}

build_trojan_link() {
    local pass=${1:-$TROJAN_PASS} host=${2:-$ARGO_URL} path=${3:-$TROJAN_PATH} name=${4:-智能隧道-trojan}
    host=${host#https://}; host=${host#http://}; host=${host%%/*}
    path=$(echo "${path:-/trojan}" | tr -cd 'A-Za-z0-9/_-')
    [[ $path == /* ]] || path="/$path"
    local path_q
    path_q=$(echo -n "$path" | sed 's|/|%2F|g')
    pass=$(echo "$pass" | tr -d '\r\n')
    [[ -z $pass || -z $host ]] && return 1
    name=$(echo "$name" | sed 's/ /%20/g')
    echo "trojan://${pass}@${host}:443?type=ws&security=tls&path=${path_q}&host=${host}&sni=${host}&fp=chrome#${name}"
}

build_ss_link() {
    # ss://base64(method:pass)@host:443?plugin=...  简化：SIP002 + 无 plugin 时部分客户端要 WS 插件
    # 输出标准 ss + 备注：需客户端支持 WS 或手动填
    local method=${1:-$SS_METHOD} pass=${2:-$SS_PASS} host=${3:-$ARGO_URL} path=${4:-$SS_PATH} name=${5:-智能隧道-ss}
    host=${host#https://}; host=${host#http://}; host=${host%%/*}
    path=$(echo "${path:-/ss}" | tr -cd 'A-Za-z0-9/_-')
    [[ $path == /* ]] || path="/$path"
    [[ -z $pass || -z $host ]] && return 1
    local user b64
    user="${method}:${pass}"
    b64=$(printf '%s' "$user" | base64 -w0 2>/dev/null || printf '%s' "$user" | base64 | tr -d '\n')
    # 备注路径，兼容性因客户端而异
    echo "ss://${b64}@${host}:443#${name}-ws${path}"
}

# 规范化协议列表（用户自选搭配）：小写、去空、去重
# 允许: vless, vmess, trojan, ss
normalize_extra_protocols() {
    local raw=${1:-$EXTRA_PROTOCOLS} out="" x
    raw=$(echo "$raw" | tr 'A-Z' 'a-z' | tr ',;' ' ' | tr -s ' ')
    for x in $raw; do
        case $x in
            vless|vmess|trojan|ss|shadowsocks|hy2|hysteria2|hysteria|tuic)
                [[ $x == shadowsocks ]] && x=ss
                [[ $x == hysteria2 || $x == hysteria ]] && x=hy2
                [[ ",$out," == *",$x,"* ]] && continue
                out="${out:+$out,}$x"
                ;;
        esac
    done
    EXTRA_PROTOCOLS=$out
}

# 是否包含某协议。列表为空时：兼容旧行为，视为「仅 vless」
proto_has() {
    local want=$1
    [[ -z $want ]] && return 1
    local list=${EXTRA_PROTOCOLS:-}
    if [[ -z $list ]]; then
        [[ $want == vless ]] && return 0
        return 1
    fi
    [[ ",${list}," == *",${want},"* ]]
}

# 兼容旧名
extra_has() { proto_has "$1"; }

# 是否含隧道类协议（需 xray + cloudflared）
has_tunnel_proto() {
    proto_has vless || proto_has vmess || proto_has trojan || proto_has ss
}

has_direct_proto() {
    proto_has hy2 || proto_has tuic
}

# 附加协议内存门槛：每种约加一档
extra_mem_ok() {
    local tm need=128 n
    tm=$(get_total_mem)
    [[ -z ${EXTRA_PROTOCOLS:-} ]] && return 0
    # 仅含 vless 时不拦
    if [[ ${EXTRA_PROTOCOLS} == "vless" ]]; then
        return 0
    fi
    # 含 hy2/tuic：建议 ≥256MB
    if proto_has hy2 || proto_has tuic; then
        need=256
        (( tm >= need )) && return 0
        return 1
    fi
    if (( tm < 128 )); then
        return 1
    fi
    n=$(echo "${EXTRA_PROTOCOLS:-}" | awk -F',' 'NF==0{print 0; exit} {print NF}')
    need=128
    (( n >= 2 )) && need=180
    (( n >= 3 )) && need=256
    (( tm >= need )) && return 0
    return 1
}

# 从 start 起找空闲本机端口
alloc_local_port() {
    local start=${1:-40000} try=0 p
    p=$start
    while ! check_port_free "$p" && (( try < 40 )); do
        p=$((p + 1))
        try=$((try + 1))
    done
    echo "$p"
}

load_panel_env() {
    # 协议完全自选：SN_PROTOCOLS 优先，其次 SN_EXTRA
    if [[ -n ${SN_PROTOCOLS:-} ]]; then
        EXTRA_PROTOCOLS=$SN_PROTOCOLS
    elif [[ -n ${SN_EXTRA:-}${SN_EXTRA_PROTOCOLS:-} ]]; then
        EXTRA_PROTOCOLS=${SN_EXTRA:-${SN_EXTRA_PROTOCOLS}}
        # 仅写了附加名时，若用户要「只要附加不要 vless」，设 SN_NO_VLESS=1
        if [[ ${SN_NO_VLESS:-0} != "1" && ${SN_NO_VLESS:-} != "true" ]]; then
            case ",${EXTRA_PROTOCOLS}," in
                *,vless,*) ;;
                *) EXTRA_PROTOCOLS="vless,${EXTRA_PROTOCOLS}" ;;
            esac
        fi
    fi
    normalize_extra_protocols "${EXTRA_PROTOCOLS:-}"
    [[ -n ${SN_TOKEN:-} ]] && CF_TOKEN=$SN_TOKEN
    [[ -n ${SN_HOST:-} ]] && FIXED_HOST=$SN_HOST
    [[ -n ${SN_UUID:-} ]] && UUID=$SN_UUID
    [[ -n ${SN_PATH:-} ]] && WS_PATH=$SN_PATH
    # 连接地址：IP 或域名（无公网 IP 的小机填面板给的域名）
    if [[ -n ${SN_ADDR:-}${SN_DOMAIN:-}${SN_IP:-} ]]; then
        SERVER_IP=${SN_ADDR:-${SN_DOMAIN:-$SN_IP}}
        SERVER_IP=${SERVER_IP#https://}; SERVER_IP=${SERVER_IP#http://}; SERVER_IP=${SERVER_IP%%/*}
        SERVER_DOMAIN=$SERVER_IP
    fi
}


# ---------- 可选全家桶：Hysteria2 / TUIC（默认不装；仅 proto_has 时安装运行）----------
_cpu_arch_hy() {
    case $(uname -m) in
        x86_64|amd64) echo amd64 ;;
        aarch64|arm64) echo arm64 ;;
        *) echo "" ;;
    esac
}

install_hysteria_bin() {
    [[ -x $HY2_BIN ]] && return 0
    local a url
    a=$(_cpu_arch_hy)
    [[ -z $a ]] && { error "不支持的架构，无法装 Hysteria2"; return 1; }
    info "按需下载 Hysteria2（仅你勾选时才装）..."
    url="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${a}"
    if ! curl -fsSL --connect-timeout 15 --max-time 120 "$url" -o /tmp/hysteria 2>/dev/null; then
        url="https://ghfast.top/https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-${a}"
        curl -fsSL --connect-timeout 15 --max-time 120 "$url" -o /tmp/hysteria || { error "Hysteria2 下载失败"; return 1; }
    fi
    chmod +x /tmp/hysteria
    mv -f /tmp/hysteria "$HY2_BIN"
    chmod +x "$HY2_BIN"
    success "Hysteria2 已安装: $($HY2_BIN version 2>/dev/null | head -n1)"
}

write_hy2_config() {
    local port=$1 pass=$2
    pass=$(printf '%s' "$pass" | tr -d '\r\n"\\')
    mkdir -p "$CONFIG_DIR"
    # 自签证书（仅本机 TLS，客户端需允许 insecure 或用 pin）
    if [[ ! -f ${CONFIG_DIR}/hy2.crt || ! -f ${CONFIG_DIR}/hy2.key ]]; then
        openssl req -x509 -nodes -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
            -keyout "${CONFIG_DIR}/hy2.key" -out "${CONFIG_DIR}/hy2.crt" \
            -subj "/CN=bing.com" -days 3650 2>/dev/null || \
        openssl req -x509 -nodes -newkey rsa:2048 \
            -keyout "${CONFIG_DIR}/hy2.key" -out "${CONFIG_DIR}/hy2.crt" \
            -subj "/CN=bing.com" -days 3650 2>/dev/null || return 1
    fi
    cat > "$HY2_CFG" << EOF
listen: :${port}
tls:
  cert: ${CONFIG_DIR}/hy2.crt
  key: ${CONFIG_DIR}/hy2.key
auth:
  type: password
  password: ${pass}
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true
EOF
}

start_hy2() {
    proto_has hy2 || return 0
    [[ -z ${HY2_PORT:-} || -z ${HY2_PASS:-} ]] && return 1
    install_hysteria_bin || return 1
    write_hy2_config "$HY2_PORT" "$HY2_PASS" || return 1
    if [[ -f $HY2_PIDFILE ]]; then
        local op; op=$(cat "$HY2_PIDFILE" 2>/dev/null)
        [[ $op =~ ^[0-9]+$ ]] && kill "$op" 2>/dev/null || true
    fi
    pkill -f "$HY2_BIN" 2>/dev/null || true
    nohup "$HY2_BIN" server -c "$HY2_CFG" >"$HY2_LOG" 2>&1 &
    echo $! > "$HY2_PIDFILE"
    sleep 1
    if proc_alive "$HY2_BIN" || kill -0 "$(cat "$HY2_PIDFILE" 2>/dev/null)" 2>/dev/null; then
        success "Hysteria2 已启动 UDP ${HY2_PORT}（需面板映射 UDP）"
        return 0
    fi
    error "Hysteria2 启动失败，见 $HY2_LOG"
    tail -15 "$HY2_LOG" 2>/dev/null || true
    return 1
}

stop_hy2() {
    [[ -f $HY2_PIDFILE ]] && { kill "$(cat "$HY2_PIDFILE" 2>/dev/null)" 2>/dev/null || true; rm -f "$HY2_PIDFILE"; }
    pkill -f "$HY2_BIN" 2>/dev/null || true
}

build_hy2_link() {
    local ip=${1:-$(get_server_addr)} pass=${2:-$HY2_PASS} port=${3:-$HY2_PORT} name=${4:-智能-hy2}
    [[ -z $ip || -z $pass || -z $port ]] && return 1
    # hy2 分享常见格式
    echo "hysteria2://${pass}@${ip}:${port}?insecure=1&sni=bing.com#${name}"
}

install_tuic_bin() {
    [[ -x $TUIC_BIN ]] && return 0
    local a url
    a=$(_cpu_arch_hy)
    [[ -z $a ]] && { error "不支持的架构，无法装 TUIC"; return 1; }
    info "按需下载 TUIC server（仅你勾选时才装）..."
    # tuic 发布名可能变化，多镜像尝试
    for url in \
        "https://github.com/tuic-protocol/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-linux-gnu" \
        "https://ghfast.top/https://github.com/tuic-protocol/tuic/releases/download/tuic-server-1.0.0/tuic-server-1.0.0-x86_64-linux-gnu"
    do
        [[ $a == arm64 ]] && continue
        if curl -fsSL --connect-timeout 15 --max-time 120 "$url" -o /tmp/tuic-server 2>/dev/null; then
            chmod +x /tmp/tuic-server
            mv -f /tmp/tuic-server "$TUIC_BIN"
            success "TUIC 已安装"
            return 0
        fi
    done
    warn "TUIC 二进制自动下载失败（发布渠道常变）。已记录选项，可稍后手动放入 $TUIC_BIN"
    return 1
}

write_tuic_config() {
    local port=$1 pass=$2
    mkdir -p "$CONFIG_DIR"
    if [[ ! -f ${CONFIG_DIR}/tuic.crt ]]; then
        openssl req -x509 -nodes -newkey rsa:2048 \
            -keyout "${CONFIG_DIR}/tuic.key" -out "${CONFIG_DIR}/tuic.crt" \
            -subj "/CN=bing.com" -days 3650 2>/dev/null || return 1
    fi
    local uuid=${UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null)}
    cat > "$TUIC_CFG" << EOF
{
  "server": "[::]:${port}",
  "users": { "${uuid}": "${pass}" },
  "certificate": "${CONFIG_DIR}/tuic.crt",
  "private_key": "${CONFIG_DIR}/tuic.key",
  "congestion_control": "bbr",
  "alpn": ["h3"],
  "log_level": "warn"
}
EOF
    TUIC_UUID=$uuid
}

start_tuic() {
    proto_has tuic || return 0
    [[ -z ${TUIC_PORT:-} || -z ${TUIC_PASS:-} ]] && return 1
    install_tuic_bin || return 1
    write_tuic_config "$TUIC_PORT" "$TUIC_PASS" || return 1
    pkill -f "$TUIC_BIN" 2>/dev/null || true
    nohup "$TUIC_BIN" -c "$TUIC_CFG" >"$TUIC_LOG" 2>&1 &
    echo $! > "$TUIC_PIDFILE"
    sleep 1
    if kill -0 "$(cat "$TUIC_PIDFILE" 2>/dev/null)" 2>/dev/null; then
        success "TUIC 已启动 UDP ${TUIC_PORT}"
        return 0
    fi
    warn "TUIC 可能未成功启动，见 $TUIC_LOG"
    return 1
}

stop_tuic() {
    [[ -f $TUIC_PIDFILE ]] && { kill "$(cat "$TUIC_PIDFILE" 2>/dev/null)" 2>/dev/null || true; rm -f "$TUIC_PIDFILE"; }
    pkill -f "$TUIC_BIN" 2>/dev/null || true
}

build_tuic_link() {
    local ip=${1:-$(get_server_addr)} pass=${2:-$TUIC_PASS} port=${3:-$TUIC_PORT} uuid=${4:-${TUIC_UUID:-$UUID}}
    [[ -z $ip || -z $pass || -z $port || -z $uuid ]] && return 1
    echo "tuic://${uuid}:${pass}@${ip}:${port}?congestion_control=bbr&alpn=h3&sni=bing.com&allow_insecure=1#智能-tuic"
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

# 把当前脚本落到 /root/smart-node.sh，方便手机 SSH「bash /root/smart-node.sh 链接」
ensure_script_on_disk() {
    local self dest="/root/smart-node.sh"
    self=$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")
    # 从管道/curl 运行时 $0 不是可读脚本文件
    case "$self" in
        /dev/fd/*|/proc/*/fd/*|-|bash|*/bash) return 0 ;;
    esac
    [[ -f $self ]] || return 0
    if [[ $self != "$dest" ]]; then
        cp -f "$self" "$dest" 2>/dev/null || true
    fi
    [[ -f $dest ]] && chmod +x "$dest" 2>/dev/null || true
    # 可选短命令（不覆盖已有非链接文件）
    if [[ -f $dest ]]; then
        if [[ ! -e /usr/local/bin/smart-node ]]; then
            ln -sf "$dest" /usr/local/bin/smart-node 2>/dev/null || true
        fi
    fi
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
            save_info "$UUID" "$PORT" "" "" "" "$(get_server_addr)" "${LEVEL:-argo}" ""
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

# 生成高兼容 Argo 链接（VLESS + WS + TLS）
# 兼容目标：v2rayNG / v2rayN / NekoBox / Clash Meta / sing-box / Shadowrocket / Hiddify 等
# mode: recommended(默认，编码path+alpn) | plain(原始path，部分老客户端)
build_argo_link() {
    local uid=${1:-$UUID} host=${2:-$ARGO_URL} path=${3:-$WS_PATH} mode=${4:-recommended}
    host=${host#https://}
    host=${host#http://}
    host=${host%%/*}
    host=$(echo "$host" | tr -d '[:space:]')
    [[ -z $host ]] && return 1
    [[ -z $uid ]] && return 1
    [[ -z $path ]] && path="/argo"
    [[ $path == /* ]] || path="/$path"
    path=$(echo "$path" | tr -cd 'A-Za-z0-9/_-')
    [[ -z $path ]] && path="/argo"
    [[ $path == /* ]] || path="/$path"

    # 优选 IP：SN_CDN_IP / CDN_IP 只改连接地址，Host/SNI 仍用域名（对照 ArgoX/甬哥习惯）
    local addr=$host
    local cdn=${SN_CDN_IP:-${CDN_IP:-}}
    cdn=$(echo "$cdn" | tr -d '[:space:]')
    [[ -n $cdn ]] && addr=$cdn

    local path_q name
    name="智能隧道-${host%%.*}"
    if [[ $mode == "plain" ]]; then
        path_q="$path"
        echo "vless://${uid}@${addr}:443?encryption=none&security=tls&type=ws&host=${host}&path=${path_q}&sni=${host}&fp=chrome#${name}"
    else
        path_q=$(echo -n "$path" | sed 's|/|%2F|g')
        echo "vless://${uid}@${addr}:443?encryption=none&security=tls&type=ws&host=${host}&path=${path_q}&sni=${host}&fp=chrome&alpn=http%2F1.1#${name}"
    fi
}

# 收集当前已装协议的分享链接（一行一个）
collect_share_links() {
    load_info
    local links="" L
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        ARGO_URL=${FIXED_HOST:-$ARGO_URL}
        if proto_has vless && [[ -n $ARGO_URL ]]; then
            L=$(build_argo_link "$UUID" "$ARGO_URL" "$WS_PATH" recommended 2>/dev/null || true)
            [[ -n $L ]] && links="${links}${L}"$'
'
        fi
        if proto_has vmess && [[ -n ${VMESS_PORT:-} && -n $ARGO_URL ]]; then
            L=$(build_vmess_link "$VMESS_UUID" "$ARGO_URL" "$VMESS_PATH" "智能隧道-vmess" 2>/dev/null || true)
            [[ -n $L ]] && links="${links}${L}"$'
'
        fi
        if proto_has trojan && [[ -n ${TROJAN_PORT:-} && -n $ARGO_URL ]]; then
            L=$(build_trojan_link "$TROJAN_PASS" "$ARGO_URL" "$TROJAN_PATH" "智能隧道-trojan" 2>/dev/null || true)
            [[ -n $L ]] && links="${links}${L}"$'
'
        fi
        if proto_has ss && [[ -n ${SS_PORT:-} && -n $ARGO_URL ]]; then
            L=$(build_ss_link "$SS_METHOD" "$SS_PASS" "$ARGO_URL" "$SS_PATH" "智能隧道-ss" 2>/dev/null || true)
            [[ -n $L ]] && links="${links}${L}"$'
'
        fi
        if proto_has hy2 && [[ -n ${HY2_PORT:-} ]]; then
            L=$(build_hy2_link "$(get_server_addr)" "$HY2_PASS" "$HY2_PORT" 2>/dev/null || true)
            [[ -n $L ]] && links="${links}${L}"$'
'
        fi
        if proto_has tuic && [[ -n ${TUIC_PORT:-} ]]; then
            L=$(build_tuic_link "$(get_server_addr)" "$TUIC_PASS" "$TUIC_PORT" "${TUIC_UUID:-$UUID}" 2>/dev/null || true)
            [[ -n $L ]] && links="${links}${L}"$'
'
        fi
    else
        [[ -n $UUID ]] && links=$(_make_link "$UUID")$'
'
        local u
        for u in $EXTRA_UUIDS; do
            [[ -z $u ]] && continue
            links="${links}$(_make_link "$u")"$'
'
        done
    fi
    printf '%s' "$links"
}

# 订阅：base64 多链接（v2rayN / 部分客户端通用）
show_subscription() {
    load_info
    [[ -z $UUID && -z ${EXTRA_PROTOCOLS:-} && ${NODE_MODE:-} != "direct" ]] && { warn "尚未安装节点"; return; }
    local raw b64 out
    raw=$(collect_share_links)
    [[ -z $raw ]] && { error "无可用链接（可先菜单 2 确认节点是否正常）"; return 1; }
    if command -v base64 >/dev/null 2>&1; then
        b64=$(printf '%s\n' "$raw" | base64 -w0 2>/dev/null || printf '%s\n' "$raw" | base64 | tr -d '\n')
    else
        warn "无 base64 命令，仅输出明文"
        echo "$raw"
        return
    fi
    out="/root/smart-node-sub-$(date +%Y%m%d_%H%M%S).txt"
    {
        echo "# smart-node v${SCRIPT_VERSION} 协议=${EXTRA_PROTOCOLS:-vless} 模式=${NODE_MODE:-}/${TUNNEL_TYPE:-}"
        echo "# 明文："
        printf '%s\n' "$raw"
        echo
        echo "# Base64（复制下面一行导入客户端）："
        echo "$b64"
    } > "$out"
    echo
    title "========== 订阅（手机可长按复制） =========="
    echo "文件: $out"
    echo "协议: ${EXTRA_PROTOCOLS:-vless}  模式: ${NODE_MODE:-?} / ${TUNNEL_TYPE:-}"
    echo
    echo -e "${YELLOW}【Base64 整段 ↓】${NC}"
    echo "$b64"
    echo -e "${CYAN}===========================================${NC}"
    info "v2rayNG / NekoBox 等：添加订阅 → 粘贴上方 Base64 或文件路径"
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
          ],
          "maxTimeDiff": 120000
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
    # 避免 token/密码换行写坏 node.info
    CF_TOKEN=$(printf '%s' "${CF_TOKEN:-}" | tr -d '\r\n')
    HY2_PASS=$(printf '%s' "${HY2_PASS:-}" | tr -d '\r\n')
    TROJAN_PASS=$(printf '%s' "${TROJAN_PASS:-}" | tr -d '\r\n')
    SS_PASS=$(printf '%s' "${SS_PASS:-}" | tr -d '\r\n')
    TUIC_PASS=$(printf '%s' "${TUIC_PASS:-}" | tr -d '\r\n')
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
EXTRA_PROTOCOLS=${EXTRA_PROTOCOLS:-}
VMESS_PORT=${VMESS_PORT:-}
VMESS_PATH=${VMESS_PATH:-}
VMESS_UUID=${VMESS_UUID:-}
TROJAN_PORT=${TROJAN_PORT:-}
TROJAN_PATH=${TROJAN_PATH:-}
TROJAN_PASS=${TROJAN_PASS:-}
SS_PORT=${SS_PORT:-}
SS_PATH=${SS_PATH:-}
SS_METHOD=${SS_METHOD:-aes-128-gcm}
SS_PASS=${SS_PASS:-}
HY2_PORT=${HY2_PORT:-}
HY2_PASS=${HY2_PASS:-}
TUIC_PORT=${TUIC_PORT:-}
TUIC_PASS=${TUIC_PASS:-}
TUIC_UUID=${TUIC_UUID:-}
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
    EXTRA_PROTOCOLS=""; VMESS_PORT=""; VMESS_PATH=""; VMESS_UUID=""
    TROJAN_PORT=""; TROJAN_PATH=""; TROJAN_PASS=""
    SS_PORT=""; SS_PATH=""; SS_METHOD="aes-128-gcm"; SS_PASS=""
    HY2_PORT=""; HY2_PASS=""; TUIC_PORT=""; TUIC_PASS=""; TUIC_UUID=""
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
            EXTRA_PROTOCOLS) EXTRA_PROTOCOLS="$v" ;;
            VMESS_PORT) VMESS_PORT="$v" ;;
            VMESS_PATH) VMESS_PATH="$v" ;;
            VMESS_UUID) VMESS_UUID="$v" ;;
            TROJAN_PORT) TROJAN_PORT="$v" ;;
            TROJAN_PATH) TROJAN_PATH="$v" ;;
            TROJAN_PASS) TROJAN_PASS="$v" ;;
            SS_PORT) SS_PORT="$v" ;;
            SS_PATH) SS_PATH="$v" ;;
            SS_METHOD) SS_METHOD="$v" ;;
            SS_PASS) SS_PASS="$v" ;;
            HY2_PORT) HY2_PORT="$v" ;;
            HY2_PASS) HY2_PASS="$v" ;;
            TUIC_PORT) TUIC_PORT="$v" ;;
            TUIC_PASS) TUIC_PASS="$v" ;;
            TUIC_UUID) TUIC_UUID="$v" ;;
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

# REALITY 高兼容链接（VLESS + TCP + REALITY + Vision）
# 兼容目标：v2rayNG / v2rayN / NekoBox / Clash Meta / sing-box / Hiddify / Shadowrocket(新版) 等
_make_link() {
    local uid=$1
    local ip=$(get_server_addr)
    local _dest=${DEST:-www.microsoft.com:443}
    local sni=${_dest%%:*}
    local sid=${SHORT_ID}
    local pbk=${PUBLIC_KEY}
    # 参数顺序与字段对齐主流客户端解析习惯；保留 encryption/flow/type/headerType
    # fp=chrome 覆盖面最广；不强制 spx，减少老客户端不识别问题
    echo "vless://${uid}@${ip}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${sni}&fp=chrome&pbk=${pbk}&sid=${sid}&type=tcp&headerType=none#智能-${LEVEL:-node}"
}

show_client_snippets() {
    local ip=$(get_server_addr)
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
  alpn:
    - http/1.1
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
    "alpn": ["http/1.1"],
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
    local ip=$(get_server_addr)
    local main_link

    if [[ ${NODE_MODE:-} == "direct" ]]; then
        echo
        title "========== 直连协议节点 =========="
        echo "自选协议  : ${EXTRA_PROTOCOLS}"
        if proto_has hy2 && [[ -n ${HY2_PORT:-} ]]; then
            echo -e "${GREEN}【Hysteria2】${NC} UDP ${HY2_PORT}"
            build_hy2_link "$(get_server_addr)" "$HY2_PASS" "$HY2_PORT" 2>/dev/null || true
        fi
        if proto_has tuic && [[ -n ${TUIC_PORT:-} ]]; then
            echo -e "${GREEN}【TUIC】${NC} UDP ${TUIC_PORT}"
            build_tuic_link "$(get_server_addr)" "$TUIC_PASS" "$TUIC_PORT" "${TUIC_UUID:-$UUID}" 2>/dev/null || true
        fi
        warn "直连需在 NAT 面板映射对应 UDP 端口"
        echo -e "${CYAN}===================================${NC}"
        return
    fi
    if [[ ${NODE_MODE:-reality} == "argo" ]]; then
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            ARGO_URL=${FIXED_HOST:-$ARGO_URL}
        else
            # Quick：域名丢了 / 进程重连换过域名 → 从日志恢复并写回
            refresh_argo_url quiet >/dev/null 2>&1 || true
            load_info
        fi
        if [[ -z $ARGO_URL ]]; then
            if has_direct_proto 2>/dev/null || proto_has hy2 || proto_has tuic; then
                warn "无隧道域名（若只装了 Hy2/TUIC 直连可忽略）"
            else
                error "无有效隧道域名"
                if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
                    error "固定隧道请菜单 25 配置域名，或菜单 14 重启"
                else
                    error "先看菜单 15 确认 cloudflared 是否运行，再菜单 14 重启"
                fi
                return
            fi
        fi
        echo
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            title "========== 固定隧道节点信息 =========="
        else
            title "========== Argo Quick 节点信息 =========="
        fi
        echo -e "${CYAN}提示: 优先复制【推荐链接】整行；勿用客户端再导出改过的链接${NC}"
        echo "域名      : $ARGO_URL"
        echo "自选协议  : ${EXTRA_PROTOCOLS:-vless}"
        echo "脚本版本  : v${SCRIPT_VERSION} (${SCRIPT_DATE})"
        echo
        main_link=""
        if proto_has vless; then
            main_link=$(build_argo_link "$UUID" "$ARGO_URL" "$WS_PATH" recommended)
            local plain_link
            plain_link=$(build_argo_link "$UUID" "$ARGO_URL" "$WS_PATH" plain)
            echo "VLESS 本机 : $PORT  path=${WS_PATH:-/argo}"
            echo "UUID       : $UUID"
            echo
            echo -e "${YELLOW}【VLESS 推荐链接】${NC}"
            echo "$main_link"
            echo
            echo -e "${YELLOW}【VLESS 备用链接】${NC}"
            echo "$plain_link"
            echo
        fi
        if proto_has vmess && [[ -n ${VMESS_PORT:-} ]]; then
            echo -e "${GREEN}【VMess】${NC} 本机 ${VMESS_PORT} path=${VMESS_PATH}"
            build_vmess_link "$VMESS_UUID" "$ARGO_URL" "$VMESS_PATH" "智能隧道-vmess" 2>/dev/null || true
            echo
            [[ -z $main_link ]] && main_link=$(build_vmess_link "$VMESS_UUID" "$ARGO_URL" "$VMESS_PATH" "智能隧道-vmess" 2>/dev/null || true)
        fi
        if proto_has trojan && [[ -n ${TROJAN_PORT:-} ]]; then
            echo -e "${GREEN}【Trojan】${NC} 本机 ${TROJAN_PORT} path=${TROJAN_PATH}"
            build_trojan_link "$TROJAN_PASS" "$ARGO_URL" "$TROJAN_PATH" "智能隧道-trojan" 2>/dev/null || true
            echo
            [[ -z $main_link ]] && main_link=$(build_trojan_link "$TROJAN_PASS" "$ARGO_URL" "$TROJAN_PATH" "智能隧道-trojan" 2>/dev/null || true)
        fi
        if proto_has ss && [[ -n ${SS_PORT:-} ]]; then
            echo -e "${GREEN}【SS】${NC} 本机 ${SS_PORT} method=${SS_METHOD} path=${SS_PATH}"
            build_ss_link "$SS_METHOD" "$SS_PASS" "$ARGO_URL" "$SS_PATH" "智能隧道-ss" 2>/dev/null || true
            echo
            warn "SS+WS 客户端兼容不一"
        fi
        if proto_has hy2 && [[ -n ${HY2_PORT:-} ]]; then
            echo -e "${GREEN}【Hysteria2 直连】${NC} UDP ${HY2_PORT}（不走隧道）"
            build_hy2_link "$(get_server_addr)" "$HY2_PASS" "$HY2_PORT" "智能-hy2" 2>/dev/null || true
            echo
        fi
        if proto_has tuic && [[ -n ${TUIC_PORT:-} ]]; then
            echo -e "${GREEN}【TUIC 直连】${NC} UDP ${TUIC_PORT}（不走隧道）"
            build_tuic_link "$(get_server_addr)" "$TUIC_PASS" "$TUIC_PORT" "${TUIC_UUID:-$UUID}" 2>/dev/null || true
            echo
        fi
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            echo -e "${YELLOW}每个协议在 CF 各配 Hostname → 对应 127.0.0.1:端口（路径留空）${NC}"
            echo -e "${YELLOW}固定域名若全超时而 Quick 通 → 可能域名/SNI 被干扰${NC}"
        else
            echo -e "${YELLOW}Quick 只绑一个本机口（优先 VLESS 端口）；多协议请用固定隧道${NC}"
        fi
        if proto_has vless; then
            show_client_snippets
        fi
        [[ -n $main_link ]] && show_qrcode_if_available "$main_link"
        echo -e "${CYAN}===================================${NC}"
        return
    fi

    main_link=$(_make_link "$UUID")
    if [[ -z $(get_server_addr) ]]; then
        warn "未能获取公网 IP，链接里地址可能为空，请手动改成面板显示的 IP"
    fi
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
    # 与 show_subscription 统一：多协议 + hy2/tuic 全部收录
    show_subscription
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
        if proc_alive "$XRAY_BIN" || proc_alive "xray run"; then
            success "Xray 进程: 运行中"
        else
            error "Xray 进程: 未运行（菜单 14 重启）"
        fi
        if proc_alive "$CLOUDFLARED_BIN" || proc_alive "cloudflared tunnel"; then
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
            info "CF Public Hostname：路径留空；服务 URL → http://127.0.0.1:${PORT}"
            info "若直连超时而 Quick 通：优先怀疑域名/SNI 干扰（链式或换域名）"
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
        if proc_alive "$XRAY_BIN" || proc_alive "xray run"; then
            success "进程: 存在"
        else
            error "进程: 未发现"
        fi
    fi

    # 2. 端口监听
    if [[ -z $PORT ]]; then
        warn "配置里没有端口，跳过监听检查（建议菜单 1 重装）"
    elif check_port_free "$PORT"; then
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
    # 先解析用户协议选择，再决定是否装 xray/cloudflared
    load_panel_env 2>/dev/null || true
    normalize_extra_protocols "${EXTRA_PROTOCOLS:-}"

    if has_tunnel_proto || [[ -z ${EXTRA_PROTOCOLS:-} ]]; then
        # 空=兼容默认 vless 隧道
        install_xray || return 1
        install_cloudflared || return 1
    else
        # 仅直连：不装 cloudflared；xray 也不强装（省空间）
        info "仅直连协议，跳过 cloudflared；不预装 Xray"
        # 仍生成 UUID 供 tuic 等使用
        if [[ ! -x ${XRAY_BIN:-} ]]; then
            UUID=${UUID:-$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)}
        fi
    fi

    if [[ -n $reuse_uuid ]]; then
        UUID=$reuse_uuid
        info "沿用原 UUID: $UUID"
    else
        if [[ -z ${UUID:-} ]]; then
            if command -v uuidgen >/dev/null 2>&1; then
                UUID=$(uuidgen | tr '[:upper:]' '[:lower:]')
            elif [[ -x ${XRAY_BIN:-} ]]; then
                UUID=$($XRAY_BIN uuid 2>/dev/null || cat /proc/sys/kernel/random/uuid 2>/dev/null)
            else
                UUID=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || openssl rand -hex 16)
            fi
            [[ -z $UUID ]] && UUID=$(openssl rand -hex 16 | sed 's/\(........\)\(....\)\(....\)\(....\)\(............\)/\1-\2-\3-\4-\5/')
        fi
    fi

    PORT=$((30000 + RANDOM % 20000))
    local try=0
    while ! check_port_free "$PORT" && (( try < 30 )); do
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
    SERVER_IP=$(get_server_addr)
    if [[ -z $SERVER_IP ]]; then
        if has_direct_proto; then
            ensure_server_addr 1 || true
        elif has_tunnel_proto || [[ -z ${EXTRA_PROTOCOLS:-} ]]; then
            : # 隧道可不需要公网 IP
        else
            ensure_server_addr 1 || true
        fi
    fi
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
        echo "       Path（路径）→ 务必留空"
        echo "       Service → http://127.0.0.1:<本机端口，下一步显示>"
        echo "  4. 把 Token 和域名填到下面"
        echo "  5. 若客户端直连超时、临时隧道却通 → 多半域名被干扰，可链式或换 Quick"
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

    # 协议完全自选（面板 SN_PROTOCOLS / SN_EXTRA）；空=兼容仅 vless
    load_panel_env 2>/dev/null || true
    normalize_extra_protocols "${EXTRA_PROTOCOLS:-}"
    local _plist=${EXTRA_PROTOCOLS:-vless}
    info "本次自选协议: ${_plist}"
    if [[ -n ${EXTRA_PROTOCOLS:-} ]] && ! extra_mem_ok; then
        local tm; tm=$(get_total_mem)
        warn "内存约 ${tm}MB，当前协议组合超出建议门槛，正在裁剪..."
        # 优先去掉直连重协议，再去掉隧道附加，尽量保留 vless
        EXTRA_PROTOCOLS=$(echo "$EXTRA_PROTOCOLS" | tr ',' '
' | grep -vE '^(hy2|tuic)$' | paste -sd, -)
        if ! extra_mem_ok; then
            EXTRA_PROTOCOLS=$(echo "$EXTRA_PROTOCOLS" | tr ',' '
' | grep -vE '^(vmess|trojan|ss)$' | paste -sd, -)
        fi
        [[ -z $EXTRA_PROTOCOLS ]] && EXTRA_PROTOCOLS="vless"
        normalize_extra_protocols "$EXTRA_PROTOCOLS"
        warn "已调整为: ${EXTRA_PROTOCOLS}"
        VMESS_PORT=""; TROJAN_PORT=""; SS_PORT=""; HY2_PORT=""; TUIC_PORT=""
    fi
    local _np=$PORT
    if proto_has vless; then
        info "VLESS-WS：127.0.0.1:${PORT} path=${WS_PATH}"
    fi
    if proto_has vmess; then
        VMESS_UUID=${VMESS_UUID:-$UUID}
        VMESS_PATH=${VMESS_PATH:-/vmess$(openssl rand -hex 3 2>/dev/null || echo x)}
        [[ $VMESS_PATH == /* ]] || VMESS_PATH="/$VMESS_PATH"
        if proto_has vless; then _np=$(alloc_local_port $((_np + 1))); else _np=$PORT; fi
        VMESS_PORT=$_np
        info "VMess-WS：127.0.0.1:${VMESS_PORT} path=${VMESS_PATH}"
        if ! proto_has vless; then PORT=$VMESS_PORT; WS_PATH=$VMESS_PATH; fi
    fi
    if proto_has trojan; then
        TROJAN_PASS=${TROJAN_PASS:-$UUID}
        TROJAN_PATH=${TROJAN_PATH:-/trojan$(openssl rand -hex 3 2>/dev/null || echo x)}
        [[ $TROJAN_PATH == /* ]] || TROJAN_PATH="/$TROJAN_PATH"
        _np=$(alloc_local_port $((_np + 1)))
        TROJAN_PORT=$_np
        info "Trojan-WS：127.0.0.1:${TROJAN_PORT} path=${TROJAN_PATH}"
        if ! proto_has vless && ! proto_has vmess; then PORT=$TROJAN_PORT; WS_PATH=$TROJAN_PATH; fi
    fi
    if proto_has ss; then
        SS_METHOD=${SS_METHOD:-aes-128-gcm}
        SS_PASS=${SS_PASS:-$(openssl rand -base64 16 2>/dev/null | tr -d '/+=' | cut -c1-16)}
        [[ -z $SS_PASS ]] && SS_PASS=$(openssl rand -hex 8 2>/dev/null || echo ss$RANDOM$RANDOM)

        SS_PATH=${SS_PATH:-/ss$(openssl rand -hex 3 2>/dev/null || echo x)}
        [[ $SS_PATH == /* ]] || SS_PATH="/$SS_PATH"
        _np=$(alloc_local_port $((_np + 1)))
        SS_PORT=$_np
        info "SS-WS：127.0.0.1:${SS_PORT} method=${SS_METHOD} path=${SS_PATH}"
        if ! proto_has vless && ! proto_has vmess && ! proto_has trojan; then PORT=$SS_PORT; WS_PATH=$SS_PATH; fi
    fi
    if [[ $mode == "named" || ${TUNNEL_TYPE:-} == "named" ]]; then
        warn "请为每个协议在 CF 配置 Public Hostname → 127.0.0.1:对应端口（路径留空）"
    elif [[ $(echo "${EXTRA_PROTOCOLS:-vless}" | awk -F',' '{print NF}') -gt 1 ]]; then
        warn "Quick 只暴露一个本机口；多协议请用固定隧道"
    fi
    # 直连全家桶组件：仅勾选才准备，不预装二进制直到 start
    if proto_has hy2; then
        HY2_PORT=${HY2_PORT:-$(alloc_local_port 40000)}
        HY2_PASS=${HY2_PASS:-$(openssl rand -hex 8 2>/dev/null || echo hy2pass$RANDOM)}
        info "Hysteria2（直连 UDP）：端口 ${HY2_PORT}（需面板映射 UDP，不走 CF 隧道）"
    fi
    if proto_has tuic; then
        TUIC_PORT=${TUIC_PORT:-$(alloc_local_port 50000)}
        TUIC_PASS=${TUIC_PASS:-$(openssl rand -hex 8 2>/dev/null || echo tuic$RANDOM)}
        info "TUIC（直连 UDP）：端口 ${TUIC_PORT}（需面板映射 UDP，不走 CF 隧道）"
    fi

    if has_tunnel_proto; then
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
    else
        info "未选隧道协议，跳过 Xray/cloudflared（仅直连协议）"
        NODE_MODE="direct"
        TUNNEL_TYPE=""
    fi
    # 未勾选则不会下载/启动
    if proto_has hy2; then start_hy2 || warn "Hysteria2 启动失败（不影响其它协议）"; fi
    if proto_has tuic; then start_tuic || warn "TUIC 启动失败（不影响其它协议）"; fi

    if has_tunnel_proto; then
        NODE_MODE="argo"
        save_info "$UUID" "$PORT" "" "" "" "$SERVER_IP" "argo" ""
        success "节点安装完成！隧道=$mode 协议=${EXTRA_PROTOCOLS:-vless}"
    else
        NODE_MODE="direct"
        save_info "$UUID" "$PORT" "" "" "" "$SERVER_IP" "direct" ""
        success "直连协议安装完成！协议=${EXTRA_PROTOCOLS}"
    fi
    ensure_script_on_disk
    echo
    title "---------- 下一步（手机） ----------"
    echo "1) 下方【推荐链接】长按复制 → 客户端导入"
    echo "2) 多协议可用菜单 4 导出订阅"
    echo "3) 日常: bash /root/smart-node.sh"
    if has_tunnel_proto; then
        if [[ $mode == "named" ]]; then
            echo -e "${GREEN}固定域名: ${FIXED_HOST}${NC}"
            echo -e "${YELLOW}CF：路径留空；URL=http://127.0.0.1:${PORT}${NC}"
            echo -e "${YELLOW}建议菜单 23 保活；全超时而 Quick 通 → 域名可能被墙${NC}"
        else
            echo -e "${YELLOW}Quick 域名会变：菜单 23 保活 + 菜单 24 刷新${NC}"
        fi
    fi
    if proto_has hy2 || proto_has tuic; then
        echo -e "${YELLOW}Hy2/TUIC 需面板映射 UDP，不走 CF${NC}"
    fi
    show_link
}

install_node() {
    detect_and_recommend refresh
    load_panel_env 2>/dev/null || true
    # 协议完全自选：无 SN_PROTOCOLS/SN_EXTRA 时保持空 → 兼容为仅 vless
    if [[ -z ${SN_PROTOCOLS:-}${SN_EXTRA:-}${SN_EXTRA_PROTOCOLS:-} ]]; then
        EXTRA_PROTOCOLS=""
        VMESS_PORT=""; VMESS_PATH=""; VMESS_UUID=""
        TROJAN_PORT=""; TROJAN_PATH=""; TROJAN_PASS=""
        SS_PORT=""; SS_PATH=""; SS_PASS=""
    fi

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
    SERVER_IP=$(get_server_addr)
    if [[ -z $SERVER_IP ]]; then
        if has_direct_proto 2>/dev/null || proto_has hy2 || proto_has tuic || [[ ${NODE_MODE:-} == "reality" ]] || [[ ${1:-} == "reality" ]]; then
            ensure_server_addr 1 || true
        else
            warn "未探测到公网 IP（隧道节点一般不需要；直连请 SN_ADDR=域名）"
        fi
    fi

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
        # 社区共识：勿用纯 CF 站点做 REALITY dest，易被扫成开放代理
        if echo "$DEST" | grep -qiE 'cloudflare\.com|workers\.dev|pages\.dev'; then
            warn "检测到 Cloudflare 系域名作 dest，有被滥用/开放代理风险，强烈建议换微软/苹果等"
            read -p "仍要继续使用该 dest？(y/N): " _cfok
            [[ $_cfok != "y" && $_cfok != "Y" ]] && DEST="${DEST_LIST[0]}"
        fi
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
    check_port_free "$new_port" || warn "端口 $new_port 似乎已被占用"
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
    if [[ ${NODE_MODE:-} == "direct" ]]; then
        info "重启直连组件..."
        if proto_has hy2; then
            start_hy2 && success "Hysteria2 已重启" || warn "Hysteria2 重启失败"
        fi
        if proto_has tuic; then
            start_tuic && success "TUIC 已重启" || warn "TUIC 重启失败"
        fi
        if ! proto_has hy2 && ! proto_has tuic; then
            warn "直连模式但无 hy2/tuic 记录，可菜单 1 重装"
        fi
        show_link
        return
    fi
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
            save_info "$UUID" "$PORT" "" "" "" "$(get_server_addr)" "argo" ""
            success "固定隧道已重启（域名不变: ${ARGO_URL}）"
        else
            start_argo_stack "$PORT" || return
            save_info "$UUID" "$PORT" "" "" "" "$(get_server_addr)" "argo" ""
            success "Quick 隧道已重启（临时域名可能已变，请菜单 2 看最新链接）"
        fi
        proto_has hy2 && start_hy2 || true
        proto_has tuic && start_tuic || true
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
    if [[ ${NODE_MODE:-} == "direct" ]]; then
        echo "模式: 直连（无 CF 隧道）"
        echo "协议: ${EXTRA_PROTOCOLS:-}"
        echo "连接地址: $(get_server_addr)"
        if proto_has hy2; then
            if proc_alive "${HY2_BIN:-/usr/local/bin/hysteria}" || { [[ -f ${HY2_PIDFILE:-} ]] && kill -0 "$(cat "$HY2_PIDFILE" 2>/dev/null)" 2>/dev/null; }; then
                success "hysteria2: 运行中 UDP ${HY2_PORT:-?}"
            else
                warn "hysteria2: 未运行"
            fi
        fi
        if proto_has tuic; then
            if [[ -f ${TUIC_PIDFILE:-} ]] && kill -0 "$(cat "$TUIC_PIDFILE" 2>/dev/null)" 2>/dev/null; then
                success "tuic: 运行中 UDP ${TUIC_PORT:-?}"
            else
                warn "tuic: 未运行"
            fi
        fi
    elif [[ ${NODE_MODE:-reality} == "argo" ]]; then
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            echo "模式: 固定隧道（Token）  域名: ${FIXED_HOST:-$ARGO_URL}"
        else
            echo "模式: Argo Quick 临时隧道（免端口）"
        fi
        echo "协议: ${EXTRA_PROTOCOLS:-vless}"
        if has_tunnel_proto 2>/dev/null || proto_has vless || proto_has vmess || [[ -z ${EXTRA_PROTOCOLS:-} ]]; then
            if proc_alive "$XRAY_BIN" || proc_alive "xray run"; then success "xray: 运行中"; else error "xray: 未运行（菜单 14 重启）"; fi
            if proc_alive "$CLOUDFLARED_BIN" || proc_alive "cloudflared tunnel"; then success "cloudflared: 运行中"; else error "cloudflared: 未运行（菜单 14 重启）"; fi
        fi
        if proto_has hy2; then
            if proc_alive "$HY2_BIN" || [[ -f ${HY2_PIDFILE:-/tmp/smart-node-hy2.pid} ]]; then success "hysteria2: 运行中 UDP ${HY2_PORT:-?}"; else warn "hysteria2: 未运行"; fi
        fi
        if proto_has tuic; then
            if [[ -f ${TUIC_PIDFILE:-/tmp/smart-node-tuic.pid} ]] && kill -0 "$(cat "$TUIC_PIDFILE" 2>/dev/null)" 2>/dev/null; then success "tuic: 运行中 UDP ${TUIC_PORT:-?}"; else warn "tuic: 未运行"; fi
        fi
        if [[ ${TUNNEL_TYPE:-quick} == "named" ]]; then
            echo "当前域名: ${FIXED_HOST:-$ARGO_URL}"
            [[ -n $PORT ]] && echo "回源地址: http://127.0.0.1:${PORT}（须与 CF 控制台一致；路径留空）"
            [[ -n ${WS_PATH:-} ]] && echo "WS Path : $WS_PATH"
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
    rm -f /usr/local/bin/hysteria /usr/local/bin/tuic-server 2>/dev/null || true
    rm -f "${CONFIG_DIR}/hy2.yaml" "${CONFIG_DIR}/hy2.crt" "${CONFIG_DIR}/hy2.key" "${CONFIG_DIR}/tuic.json" "${CONFIG_DIR}/tuic.crt" "${CONFIG_DIR}/tuic.key" 2>/dev/null || true
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
    EXTRA_PROTOCOLS=""; VMESS_PORT=""; VMESS_PATH=""; VMESS_UUID=""
    TROJAN_PORT=""; TROJAN_PATH=""; TROJAN_PASS=""
    SS_PORT=""; SS_PATH=""; SS_METHOD="aes-128-gcm"; SS_PASS=""
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
# 可选 Hy2（仅 node.info 含 hy2 时）
EXTRA=$(grep -m1 '^EXTRA_PROTOCOLS=' "$INFO" 2>/dev/null | cut -d= -f2-)
case ",$EXTRA," in
  *,hy2,*)
    HY2=/usr/local/bin/hysteria
    HCFG=/usr/local/etc/xray/hy2.yaml
    if [ -x "$HY2" ] && [ -f "$HCFG" ]; then
      if ! pgrep -f "$HY2" >/dev/null 2>&1; then
        nohup "$HY2" server -c "$HCFG" >/tmp/smart-node-hy2.log 2>&1 &
      fi
    fi
    ;;
esac
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

# ======================== 实用工具箱 ========================
# 面向 NAT / 低内存 / 无面板场景的日常诊断与小工具

tools_show_resources() {
    echo
    title "========== 资源占用 =========="
    echo "----- 内存 -----"
    free -m 2>/dev/null || cat /proc/meminfo 2>/dev/null | head -5
    echo
    echo "----- 负载 / 磁盘 -----"
    uptime 2>/dev/null || true
    df -h / 2>/dev/null || df / 2>/dev/null || true
    echo
    echo "----- 本脚本相关进程 -----"
    local xr cf
    xr=$(ps -o rss=,comm= -C xray 2>/dev/null | awk '{printf "xray  RSS≈%dMB\n", $1/1024}')
    cf=$(ps -o rss=,comm= -C cloudflared 2>/dev/null | awk '{printf "cloudflared  RSS≈%dMB\n", $1/1024}')
    # Alpine/BusyBox 无 -C 时回退
    if [[ -z $xr ]]; then
        xr=$(ps w 2>/dev/null | grep -E '[x]ray' | head -3)
    fi
    if [[ -z $cf ]]; then
        cf=$(ps w 2>/dev/null | grep -E '[c]loudflared' | head -3)
    fi
    [[ -n $xr ]] && echo "$xr" || echo "xray: 未运行"
    [[ -n $cf ]] && echo "$cf" || echo "cloudflared: 未运行"
    echo -e "${CYAN}=================================${NC}"
}

tools_check_clock() {
    echo
    title "========== 时钟与时区 =========="
    date
    if command -v timedatectl >/dev/null 2>&1; then
        timedatectl 2>/dev/null | head -8
    fi
    # 与公共 HTTP 头粗略比对（不依赖 NTP 包）
    local remote
    remote=$(curl -sI --connect-timeout 4 --max-time 8 https://www.cloudflare.com 2>/dev/null | grep -i '^date:' | head -1 | sed 's/[Dd]ate: //')
    if [[ -n $remote ]]; then
        echo "远端参考时间(CF): $remote"
        info "若本机与远端差几分钟以上，TLS/REALITY 可能异常，请同步时间"
    else
        warn "无法获取远端时间参考（网络或被拦）"
    fi
    # 简单建议
    if command -v ntpdate >/dev/null 2>&1; then
        echo "可用: ntpdate -u pool.ntp.org"
    elif command -v chronyc >/dev/null 2>&1; then
        echo "可用: chronyc -a makestep"
    elif command -v busybox >/dev/null 2>&1; then
        echo "Alpine 可: apk add --no-cache openntpd || 使用硬件时钟校准"
    fi
    echo -e "${CYAN}=================================${NC}"
}

tools_net_diag() {
    echo
    title "========== 网络诊断 =========="
    local ip
    ip=$(get_ip)
    echo "当前识别公网 IP: ${ip:-未知}"
    echo
    echo "----- DNS 解析测试 -----"
    for h in www.microsoft.com www.cloudflare.com github.com; do
        if command -v nslookup >/dev/null 2>&1; then
            echo -n "$h → "
            nslookup "$h" 2>/dev/null | awk '/^Address:/{print $2}' | tail -1
        elif command -v ping >/dev/null 2>&1; then
            echo -n "$h → "
            ping -c1 -W2 "$h" 2>/dev/null | head -1 || echo "失败"
        else
            echo "$h: 无 nslookup/ping，跳过"
            break
        fi
    done
    echo
    echo "----- HTTPS 连通 -----"
    for u in "https://www.cloudflare.com" "https://www.microsoft.com" "https://github.com"; do
        code=$(curl -sI -o /dev/null -w "%{http_code}" --connect-timeout 4 --max-time 8 "$u" 2>/dev/null || echo "fail")
        echo "$u → HTTP $code"
    done
    echo
    if [[ -f $INFO_FILE ]]; then
        load_info
        if [[ ${NODE_MODE:-reality} == "reality" && -n ${DEST:-} ]]; then
            local dhost=${DEST%%:*}
            echo "----- REALITY dest 探测: $DEST -----"
            code=$(curl -sI -o /dev/null -w "%{http_code}" --connect-timeout 4 --max-time 8 "https://${dhost}" 2>/dev/null || echo "fail")
            echo "HTTPS $dhost → $code"
        fi
        if [[ ${NODE_MODE:-} == "argo" ]]; then
            local _probe_host=${FIXED_HOST:-$ARGO_URL}
            if [[ -n $_probe_host ]]; then
                echo "----- 隧道域名探测: $_probe_host -----"
                code=$(curl -sI -o /dev/null -w "%{http_code}" --connect-timeout 5 --max-time 10 "https://${_probe_host}" 2>/dev/null || echo "fail")
                echo "HTTPS $_probe_host → $code （404/302 也可能正常；超时/fail 可能被干扰）"
                if [[ $code == "fail" || $code == "000" ]]; then
                    warn "域名探测失败：若临时隧道能通，优先怀疑固定域名/SNI 被墙"
                fi
            fi
        fi
    fi
    echo -e "${CYAN}=================================${NC}"
}

tools_list_ports() {
    echo
    title "========== 本机监听端口 =========="
    if command -v ss >/dev/null 2>&1; then
        ss -tlnp 2>/dev/null | head -40
    elif command -v netstat >/dev/null 2>&1; then
        netstat -tlnp 2>/dev/null | head -40
    else
        echo "----- /proc/net/tcp（仅端口号）-----"
        awk 'NR>1 && $4=="0A" {
            split($2,a,":");
            printf "port %d\n", strtonum("0x" a[2])
        }' /proc/net/tcp 2>/dev/null | sort -n | uniq | head -40
    fi
    if [[ -f $INFO_FILE ]]; then
        load_info
        echo
        info "节点配置端口: ${PORT:-?}  模式: ${NODE_MODE:-?}"
    fi
    echo -e "${CYAN}=================================${NC}"
}

tools_light_clean() {
    echo
    title "========== 轻量清理（不卸节点） =========="
    echo "将清理：临时下载、旧备份（保留最近3份）、journal 多余日志（若有）"
    read -p "确认？(y/N): " c
    [[ $c != "y" && $c != "Y" ]] && return
    rm -f /tmp/xray*.zip /tmp/xray_dl_*.zip /tmp/cloudflared* /tmp/smart-node-update-*.sh 2>/dev/null || true
    if [[ -d $BACKUP_DIR ]]; then
        ls -1t "$BACKUP_DIR"/config.*.json 2>/dev/null | tail -n +4 | xargs -r rm -f 2>/dev/null || true
        ls -1t "$BACKUP_DIR"/node.*.info 2>/dev/null | tail -n +4 | xargs -r rm -f 2>/dev/null || true
    fi
    if has_systemd && command -v journalctl >/dev/null 2>&1; then
        journalctl --vacuum-time=2d >/dev/null 2>&1 || true
    fi
    success "轻量清理完成"
}

tools_backup_info() {
    load_info
    [[ -z $UUID ]] && { warn "尚未安装节点"; return; }
    mkdir -p "$BACKUP_DIR"
    local ts out
    ts=$(date +%Y%m%d_%H%M%S 2>/dev/null || echo manual)
    out="${BACKUP_DIR}/manual-${ts}"
    mkdir -p "$out"
    [[ -f $CONFIG_FILE ]] && cp -f "$CONFIG_FILE" "$out/"
    [[ -f $INFO_FILE ]] && cp -f "$INFO_FILE" "$out/"
    success "已备份到 $out"
    ls -la "$out"
}

tools_doctor() {
    echo
    title "========== 一键体检 =========="
    tools_show_resources
    tools_check_clock
    tools_net_diag
    if declare -f self_check >/dev/null 2>&1; then
        self_check
    fi
    echo
    if [[ ${NODE_MODE:-} == "argo" && ${TUNNEL_TYPE:-} == "named" ]]; then
        echo
        info "固定隧道补充："
        echo "  · CF 路径留空；服务 URL=http://127.0.0.1:${PORT:-?}"
        echo "  · 直连全超时、临时隧道却通 → 域名/SNI 可能被干扰"
    fi
    if [[ -x ${CLOUDFLARED_BIN:-} ]]; then
        info "cloudflared: $($CLOUDFLARED_BIN --version 2>/dev/null | head -n1)"
        info "CF 建议保持 cloudflared 为较新版本；菜单可重装/更新隧道组件"
    fi
    success "体检结束：请重点看时钟偏差、HTTPS 失败、进程未运行项"
}

tools_menu() {
    echo
    title "========== 实用工具箱 =========="
    echo "  1) 资源占用（内存/磁盘/xray/cloudflared）"
    echo "  2) 时钟检查（TLS/REALITY 强相关）"
    echo "  3) 网络诊断（DNS / HTTPS / dest·域名）"
    echo "  4) 本机监听端口"
    echo "  5) 轻量清理临时文件与旧备份"
    echo "  6) 手动备份当前配置"
    echo "  7) 一键体检（资源+时钟+网络+自检）"
    echo "  0) 返回"
    echo
    read -p "请选择 [0-7]: " tc
    case $tc in
        1) tools_show_resources ;;
        2) tools_check_clock ;;
        3) tools_net_diag ;;
        4) tools_list_ports ;;
        5) tools_light_clean ;;
        6) tools_backup_info ;;
        7) tools_doctor ;;
        *) info "返回" ;;
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
        elif [[ ${NODE_MODE:-} == "direct" ]]; then
            st="${GREEN}直连${NC} ${EXTRA_PROTOCOLS:-hy2/tuic}"
            if proto_has hy2 && proc_alive "$HY2_BIN"; then
                st="${GREEN}直连运行中${NC}"
            fi
        else
            st="${GREEN}REALITY${NC} 端口 ${PORT:-?}"
        fi
    fi

    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE} 智能节点 v${SCRIPT_VERSION}${NC}  ${YELLOW}${mem}MB${NC} 压力:$(get_mem_pressure_hint)"
    echo -e " 状态: ${st}"
    [[ -n $dom ]] && echo -e " 域名: ${YELLOW}${dom}${NC}"
    [[ -n ${EXTRA_PROTOCOLS:-} ]] && echo -e " 协议: ${CYAN}${EXTRA_PROTOCOLS}${NC}"
    [[ -f /root/smart-node.sh ]] && echo -e " 管理: ${CYAN}bash /root/smart-node.sh${NC}"
    echo -e "${BLUE}================================${NC}"
    echo " 【核心 · 手机SSH建议用 2/4】"
    echo "  1. 安装节点（NAT 推荐 Argo/固定隧道）"
    echo "  2. 看链接（推荐链接置顶，方便复制）"
    echo "  3. 导出完整信息到文件"
    echo "  4. 导出 Base64 订阅（多协议）"
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
    echo " 【工具】"
    echo " 26. 实用工具箱（资源/时钟/网络/端口/轻清理/备份）"
    echo " 27. 设置连接地址（无公网IP填域名）"
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
        copy|primary|推荐)
            # 仅输出主推荐链接一行，方便手机复制
            load_info
            local one=""
            if [[ ${NODE_MODE:-} == "direct" ]]; then
                proto_has hy2 && one=$(build_hy2_link "$(get_server_addr)" "$HY2_PASS" "$HY2_PORT" 2>/dev/null)
                [[ -z $one ]] && proto_has tuic && one=$(build_tuic_link "$(get_server_addr)" "$TUIC_PASS" "$TUIC_PORT" "${TUIC_UUID:-$UUID}" 2>/dev/null)
            elif [[ ${NODE_MODE:-reality} == "argo" ]]; then
                ARGO_URL=${FIXED_HOST:-$ARGO_URL}
                [[ -z $ARGO_URL ]] && { refresh_argo_url quiet >/dev/null 2>&1 || true; load_info; }
                if proto_has vless && [[ -n $ARGO_URL ]]; then
                    one=$(build_argo_link "$UUID" "$ARGO_URL" "$WS_PATH" recommended 2>/dev/null)
                elif proto_has vmess && [[ -n $ARGO_URL ]]; then
                    one=$(build_vmess_link "$VMESS_UUID" "$ARGO_URL" "$VMESS_PATH" 2>/dev/null)
                fi
            else
                one=$(_make_link "$UUID" 2>/dev/null)
            fi
            [[ -z $one ]] && { error "无可用推荐链接"; exit 1; }
            echo "$one"
            exit 0
            ;;
        sub|subscription|订阅)
            show_subscription
            exit 0
            ;;
        addr|address|域名|地址)
            # SN_ADDR=xxx bash smart-node.sh 地址  或交互填写
            if [[ -n ${SN_ADDR:-}${SN_DOMAIN:-}${2:-} ]]; then
                SERVER_IP=${SN_ADDR:-${SN_DOMAIN:-$2}}
                SERVER_IP=${SERVER_IP#https://}; SERVER_IP=${SERVER_IP#http://}; SERVER_IP=${SERVER_IP%%/*}
                load_info
                if [[ -f $INFO_FILE ]]; then
                    if grep -q '^SERVER_IP=' "$INFO_FILE" 2>/dev/null; then
                        safe_sed "s|^SERVER_IP=.*|SERVER_IP=$SERVER_IP|" "$INFO_FILE"
                    else
                        echo "SERVER_IP=$SERVER_IP" >> "$INFO_FILE"
                    fi
                    chmod 600 "$INFO_FILE" 2>/dev/null || true
                fi
                success "连接地址: $SERVER_IP"
                show_link
            else
                set_server_addr
            fi
            exit 0
            ;;
        restart|--restart|重启)
            restart_xray
            exit 0
            ;;
        tools|tool|工具)
            tools_menu
            exit 0
            ;;
        diag|网络|诊断)
            tools_net_diag
            exit 0
            ;;
        clock|时间|时钟)
            tools_check_clock
            exit 0
            ;;
        doctor|体检)
            tools_doctor
            exit 0
            ;;
        help|-h|--help|帮助)
            echo "智能节点脚本 v${SCRIPT_VERSION}"
            echo "用法："
            echo "  bash smart-node.sh              进入中文交互菜单"
            echo "  bash smart-node.sh 清理         一键清理本脚本全部内容（需输入 YES）"
            echo "  bash smart-node.sh 清理 --强制  无确认直接清理"
            echo "  bash smart-node.sh 状态         查看运行状态"
            echo "  bash /root/smart-node.sh 链接   显示分享链接（推荐完整路径）"
            echo "  bash smart-node.sh 链接         显示分享链接"
            echo "  bash smart-node.sh 推荐         只输出一行推荐链接（易复制）"
            echo "  bash smart-node.sh 地址         设置连接域名/IP（无公网IP小机）"
            echo "  SN_ADDR=vps.example.com         指定连接地址（可与安装同用）"
            echo "  bash smart-node.sh 订阅         base64 订阅（多协议）"
            echo "  bash smart-node.sh 重启         重启服务"
            echo "  bash smart-node.sh 工具         实用工具箱"
            echo "  bash smart-node.sh 诊断         网络诊断"
            echo "  bash smart-node.sh 时钟         时钟检查"
            echo "  bash smart-node.sh 体检         一键体检"
            echo "  bash smart-node.sh 帮助         显示本说明"
            echo
            echo "协议完全自选（搭配由你决定）："
            echo "  SN_PROTOCOLS=vless,vmess,trojan,ss,hy2,tuic  # 写谁装谁；默认不装 hy2/tuic"
            echo "  SN_ADDR=vps.example.com   # 无公网IP时填小机域名（直连协议）"
            echo "  不设则兼容默认仅 vless（适合小内存）"
            echo "  SN_NO_VLESS=1 配合 SN_EXTRA=vmess 可不要 vless"
            echo "  直连: 菜单 REALITY；SN_TOKEN/SN_HOST/SN_UUID/SN_PATH 可选"
            echo
            echo "英文别名: uninstall/purge/status/link/restart/tools/diag/clock/doctor"
            exit 0
            ;;
        "")
            return 0
            ;;
        *)
            # 用户把分享链接粘成参数时，避免默默进菜单
            if [[ $cmd == vless://* || $cmd == vmess://* || $cmd == ss://* ]]; then
                error "参数看起来是节点链接，不是脚本命令"
                echo "请复制链接到客户端导入；在服务器查看链接请执行："
                echo "  bash /root/smart-node.sh 链接"
                exit 1
            fi
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
    read -p "请输入选项 [0-27]: " choice
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
        26) tools_menu ;;
        27) set_server_addr ;;
        0)  echo "已退出"; exit 0 ;;
        "") warn "请输入选项数字" ;;
        *)  warn "无效选项，请输入 0–27" ;;
    esac
    echo
    read -p "按回车返回菜单…" _
done
