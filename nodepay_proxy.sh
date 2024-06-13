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
    
    # 设置环境配置
    cp .env_example .env
    chmod 777 .env
    
    # 提示用户输入NP_TOKEN并替换文件中的值
    read -p "请输入NP_TOKEN: " TOKEN
    TOKEN='"'"${TOKEN}"'"'  # 在输入的TOKEN前后加上双引号
    
    sed -i "s/^NP_TOKEN=.*/NP_TOKEN=${TOKEN}/" .env
    # 开始脚本
    screen -dmS nodepay python3 -c 'while :; do python3 nodepay_no_proxy.py || sleep 5; done'
    echo '====================== 安装完成，节点已经后台启动，输入screen -r nodepay 查看运行情况==========================='

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
        echo "2. nodepay"
        read -p "请输入选项: " OPTION
        
        case $OPTION in
        1) socks5 ;;
        2) nodepay ;;
        *) echo "无效选项。" ;;
        esac
        echo "按任意键返回主菜单..."
        read -n 1
    done
}

# 显示主菜单
main_menu
