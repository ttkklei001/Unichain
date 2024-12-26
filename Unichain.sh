#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 图标定义
CHECK_MARK="✅"
CROSS_MARK="❌"
PACKAGE_ICON="📦"
WRENCH_ICON="🔧"
KEY_ICON="🔑"

# 变量定义
DOCKER_COMPOSE_VERSION="2.20.2"
ETH_RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"
BEACON_API_URL="https://ethereum-sepolia-beacon-api.publicnode.com"
NODE_DIR="unichain-node"
NODEKEY_PATH="$NODE_DIR/geth-data/geth/nodekey"
DOCKER_COMPOSE_FILE="$NODE_DIR/docker-compose.yml"
SERVICE_FILE_PATH="/etc/systemd/system/unichain-node.service"

# 显示菜单头部信息
show_header() {
    echo -e "${BLUE}================= Unichain 管理脚本 =================${NC}"
    echo -e "作者: ${YELLOW}K2节点教程分享${NC}"
    echo -e "推特: ${GREEN}https://x.com/BtcK241918${NC}"
    echo -e "${BLUE}====================================================${NC}"
}

# 检查节点是否安装
check_node_installed() {
    [ -d "$NODE_DIR" ] && [ -f "$DOCKER_COMPOSE_FILE" ]
}

# 检查 Docker 容器是否在运行
check_docker_running() {
    docker ps -a --format '{{.Names}}' | grep -q "unichain-node"
}

# 显示菜单
show_menu() {
    echo -e "${BLUE}================= Unichain 管理菜单 =================${NC}"
    echo -e "${PACKAGE_ICON} 1. 安装 Unichain 节点"
    echo -e "${WRENCH_ICON} 2. 查看节点日志"
    echo -e "${CROSS_MARK} 3. 卸载 Unichain 节点（保留依赖）"
    echo -e "${KEY_ICON} 4. 导出私钥"
    echo -e "${WRENCH_ICON} 5. 设置开机自启"
    echo -e "🚪 6. 退出"
    echo -e "${BLUE}====================================================${NC}"
}

# 导入私钥
import_private_key() {
    read -p "请输入你的私钥（64位十六进制）： " user_private_key
    if [[ ${#user_private_key} -ne 64 ]]; then
        echo -e "${RED}${CROSS_MARK} 无效的私钥！请确保私钥为64位的十六进制字符串。${NC}"
        exit 1
    fi
    mkdir -p "$NODE_DIR/geth-data/geth"
    echo "$user_private_key" > "$NODEKEY_PATH"
    echo -e "${GREEN}${CHECK_MARK} 私钥已成功导入！${NC}"
}

# 安装 Unichain 节点
install_node() {
    echo -e "${PACKAGE_ICON} 更新系统..."
    sudo apt update -y && sudo apt upgrade -y
    echo -e "${PACKAGE_ICON} 安装 Git 和 curl..."
    sudo apt install -y git curl

    if ! command -v docker &> /dev/null; then
        echo -e "${PACKAGE_ICON} 安装 Docker..."
        sudo apt install -y docker.io
        sudo systemctl enable docker
        sudo systemctl start docker
        if ! command -v docker &> /dev/null; then
            echo -e "${RED}${CROSS_MARK} Docker 安装失败！${NC}"
            exit 1
        fi
    fi

    if ! command -v docker-compose &> /dev/null || [[ "$(docker-compose --version)" != *"$DOCKER_COMPOSE_VERSION"* ]]; then
        echo -e "${PACKAGE_ICON} 安装 Docker Compose..."
        sudo curl -L "https://github.com/docker/compose/releases/download/v$DOCKER_COMPOSE_VERSION/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
    fi

    if [ ! -d "$NODE_DIR" ]; then
        echo -e "${PACKAGE_ICON} 克隆 Unichain 仓库..."
        git clone https://github.com/Uniswap/unichain-node
    else
        echo -e "${GREEN}${CHECK_MARK} Unichain 仓库已存在，更新中...${NC}"
        cd $NODE_DIR && git pull && cd ..
    fi

    read -p "是否要导入现有私钥？(y/n): " import_key_choice
    if [[ "$import_key_choice" =~ ^[yY]$ ]]; then
        import_private_key
    fi

    cd $NODE_DIR
    echo -e "${WRENCH_ICON} 编辑 .env.sepolia 文件..."
    sed -i "s|OP_NODE_L1_ETH_RPC=.*|OP_NODE_L1_ETH_RPC=$ETH_RPC_URL|" .env.sepolia
    sed -i "s|OP_NODE_L1_BEACON=.*|OP_NODE_L1_BEACON=$BEACON_API_URL|" .env.sepolia

    echo -e "${WRENCH_ICON} 启动 Unichain 节点..."
    docker-compose up -d
    echo -e "${GREEN}${CHECK_MARK} 节点安装完成！${NC}"
}

# 查看节点日志（仅显示最后 100 行）
view_logs() {
    if check_node_installed && check_docker_running; then
        echo -e "${WRENCH_ICON} 显示节点日志（仅显示最后 100 行）..."
        cd $NODE_DIR
        docker-compose logs --tail 100 -f
    else
        echo -e "${RED}${CROSS_MARK} 节点未安装或未运行！${NC}"
    fi
}

# 卸载 Unichain 节点
uninstall_node() {
    if check_node_installed; then
        echo -e "${CROSS_MARK} 停止并删除 Unichain 节点容器..."
        cd $NODE_DIR
        docker-compose down
        cd ..
        rm -rf "$NODE_DIR"
        echo -e "${GREEN}${CHECK_MARK} 卸载完成！${NC}"
    else
        echo -e "${RED}${CROSS_MARK} 节点未安装！${NC}"
    fi
}

# 导出私钥
export_private_key() {
    if [ -f "$NODEKEY_PATH" ]; then
        echo -e "${KEY_ICON} 导出私钥..."
        cat "$NODEKEY_PATH"
        echo -e "${YELLOW}请妥善保管此私钥！${NC}"
    else
        echo -e "${RED}${CROSS_MARK} 未找到私钥文件！${NC}"
    fi
}

# 设置开机自启
set_autostart() {
    if [ ! -f "$SERVICE_FILE_PATH" ]; then
        echo -e "${PACKAGE_ICON} 创建 systemd 服务文件..."
        sudo bash -c "cat > $SERVICE_FILE_PATH << EOF
[Unit]
Description=Unichain Node
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/docker-compose -f $NODE_DIR/docker-compose.yml up
ExecStop=/usr/local/bin/docker-compose -f $NODE_DIR/docker-compose.yml down
Restart=always
WorkingDirectory=$NODE_DIR

[Install]
WantedBy=multi-user.target
EOF"
        sudo systemctl daemon-reload
        sudo systemctl enable unichain-node.service
        echo -e "${GREEN}${CHECK_MARK} 开机自启已设置！${NC}"
    else
        echo -e "${GREEN}${CHECK_MARK} 系统已设置开机自启！${NC}"
    fi
}

# 主程序循环
while true; do
    show_header
    show_menu
    read -p "请选择一个选项 [1-6]: " choice
    case $choice in
        1) install_node ;;
        2) view_logs ;;
        3) uninstall_node ;;
        4) export_private_key ;;
        5) set_autostart ;;
        6) echo -e "${GREEN}退出程序${NC}"; exit 0 ;;
        *) echo -e "${RED}无效选项，请重新输入${NC}";;
    esac
done
