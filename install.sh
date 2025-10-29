#!/bin/bash

set -e

# --- 颜色和样式定义 ---
GREEN_BOLD="\033[1;32m"
YELLOW_BOLD="\033[1;33m"
BLUE_BOLD="\033[1;34m"
RED_BOLD="\033[1;31m"
RESET="\033[0m"

# --- 您可以自定义这里的变量 ---
WORKDIR="/root/SillyTavern"
AUTH_USER="admin"
AUTH_PASS="123456"
# --- 自定义变量结束 ---

CONFIG_DIR="$WORKDIR/config"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"

# 脚本需要以 root 权限运行
if [ "$(id -u)" -ne 0 ]; then
   echo -e "${RED_BOLD}错误：此脚本需要以 root 权限运行。请尝试使用 'sudo'。${RESET}" 1>&2
   exit 1
fi

# =================================================================
# ==              SillyTavern 主程序安装部分                      ==
# =================================================================

echo -e "${BLUE_BOLD}====== 开始部署 SillyTavern 主程序 ======${RESET}"

echo -e "${GREEN_BOLD}>> 步骤 1/7: 创建 SillyTavern 目录...${RESET}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo -e "${GREEN_BOLD}>> 步骤 2/7: 生成 docker-compose.yml 文件...${RESET}"
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

echo -e "${GREEN_BOLD}>> 步骤 3/7: 拉取镜像并首次启动服务...${RESET}"
docker compose up -d

echo -e "${GREEN_BOLD}>> 步骤 4/7: 等待生成默认配置文件...${RESET}"
while [ ! -f "$CONFIG_DIR/config.yaml" ]; do
    sleep 2
done

echo -e "${GREEN_BOLD}>> 步骤 5/7: 停止服务以修改配置...${RESET}"
docker compose stop

echo -e "${GREEN_BOLD}>> 步骤 6/7: 备份并修改配置文件...${RESET}"
cd "$CONFIG_DIR"
cp config.yaml config.yaml.bak
sed -i 's/^listen: false$/listen: true/' config.yaml
sed -i 's/^whitelistMode: true$/whitelistMode: false/' config.yaml
sed -i 's/^basicAuthMode: false$/basicAuthMode: true/' config.yaml
sed -i "s/^  username: \"user\"$/  username: \"$AUTH_USER\"/" config.yaml
sed -i "s/^  password: \"password\"$/  password: \"$AUTH_PASS\"/" config.yaml

echo -e "${GREEN_BOLD}>> 步骤 7/7: 重启服务应用新配置...${RESET}"
cd "$WORKDIR"
docker compose start

echo -e "\n${GREEN_BOLD}SillyTavern 主程序部署完成！${RESET}"
echo -e "您现在可以通过 ${YELLOW_BOLD}http://<您的服务器IP>:8000${RESET} 访问。"
echo -e "用户名: ${GREEN_BOLD}${AUTH_USER}${RESET}"
echo -e "密码: ${GREEN_BOLD}${AUTH_PASS}${RESET}\n"

# =================================================================
# ==                 插件全自动安装部分                           ==
# =================================================================

echo -e "${BLUE_BOLD}====== 开始自动安装所有指定插件 ======${RESET}"

# 插件安装的通用函数
install_plugin() {
    local plugin_name="$1"
    local repo_url="$2"
    local target_dir_name="$3"
    # 根据 docker-compose.yml 的 volumes 映射，插件应安装在 ./extensions 目录下
    local plugin_dir="${WORKDIR}/extensions/${target_dir_name}"

    echo -e "\n${YELLOW_BOLD}--- 正在安装 [${plugin_name}] ---${RESET}"

    # 首先检查目录是否已存在
    if [ -d "$plugin_dir" ]; then
        # 如果已存在，打印提示并跳过
        echo -e "${YELLOW_BOLD}>> 插件目录已存在，跳过安装。${RESET}"
    else
        # 如果不存在，执行 git clone
        # 这里是实现成功/失败提示的关键
        git clone "${repo_url}" "$plugin_dir" \
            && echo -e "${GREEN_BOLD}>> [${plugin_name}] 安装成功。${RESET}" \
            || echo -e "${RED_BOLD}>> [${plugin_name}] 安装失败，请检查网络或仓库地址。${RESET}"
    fi
}

# 依次调用函数，安装所有插件
install_plugin "酒馆助手" "https://dgithub.xyz/N0VI028/JS-Slash-Runner.git" "JS-Slash-Runner"
install_plugin "信息栏集成工具" "https://dgithub.xyz/loveyouguhan/Information-bar-integration-tool.git" "Information-bar-integration-tool"
install_plugin "前端分词器" "https://dgithub.xyz/GoldenglowMeow/ST-Frontend-Tokenizer.git" "ST-Frontend-Tokenizer"

echo -e "\n${GREEN_BOLD}所有插件安装流程执行完毕。${RESET}"
echo -e "${GREEN_BOLD}部署完成，祝您使用愉快！${RESET}"
