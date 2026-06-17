#!/usr/bin/env bash
#
# 无 Docker 直接部署（在服务器上运行，例如阿里云 Workbench 终端）。
# 把 Next.js standalone 产物直接用 node 跑、pm2 守护，复用现有 nginx 反代端口。
# 会自动探测 tripmc.top 当前的 nginx 上游端口，并停掉占用该端口的旧 Docker 容器。
#
# 用法：  bash server-deploy.sh /path/to/tripmc-standalone.tar.gz
#
set -euo pipefail

BUNDLE="${1:-./tripmc-standalone.tar.gz}"
APP_DIR="${APP_DIR:-/opt/tripmc/3d-portfolio}"
APP_NAME="${APP_NAME:-tripmc-web}"

if [[ ! -f "${BUNDLE}" ]]; then
  echo "找不到部署包：${BUNDLE}" >&2; exit 1
fi

# ---- 1) 自动探测 nginx 为 tripmc.top 反代的上游端口 ----
PORT="${PORT:-}"
if [[ -z "${PORT}" ]]; then
  CONF="$(grep -rlsE 'server_name[^;]*tripmc\.top' /etc/nginx 2>/dev/null | head -1 || true)"
  if [[ -n "${CONF}" ]]; then
    PORT="$(grep -oE 'proxy_pass[[:space:]]+https?://127\.0\.0\.1:[0-9]+' "${CONF}" 2>/dev/null | grep -oE '[0-9]+$' | head -1 || true)"
    echo "==> nginx 配置：${CONF}（探测到上游端口：${PORT:-未识别}）"
  fi
fi
PORT="${PORT:-3001}"
echo "==> 将使用端口：${PORT}"

# ---- 2) 停掉占用该端口的旧 Docker 容器（彻底弃用镜像方式）----
if command -v docker >/dev/null 2>&1; then
  OLD="$(docker ps --format '{{.ID}} {{.Names}} {{.Ports}}' 2>/dev/null | grep -E "[:]${PORT}->" | awk '{print $1}' | head -1 || true)"
  [[ -z "${OLD}" ]] && OLD="$(docker ps -aq -f name=tripmc-web 2>/dev/null | head -1 || true)"
  if [[ -n "${OLD}" ]]; then
    echo "==> 停止并删除旧 Docker 容器 ${OLD}"
    docker rm -f "${OLD}" >/dev/null 2>&1 || true
  fi
fi

# ---- 3) 检查 node ----
if ! command -v node >/dev/null 2>&1; then
  echo "服务器未安装 node，请先装 Node 18+（nvm install 20 或系统包管理器）后重试。" >&2; exit 1
fi
echo "==> node $(node -v)"

# ---- 4) 解包到带时间戳的发布目录，原子切换 ----
RELEASES_DIR="$(dirname "${APP_DIR}")/releases"
RELEASE_DIR="${RELEASES_DIR}/$(date +%Y%m%d-%H%M%S)"
mkdir -p "${RELEASE_DIR}"
echo "==> 解包到 ${RELEASE_DIR}"
tar -xzf "${BUNDLE}" -C "${RELEASE_DIR}"

# 可选运行时环境变量（如 RESEND_API_KEY 让联系表单可用）
if [[ -f "${APP_DIR}/app.env" ]]; then
  cp "${APP_DIR}/app.env" "${RELEASE_DIR}/app.env"
  echo "==> 带入运行时环境变量 ${APP_DIR}/app.env"
fi

mkdir -p "$(dirname "${APP_DIR}")"
ln -sfn "${RELEASE_DIR}" "${APP_DIR}"

# ---- 5) 启动（pm2 优先，nohup 兜底）----
cd "${APP_DIR}"
[[ -f "${APP_DIR}/app.env" ]] && set -a && . "${APP_DIR}/app.env" && set +a || true
export PORT HOSTNAME=0.0.0.0

if command -v pm2 >/dev/null 2>&1 || npm install -g pm2 >/dev/null 2>&1; then
  pm2 delete "${APP_NAME}" >/dev/null 2>&1 || true
  PORT="${PORT}" HOSTNAME=0.0.0.0 pm2 start server.js --name "${APP_NAME}" --update-env
  pm2 save >/dev/null 2>&1 || true
  echo "==> 已用 pm2 启动 ${APP_NAME}（开机自启：pm2 startup）"
else
  pkill -f "node ${APP_DIR}/server.js" >/dev/null 2>&1 || true
  PORT="${PORT}" HOSTNAME=0.0.0.0 nohup node server.js > "${APP_DIR}/app.log" 2>&1 &
  echo "==> 已用 nohup 启动（日志：${APP_DIR}/app.log）"
fi

# ---- 6) 探活 ----
sleep 2
echo "==> 本地探活 http://127.0.0.1:${PORT}/"
curl -sS -o /dev/null -w "  HTTP %{http_code}\n" "http://127.0.0.1:${PORT}/" || {
  echo "探活失败，看日志：pm2 logs ${APP_NAME}  或  ${APP_DIR}/app.log" >&2; exit 1; }
echo "==> 完成。外网访问： https://tripmc.top/"

# 只保留最近 5 个发布
ls -1dt "${RELEASES_DIR}"/*/ 2>/dev/null | tail -n +6 | xargs -r rm -rf || true
