#!/bin/bash

for cmd in curl wget tar jq; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌  Missing required tool: $cmd"
        exit 1
    fi
    echo "🔧  $cmd is installed."
done

declare -A rpcs=(
    ["l2rn"]="https://b2n.rpc.caldera.xyz/http"
    ["arbt"]="https://arbitrum-sepolia.drpc.org https://sepolia-rollup.arbitrum.io/rpc"
    ["bast"]="https://base-sepolia-rpc.publicnode.com https://base-sepolia.drpc.org"
    ["blst"]="https://sepolia.blast.io"
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
while true; do
    echo ""
    echo "====== Executor Version Selection ======"
    echo "1) Install latest version"
    echo "2) Install specific version"
    echo ""
    echo "0) Back to main menu"
    echo ""
    read -p "Select an option [0–2] and press Enter: " ver_choice

    case $ver_choice in
            0) return;;
            1)
                TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
                break
                ;;
            2)
                read -p "🔢  Enter version (e.g. 0.60.0): " input_version
                input_version=$(echo "$input_version" | xargs)

                if [[ -z "$input_version" ]]; then
                    echo "↩️  No version entered. Returning to version selection."
                    continue
                fi

                if [[ $input_version != v* ]]; then
                    TAG="v$input_version"
                else
                    TAG="$input_version"
                fi
                break
                ;;
            *)
                echo "❌  Invalid option."
                ;;
        esac
done

    if [[ -d "$HOME/t3rn" ]]; then
        echo "📁  Directory 't3rn' already exists."
        read -p "❓  Do you want to remove and reinstall? (y/N): " confirm
        confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)

        if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
            echo "🚫  Reinstallation cancelled."
            return
        fi

        if [[ "$(pwd)" == "$HOME/t3rn"* ]]; then
            echo "🔁  Moving out of the t3rn directory before deletion..."
            cd ~ || exit 1
        fi

        echo "🧹  Removing previous installation..."
        sudo systemctl disable --now t3rn-executor.service 2>/dev/null
        sudo rm -f /etc/systemd/system/t3rn-executor.service
        sudo systemctl daemon-reload
        rm -rf "$HOME/t3rn"
    fi

    mkdir -p "$HOME/t3rn" && cd "$HOME/t3rn" || exit 1
    if [[ -z "$TAG" ]]; then
        echo "❌  Failed to determine executor version tag. Aborting installation."
        return
    fi
    echo "⬇️  Downloading executor version $TAG..."
    wget --quiet --show-progress https://github.com/t3rn/executor-release/releases/download/${TAG}/executor-linux-${TAG}.tar.gz
    tar -xzf executor-linux-${TAG}.tar.gz
    rm -f executor-linux-${TAG}.tar.gz
    cd executor/executor/bin || exit 1

    export ENVIRONMENT=testnet
    export LOG_LEVEL=debug
    export LOG_PRETTY=false
    export EXECUTOR_PROCESS_BIDS_ENABLED=true
    export EXECUTOR_PROCESS_ORDERS_ENABLED=true
    export EXECUTOR_PROCESS_CLAIMS_ENABLED=true
    export ENABLED_NETWORKS='arbitrum-sepolia,base-sepolia,optimism-sepolia,l2rn,blast-sepolia,unichain-sepolia'

    read -p "⛽  Max L3 gas price (default 1000): " gas_price
    export EXECUTOR_MAX_L3_GAS_PRICE=${gas_price:-1000}

    read -p "🔧  EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API (true/false, default: true): " pending_api
    export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=${pending_api:-true}

    read -p "🔧  EXECUTOR_PROCESS_ORDERS_API_ENABLED (true/false, default: true): " orders_api
    export EXECUTOR_PROCESS_ORDERS_API_ENABLED=${orders_api:-true}

    read -p "🔑  Enter PRIVATE_KEY_LOCAL (without 0x): " private_key

    if [[ -z "$private_key" ]]; then
        echo -e "⚠️  Private key is empty."

        while true; do
            echo -e "\n❓  Do you want to continue without setting the private key?"
            echo "1) 🔁  Go back and enter private key"
            echo "2) ⏩  Continue installation without private key"
            echo ""
            echo "0) ❌  Cancel installation"
            echo ""
            read -p "Select an option [0–2] and press Enter: " pk_choice

            case $pk_choice in
                1)
                    read -p "🔑  Enter PRIVATE_KEY_LOCAL (without 0x): " private_key
                    if [[ -n "$private_key" ]]; then
                        break
                    else
                        echo "⚠️  Still empty. Try again."
                    fi
                    ;;
                2)
                    echo "⚠️  Continuing without a private key. Executor may fail to start."
                    break
                    ;;
                0)
                    echo "❌  Installation cancelled."
                    return
                    ;;
                *)
                    echo "❌  Invalid option. Please choose 1, 2 or 0."
                    ;;
            esac
        done
    fi

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
    echo "✅  Systemd service 't3rn-executor' installed and started."
    sleep 0.3

    if systemctl is-active --quiet t3rn-executor; then
        echo "🚀  Executor is running."
    else
        echo "❌  Executor failed to start. Run option 10 to check status."
    fi
}

rebuild_rpc_endpoints() {
    rpc_json=$(jq -n '{
        l2rn: $l2rn,
        arbt: $arbt,
        bast: $bast,
        blst: $blst,
        opst: $opst,
        unit: $unit
    }' \
        --argjson l2rn "$(printf '%s\n' ${rpcs[l2rn]} | jq -R . | jq -s .)" \
        --argjson arbt "$(printf '%s\n' ${rpcs[arbt]} | jq -R . | jq -s .)" \
        --argjson bast "$(printf '%s\n' ${rpcs[bast]} | jq -R . | jq -s .)" \
        --argjson blst "$(printf '%s\n' ${rpcs[blst]} | jq -R . | jq -s .)" \
        --argjson opst "$(printf '%s\n' ${rpcs[opst]} | jq -R . | jq -s .)" \
        --argjson unit "$(printf '%s\n' ${rpcs[unit]} | jq -R . | jq -s .)"
    )

    export RPC_ENDPOINTS="$rpc_json"
}

edit_rpc_menu() {
    echo -e "\n🌐  Edit RPC Endpoints"
    local changes_made=false

    for net in "l2rn" "arbt" "bast" "blst" "opst" "unit"; do
        name=${network_names[$net]}
        echo "🔗  Enter new RPC URL(s) for $name ($net), separated by space (or press Enter to keep current):"
        echo "    Current: ${rpcs[$net]}"
        read -p "> " input

        if [[ -n $input ]]; then
            rpcs[$net]="$input"
            echo "✅  RPCs updated."
            changes_made=true
        fi
    done

    if [[ "$changes_made" == true ]]; then
        rebuild_rpc_endpoints
        echo -e "✅  RPC endpoints updated."
        echo -e "🔄  Restart required to apply changes. Use option [9] in the main menu."
    else
        echo -e "\nℹ️  No RPC endpoints were changed."
    fi
}

uninstall_t3rn() {
    read -p "❗  Are you sure you want to completely remove T3rn Installer and Executor? (y/N): " confirm
    confirm=$(echo "$confirm" | tr '[:upper:]' '[:lower:]' | xargs)

        if [[ "$confirm" != "y" && "$confirm" != "yes" ]]; then
        echo "🚫  Uninstall cancelled."
        return
    fi

    echo "🗑️  Uninstalling T3rn Installer and Executor..."
    sudo systemctl disable --now t3rn-executor.service 2>/dev/null
    sudo rm -f /etc/systemd/system/t3rn-executor.service
    sudo systemctl daemon-reload
    rm -rf "$HOME/t3rn"
    sudo journalctl --rotate
    sudo journalctl --vacuum-time=1s
    echo "✅  T3rn Installer and Executor have been removed."
}

while true; do
    echo ""
    echo "====== ⚙️  T3rn Installer Menu ======"
    echo ""
    echo "📦  Installation"
    echo "1) Install / Update Executor"
    echo "2) Uninstall Installer & Executor"
    echo ""
    echo "🛠️  Configuration"
    echo "3) View Executor Logs"
    echo "4) Show Configured RPCs"
    echo "5) Edit RPC Endpoints"
    echo "6) Set Max L3 Gas Price"
    echo "7) Configure Order API Flags"
    echo "8) Set / Update Private Key"
    echo ""
    echo "🔁  Executor Control"
    echo "9) Restart Executor"
    echo "10) View Executor Status [systemd]"
    echo ""
    echo "0) Exit"
    echo ""
    read -p "➡️  Select an option [0–10] and press Enter: " opt

    case $opt in
        1) install_executor;;
        2) uninstall_t3rn;;
        3)
            echo "📜  Viewing executor logs (without timestamps/hostnames)..."
            sudo journalctl -u t3rn-executor -f --no-pager --output=cat;;
        4)
            echo -e "\n🌐  Current RPC Endpoints:"
            for net in "${!rpcs[@]}"; do
                echo "- ${network_names[$net]} ($net):"
                for url in ${rpcs[$net]}; do
                    echo "   • $url"
                done
            done;;
        5) edit_rpc_menu;;

        6)
            read -p "⛽  Enter new Max L3 gas price: " gas

            if [[ -z "$gas" ]]; then
                echo "ℹ️  No input provided. Gas price unchanged."
            elif ! [[ "$gas" =~ ^[0-9]+$ ]]; then
                echo "❌  Invalid gas price. Must be a number."
            else
                export EXECUTOR_MAX_L3_GAS_PRICE=$gas
                echo "✅  New gas price set to $EXECUTOR_MAX_L3_GAS_PRICE."
                echo "🔄  Restart required to apply changes. Use option [9] in the main menu."
            fi
            ;;

        7)
            read -p "🔧  EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API (true/false, default: true): " val1
            read -p "🔧  EXECUTOR_PROCESS_ORDERS_API_ENABLED (true/false, default: true): " val2

            if [[ -z "$val1" && -z "$val2" ]]; then
                echo "ℹ️  No input provided. Flags remain unchanged."
            else
                valid=true
                for flag in "$val1" "$val2"; do
                    if [[ -n "$flag" && "$flag" != "true" && "$flag" != "false" ]]; then
                        echo "❌  Invalid value: '$flag'. Allowed values are 'true' or 'false'."
                        valid=false
                    fi
                done

                if [[ "$valid" == true ]]; then
                    export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=${val1:-true}
                    export EXECUTOR_PROCESS_ORDERS_API_ENABLED=${val2:-true}
                    echo "✅  Order processing flags updated."
                    echo "🔄  Restart required to apply changes. Use option [9] in the main menu."
                fi
            fi
            ;;

        8)
            read -p "🔑  Enter new PRIVATE_KEY_LOCAL (without 0x): " pk
            if [[ -n "$pk" ]]; then
                export PRIVATE_KEY_LOCAL=$pk
                echo "✅  Private key updated."
                echo "🔄  Restart required to apply changes. Use option [9] in the main menu."
            else
                echo "ℹ️  No input provided. Private key unchanged."
            fi;;
        9)
            echo "🔁  Restarting executor..."
            rebuild_rpc_endpoints
            create_systemd_unit
            if sudo systemctl restart t3rn-executor; then
                echo "✅  Executor restarted successfully."
            else
                echo "❌  Failed to restart executor. Please check the systemctl logs."
            fi;;
        10)
            echo "🔍  Checking Executor status using systemd..."
            sleep 0.3
            systemctl status t3rn-executor --no-pager || echo "❌  Executor is not running.";;
        0)
            echo "👋  Exiting. Goodbye!"
            exit 0;;
        *) echo "❌  Invalid option. Please try again.";;
    esac
done
