#!/bin/bash

# 检查是否以root用户运行脚本
if [ "$(id -u)" != "0" ]; then
    echo "此脚本需要以root用户权限运行。"
    echo "请尝试使用 'sudo -i' 命令切换到root用户，然后再次运行此脚本。"
    exit 1
fi

    # 配置 0gchaind 环境变量
    if [ -z "$MONIKER" ]; then
        echo 'export MONIKER="My_Node"' >> $HOME/.profile
    fi

    if [ -z "$wallet_name" ]; then
        echo 'export wallet_name="wallet"' >> $HOME/.profile
    fi
    
    source $HOME/.profile

# 检查并安装 Node.js 和 npm
function install_nodejs_and_npm() {
    if command -v node > /dev/null 2>&1; then
        echo "Node.js 已安装"
    else
        echo "Node.js 未安装，正在安装..."
        curl -fsSL https://deb.nodesource.com/setup_16.x | sudo -E bash -
        sudo apt-get install -y nodejs
    fi

    if command -v npm > /dev/null 2>&1; then
        echo "npm 已安装"
    else
        echo "npm 未安装，正在安装..."
        sudo apt-get install -y npm
    fi
}

# 检查并安装 PM2
function install_pm2() {
    if command -v pm2 > /dev/null 2>&1; then
        echo "PM2 已安装"
    else
        echo "PM2 未安装，正在安装..."
        npm install pm2@latest -g
    fi
}

# 检查Go环境
function check_go_installation() {
    if command -v go > /dev/null 2>&1; then
        echo "Go 环境已安装"
        return 0
    else
        echo "Go 环境未安装，正在安装..."
        return 1
    fi
}

# 验证节点安装功能
function install_validator() {

    install_nodejs_and_npm
    install_pm2

    # 检查curl是否安装，如果没有则安装
    if ! command -v curl > /dev/null; then
        sudo apt update && sudo apt install curl -y
    fi

    # 更新和安装必要的软件
    sudo apt update && sudo apt upgrade -y
    sudo apt install git wget build-essential jq make lz4 gcc -y

    # 安装 Go
    if ! check_go_installation; then
        sudo rm -rf /usr/local/go
        curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
        echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
        source $HOME/.bash_profile
        go version
    fi

    # 下载二进制文件
    wget -O 0gchaind https://github.com/0glabs/0g-chain/releases/download/v0.5.0/0gchaind-linux-v0.5.0
    chmod +x $HOME/0gchaind
    mv $HOME/0gchaind /usr/local/go/bin
    source $HOME/.profile

    # 初始化节点
    cd $HOME
    0gchaind init $MONIKER --chain-id zgtendermint_16600-2
    0gchaind config chain-id zgtendermint_16600-2
    0gchaind config node tcp://localhost:13457

    # 配置创世文件
    rm ~/.0gchain/config/genesis.json
    wget -O $HOME/.0gchain/config/genesis.json https://server-5.itrocket.net/testnet/og/genesis.json
    0gchaind validate-genesis

    # 配置节点
    SEEDS="bac83a636b003495b2aa6bb123d1450c2ab1a364@og-testnet-seed.itrocket.net:47656"
    PEERS="80fa309afab4a35323018ac70a40a446d3ae9caf@og-testnet-peer.itrocket.net:11656,407e52882cd3e9027c3979742c38f4d655334ee1@185.239.208.65:12656,3b8df79c5322dcb2d25aa8d10f886461fcbb93a5@161.97.89.237:12656,1dd9da1053e932e7c287c94191c418212c96da96@157.173.125.137:26656,1469b5aba1c6401bc191fa5a6fabbc6e02720add@62.171.156.121:12656,af4fe9d510848eb952110da4b03b7ca696d46a3a@84.247.191.112:12656,c30554e3c291acacf327c717beb5c01fc7acf9c1@109.123.253.9:12656,80aead3e238fca6805c37be8b780c99b0e934daf@77.237.246.197:12656,8db25df522e76176b00ab184df972b86bf72cd22@161.97.103.44:12656,e142f3cb55585a1987faa01f5c70de51aa82dd13@31.220.81.231:12656,4a77eb8103ada3687be7038ab722b611acc832be@158.220.111.17:12656,6e9edc59c3a6495bf5769c23fc37dc9756e258d3@161.97.110.78:12656,4ebff8cc1d7fb899643228d367b8e5395b6cb4ca@62.171.189.13:12656,492453098ed9c42e214d5bd3d4bb84113c92571c@89.116.27.67:12656,0f835342124117a4a5f0177c049bf57802de959c@5.252.54.96:47656,c3674c176cf70b8832930bd0c01d57cd1df292ac@161.97.78.57:12656"
    sed -i "s/persistent_peers = \"\"/persistent_peers = \"$PEERS\"/" $HOME/.0gchain/config/config.toml
    sed -i "s/seeds = \"\"/seeds = \"$SEEDS\"/" $HOME/.0gchain/config/config.toml
    sed -i -e 's/max_num_inbound_peers = 40/max_num_inbound_peers = 100/' -e 's/max_num_outbound_peers = 10/max_num_outbound_peers = 100/' $HOME/.0gchain/config/config.toml
    wget -O $HOME/.0gchain/config/addrbook.json https://server-5.itrocket.net/testnet/og/addrbook.json


    # 配置裁剪
    sed -i -e "s/^pruning *=.*/pruning = \"custom\"/" $HOME/.0gchain/config/app.toml
    sed -i -e "s/^pruning-keep-recent *=.*/pruning-keep-recent = \"100\"/" $HOME/.0gchain/config/app.toml
    sed -i -e "s/^pruning-keep-every *=.*/pruning-keep-every = \"0\"/" $HOME/.0gchain/config/app.toml
    sed -i -e "s/^pruning-interval *=.*/pruning-interval = \"10\"/" $HOME/.0gchain/config/app.toml

    # 配置端口
    sed -i -e "s%^proxy_app = \"tcp://127.0.0.1:26658\"%proxy_app = \"tcp://127.0.0.1:13458\"%; s%^laddr = \"tcp://127.0.0.1:26657\"%laddr = \"tcp://127.0.0.1:13457\"%; s%^pprof_laddr = \"localhost:6060\"%pprof_laddr = \"localhost:13460\"%; s%^laddr = \"tcp://0.0.0.0:26656\"%laddr = \"tcp://0.0.0.0:13456\"%; s%^prometheus_listen_addr = \":26660\"%prometheus_listen_addr = \":13466\"%" $HOME/.0gchain/config/config.toml
    sed -i -e "s%^address = \"tcp://localhost:1317\"%address = \"tcp://0.0.0.0:13417\"%; s%^address = \":8080\"%address = \":13480\"%; s%^address = \"localhost:9090\"%address = \"0.0.0.0:13490\"%; s%^address = \"localhost:9091\"%address = \"0.0.0.0:13491\"%; s%^address = \"127.0.0.1:8545\"%address = \"0.0.0.0:13445\"%; s%:8546%:13446%; s%:6065%:13465%" $HOME/.0gchain/config/app.toml
    source $HOME/.profile

    # 下载快照
    cp $HOME/.0gchain/data/priv_validator_state.json $HOME/.0gchain/priv_validator_state.json.backup
    rm -rf $HOME/.0gchain/data
    curl -o - -L https://config-t.noders.services/og/data.tar.lz4 | lz4 -d | tar -x -C ~/.0gchain
    mv $HOME/.0gchain/priv_validator_state.json.backup $HOME/.0gchain/data/priv_validator_state.json

    # 使用 PM2 启动节点进程
    pm2 start 0gchaind -- start --log_output_console --home ~/.0gchain && pm2 save && pm2 startup
    pm2 restart 0gchaind

    echo '====================== 安装完成,请退出脚本后执行 source $HOME/.profile 以加载环境变量==========================='

}

# 查看 PM2 服务状态
function check_service_status() {
    pm2 list
}

# 验证节点日志查询
function view_logs() {
    pm2 logs 0gchaind
}

# 卸载节点功能
function uninstall_validator() {
    echo "你确定要卸载 0gchain 验证节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo "开始卸载节点程序..."
            pm2 stop 0gchaind && pm2 delete 0gchaind
            rm -rf $HOME/.0gchain $(which 0gchaind)  $HOME/0g-chain
            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

# 创建钱包
function add_wallet() {
    #read -p "请输入你想设置的钱包名称: " wallet_name
    0gchaind keys add $wallet_name --eth
}

# 导入钱包
function import_wallet() {
    #read -p "请输入你想设置的钱包名称: " wallet_name
    0gchaind keys add $wallet_name --recover --eth
}

# 查询余额
function check_balances() {
    echo "请确认同步到最新区块之后再查询余额"
    read -p "请输入钱包地址: " wallet_address
    0gchaind query bank balances "$wallet_address"
}

# 查看节点同步状态
function check_sync_status() {
    0gchaind status | jq .sync_info
}

# 创建验证者
function add_validator() {

    #read -p "请输入您的钱包名称: " wallet_name
    read -p "请输入您想设置的验证者的名字: " validator_name
    read -p "请输入您的验证者详情（例如'吊毛资本'）: " details
    
    0gchaind tx staking create-validator \
    --amount 100000ua0gi \
    --from $wallet_name \
    --commission-rate 0.1 \
    --commission-max-rate 0.2 \
    --commission-max-change-rate 0.01 \
    --min-self-delegation 1 \
    --pubkey $(0gchaind tendermint show-validator) \
    --moniker "$validator_name" \
    --identity "" \
    --website "" \
    --details "$details" \
    --chain-id zgtendermint_16600-2 \
    --gas=auto --gas-adjustment=1.6 --gas-prices 0.00252ua0gi \
    -y
}

# 给自己地址验证者质押
function delegate_self_validator() {
    #read -p "请输入质押代币数量(单位为ua0gai,比如你有1000000个ua0gai，留点水给自己，输入900000回车就行): " math
    #read -p "请输入钱包名称: " wallet_name
    #0gchaind tx staking delegate $(0gchaind keys show $wallet_name --bech val -a) ${math}ua0gi --from $wallet_name   --gas=auto --gas-adjustment=1.4 -y
    0gchaind tx staking delegate $(0gchaind keys show $wallet_name --bech val -a) 1000000ua0gi --from $wallet_name --chain-id zgtendermint_16600-2 --gas=auto --gas-adjustment=1.6 --gas-prices 0.00252ua0gi -y 

}


function install_storage_node() {

    sudo apt-get update
    sudo apt-get install clang cmake build-essential git screen openssl pkg-config libssl-dev -y


    # 安装 Go
    sudo rm -rf /usr/local/go
    curl -L https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | sudo tar -xzf - -C /usr/local
    echo 'export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin' >> $HOME/.bash_profile
    export PATH=$PATH:/usr/local/go/bin:$HOME/go/bin
    source $HOME/.bash_profile

    # 安装 rust
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

    # 克隆仓库
    git clone -b v0.8.4 https://github.com/0glabs/0g-storage-node.git

    # 进入对应目录构建
    cd 0g-storage-node
    git checkout 40d4355
    git submodule update --init

    # 构建代码
    echo "准备构建，该步骤消耗一段时间。请保持 SSH 不要断开。看到 Finish 字样为构建完成。"
    cargo build --release

    # 编辑配置
    read -p "请输入你想导入的EVM钱包私钥，不带0x: " miner_key
    read -p "请输入使用的 JSON-RPC (官方 https://evmrpc-testnet.0g.ai ): " json_rpc
    sed -i '
    s|# blockchain_rpc_endpoint = ".*"|blockchain_rpc_endpoint = "'$json_rpc'"|
    s|# miner_key = ""|miner_key = "'$miner_key'"|
    ' $HOME/0g-storage-node/run/config-testnet-turbo.toml

    # 启动
    cd ~/0g-storage-node/run
    start="while true; do $HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config-testnet-turbo.toml; echo '进程异常退出，等待重启60s' >&2; sleep 60; done"
    screen -dmS zgs_node_session bash -c "$start"
    #screen -dmS zgs_node_session $HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config-testnet-turbo.toml

    echo '====================== 安装完成，使用 screen -ls 命令查询 ==========================='

}

# 检查存储节点同步状态
function check_storage_status() {
    while true; do
    response=$(curl -s -X POST http://localhost:5678 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
    logSyncHeight=$(echo $response | jq '.result.logSyncHeight')
    connectedPeers=$(echo $response | jq '.result.connectedPeers')
    echo -e "Block: \033[32m$logSyncHeight\033[0m, Peers: \033[34m$connectedPeers\033[0m"
    sleep 5;
    done
}

# 查看存储节点日志
function check_storage_logs() {
    tail -f -n50 ~/0g-storage-node/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d)
}

# 过滤错误日志
function check_storage_error() {
    tail -f -n50 ~/0g-storage-node/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d) | grep ERROR
}

# 重启存储节点
function restart_storage() {
    # 退出现有进程
    screen -S zgs_node_session -X quit
    # 启动
    cd ~/0g-storage-node/run
    start="while true; do $HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config-testnet-turbo.toml; echo '进程异常退出，等待重启60s' >&2; sleep 60; done"
    screen -dmS zgs_node_session bash -c "$start"
    #screen -dmS zgs_node_session $HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config-testnet-turbo.toml
    echo '====================== 启动成功，请通过screen -r zgs_node_session 查询 ==========================='

}

# 删除存储节点日志
function delete_storage_logs(){
    echo "确定删除存储节点日志？[Y/N]"
    read -r -p "请确认: " response
        case "$response" in
        [yY][eE][sS]|[yY])
            rm -r ~/0g-storage-node/run/log/*
            echo "删除完成，请重启存储节点"
            ;;
        *)
            echo "取消操作"
            ;;
    esac

}

function uninstall_storage_node() {
    echo "你确定要卸载0g ai 存储节点程序吗？这将会删除所有相关的数据。[Y/N]"
    read -r -p "请确认: " response

    case "$response" in
        [yY][eE][sS]|[yY])
            echo "开始卸载节点程序..."
            rm -rf $HOME/0g-storage-node
            echo "节点程序卸载完成。"
            ;;
        *)
            echo "取消卸载操作。"
            ;;
    esac
}

# 转换 ETH 地址
function transfer_EIP() {
    #read -p "请输入你的钱包名称: " wallet_name
    echo "0x$(0gchaind debug addr $(0gchaind keys show $wallet_name -a) | grep hex | awk '{print $3}')"

}


# 导出验证者key
function export_priv_validator_key() {
    echo "====================请将下方所有内容备份到自己的记事本或者excel表格中记录==========================================="
    cat ~/.0gchain/config/priv_validator_key.json

}


function update_script() {
    SCRIPT_PATH="./0g-chanway.sh"  # 定义脚本路径
    SCRIPT_URL="https://raw.githubusercontent.com/chanway0602/0g-storage-node/main/0g-chanway.sh"

    # 备份原始脚本
    cp $SCRIPT_PATH "${SCRIPT_PATH}.bak"

    # 下载新脚本并检查是否成功
    if curl -o $SCRIPT_PATH $SCRIPT_URL; then
        chmod +x $SCRIPT_PATH
        echo "脚本已更新。请退出脚本后，执行bash 0g.sh 重新运行此脚本。"
    else
        echo "更新失败。正在恢复原始脚本。"
        mv "${SCRIPT_PATH}.bak" $SCRIPT_PATH
    fi

}

function check_validator_height() {
    rpc_port=$(grep -m 1 -oP '^laddr = "\K[^"]+' "$HOME/.0gchain/config/config.toml" | cut -d ':' -f 3)

    local_height=$(curl -s localhost:$rpc_port/status | jq -r '.result.sync_info.latest_block_height')
    network_height=$(curl -s https://og-testnet-rpc.itrocket.net/status | jq -r '.result.sync_info.latest_block_height')

    if ! [[ "$local_height" =~ ^[0-9]+$ ]] || ! [[ "$network_height" =~ ^[0-9]+$ ]]; then
    echo -e "\033[1;31mError: Invalid block height data. Retrying...\033[0m"
    sleep 5
    continue
    fi

    blocks_left=$((network_height - local_height))
    if [ "$blocks_left" -lt 0 ]; then
    blocks_left=0
    fi

    echo -e "\033[1;33mNode Height:\033[1;34m $local_height\033[0m \033[1;33m| Network Height:\033[1;36m $network_height\033[0m \033[1;33m| Blocks Left:\033[1;31m $blocks_left\033[0m"
}

function check_storage_height() {
RPC_URL=$(grep 'blockchain_rpc_endpoint' $HOME/0g-storage-node/run/config-testnet-turbo.toml | cut -d '"' -f2)

cd $HOME/0g-storage-node
VERSION=$($HOME/0g-storage-node/target/release/zgs_node --version 2>/dev/null)
if [[ -n "$VERSION" ]]; then
    echo -e "🧩 Storage Node Version: \e[1;32m$VERSION\e[0m"
else
    echo -e "🧩 Storage Node Version: \e[31mUnknown\e[0m"
fi

# Display RPC used
echo -e "🔗 RPC: \033[1;34m$RPC_URL\033[0m"
echo -e ""
while true; do 
    # Fetch local node status
    LOCAL_RESPONSE=$(curl -s -X POST http://127.0.0.1:5678 -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"zgs_getStatus","params":[],"id":1}')
    logSyncHeight=$(echo "$LOCAL_RESPONSE" | jq '.result.logSyncHeight' 2>/dev/null)
    connectedPeers=$(echo "$LOCAL_RESPONSE" | jq '.result.connectedPeers' 2>/dev/null)

    # Fetch network block number
    NETWORK_RESPONSE=$(curl -s -m 5 -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}')
    latestBlockHex=$(echo "$NETWORK_RESPONSE" | jq -r '.result' 2>/dev/null)

    # Validate and set fallback values
    if [[ "$logSyncHeight" =~ ^[0-9]+$ ]]; then
        local_status="$logSyncHeight"
    else
        local_status="N/A"
    fi

    [[ "$connectedPeers" =~ ^[0-9]+$ ]] || connectedPeers=0  # Default to 0 if error

    if [[ "$NETWORK_RESPONSE" == *"rate limit"* || "$NETWORK_RESPONSE" == *"Too Many Requests"* ]]; then
        network_status="N/A (RPC Rate Limited)"
    elif [[ -z "$NETWORK_RESPONSE" || "$NETWORK_RESPONSE" == "null" ]]; then
        network_status="N/A (RPC Timeout)"
    elif [[ "$latestBlockHex" =~ ^0x[0-9a-fA-F]+$ ]]; then
        latestBlock=$((16#${latestBlockHex:2}))
        network_status="$latestBlock"
    else
        network_status="N/A (Invalid RPC Response)"
    fi

    extra_info=""
    if [[ "$logSyncHeight" =~ ^[0-9]+$ && "$latestBlock" =~ ^[0-9]+$ ]]; then
        block_diff=$((latestBlock - logSyncHeight))

        current_time=$(date +%s)
        if [[ "$prev_block" =~ ^[0-9]+$ && "$prev_time" =~ ^[0-9]+$ ]]; then
            delta_block=$((logSyncHeight - prev_block))
            delta_time=$((current_time - prev_time))
            if (( delta_time > 0 && delta_block >= 0 )); then
                bps=$(echo "scale=2; $delta_block / $delta_time" | bc)

                if (( block_diff >= 10 )); then
                    if (( $(echo "$bps > 0" | bc -l) )); then
                        eta_sec=$(echo "scale=0; $block_diff / $bps" | bc)

                        if (( eta_sec < 60 )); then
                            eta_display="$eta_sec sec"
                        elif (( eta_sec < 3600 )); then
                            eta_display="$((eta_sec / 60)) min"
                        elif (( eta_sec < 86400 )); then
                            eta_display="$((eta_sec / 3600)) hr"
                        else
                            eta_display="$((eta_sec / 86400)) day(s)"
                        fi

                        extra_info="| Speed: ${bps} blocks/s | ETA: ${eta_display}"
                    else
                        extra_info="| Speed: 0 blocks/s | ETA: ∞"
                    fi
                fi
            fi
        fi

        prev_block=$logSyncHeight
        prev_time=$current_time

        if [ "$block_diff" -le 5 ]; then
            diff_color="\\033[32m" # Green
        elif [ "$block_diff" -le 20 ]; then
            diff_color="\\033[33m" # Yellow
        else
            diff_color="\\033[31m" # Red
        fi

        block_status="(\033[0m${diff_color}Behind $block_diff\033[0m)"
    else
        block_status=""
    fi

    echo -e "Local Block: \033[32m$local_status\033[0m / Network Block: \033[33m$network_status\033[0m $block_status | Peers: \033[34m$connectedPeers\033[0m $extra_info"

    sleep 5
done
}

function check_DA_logs() {
    sudo journalctl -u 0gda -f -o cat
}

# 主菜单
function main_menu() {
    while true; do
        clear
        echo "脚本以及教程由推特用户大赌哥 @y95277777 编写，Chanway客制化更新"
        echo "=======================0GAI节点安装================================"
        echo "=======================验证节点功能================================"
        echo "退出脚本，请按键盘ctrl c退出即可"
        echo "请选择要执行的操作:"
        echo "=======================验证节点================================"
        echo "1. 安装验证节点"
        echo "2. 创建钱包"
        echo "3. 导入钱包"
        echo "4. 查看钱包地址余额"
        echo "5. 查看节点同步状态"
        echo "6. 查看当前服务状态"
        echo "7. 运行日志查询"
        echo "8. 卸载0gchain验证者节点"
        echo "9. 创建验证者"
        echo "10. 给自己验证者地址质押代币"
        echo "11. 转换ETH地址"
        echo "=======================存储节点================================"
        echo "12. 安装存储节点"
        echo "13. 检查存储节点同步状态"
        echo "14. 查看存储节点日志"
        echo "15. 过滤错误日志"
        echo "16. 重启存储节点"
        echo "17. 卸载存储节点"
        echo "18. 删除存储节点日志"
        echo "=======================备份功能================================"
        echo "19. 备份验证者私钥"
        echo "======================================================="
        echo "20. 更新本脚本"
        echo "=======================查看节点高度================================"
        echo "21. 查看验证者节点高度"
        echo "22. 查看存储节点高度"
        echo "23. 查看DA节点日志"
        read -p "请输入选项（1-22）: " OPTION

        case $OPTION in
        1) install_validator ;;
        2) add_wallet ;;
        3) import_wallet ;;
        4) check_balances ;;
        5) check_sync_status ;;
        6) check_service_status ;;
        7) view_logs ;;
        8) uninstall_validator ;;
        9) add_validator ;;
        10) delegate_self_validator ;;
        11) transfer_EIP ;;
        12) install_storage_node ;;
        13) check_storage_status ;;
        14) check_storage_logs ;;
        15) check_storage_error;;
        16) restart_storage ;;
        17) uninstall_storage_node ;;
        18) delete_storage_logs ;;
        19) export_priv_validator_key ;;
        20) update_script ;;
        21) check_validator_height ;;
        22) check_storage_height ;;
        23) check_DA_logs ;;

        *) echo "无效选项。" ;;
        esac
        
        echo "按任意键返回主菜单..."
        read -n 1
    done

}

# 显示主菜单
main_menu
