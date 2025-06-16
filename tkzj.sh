#!/bin/sh

echo "蓝海科技一键脚本，有问题请联系 QQ:136014789"
echo "请选择操作："
echo "1) 安装节点程序（第一次运行）"
echo "2) 安装节点程序（非第一次运行）"
echo "3) 结束节点运行程序"
echo "4) 查看节点运行状态"
echo "5) 矿工开始挖矿（编译方式）"
echo "6) 矿工开始挖矿（非编译方式）"
echo "7) 查看矿工状态"
echo "8) 结束矿工挖矿"
echo "9) 退出程序"
read -p "请输入选项 (1/2/3/4/5/6/7/8/9): " choice

case $choice in
    1)
        echo "正在安装节点程序（第一次运行）..."

        # 安装必要的依赖
        sudo apt update
        sudo apt install -y snapd git make g++ wget

        # 安装 Go
        sudo snap install go --classic

        # 获取用户输入的 coinbases 地址
        echo "请输入 'quai-coinbases' 地址（例如：0x000D72e6f62C9D1ce58207FD36866f272718D044）："
        read QUAI_COINBASES
        echo "请输入 'qi-coinbases' 地址（例如：0x00CC04a1A16CE070654eFA457A48609060889687）："
        read QI_COINBASES

        # 克隆并编译 go-quai
        git clone https://github.com/dominant-strategies/go-quai
        cd go-quai
        git checkout v0.38.0
        make go-quai

        # 清理旧数据并恢复备份
        sudo rm -rf nodelogs ~/.local/share/go-quai
        sudo rm quai-goldenage-backup.tgz
        wget https://storage.googleapis.com/colosseum-db/goldenage_backups/quai-goldenage-backup.tgz
        tar -xvf quai-goldenage-backup.tgz
        cp -r quai-goldenage-backup ~/.local/share/go-quai

        # 启动 go-quai 节点
        nohup ./build/bin/go-quai start \
            --node.slices '[0 0]' \
            --node.genesis-nonce 6224362036655375007 \
            --node.quai-coinbases "$QUAI_COINBASES" \
            --node.qi-coinbases "$QI_COINBASES" \
            --node.miner-preference '0.5' &

        # 克隆并编译 go-quai-stratum
        sudo rm -rf go-quai-stratum
        git clone https://github.com/dominant-strategies/go-quai-stratum
        cd go-quai-stratum
        git checkout v0.16.0
        cp config/config.example.json config/config.json
        make go-quai-stratum

        # 启动 go-quai-stratum
        nohup ./build/bin/go-quai-stratum --region=cyprus --zone=cyprus1 --stratum=3333 &
        echo "运行结束"
        ;;
    2)
        echo "正在安装节点程序（非第一次运行）..."

        # 获取用户输入的 coinbases 地址
        echo "请输入 'quai-coinbases' 地址（例如：0x000D72e6f62C9D1ce58207FD36866f272718D044）："
        read QUAI_COINBASES
        echo "请输入 'qi-coinbases' 地址（例如：0x00CC04a1A16CE070654eFA457A48609060889687）："
        read QI_COINBASES
        cd go-quai
        git checkout v0.38.0
        make go-quai

        # 重新启动 go-quai 节点
        nohup ./build/bin/go-quai start \
            --node.slices '[0 0]' \
            --node.genesis-nonce 6224362036655375007 \
            --node.quai-coinbases "$QUAI_COINBASES" \
            --node.qi-coinbases "$QI_COINBASES" \
            --node.miner-preference '0.5' &

        # 重新启动 go-quai-stratum
        git clone https://github.com/dominant-strategies/go-quai-stratum
        cd go-quai-stratum
        git checkout v0.16.0
        cp config/config.example.json config/config.json
        make go-quai-stratum
        nohup ./build/bin/go-quai-stratum --region=cyprus --zone=cyprus1 --stratum=3333 &
        echo "运行结束"
        ;;
    3)
        echo "正在结束节点运行程序..."
        sudo pkill -f go-quai
        sudo pkill -f go-quai-stratum
        echo "节点运行程序已结束。"
        ;;
    4)
        echo "正在查看节点运行状态..."
        cd go-quai
        tail -f nodelogs/* | grep Appended
        ;;
    5)
        echo "正在开始挖矿（编译方式）..."

        # 安装依赖
        if ! command -v cmake &> /dev/null; then
            echo "正在安装依赖..."
            sudo apt update && apt install -y build-essential cmake mesa-common-dev git wget
        else
            echo "依赖已安装。"
        fi

        # 检查 CUDA toolkit 12.6 是否安装
        if ! dpkg -l | grep -q cuda-toolkit-12-6; then
            echo "CUDA toolkit 12.6 未安装，正在安装..."
            wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
            dpkg -i cuda-keyring_1.1-1_all.deb
            sudo apt update && apt install -y cuda-toolkit-12-6
        else
            echo "CUDA toolkit 12.6 已安装。"
        fi

        echo "所有依赖项已成功安装！"

        # 克隆并编译 quai-gpu-miner
        git clone https://gitee.com/xuzhen527/quai-gpu-miner.git
        cd quai-gpu-miner
        git submodule update --init --recursive
        mkdir build && cd build
        cmake .. -DETHASHCUDA=ON -DETHASHCL=ON
        cmake --build .

        # 复制二进制文件到输出文件夹
        mkdir -p ../../output && cp kawpowminer/kawpowminer ../../output/quai-gpu-miner

        # 安装 CUDA 驱动
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y cuda-drivers
        # 提示用户输入 PROXYIPADDRESS 和 STRATUMPORT
        read -p "请输入矿池代理 IP 地址（PROXYIPADDRESS）： " PROXYIPADDRESS

        set -e
        set -x
        # 启动矿工
        ./output/quai-gpu-miner -U -P stratum://$PROXYIPADDRESS:3333
        echo "挖矿已开始。"
        ;;
    6)
        echo "正在开始挖矿（非编译方式）..."
        if ! command -v cmake &> /dev/null; then
            echo "正在安装依赖..."
            sudo apt update && apt install -y build-essential cmake mesa-common-dev git wget
        else
            echo "依赖已安装。"
        fi

        # 检查 CUDA toolkit 12.6 是否安装
        if ! dpkg -l | grep -q cuda-toolkit-12-6; then
            echo "CUDA toolkit 12.6 未安装，正在安装..."
            wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
            dpkg -i cuda-keyring_1.1-1_all.deb
            sudo apt update && apt install -y cuda-toolkit-12-6
            
        else
            echo "CUDA toolkit 12.6 已安装。"
        fi
        # 安装 CUDA 驱动
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y cuda-drivers
        echo "所有依赖项已成功安装！"
        # 检查是否已经存在预编译的矿工程序
        if [ -f "./quai-gpu-miner" ]; then
            echo "检测到已有矿工程序，跳过下载步骤。"
        else
            # 下载预编译的矿工程序
            echo "未检测到矿工程序，正在下载..."
            wget https://github.com/dominant-strategies/quai-gpu-miner/releases/download/v0.2.0/quai-gpu-miner -O quai-gpu-miner
            chmod +x quai-gpu-miner
        fi

        # 提示用户输入矿池代理 IP 地址
        read -p "请输入矿池代理 IP 地址（PROXYIPADDRESS）： " PROXYIPADDRESS

        # 启动矿工
        ./quai-gpu-miner -U -P stratum://$PROXYIPADDRESS:3333
        echo "非编译挖矿已结束。"
        ;;

    7)
        echo "正在查看矿工状态..."
        if pgrep -f quai-gpu-miner > /dev/null; then
            echo "矿工正在运行。"
        else
            echo "矿工未运行。"
        fi
        ;;
    8)
        echo "正在结束矿工挖矿..."
        sudo pkill -f quai-gpu-miner
        echo "矿工挖矿已结束。"
        ;;
    9)
        echo "退出程序..."
        exit 0
        ;;
    *)
        echo "无效的选项，请输入 1 到 9 之间的数字。"
        ;;
esac
