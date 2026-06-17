# tripmc-deploy

无 Docker 直接部署 tripmc.top（个人主页 / 3d-portfolio）。
standalone 产物随 GitHub Release 发布，服务器侧用 `node + pm2` 跑，复用现有 nginx 反代端口。

## 服务器一键部署（在阿里云 Workbench 终端粘贴）

```bash
cd /tmp && curl -fsSL https://github.com/appergb/tripmc-deploy/releases/latest/download/tripmc-standalone.tar.gz -o tripmc-standalone.tar.gz \
 && curl -fsSL https://raw.githubusercontent.com/appergb/tripmc-deploy/main/server-deploy.sh -o server-deploy.sh \
 && bash server-deploy.sh ./tripmc-standalone.tar.gz
```

脚本会：自动探测 nginx 为 tripmc.top 反代的端口 → 停掉占用该端口的旧 Docker 容器 → 解包 → `node server.js` 由 pm2 守护 → 本地探活。nginx 配置无需改动。
