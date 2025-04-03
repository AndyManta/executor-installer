#!/bin/bash

# Dependency check
for cmd in curl wget tar jq; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Missing required tool: $cmd"
        exit 1
    fi
    echo "🔧 $cmd is installed."
    sleep 0.1
done

# Default RPCs (no file-based config)
declare -A rpcs=(
    ["l2rn"]="https://b2n.rpc.caldera.xyz/http https://b2n-testnet.blockpi.network/v1/rpc/public"
    ["arbt"]="https://arbitrum-sepolia.drpc.org https://sepolia-rollup.arbitrum.io/rpc"
    ["bast"]="https://base-sepolia-rpc.publicnode.com https://base-sepolia.drpc.org"
    ["blst"]="https://sepolia.blast.io https://blast-sepolia.drpc.org"
    ["opst"]="https://sepolia.optimism.io https://optimism-sepolia.drpc.org"
    ["unit"]="https://unichain-sepolia.drpc.org https://sepolia.unichain.org"
)

declare -A network_names=(
    ["l2rn"]="L2RN Testnet"
    ["arbt"]="Arbitrum Sepolia"
    ["bast"]="Base Sepolia"
    ["blst"]="Blast Sepolia"
    ["opst"]="Optimism Sepolia"
    ["unit"]="Unichain Sepolia"
)

install_executor() {
    if [[ -d "t3rn" ]]; then
        echo "📁 Directory 't3rn' already exists."
        read -p "❓ Do you want to remove and reinstall? (y/N): " confirm
        confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
        if [[ "$confirm" != "y" ]]; then return; fi
        sudo systemctl disable --now t3rn-executor.service 2>/dev/null
        sudo rm -f /etc/systemd/system/t3rn-executor.service
        sudo systemctl daemon-reload
        rm -rf t3rn
    fi

    mkdir -p t3rn && cd t3rn || exit 1
    TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
    echo "⬇️ Downloading executor..."
    wget --show-progress https://github.com/t3rn/executor-release/releases/download/${TAG}/executor-linux-${TAG}.tar.gz
    tar -xzf executor-linux-${TAG}.tar.gz
    cd executor/executor/bin || exit 1

    export ENVIRONMENT=testnet
    export LOG_LEVEL=debug
    export LOG_PRETTY=false
    export EXECUTOR_PROCESS_BIDS_ENABLED=true
    export EXECUTOR_PROCESS_ORDERS_ENABLED=true
    export EXECUTOR_PROCESS_CLAIMS_ENABLED=true

    read -p "⛽ Max L3 gas price (default 1000): " gas_price
    export EXECUTOR_MAX_L3_GAS_PRICE=${gas_price:-1000}

    read -p "🔧 EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API (default: true): " pending_api
    export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=${pending_api:-true}

    read -p "🔧 EXECUTOR_PROCESS_ORDERS_API_ENABLED (default: true): " orders_api
    export EXECUTOR_PROCESS_ORDERS_API_ENABLED=${orders_api:-true}

    read -p "🔑 Enter PRIVATE_KEY_LOCAL (without 0x): " private_key
    export PRIVATE_KEY_LOCAL=$private_key

    rpc_json="{"
    for key in "l2rn" "arbt" "bast" "blst" "opst" "unit"; do
        urls_string=${rpcs[$key]}
        rpc_json+="\"$key\": ["
        for url in $urls_string; do
            rpc_json+="\"$url\", "
        done
        rpc_json="${rpc_json%, }], "
    done
    rpc_json="${rpc_json%, }"; rpc_json+='}'
    export RPC_ENDPOINTS="$rpc_json"

    create_systemd_unit
    cd ../../..
}

create_systemd_unit() {
    UNIT_PATH="/etc/systemd/system/t3rn-executor.service"
    rpc_escaped=$(echo "$RPC_ENDPOINTS" | jq -c . | sed 's/"/\\"/g')
    sudo bash -c "cat > $UNIT_PATH" <<EOF
[Unit]
Description=T3rn Executor Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/t3rn/executor/executor/bin

Environment=ENVIRONMENT=${ENVIRONMENT}
Environment=LOG_LEVEL=${LOG_LEVEL}
Environment=LOG_PRETTY=${LOG_PRETTY}
Environment=EXECUTOR_PROCESS_BIDS_ENABLED=${EXECUTOR_PROCESS_BIDS_ENABLED}
Environment=EXECUTOR_PROCESS_ORDERS_ENABLED=${EXECUTOR_PROCESS_ORDERS_ENABLED}
Environment=EXECUTOR_PROCESS_CLAIMS_ENABLED=${EXECUTOR_PROCESS_CLAIMS_ENABLED}
Environment=EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=${EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API}
Environment=EXECUTOR_PROCESS_ORDERS_API_ENABLED=${EXECUTOR_PROCESS_ORDERS_API_ENABLED}
Environment=EXECUTOR_MAX_L3_GAS_PRICE=${EXECUTOR_MAX_L3_GAS_PRICE}
Environment=PRIVATE_KEY_LOCAL=${PRIVATE_KEY_LOCAL}
Environment=ENABLED_NETWORKS=${ENABLED_NETWORKS}
Environment=RPC_ENDPOINTS=$rpc_escaped

ExecStart=$HOME/t3rn/executor/executor/bin/executor
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now t3rn-executor
    echo "✅ Systemd service 't3rn-executor' installed and started."
sleep 0.3
if systemctl is-active --quiet t3rn-executor; then
    echo "🚀 Executor is running."
else
    echo "❌ Executor failed to start. Run option 10 to check status."
fi
}

rebuild_rpc_endpoints() {
    rpc_json="{"
    for key in "l2rn" "arbt" "bast" "blst" "opst" "unit"; do
        urls_string=${rpcs[$key]}
        rpc_json+="\"$key\": ["
        for url in $urls_string; do
            rpc_json+="\"$url\", "
        done
        rpc_json="${rpc_json%, }], "
    done
    rpc_json="${rpc_json%, }"; rpc_json+='}'
    export RPC_ENDPOINTS="$rpc_json"
}

edit_rpc_menu() {
    echo -e "\n🌐 Edit RPC Endpoints"
    for net in "l2rn" "arbt" "bast" "blst" "opst" "unit"; do
        name=${network_names[$net]}
        echo "🔗 Enter new RPC URL(s) for $name ($net), separated by space (or press Enter to keep current):"
        echo "   Current: ${rpcs[$net]}"
        read -p "> " input
        [[ -n $input ]] && rpcs[$net]="$input"
    done
    rebuild_rpc_endpoints
    echo "✅ All RPC endpoints updated."
}

uninstall_t3rn() {
    read -p "❗ Are you sure you want to completely remove T3rn Installer and Executor? (y/N): " confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)
    if [[ "$confirm" != "y" ]]; then
        echo "🚫 Uninstall cancelled."
        return
    fi

    echo "🗑️ Uninstalling T3rn Installer and Executor..."
    sudo systemctl disable --now t3rn-executor.service 2>/dev/null
    sudo rm -f /etc/systemd/system/t3rn-executor.service
    sudo systemctl daemon-reload
    rm -rf "$HOME/t3rn"
    echo "✅ T3rn Installer and Executor have been removed."
}

# Main Menu
while true; do
    echo ""
    echo "====== T3rn Installer Menu ======"
    echo "1) Install or Update Executor"
    echo "2) Uninstall T3rn Installer and Executor"
    echo "3) View Executor Logs"
    echo "4) Show All Current RPCs"
    echo "5) Edit RPC Endpoints"
    echo "6) Change Max L3 Gas Price"
    echo "7) Toggle Order API Flags"
    echo "8) Set Private Key"
    echo "9) Restart Executor"
    echo "10) Check Executor Status"
    echo "0) Exit"
    read -p "Select an option [0–10]: " opt
    case $opt in
        1) install_executor;;
        2) uninstall_t3rn;;
        3)
            echo "📜 Viewing executor logs (without timestamps/hostnames)..."
            sudo journalctl -u t3rn-executor -f --no-pager --output=cat;;
        4)
            echo -e "\n🌐 Current RPC Endpoints:"
            for net in "${!rpcs[@]}"; do
                echo "- ${network_names[$net]} ($net):"
                for url in ${rpcs[$net]}; do
                    echo "   • $url"
                done
            done;;
        5) edit_rpc_menu;;
        6)
            read -p "⛽ Enter new Max L3 gas price: " gas
            if [[ -n "$gas" ]]; then
                export EXECUTOR_MAX_L3_GAS_PRICE=$gas
                echo "ℹ️  New gas price set to \${EXECUTOR_MAX_L3_GAS_PRICE}. To apply changes, please restart the executor (option 9)."
            else
                echo "⚠️  No input provided. Gas price unchanged."
            fi;;
        7)
            read -p "🔧 EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API (true/false): " val1
            export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=${val1:-true}
            read -p "🔧 EXECUTOR_PROCESS_ORDERS_API_ENABLED (true/false): " val2
            export EXECUTOR_PROCESS_ORDERS_API_ENABLED=${val2:-true}
            echo "ℹ️  Order processing flags updated. Please restart the executor (option 9).";;
        8)
            read -p "🔑 Enter new PRIVATE_KEY_LOCAL (without 0x): " pk
            if [[ -n "$pk" ]]; then
                export PRIVATE_KEY_LOCAL=$pk
                echo "ℹ️  Private key updated. Please restart the executor (option 9)."
            else
                echo "⚠️  No input provided. Private key unchanged."
            fi;;
        9)
            echo "🔁 Restarting executor..."
            rebuild_rpc_endpoints
            create_systemd_unit
            if sudo systemctl restart t3rn-executor; then
                echo "✅ Executor restarted successfully."
            else
                echo "❌ Failed to restart executor. Please check the systemctl logs."
            fi;;
        10)
            echo "🔍 Checking Executor status..."
            sleep 0.3
            systemctl status t3rn-executor --no-pager || echo "❌ Executor is not running.";;
        0)
            echo "👋 Exiting. Goodbye!"
            exit 0;;
        *) echo "❌ Invalid option. Please try again.";;
    esac
done
