# tripmc-deploy

无 Docker 直接部署 tripmc.top（个人主页）。standalone 产物随 GitHub Release 发布，
服务器用 `node + pm2` 运行，复用现有 nginx 反代端口（自动探测，无需改 nginx）。

## 一键部署（在服务器 / 阿里云 Workbench 终端粘贴）

```bash
cd /tmp \
 && curl -fL --retry 8 --retry-all-errors -C - -o tripmc-standalone.tar.gz \
      https://github.com/appergb/tripmc-deploy/releases/latest/download/tripmc-standalone.tar.gz \
 && curl -fL --retry 8 --retry-all-errors -o server-deploy.sh \
      https://github.com/appergb/tripmc-deploy/releases/latest/download/server-deploy.sh \
 && bash server-deploy.sh ./tripmc-standalone.tar.gz
```

脚本会：探测 nginx 为 tripmc.top 反代的端口 → 停掉占用该端口的旧 Docker 容器 →
解包 → `node server.js` 由 pm2 守护 → 本地探活。完成后访问 https://tripmc.top/ 即新版。
