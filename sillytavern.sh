#!/bin/bash

set -e

GREEN_BOLD="\033[1;32m"
RESET="\033[0m"

# --- 您可以自定义这里的变量 ---
# 工作目录，所有 SillyTavern 的数据将存放在这里
WORKDIR="/root/SillyTavern"
# 您希望设置的全局用户名
AUTH_USER="admin"
# 您希望设置的全局密码 (警告：请在生产环境中使用更复杂的密码)
AUTH_PASS="123456"
# --- 自定义变量结束 ---

CONFIG_DIR="$WORKDIR/config"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"

echo -e "${GREEN_BOLD}创建 SillyTavern 目录...${RESET}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo -e "${GREEN_BOLD}生成 docker-compose.yml 文件...${RESET}"
cat > "$COMPOSE_FILE" <<EOF
services:
  sillytavern:
    container_name: sillytavern
    hostname: sillytavern
    image: ghcr.io/sillytavern/sillytavern:latest
    environment:
      - NODE_ENV=production
      - FORCE_COLOR=1
    ports:
      - "8000:8000"
    volumes:
      - "./config:/home/node/app/config"
      - "./data:/home/node/app/data"
      - "./plugins:/home/node/app/plugins"
      - "./extensions:/home/node/app/public/scripts/extensions/third-party"
    restart: unless-stopped
EOF

echo -e "${GREEN_BOLD}拉取镜像并启动 SillyTavern 服务...${RESET}"
docker compose up -d

echo -e "${GREEN_BOLD}等待生成 config.yaml 配置文件...${RESET}"
while [ ! -f "$CONFIG_DIR/config.yaml" ]; do
    sleep 2
done

echo -e "${GREEN_BOLD}停止 SillyTavern 服务...${RESET}"
docker compose stop

echo -e "${GREEN_BOLD}备份配置文件 config.yaml...${RESET}"
cd "$CONFIG_DIR"
cp config.yaml config.yaml.bak

echo -e "${GREEN_BOLD}修改配置参数以允许公网访问和密码保护...${RESET}"
# 1. 允许服务监听外部连接
sed -i 's/^listen: false$/listen: true/' config.yaml

# 2. 关闭IP白名单模式，允许所有IP访问
sed -i 's/^whitelistMode: true$/whitelistMode: false/' config.yaml

# 3. 启用基础认证模式（全局密码）
sed -i 's/^basicAuthMode: false$/basicAuthMode: true/' config.yaml

# 4. 设置您的用户名和密码
sed -i "s/^  username: \"user\"$/  username: \"$AUTH_USER\"/" config.yaml
sed -i "s/^  password: \"password\"$/  password: \"$AUTH_PASS\"/" config.yaml

echo -e "${GREEN_BOLD}重启 SillyTavern 服务...${RESET}"
cd "$WORKDIR"
docker compose start

echo -e "${GREEN_BOLD}SillyTavern 部署完成！${RESET}"
echo -e "您现在可以通过 http://<您的服务器IP>:8000 访问。"
echo -e "用户名: ${GREEN_BOLD}${AUTH_USER}${RESET}"
echo -e "密码: ${GREEN_BOLD}${AUTH_PASS}${RESET}"
echo -e "${GREEN_BOLD}警告：请务必使用防火墙保护您的服务器，并考虑使用更强的密码！${RESET}"
