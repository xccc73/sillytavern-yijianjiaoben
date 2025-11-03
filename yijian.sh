#!/bin/bash

# --- 安全检查：确保以 root 或 sudo 权限运行 ---
if [ "$(id -u)" -ne 0 ]; then
   echo "‼️ 错误：此脚本需要以 root 或 sudo 权限运行。"
   exit 1
fi

# --- 步骤 1: 安装 1Panel 并捕获初始凭证 ---
# 创建一个临时文件来安全地记录1Panel的安装输出
LOG_FILE=$(mktemp)

echo "🚀 (1/6) 开始安装 1Panel，请稍候..."
# 使用 tee 命令将安装脚本的输出同时显示在屏幕上并写入日志文件
# 自动输入“2”（中文），后续全部回车使用默认值
echo -e "2\n\n\n\n" | bash -c "$(curl -sSL https://resource.fit2cloud.com/1panel/package/quick_start.sh -o quick_start.sh && bash quick_start.sh)" | tee $LOG_FILE

# 检查1Panel安装是否成功（通过查找成功信息）
if ! grep -q "恭喜您！1Panel 已成功安装" "$LOG_FILE"; then
    echo "‼️ 严重错误：1Panel 安装失败，请检查上面的日志输出。"
    rm "$LOG_FILE"
    exit 1
fi

echo "✅ 1Panel 安装成功。"

# --- 步骤 2: 从日志中提取用户名和密码 ---
echo "🔑 (2/6) 正在提取初始登录凭证..."
PANEL_USER=$(grep '面板用户' "$LOG_FILE" | awk '{print $2}')
PANEL_PASSWORD=$(grep '面板密码' "$LOG_FILE" | awk '{print $2}')

# 清理临时日志文件
rm "$LOG_FILE"

# --- 步骤 3: 重置 1Panel 安全入口 ---
echo "🔄 (3/6) 正在重置 1Panel 安全入口..."
1pctl reset entrance > /dev/null 2>&1

# --- 步骤 4: 安装 SillyTavern ---
echo "🍻 (4/6) 开始安装 SillyTavern..."
bash -c "$(curl -fsSL https://raw.githubusercontent.com/xccc73/sillytavern-yijianjiaoben/main/install.sh)"

# --- 步骤 5: 配置防火墙（带安全检查）---
echo "🛡️ (5/6) 正在配置防火墙..."
# 静默安装ufw
apt-get update > /dev/null 2>&1
apt-get install -y ufw > /dev/null 2>&1

# 开放基础端口
ufw allow 22/tcp > /dev/null 2>&1
ufw allow 8000/tcp > /dev/null 2>&1
ufw allow 7861/tcp > /dev/null 2>&1

# 动态获取 1Panel 端口
echo "🔍 正在动态检测 1Panel 端口..."
PANEL_PORT=$(1pctl user-info | grep '面板地址' | awk -F':' '{print $3}' | cut -d'/' -f1)

# *** 核心安全检查 ***
# 检查是否成功获取到端口号 (必须是一个大于0的数字)
if [[ "$PANEL_PORT" =~ ^[0-9]+$ && "$PANEL_PORT" -gt 0 ]]; then
    echo "✅ 成功检测到 1Panel 端口: $PANEL_PORT"
    echo "➕ 正在为端口 $PANEL_PORT 添加防火墙规则..."
    ufw allow "$PANEL_PORT"/tcp
    
    # 只有在成功添加规则后，才启用防火墙
    echo "🔐 正在启用防火墙..."
    echo "y" | ufw enable
    echo "✅ 防火墙已成功配置并启用。"
else
    # 如果没有获取到端口，打印错误信息并终止脚本
    echo "================================================================="
    echo "‼️ 严重错误：未能自动检测到 1Panel 端口！"
    echo "脚本已中止，以防止防火墙将您锁定在面板之外。"
    echo "可能的原因是 1Panel 服务未能正常启动。"
    echo "请尝试手动运行 '1pctl user-info' 命令进行检查。"
    echo "防火墙规则已部分添加，但防火墙【未启用】。"
    echo "================================================================="
    exit 1 # 使用非零退出码表示脚本执行失败
fi

# --- 步骤 6: 输出最终信息 ---
echo ""
echo "🎉 (6/6) 所有部署流程已成功执行完毕！"
echo "========================================"
echo "请务必保存好您的面板登录信息："
echo ""
echo "  面板用户: $PANEL_USER"
echo "  面板密码: $PANEL_PASSWORD"
echo ""
echo "========================================"
