#!/bin/bash

set -e

GREEN_BOLD="\033[1;32m"
RESET="\033[0m"

# 配置参数（可根据实际需求调整路径和端口）
WORKDIR="/root/SillyTavern"
CONFIG_DIR="$WORKDIR/config"
NODE_VERSION="v20.10.0"  # Node.js LTS版本（稳定兼容SillyTavern）
PORT=8000  # 与你目标config.yaml中的端口一致

# 安装必要系统依赖
echo -e "${GREEN_BOLD}1/8 安装系统依赖（git、curl等）...${RESET}"
apt update && apt install -y git curl build-essential && apt clean

# 安装Node.js（SillyTavern运行依赖）
echo -e "${GREEN_BOLD}2/8 安装Node.js $NODE_VERSION...${RESET}"
# 下载Node.js压缩包
curl -fsSL "https://nodejs.org/dist/$NODE_VERSION/node-$NODE_VERSION-linux-x64.tar.xz" -o node.tar.xz
# 解压并移动到系统目录
tar -xJf node.tar.xz
mv "node-$NODE_VERSION-linux-x64" /usr/local/node
# 建立全局软链接（确保node/npm命令可用）
ln -sf /usr/local/node/bin/node /usr/bin/node
ln -sf /usr/local/node/bin/npm /usr/bin/npm
ln -sf /usr/local/node/bin/npx /usr/bin/npx
# 验证安装
echo -e "${GREEN_BOLD}Node.js版本验证：${RESET}"
node -v || { echo -e "${RED}Node.js安装失败！${RESET}"; exit 1; }
npm -v || { echo -e "${RED}npm安装失败！${RESET}"; exit 1; }
# 删除安装包（释放空间）
rm -f node.tar.xz

# 克隆SillyTavern源码（从官方仓库获取最新稳定版）
echo -e "${GREEN_BOLD}3/8 克隆SillyTavern官方源码...${RESET}"
mkdir -p "$WORKDIR"
git clone https://github.com/SillyTavern/SillyTavern.git "$WORKDIR" || { echo -e "${RED}源码克隆失败！请检查网络连接${RESET}"; exit 1; }
cd "$WORKDIR"

# 安装项目依赖（生产环境模式，忽略开发依赖）
echo -e "${GREEN_BOLD}4/8 安装SillyTavern项目依赖...${RESET}"
npm ci --omit=dev || { echo -e "${RED}依赖安装失败！请检查Node.js版本或网络${RESET}"; exit 1; }

# 首次启动服务（生成初始config.yaml配置文件）
echo -e "${GREEN_BOLD}5/8 首次启动服务，生成初始配置文件...${RESET}"
# 后台启动服务并记录进程ID
npm start &
PID=$!
# 等待config.yaml生成（最多等待60秒，避免无限循环）
timeout=60
elapsed=0
while [ ! -f "$CONFIG_DIR/config.yaml" ]; do
    if [ $elapsed -ge $timeout ]; then
        echo -e "${RED}超时！config.yaml未生成，可能服务启动失败${RESET}"
        kill $PID 2>/dev/null
        exit 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
    echo -e "${GREEN_BOLD}已等待${elapsed}秒，正在等待config.yaml生成...${RESET}"
done

# 停止临时服务（避免修改配置时文件被占用）
echo -e "${GREEN_BOLD}6/8 停止临时服务，准备修改配置...${RESET}"
kill $PID 2>/dev/null
# 等待进程完全退出（最多等待10秒）
sleep 5
if ps -p $PID >/dev/null; then
    echo -e "${YELLOW}强制终止残留进程...${RESET}"
    kill -9 $PID 2>/dev/null
fi

# 备份初始配置文件（便于后续回滚）
echo -e "${GREEN_BOLD}7/8 备份初始配置并修改为目标配置...${RESET}"
cd "$CONFIG_DIR"
cp config.yaml config.yaml.bak || echo -e "${YELLOW}初始配置备份警告：config.yaml.bak创建失败${RESET}"

# -------------------------- 核心：修改为你的目标config.yaml配置 --------------------------
# 1. 确保listen为true（与目标一致）
sed -i 's/^listen: false$/listen: true/' config.yaml
# 2. 确保enableUserAccounts为false（与目标一致，覆盖默认true）
sed -i 's/^enableUserAccounts: true$/enableUserAccounts: false/' config.yaml
# 3. 确保enableDiscreetLogin为false（与目标一致，覆盖默认true）
sed -i 's/^enableDiscreetLogin: true$/enableDiscreetLogin: false/' config.yaml
# 4. 配置白名单IP（完全匹配你的目标：::1、127.0.0.1、0.0.0.0/0）
# 先删除默认的127.0.0.1（避免重复）
sed -i '/^  - 127\.0\.0\.1$/d' config.yaml
# 在whitelist:行下方新增所有目标IP（注意缩进格式：2个空格+'- '）
sed -i '/^whitelist:$/a \  - ::1\n  - 127.0.0.1\n  - 0.0.0.0\/0' config.yaml
# 5. 确保whitelistMode为true（开启白名单，与目标一致）
sed -i 's/^whitelistMode: false$/whitelistMode: true/' config.yaml
# 6. 确保enableForwardedWhitelist为true（与目标一致）
sed -i 's/^enableForwardedWhitelist: false$/enableForwardedWhitelist: true/' config.yaml
# 7. 确保whitelistDockerHosts为true（与目标一致）
sed -i 's/^whitelistDockerHosts: false$/whitelistDockerHosts: true/' config.yaml
# 8. 开启基础认证（basicAuthMode=true，与目标一致）
sed -i 's/^basicAuthMode: false$/basicAuthMode: true/' config.yaml
# 9. 配置基础认证账号密码（用户名111，密码123，与目标一致）
# 先删除原有username行，再新增
sed -i '/^  username: /d' config.yaml
sed -i '/^basicAuthUser:$/a \  username: "111"' config.yaml
# 先删除原有password行，再新增
sed -i '/^  password: /d' config.yaml
sed -i '/^  username: "111"$/a \  password: "123"' config.yaml
# 10. 确保port为8000（与目标一致，避免默认端口冲突）
sed -i "s/^port: [0-9]*$/port: $PORT/" config.yaml
# 11. 确保sessionTimeout为-1（永不超时，与目标一致）
sed -i 's/^sessionTimeout: [0-9]*$/sessionTimeout: -1/' config.yaml
# 12. 确保logging相关配置（与目标一致：enableAccessLog=true，minLogLevel=0）
sed -i 's/^  enableAccessLog: false$/  enableAccessLog: true/' config.yaml
sed -i 's/^  minLogLevel: [0-3]$/  minLogLevel: 0/' config.yaml
# --------------------------------------------------------------------------------------

# 配置系统服务（实现开机自启、自动重启）
echo -e "${GREEN_BOLD}8/8 配置系统服务，启动SillyTavern...${RESET}"
cd "$WORKDIR"
# 创建systemd服务文件
cat > /etc/systemd/system/sillytavern.service <<EOF
[Unit]
Description=SillyTavern Service（AI角色交互工具）
After=network.target  # 网络就绪后启动服务

[Service]
User=root  # 运行用户（若需非root，需修改WORKDIR权限为该用户所有）
WorkingDirectory=$WORKDIR  # 项目根目录
ExecStart=/usr/bin/npm start  # 启动命令
Restart=always  # 服务异常退出时自动重启
RestartSec=3  # 重启间隔3秒
LimitNOFILE=65535  # 提升文件描述符限制（避免高并发报错）

[Install]
WantedBy=multi-user.target  # 多用户模式下开机自启
EOF

# 重载systemd配置并启动服务
systemctl daemon-reload
systemctl enable sillytavern --now  # 启用并立即启动服务

# 验证服务状态
echo -e "${GREEN_BOLD}验证服务状态...${RESET}"
if systemctl is-active --quiet sillytavern; then
    echo -e "\n${GREEN_BOLD}==================== 部署完成！ ====================${RESET}"
    echo -e "${GREEN_BOLD}SillyTavern已启动，访问地址：http://服务器IP:$PORT${RESET}"
    echo -e "${GREEN_BOLD}基础认证账号：111  |  密码：123${RESET}"
    echo -e "${GREEN_BOLD}---------------------------------------------------${RESET}"
    echo -e "${GREEN_BOLD}服务管理命令：${RESET}"
    echo -e "  查看状态：systemctl status sillytavern"
    echo -e "  重启服务：systemctl restart sillytavern"
    echo -e "  停止服务：systemctl stop sillytavern"
    echo -e "  配置文件：$CONFIG_DIR/config.yaml（已备份为config.yaml.bak）"
    echo -e "${GREEN_BOLD}===================================================${RESET}"
else
    echo -e "${RED}服务启动失败！请执行以下命令查看日志：${RESET}"
    echo -e "  journalctl -u sillytavern -xe"
    exit 1
fi
