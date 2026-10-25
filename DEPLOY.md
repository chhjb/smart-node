# 智能节点（smart-node）详细部署说明

版本配套：**v5.8.5**  
适用：NAT 小鸡 / Alpine / 低内存 / 无公网 IP（仅域名 SSH）等环境。

---

## 一、你能装成什么样

| 模式 | 客户端怎么连 | 要不要在商家面板映射端口 | 适合谁 |
|------|--------------|--------------------------|--------|
| **Argo 临时隧道** | Cloudflare 临时域名 `*.trycloudflare.com` | **不需要** | 先试通、最省事 |
| **固定隧道** | 你自己的域名（如 `r2.example.com`） | **不需要** | 要域名长期不变、多协议 |
| **REALITY 直连** | 你的公网 IP 或商家域名 + 映射端口 | **需要 TCP** | 有映射口、想少绕 CF |
| **Hy2 / TUIC**（可选） | 同上直连，UDP | **需要 UDP** | 内存 ≥256MB，勾选才装 |

原则：**协议完全自选**——不勾就不下载、不启动。默认兼容为仅 VLESS 隧道。

---

## 二、部署前准备

### 1. 小鸡与 SSH

- 建议 **root** 登录。
- 若面板显示类似：`1145.us1.firadio.net:12345`  
  - SSH：主机 `1145.us1.firadio.net`，端口 `12345`  
  - 这是 **SSH 入口**，不是节点端口。

### 2. 按模式准备

**临时隧道**  
- 无需域名、无需 CF Token。  
- 能访问 GitHub / 镜像下载即可。

**固定隧道**  
1. 域名 DNS 交给 Cloudflare。  
2. [Zero Trust](https://one.dash.cloudflare.com/) → 网络 → 隧道 → 创建隧道。  
3. 安装方式选 **Token**，复制整段 Token。  
4. 添加「公共主机名」：  
   - 域名：如 `r2.你的域名.com`  
   - 类型：HTTP  
   - URL：`http://127.0.0.1:本机端口`（装完后脚本会显示端口，可先占位再改）  
   - **路径留空**（不要填 WebSocket path）。

**REALITY / Hy2 / TUIC**  
- 在商家面板映射 TCP（REALITY）或 UDP（Hy2/TUIC）。  
- 无公网 IP 时记下商家给的 **主机名**（不要带 SSH 端口），部署时作 `SN_ADDR`。

### 3. 手机无电脑时

1. 打开本包里的 `smart-node-panel.html`（浏览器打开即可）。  
2. 选模式、勾协议、填 Token/域名等。  
3. 点「生成步骤与命令」→ 复制到 SSH 粘贴。

---

## 三、安装步骤（推荐流程）

### 方式 A：在线面板生成命令（推荐手机）

1. 打开 `smart-node-panel.html`。  
2. 选择模式与协议。  
3. 固定隧道：填 Token + 固定域名。  
4. 无公网 IP 且用直连：填「服务器连接地址」= 商家域名。  
5. 复制「安装一行」到 SSH 执行。  
6. 按脚本菜单完成安装（若命令已带 `SN_TOKEN`/`SN_HOST`，交互会少很多）。

### 方式 B：直接在小鸡执行

```bash
# 下载（任选一个源）
curl -fsSL -o /root/smart-node.sh https://raw.githubusercontent.com/chhjb/smart-node/main/smart-node.sh
# 或用本包上传的 smart-node.sh：
#   传到 /root/smart-node.sh

chmod +x /root/smart-node.sh
bash /root/smart-node.sh
```

菜单 **1** 安装 → 选 临时隧道 / 固定隧道 / REALITY。

### 方式 C：环境变量半自动（适合面板生成）

```bash
# 固定隧道 + 仅 VLESS
SN_TOKEN='你的Token' SN_HOST=r2.example.com bash /root/smart-node.sh

# 固定隧道 + 多协议
SN_PROTOCOLS=vless,vmess SN_TOKEN='...' SN_HOST=r2.example.com bash /root/smart-node.sh

# 无公网 IP + 直连地址
SN_ADDR=1145.us1.firadio.net SN_PROTOCOLS=hy2 bash /root/smart-node.sh

# 临时隧道默认
bash /root/smart-node.sh
```

| 变量 | 含义 |
|------|------|
| `SN_PROTOCOLS` | 协议列表，如 `vless,vmess,trojan,ss,hy2,tuic` |
| `SN_TOKEN` | CF 固定隧道 Token |
| `SN_HOST` | 固定隧道域名 |
| `SN_UUID` / `SN_PATH` | 可选 UUID、WS 路径 |
| `SN_ADDR` / `SN_DOMAIN` | 直连连接地址（域名或 IP） |
| `SN_CDN_IP` / `CDN_IP` | 隧道节点优选 IP（Host/SNI 仍用域名） |

---

## 四、装完后必做

```bash
# 一行推荐链接（手机好复制）
bash /root/smart-node.sh 推荐

# 完整信息
bash /root/smart-node.sh 链接

# 多协议 Base64 订阅
bash /root/smart-node.sh 订阅

# 看进程与端口
bash /root/smart-node.sh 状态

# 一键体检
bash /root/smart-node.sh 体检
```

建议：

1. **菜单 23** 安装 crontab 保活（无 systemd 时尤其重要）。  
2. 脚本固定到：`/root/smart-node.sh`，日常只跑这个路径。  
3. 客户端优先导入脚本生成的 **推荐链接**，不要用客户端再导出改写后的链接。

### 固定隧道核对清单

- [ ] CF 公共主机名 **路径为空**  
- [ ] 服务 URL = `http://127.0.0.1:脚本显示的端口`  
- [ ] Token 完整、隧道在 CF 显示 Healthy  
- [ ] 若 v2rayNG 通、NekoBox 全超时，而临时隧道正常 → **域名/SNI 可能被干扰**，可链式代理或换域名/改 Quick  

### 直连核对清单

- [ ] `SN_ADDR` 或菜单 27 已填商家域名/公网 IP  
- [ ] 面板映射的是 **节点端口**，不是 SSH 端口  
- [ ] Hy2/TUIC 映射的是 **UDP**

---

## 五、日常维护

| 操作 | 命令或菜单 |
|------|------------|
| 看链接 | `链接` / 菜单 2 |
| 只复制一行 | `推荐` |
| 订阅 | `订阅` / 菜单 4 |
| 重启 | `重启` / 菜单 14 |
| 刷新临时域名 | 菜单 24 |
| 改固定隧道 Token/域名 | 菜单 25 |
| 设置连接域名 | `地址` / 菜单 27 |
| 保活 | 菜单 23 |
| 更新脚本 | 菜单 22（或覆盖 `/root/smart-node.sh`） |
| 彻底卸载 | `清理 --强制` / 菜单 21 |

---

## 六、常见问题

**Q：只有 v2rayNG 通，NekoBox/Karing 不通？**  
先对比临时隧道是否正常。临时通、固定不通 → 多半是自定义域名被干扰。路径必须留空；用脚本「推荐链接」。

**Q：提示 No such file？**  
始终使用：`bash /root/smart-node.sh`。

**Q：机器没有公网 IP？**  
隧道模式一般不用 IP。直连用：  
`SN_ADDR=商家域名 bash /root/smart-node.sh 地址`

**Q：内存很小？**  
只装 VLESS 隧道；不要勾 Hy2/TUIC/多协议。

**Q：二维码扫不了？**  
直接复制推荐链接文本导入。

---

## 七、本包文件说明

| 文件 | 用途 |
|------|------|
| `smart-node.sh` | 主脚本（部署到小鸡） |
| `smart-node-panel.html` | 手机在线配置面板 |
| `DEPLOY.md` | 本部署说明 |
| `HANDOFF.md` | 开发/续作交接 |
| `PANEL_README.txt` | 面板简要说明 |
| `CHANGELOG-*.md` | 版本变更 |

自检：`bash -n smart-node.sh`
