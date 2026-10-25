# smart-node

面向 **NAT / 低内存小鸡**（64MB–256MB）的轻量节点脚本，可选静态网页面板生成安装命令。

- 默认只跑 **VLESS + Cloudflare 隧道**（控内存）
- 其它协议（VMess / Trojan / Hy2 / TUIC / AnyTLS 等）**勾选才安装**
- 支持 Alpine / Debian 等常见环境

脚本版本以文件内 `SCRIPT_VERSION` 为准（当前 **v5.12.4**）。

## 快速使用

### 交互菜单

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/<你的用户名>/smart-node/main/smart-node.sh)
```

```bash
chmod +x smart-node.sh && ./smart-node.sh
```

### 非交互

```bash
SN_PROTOCOLS=vless SN_AUTO=1 bash <(curl -fsSL https://raw.githubusercontent.com/<你的用户名>/smart-node/main/smart-node.sh)
```

```bash
bash /root/smart-node.sh 推荐   # 一行链接
bash /root/smart-node.sh 状态
bash /root/smart-node.sh 体检
bash /root/smart-node.sh 清理 --强制
```

## 网页面板

`panel.html` 纯静态、无后端。浏览器打开，或开启 GitHub Pages。

上传说明见 [GITHUB_UPLOAD.md](GITHUB_UPLOAD.md)。

## 主要环境变量

| 变量 | 说明 |
|------|------|
| `SN_PROTOCOLS` | 如 `vless,vmess,hy2` |
| `SN_TOKEN` / `SN_HOST` | 固定 Argo 隧道 |
| `SN_ADDR` | 无公网 IP 时的连接域名 |
| `SN_AUTO=1` | 免菜单安装 |
| `SN_REUSE=1` | 重装沿用 UUID/路径 |
| `SN_PANEL_MEM` | 面板内存档 |
| `SN_FORCE=1` | 强制保留重协议 |

## 仓库结构

```
smart-node.sh
panel.html
README.md
LICENSE
CHANGELOG.md
DEPLOY.md
GITHUB_UPLOAD.md
```

## 注意

- CF 固定隧道：Public Hostname **路径留空**
- 将面板/文档中的 `<你的用户名>` 换成实际 GitHub 用户名与仓库名

## License

MIT
