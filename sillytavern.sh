#!/bin/bash

set -e

GREEN_BOLD="\033[1;32m"
RESET="\033[0m"

WORKDIR="/root/SillyTavern"
CONFIG_DIR="$WORKDIR/config"
COMPOSE_FILE="$WORKDIR/docker-compose.yml"

echo -e "${GREEN_BOLD}配置 Docker 镜像源...${RESET}"
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "registry-mirrors": [
    "https://xhdk7b0n.mirror.aliyuncs.com",
    "https://docker.hpcloud.cloud",
    "https://docker.m.daocloud.io",
    "https://docker.unsee.tech",
    "https://docker.1panel.live",
    "http://mirrors.ustc.edu.cn",
    "https://docker.chenby.cn",
    "http://mirror.azure.cn",
    "https://dockerpull.org",
    "https://dockerhub.icu",
    "https://hub.rat.dev",
    "https://docker.imgdb.de",
    "https://hub.fast360.xyz",
    "https://hub.littlediary.cn",
    "https://docker.kejilion.pro",
    "https://dockerpull.cn",
    "https://docker-0.unsee.tech",
    "https://docker.tbedu.top",
    "https://docker.1panelproxy.com",
    "https://docker.melikeme.cn",
    "https://cr.laoyou.ip-ddns.com",
    "https://hub.firefly.store",
    "https://docker.hlmirror.com",
    "https://image.cloudlayer.icu",
    "https://docker.1ms.run"
  ]
}
EOF

echo -e "${GREEN_BOLD}重启 Docker 服务...${RESET}"
systemctl daemon-reload
systemctl restart docker


echo -e "${GREEN_BOLD}创建 SillyTavern 目录...${RESET}"
mkdir -p "$WORKDIR"
cd "$WORKDIR"

echo -e "${GREEN_BOLD}生成 docker-compose.yml 文件...${RESET}"
cat > "$COMPOSE_FILE" <<EOF
services:
  sillytavern:
    build: ..
    container_name: sillytavern
    hostname: sillytavern
    image: ghcr.nju.edu.cn/sillytavern/sillytavern:latest
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

echo -e "${GREEN_BOLD}修改配置参数...${RESET}"
# 1. 基础监听配置：确保 listen 为 true（与目标一致）
sed -i 's/^listen: false$/listen: true/' config.yaml

# 2. 监听地址配置：设置 IPv4 为 0.0.0.0，IPv6 为 [::]
sed -i 's/^  ipv4: .*$/  ipv4: 0.0.0.0/' config.yaml
sed -i 's/^  ipv6: .*$/  ipv6: '[::]'/' config.yaml

# 3. 协议开关配置：启用 IPv4，禁用 IPv6（在 protocol 块内修改）
sed -i '/^protocol:$/,/^[^  ]/ s/^    ipv4: .*$/    ipv4: true/' config.yaml
sed -i '/^protocol:$/,/^[^  ]/ s/^    ipv6: .*$/    ipv6: false/' config.yaml

# 4. DNS IPv6 偏好：禁用 DNS 优先 IPv6
sed -i 's/^dnsPreferIPv6: .*$/dnsPreferIPv6: false/' config.yaml

# 5. 浏览器自动启动：启用自动打开浏览器，默认浏览器，自动 hostname
sed -i '/^browserLaunch:$/,/^[^  ]/ s/^  enabled: .*$/  enabled: true/' config.yaml
sed -i '/^browserLaunch:$/,/^[^  ]/ s/^  browser: .*$/  browser: '\''default'\''/' config.yaml
sed -i '/^browserLaunch:$/,/^[^  ]/ s/^  hostname: .*$/  hostname: '\''auto'\''/' config.yaml
sed -i '/^browserLaunch:$/,/^[^  ]/ s/^  port: .*$/  port: -1/' config.yaml
sed -i '/^browserLaunch:$/,/^[^  ]/ s/^  avoidLocalhost: .*$/  avoidLocalhost: false/' config.yaml

# 6. 服务端口：确保端口为 8000（默认通常已满足，冗余处理）
sed -i 's/^port: .*$/port: 8000/' config.yaml

# 7. SSL 配置：禁用 SSL（与目标一致）
sed -i '/^ssl:$/,/^[^  ]/ s/^  enabled: .*$/  enabled: false/' config.yaml

# 8. 安全配置 - 白名单模式：启用白名单、信任转发头、自动白名单 Docker 主机
sed -i 's/^whitelistMode: .*$/whitelistMode: true/' config.yaml
sed -i 's/^enableForwardedWhitelist: .*$/enableForwardedWhitelist: true/' config.yaml
sed -i 's/^whitelistDockerHosts: .*$/whitelistDockerHosts: true/' config.yaml

# 9. 安全配置 - 白名单IP：清空原始IP并添加目标列表
sed -i '/^whitelist:$/,/^[^  ]/ { /^  - /d }' config.yaml  # 删除原始IP
sed -i '/^whitelist:$/a \  - ::1\n  - 127.0.0.1\n  - 0.0.0.0/0' config.yaml  # 插入目标IP

# 10. 安全配置 - 基础认证：启用基础认证，设置用户名 123、密码 123
sed -i 's/^basicAuthMode: .*$/basicAuthMode: true/' config.yaml
sed -i '/^basicAuthUser:$/,/^[^  ]/ s/^  username: .*$/  username: "123"/' config.yaml
sed -i '/^basicAuthUser:$/,/^[^  ]/ s/^  password: .*$/  password: "123"/' config.yaml

# 14. 会话超时：设置为永不过期（-1）
sed -i 's/^sessionTimeout: .*$/sessionTimeout: -1/' config.yaml

# 22. API 安全：禁用密钥暴露、启用内容检查
sed -i 's/^allowKeysExposure: .*$/allowKeysExposure: true/' config.yaml

echo -e "${GREEN_BOLD}重启 SillyTavern 服务...${RESET}"
cd "$WORKDIR"
docker compose start

echo -e "${GREEN_BOLD}SillyTavern 部署完成，欢迎使用！${RESET}"
