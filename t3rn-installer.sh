#!/bin/bash
VERSION="v1.1.1"

ENV_FILE="$HOME/t3rn/.env"

if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

confirm_prompt() {
    local prompt="$1"
    read -p "$prompt (y/N): " response
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]' | xargs)
    [[ "$response" == "y" || "$response" == "yes" ]]
}

prompt_input() {
    local prompt="$1"
    local var
    read -p "$prompt" var
    echo "$var" | xargs
}

is_number() {
    [[ "$1" =~ ^[0-9]+$ ]]
}

if ! command -v sudo &>/dev/null; then
    echo "⚠️  'sudo' is not installed. It is required for this script to work properly."
    if confirm_prompt "📦  Do you want to install 'sudo' now?"; then
        if command -v apt &>/dev/null; then
            echo "🔐  Installing sudo (root password will be required)..."
            su -c "apt update && apt install -y sudo"
        elif command -v yum &>/dev/null; then
            echo "🔐  Installing sudo (root password will be required)..."
            su -c "yum install -y sudo"
        else
            echo "❌  Unsupported package manager. Please install 'sudo' manually and rerun the script."
            exit 1
        fi

        if ! command -v sudo &>/dev/null; then
            echo "❌  Failed to install sudo. Please install it manually."
            exit 1
        fi
    else
        echo "❌  Cannot continue without 'sudo'. Exiting."
        exit 1
    fi
fi

required_tools=(sudo curl wget tar jq lsof)
missing=()
installed=()

for tool in "${required_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        installed+=("$tool")
    else
        missing+=("$tool")
    fi
done

echo -n "🔧  Installed tools: "
echo "${installed[*]}"
echo ""
echo "🛠️  T3rn Installer — Version $VERSION"

for tool in "${missing[@]}"; do
    echo "❌  $tool is missing."
    read -p "📦  Do you want to install '$tool'? (Y/n): " reply
    reply=${reply,,}
    if [[ -z "$reply" || "$reply" == "y" || "$reply" == "yes" ]]; then
        if command -v apt &>/dev/null; then
            sudo apt update && sudo apt install -y "$tool"
        elif command -v yum &>/dev/null; then
            sudo yum install -y "$tool"
        else
            echo "⚠️  Package manager not recognized. Please install '$tool' manually."
            exit 1
        fi
    else
        echo "⚠️  '$tool' is required. Exiting."
        exit 1
    fi
done

declare -A rpcs=(
    ["l2rn"]="https://b2n.rpc.caldera.xyz/http"
    ["arbt"]="https://arbitrum-sepolia-rpc.publicnode.com https://sepolia-rollup.arbitrum.io/rpc"
    ["bast"]="https://base-sepolia-rpc.publicnode.com https://sepolia.base.org"
    ["blst"]="https://sepolia.blast.io"
    ["opst"]="https://optimism-sepolia-rpc.publicnode.com https://sepolia.optimism.io"
    ["unit"]="https://unichain-sepolia-rpc.publicnode.com https://sepolia.unichain.org"
    ["mont"]="https://testnet-rpc.monad.xyz"
    ["seit"]="https://evm-rpc-testnet.sei-apis.com"
)

declare -A network_names=(
    ["l2rn"]="B2N Testnet"
    ["arbt"]="Arbitrum Sepolia"
    ["bast"]="Base Sepolia"
    ["blst"]="Blast Sepolia"
    ["opst"]="Optimism Sepolia"
    ["unit"]="Unichain Sepolia"
    ["mont"]="Monad Testnet"
    ["arbm"]="Arbitrum Mainnet"
    ["basm"]="Base Mainnet"
    ["opsm"]="Optimism Mainnet"
    ["seit"]="Sei Testnet"
)

declare -A executor_ids=(
    ["l2rn"]="l2rn"
    ["arbt"]="arbitrum-sepolia"
    ["bast"]="base-sepolia"
    ["blst"]="blast-sepolia"
    ["opst"]="optimism-sepolia"
    ["unit"]="unichain-sepolia"
    ["mont"]="monad-testnet"
    ["arbm"]="arbitrum"
    ["basm"]="base"
    ["opsm"]="optimism"
    ["seit"]="sei-testnet"
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
        0) return ;;
        1)
            TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")')
            break
            ;;
        2)
            input_version=$(prompt_input "🔢  Enter version (e.g. 0.60.0): ")
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

    if [[ -f "$ENV_FILE" ]]; then
        echo "🧹  Removing existing configuration: $ENV_FILE"
        rm -f "$ENV_FILE"
    fi

    for dir in "$HOME/t3rn" "$HOME/executor"; do
        if [[ -d "$dir" ]]; then
            echo "📁  Directory '$(basename "$dir")' already exists."
            if confirm_prompt "❓  Do you want to remove it?"; then
                if [[ "$(pwd)" == "$dir"* ]]; then
                    cd ~ || exit 1
                fi
                echo "🧹  Removing $dir..."
                rm -rf "$dir"
            else
                echo "🚫  Installation cancelled due to existing directory: $dir"
                return
            fi
        fi
    done

    if lsof -i :9090 &>/dev/null; then
        echo "⚠️  Port 9090 is currently in use."
        pid_9090=$(lsof -ti :9090)
        echo "🔪  Killing process using port 9090 (PID: $pid_9090)..."
        kill -9 $pid_9090
        sleep 1
        echo "✅  Port 9090 is now free."
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

    export ENVIRONMENT=${ENVIRONMENT:-testnet}
    export LOG_LEVEL=${LOG_LEVEL:-debug}
    export LOG_PRETTY=${LOG_PRETTY:-false}
    export EXECUTOR_PROCESS_BIDS_ENABLED=${EXECUTOR_PROCESS_BIDS_ENABLED:-true}
    export EXECUTOR_PROCESS_ORDERS_ENABLED=${EXECUTOR_PROCESS_ORDERS_ENABLED:-true}
    export EXECUTOR_PROCESS_CLAIMS_ENABLED=${EXECUTOR_PROCESS_CLAIMS_ENABLED:-true}
    export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=${EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API:-true}
    export EXECUTOR_PROCESS_ORDERS_API_ENABLED=${EXECUTOR_PROCESS_ORDERS_API_ENABLED:-true}
    export EXECUTOR_MAX_L3_GAS_PRICE=${EXECUTOR_MAX_L3_GAS_PRICE:-1000}
    export EXECUTOR_PROCESS_BIDS_API_INTERVAL_SEC=${EXECUTOR_PROCESS_BIDS_API_INTERVAL_SEC:-30}
    export EXECUTOR_MIN_BALANCE_THRESHOLD_ETH=${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-1}
    export PROMETHEUS_ENABLED=${PROMETHEUS_ENABLED:-false}
    while true; do

        private_key=$(prompt_input "🔑  Enter PRIVATE_KEY_LOCAL: ")
        private_key=$(echo "$private_key" | sed 's/^0x//')
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
                    read -p "🔑  Enter PRIVATE_KEY_LOCAL: " private_key
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
        break
    done

    export PRIVATE_KEY_LOCAL=$private_key
    rebuild_rpc_endpoints
    rebuild_network_lists
    if ! validate_config_before_start; then
        echo "❌ Aborting due to invalid configuration."
        return
    fi
    save_env_file
    sudo systemctl disable --now t3rn-executor.service 2>/dev/null
    sudo rm -f /etc/systemd/system/t3rn-executor.service
    sudo systemctl daemon-reload
    create_systemd_unit
}

validate_config_before_start() {
    echo -e "\n🧪 Validating configuration before starting executor..."
    local error=false

    if [[ -z "$PRIVATE_KEY_LOCAL" ]]; then
        echo "❌ PRIVATE_KEY_LOCAL is not set."
        error=true
    elif [[ ! "$PRIVATE_KEY_LOCAL" =~ ^[a-fA-F0-9]{64}$ ]]; then
        echo "❌ PRIVATE_KEY_LOCAL format is invalid. Should be 64 hex characters (without 0x)."
        error=true
    fi

    if [[ -z "$RPC_ENDPOINTS" ]]; then
        echo "❌ RPC_ENDPOINTS is empty or not set."
        error=true
    else
        if ! echo "$RPC_ENDPOINTS" | jq empty &>/dev/null; then
            echo "❌ RPC_ENDPOINTS is not valid JSON."
            error=true
        fi
    fi

    if [[ -z "$ENABLED_NETWORKS" ]]; then
        echo "❌ ENABLED_NETWORKS is not set."
        error=true
    fi

    local bin_path="$HOME/t3rn/executor/executor/bin/executor"
    if [[ ! -f "$bin_path" ]]; then
        echo "❌ Executor binary not found at: $bin_path"
        error=true
    elif [[ ! -x "$bin_path" ]]; then
        echo "❌ Executor binary is not executable. Try: chmod +x $bin_path"
        error=true
    fi

    for flag in EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API EXECUTOR_PROCESS_ORDERS_API_ENABLED; do
        val="${!flag}"
        if [[ "$val" != "true" && "$val" != "false" ]]; then
            echo "❌ $flag must be 'true' or 'false'. Got: '$val'"
            error=true
        fi
    done

    available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    if ((available_space < 500000)); then
        echo "⚠️  Less than 500MB of free space available in home directory."
    fi

    if ! command -v systemctl &>/dev/null; then
        echo "❌ systemctl is not available. This script relies on systemd."
        error=true
    fi

    if ! sudo -n true 2>/dev/null; then
        echo "⚠️  You might be prompted for a sudo password during setup."
    fi

    if [[ "$error" == true ]]; then
        echo -e "\n⚠️  Configuration invalid. Please fix the above issues before proceeding.\n"
        return 1
    else
        echo "✅ All checks passed. Configuration looks valid!"
        return 0
    fi
}

save_env_file() {
    mkdir -p "$HOME/t3rn"
    rebuild_network_lists
    cat >"$ENV_FILE" <<EOF
ENVIRONMENT=${ENVIRONMENT:-testnet}
LOG_LEVEL=${LOG_LEVEL:-debug}
LOG_PRETTY=${LOG_PRETTY:-false}

EXECUTOR_PROCESS_BIDS_ENABLED=${EXECUTOR_PROCESS_BIDS_ENABLED:-true}
EXECUTOR_PROCESS_ORDERS_ENABLED=${EXECUTOR_PROCESS_ORDERS_ENABLED:-true}
EXECUTOR_PROCESS_CLAIMS_ENABLED=${EXECUTOR_PROCESS_CLAIMS_ENABLED:-true}
EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=${EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API:-true}
EXECUTOR_PROCESS_ORDERS_API_ENABLED=${EXECUTOR_PROCESS_ORDERS_API_ENABLED:-true}
EXECUTOR_MAX_L3_GAS_PRICE=${EXECUTOR_MAX_L3_GAS_PRICE:-1000}
EXECUTOR_PROCESS_BIDS_API_INTERVAL_SEC=${EXECUTOR_PROCESS_BIDS_API_INTERVAL_SEC:-30}
EXECUTOR_MIN_BALANCE_THRESHOLD_ETH=${EXECUTOR_MIN_BALANCE_THRESHOLD_ETH:-1}
PROMETHEUS_ENABLED=${PROMETHEUS_ENABLED:-false}

PRIVATE_KEY_LOCAL=${PRIVATE_KEY_LOCAL:-""}
ENABLED_NETWORKS=${ENABLED_NETWORKS}
NETWORKS_DISABLED=${NETWORKS_DISABLED}

RPC_ENDPOINTS='${RPC_ENDPOINTS}'
EOF
}

create_systemd_unit() {
    UNIT_PATH="/etc/systemd/system/t3rn-executor.service"
    ENV_PATH="$HOME/t3rn/.env"
    EXEC_PATH="$HOME/t3rn/executor/executor/bin/executor"
    sudo bash -c "cat > $UNIT_PATH" <<EOF

[Unit]
Description=T3rn Executor Service
After=network.target

[Service]
Type=simple
User=${SUDO_USER:-$USER}
WorkingDirectory=$(dirname "$EXEC_PATH")
EnvironmentFile=$ENV_PATH
ExecStart=$EXEC_PATH
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now t3rn-executor
    echo "✅  Systemd service 't3rn-executor' installed and started. Run option [3] to check logs."
    sleep 0.3

    if systemctl is-active --quiet t3rn-executor; then
        echo "🚀  Executor is running."
    else
        echo "❌  Executor failed to start. Run option [12] to check status."
    fi
}

rebuild_rpc_endpoints() {
    rpc_json=$(
        jq -n '{
        l2rn: $l2rn,
        arbt: $arbt,
        bast: $bast,
        blst: $blst,
        opst: $opst,
        unit: $unit,
        mont: $mont,
        seit: $seit
    }' \
            --argjson l2rn "$(printf '%s\n' ${rpcs[l2rn]} | jq -R . | jq -s .)" \
            --argjson arbt "$(printf '%s\n' ${rpcs[arbt]} | jq -R . | jq -s .)" \
            --argjson bast "$(printf '%s\n' ${rpcs[bast]} | jq -R . | jq -s .)" \
            --argjson blst "$(printf '%s\n' ${rpcs[blst]} | jq -R . | jq -s .)" \
            --argjson opst "$(printf '%s\n' ${rpcs[opst]} | jq -R . | jq -s .)" \
            --argjson unit "$(printf '%s\n' ${rpcs[unit]} | jq -R . | jq -s .)" \
            --argjson mont "$(printf '%s\n' ${rpcs[mont]} | jq -R . | jq -s .)" \
            --argjson seit "$(printf '%s\n' ${rpcs[seit]} | jq -R . | jq -s .)"
    )

    export RPC_ENDPOINTS="$rpc_json"
}

edit_rpc_menu() {
    echo -e "\n🌐  Edit RPC Endpoints"
    local changes_made=false

    for net in "l2rn" "arbt" "bast" "blst" "opst" "unit" "mont" "seit"; do
        name=${network_names[$net]}
        echo "🔗  Enter new RPC URL(s) for $name, separated by space (or press Enter to keep current):"
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
        save_env_file
        echo -e "✅  RPC endpoints updated and saved to .env."
        echo -e "🔄  Restart required to apply changes. Use option [11] in the main menu."
    else
        echo -e "\nℹ️  No RPC endpoints were changed."
    fi

}

uninstall_t3rn() {
    if ! confirm_prompt "❗  Are you sure you want to completely remove T3rn Installer and Executor?"; then
        echo "🚫  Uninstall cancelled."
        return
    fi

    echo "🗑️  Uninstalling T3rn Installer and Executor..."

    sudo systemctl disable --now t3rn-executor.service 2>/dev/null
    sudo rm -f /etc/systemd/system/t3rn-executor.service
    sudo systemctl daemon-reload

    for dir in "$HOME/t3rn" "$HOME/executor"; do
        if [[ -d "$dir" ]]; then
            if [[ "$(pwd)" == "$dir"* ]]; then
                cd ~ || exit 1
            fi
            echo "🧹  Removing directory: $dir"
            rm -rf "$dir"
        fi
    done

    sudo journalctl --rotate
    sudo journalctl --vacuum-time=1s
    rm -f "$HOME/t3rn/.env"

    echo "✅  T3rn Installer and Executor have been removed."
}

configure_disabled_networks() {
    echo -e "\n🛑  Disable Networks"
    echo "Select networks you want to disable."
    echo "Enter the numbers (e.g. 1 3 5):"
    echo ""

    IFS=',' read -ra already_disabled <<<"$NETWORKS_DISABLED"
    declare -A disabled_set
    for net in "${already_disabled[@]}"; do
        disabled_set[$net]=1
    done

    local i=1
    declare -A index_to_key

    for key in "${!executor_ids[@]}"; do
        exec_name="${executor_ids[$key]}"
        if [[ -n "${disabled_set[$exec_name]}" ]]; then
            continue
        fi

        echo "$i) ${network_names[$key]}"
        index_to_key[$i]="$key"
        ((i++))
    done

    echo ""
    read -p "➡️  Enter numbers of networks to disable (e.g. 1 2 3): " input

    if [[ -z "$input" ]]; then
        echo "ℹ️  No input provided. No networks disabled."
        return
    fi

    for d in $input; do
        if ! is_number "$d" || [[ -z "${index_to_key[$d]}" ]]; then
            echo "❌ Invalid input: '$d'. Allowed: numbers from 1 to $((${#index_to_key[@]})) separated by spaces."
            return
        fi
    done

    declare -A seen
    for d in $input; do
        key="${index_to_key[$d]}"
        exec_name="${executor_ids[$key]}"
        disabled_set[$exec_name]=1
    done

    final_disabled=()
    for net in "${!disabled_set[@]}"; do
        final_disabled+=("$net")
    done

    export NETWORKS_DISABLED="$(IFS=','; echo "${final_disabled[*]}")"

    echo -e "\n✅  Networks to be disabled:"
    for net in "${final_disabled[@]}"; do
        echo "   • $net"
    done

    rebuild_network_lists
    save_env_file
    echo -e "\n🔄  Restart required to apply changes. Use option [11] in the main menu."
}

enable_networks() {
    echo -e "\n✅  Enable Networks"

    if [[ -z "$NETWORKS_DISABLED" ]]; then
        echo "ℹ️  No networks are currently disabled."
        return
    fi

    IFS=',' read -ra disabled <<<"$NETWORKS_DISABLED"

    echo "Currently disabled networks:"
    local i=1
    declare -A index_to_network
    for net in "${disabled[@]}"; do
        echo "$i) $net"
        index_to_network[$i]="$net"
        ((i++))
    done

    echo ""
    read -p "➡️  Enter numbers of networks to enable (e.g. 1 2 3): " input

    if [[ -z "$input" ]]; then
        echo "ℹ️  No input provided. Disabled networks remain unchanged."
        return
    fi

    declare -A selected
    for d in $input; do
        if ! is_number "$d" || [[ -z "${index_to_network[$d]}" ]]; then
            echo "❌ Invalid input: '$d'."
            return
        fi
        selected[$d]=1
    done

    local remaining=()
    local reenabled=()
    for i in "${!index_to_network[@]}"; do
        if [[ -z "${selected[$i]}" ]]; then
            remaining+=("${index_to_network[$i]}")
        else
            reenabled+=("${index_to_network[$i]}")
        fi
    done

    if [[ ${#remaining[@]} -eq 0 ]]; then
        unset NETWORKS_DISABLED
        echo "✅  All networks enabled."
    else
        export NETWORKS_DISABLED="$(IFS=','; echo "${remaining[*]}")"
    fi

    rebuild_network_lists
    save_env_file

    echo -e "\n✅  Networks that were enabled:"
    for net in "${reenabled[@]}"; do
        echo "   • $net"
    done

    echo -e "\n🔄  Restart required to apply changes. Use option [11] in the main menu."
}

rebuild_network_lists() {
    local default_disabled=(arbitrum base optimism sei-testnet)

    if [[ -z "$NETWORKS_DISABLED" ]]; then
        NETWORKS_DISABLED="$(IFS=','; echo "${default_disabled[*]}")"
    fi

    NETWORKS_DISABLED=$(echo "$NETWORKS_DISABLED" | tr ',' '\n' | awk '!seen[$0]++' | paste -sd, -)

    declare -A disabled_map
    IFS=',' read -ra disabled_arr <<<"$NETWORKS_DISABLED"
    for net in "${disabled_arr[@]}"; do
        disabled_map["$net"]=1
    done

    declare -A seen
    local enabled_networks=()

    for key in "${!executor_ids[@]}"; do
        executor_id="${executor_ids[$key]}"
        if [[ -z "${disabled_map[$executor_id]}" && -z "${seen[$executor_id]}" ]]; then
            enabled_networks+=("$executor_id")
            seen[$executor_id]=1
        fi
    done

    ENABLED_NETWORKS="$(IFS=','; echo "${enabled_networks[*]}")"
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
    echo "9) Disable Networks"
    echo "10) Enable Networks"
    echo ""
    echo "🔁  Executor Control"
    echo "11) Restart Executor"
    echo "12) View Executor Status [systemd]"
    echo ""
    echo "0) Exit"
    echo ""
    read -p "➡️  Select an option [0–12] and press Enter: " opt

    case $opt in
    1) install_executor ;;
    2) uninstall_t3rn ;;
    3)
        echo "📜  Viewing executor logs (without timestamps/hostnames)..."
        sudo journalctl -u t3rn-executor -f --no-pager --output=cat
        ;;

    4)
        echo -e "\n🌐  Current RPC Endpoints:"
        echo ""
        for net in "${!rpcs[@]}"; do
            echo "- ${network_names[$net]}:"
            for url in ${rpcs[$net]}; do
                echo "   • $url"
            done
            echo ""
        done
        ;;

    5) edit_rpc_menu ;;

    6)
        gas=$(prompt_input "⛽  Enter new Max L3 gas price: ")

        if [[ -z "$gas" ]]; then
            echo "ℹ️  No input provided. Gas price unchanged."
        elif ! is_number "$gas"; then
            echo "❌  Invalid gas price. Must be a number."
        else
            export EXECUTOR_MAX_L3_GAS_PRICE=$gas
            save_env_file
            echo "✅  New gas price set to $EXECUTOR_MAX_L3_GAS_PRICE."
            echo "🔄  Restart required to apply changes. Use option [11] in the main menu."
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
                save_env_file
                echo "✅  Order processing flags updated."
                echo "🔄  Restart required to apply changes. Use option [11] in the main menu."
            fi
        fi
        ;;

    8)
        read -p "🔑  Enter new PRIVATE_KEY_LOCAL: " pk
        pk=$(echo "$pk" | sed 's/^0x//' | xargs)
        if [[ -n "$pk" ]]; then
            export PRIVATE_KEY_LOCAL=$pk
            save_env_file
            echo "✅  Private key updated."
            echo "🔄  Restart required to apply changes. Use option [11] in the main menu."
        else
            echo "ℹ️  No input provided. Private key unchanged."
        fi
        ;;

    11)
        echo "🔁 Restarting executor..."
        if sudo systemctl restart t3rn-executor; then
            echo "✅ Executor restarted successfully."
        else
            echo "❌ Failed to restart executor. Please check the systemctl logs."
        fi
        ;;

    12)
        echo "🔍  Checking Executor status using systemd..."
        sleep 0.3
        systemctl status t3rn-executor --no-pager || echo "❌  Executor is not running."
        ;;

    9) configure_disabled_networks ;;
    10) enable_networks ;;

    0)
        echo "👋  Exiting. Goodbye!"
        exit 0
        ;;
    *) echo "❌  Invalid option. Please try again." ;;
    esac
done
