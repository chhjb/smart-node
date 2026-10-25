# 上传到 GitHub

1. GitHub 新建空仓库 `smart-node`（可不初始化 README）
2. 解压本包后执行：

```bash
cd smart-node-github
git init
git add .
git commit -m "release: smart-node v5.12.4"
git branch -M main
git remote add origin https://github.com/<你的用户名>/smart-node.git
git push -u origin main
```

3. 安装用 raw 地址：

```text
https://raw.githubusercontent.com/<你的用户名>/smart-node/main/smart-node.sh
```

4. 可选：仓库 Settings → Pages → Deploy from branch `main`，在线打开面板。
