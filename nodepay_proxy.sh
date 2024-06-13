#!/bin/bash

function socks5() {
    # 安装sk5
    wget -O /usr/local/bin/sk5 https://github.com/yanpeng997995/prxoy/raw/main/sk5
    chmod +x /usr/local/bin/sk5
    
    # 判断是否是root用户
    if [ "$(id -u)" != "0" ]; then
        echo "此脚本需要以root用户权限运行。"
        echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
        exit 1
    fi
    
    # 交互式提示设置端口、用户名和密码
    read -p "请输入端口: " PORT
    read -p "请输入用户名: " USER
    read -p "请输入密码: " PASSWD
    
    # 清空防火墙规则
    iptables -P INPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -t nat -F
    iptables -t mangle -F
    iptables -F
    iptables -X
    iptables-save > /etc/iptables/rules.v4  # 保存防火墙规则
    
    ips=$(hostname -I | xargs)  # 获取主机IP地址列表
    
    # sk5 安装和配置
    cat <<EOF > /etc/systemd/system/sk5.service
[Unit]
Description=The sk5 Proxy Server
After=network-online.target

[Service]
ExecStart=/usr/local/bin/sk5 -c /etc/sk5/serve.toml
ExecStop=/bin/kill -s QUIT \$MAINPID
Restart=always
RestartSec=15s

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable sk5
    
    # sk5 配置
    mkdir -p /etc/sk5
    cat <<EOF > /etc/sk5/serve.toml
[[inbounds]]
listen = "0.0.0.0"
port = ${PORT}
protocol = "socks"
tag = "socks-inbound"

[inbounds.settings]
auth = "password"
udp = true

[[inbounds.settings.accounts]]
user = "${USER}"
pass = "${PASSWD}"

[[routing.rules]]
type = "field"
inboundTag = "socks-inbound"
outboundTag = "freedom-outbound"

[[outbounds]]
protocol = "freedom"
tag = "freedom-outbound"
EOF

    systemctl stop sk5
    systemctl start sk5
    
    echo "代理服务器已设置完成，端口：${PORT}，用户名：${USER}，密码：${PASSWD}"
}
function nodepay() {
    # 克隆仓库
    git clone https://github.com/aston668334/nodepay-socks-python.git
    
    # 切换到克隆的目录
    cd nodepay-socks-python
    pip3 install -r requirements.txt
    
    # 设置环境配置
    cp .env_example .env
    chmod 777 .env
    
    # 提示用户输入NP_TOKEN并替换文件中的值
    read -p "请输入NP_TOKEN: " TOKEN
    TOKEN='"'"${TOKEN}"'"'  # 在输入的TOKEN前后加上双引号
    
    sed -i "s/^NP_TOKEN=.*/NP_TOKEN=${TOKEN}/" .env

    
    # 开始脚本
    screen -S nodepay -dm bash -c 'cd /root/nodepay-socks-python/ && python3 nodepay_no_proxy.py'

    echo '====================== 安装完成，节点已经后台启动，输入screen -r nodepay 查看运行情况==========================='

}
# 查询脚本
function chaxun() {
    screen -r nodepay
}
# 泰坦安装
function taitan() {
# 读取加载身份码信息
    read -p "输入你的身份码: " id

# 让用户输入想要创建的容器数量
    read -p "请输入你想要创建的节点数量，单IP限制最多5个节点: " container_count

# 让用户输入起始 RPC 端口号
    read -p "请输入你想要设置的起始 RPC端口 （端口号请自行设定，开启5个节点端口将会依次数字顺延，建议输入30000即可）: " start_rpc_port

# 让用户输入想要分配的空间大小
    read -p "请输入你想要分配每个节点的存储空间大小（GB），单个上限64G, 网页生效较慢，等待20分钟后，网页查询即可: " storage_gb

# 让用户输入存储路径（可选）
    read -p "请输入节点存储数据的宿主机路径（直接回车将使用默认路径 titan_storage_$i,依次数字顺延）: " custom_storage_path

    apt update

# 检查 Docker 是否已安装
if ! command -v docker &> /dev/null
    then
    echo "未检测到 Docker，正在安装..."
    apt-get install ca-certificates curl gnupg lsb-release -y
    
    # 安装 Docker 最新版本
    apt-get install docker.io -y
else
    echo "Docker 已安装。"
fi

# 拉取Docker镜像
docker pull nezha123/titan-edge:1.5

# 创建用户指定数量的容器
for ((i=1; i<=container_count; i++))
do
    current_rpc_port=$((start_rpc_port + i - 1))

    # 判断用户是否输入了自定义存储路径
    if [ -z "$custom_storage_path" ]; then
        # 用户未输入，使用默认路径
        storage_path="$PWD/titan_storage_$i"
    else
        # 用户输入了自定义路径，使用用户提供的路径
        storage_path="$custom_storage_path"
    fi

    # 确保存储路径存在
    mkdir -p "$storage_path"

    # 运行容器，并设置重启策略为always
    container_id=$(docker run -d --restart always -v "$storage_path:/root/.titanedge/storage" --name "titan$i" --net=host  nezha123/titan-edge:1.5)

    echo "节点 titan$i 已经启动 容器ID $container_id"

    sleep 30

    # 修改宿主机上的config.toml文件以设置StorageGB值和端口
    docker exec $container_id bash -c "\
        sed -i 's/^[[:space:]]*#StorageGB = .*/StorageGB = $storage_gb/' /root/.titanedge/config.toml && \
        sed -i 's/^[[:space:]]*#ListenAddress = \"0.0.0.0:1234\"/ListenAddress = \"0.0.0.0:$current_rpc_port\"/' /root/.titanedge/config.toml && \
        echo '容器 titan'$i' 的存储空间设置为 $storage_gb GB，RPC 端口设置为 $current_rpc_port'"

    # 重启容器以让设置生效
    docker restart $container_id

    # 进入容器并执行绑定命令
    docker exec $container_id bash -c "\
        titan-edge bind --hash=$id https://api-test1.container1.titannet.io/api/v2/device/binding"
    echo "节点 titan$i 已绑定."

done

echo "==============================所有节点均已设置并启动==================================="
}
# 主菜单
function main_menu() {
    while true; do
        clear
        echo "脚本由游艇舰队----迫击炮进行编写"
        echo "=========================基于github仓库修改======================================="
        echo "节点社区:微信             微信联系:17784902889"
        echo "欢迎各位交流，包括低价腾讯云，阿里云，华为云服务器：17784902889"
        echo "退出脚本，请按键盘ctrl c退出即可"
        echo "请选择要执行的操作:"
        echo "1. 安装socks5"
        echo "2. nodepay安装"
        echo "3. 查看nodepay脚本情况"
        echo "4. 安装泰坦节点"
        read -p "请输入选项: " OPTION
        
        case $OPTION in
        1) socks5 ;;
        2) nodepay ;;
        3) chaxun ;;
        4) taitan ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu
