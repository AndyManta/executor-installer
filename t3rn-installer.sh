#!/bin/bash

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

install_package() {
    local package="$1"
    if command -v apt &>/dev/null; then
        sudo apt update && sudo apt install -y "$package"
    elif command -v yum &>/dev/null; then
        sudo yum install -y "$package"
    else
        echo "❌ Unsupported package manager. Install $package manually."
        exit 1
    fi
}

required_tools=(sudo curl wget tar jq lsof nano)
missing_tools=()
installed_tools=()

for tool in "${required_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
        installed_tools+=("$tool")
    else
        missing_tools+=("$tool")
    fi
done

if ! command -v sudo &>/dev/null; then
    echo "⚠️  'sudo' is required."
    if confirm_prompt "📦  Install 'sudo' now?"; then
        install_package "sudo"
    else
        echo "❌ Cannot continue without 'sudo'. Exiting."
        exit 1
    fi
fi

for tool in "${missing_tools[@]}"; do
    echo "❌ $tool is missing."
    if confirm_prompt "📦 Install '$tool' now?"; then
        install_package "$tool"
    else
        echo "❌ '$tool' is required. Exiting."
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

if [[ -f "$ENV_FILE" ]]; then
    set -a
    source "$ENV_FILE"
    set +a

    if [[ -n "$RPC_ENDPOINTS" ]]; then
        for key in $(echo "$RPC_ENDPOINTS" | jq -r 'keys[]'); do
            urls=$(echo "$RPC_ENDPOINTS" | jq -r ".$key | @sh" | sed "s/'//g")
            rpcs[$key]="$urls"
        done
    fi
fi

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

rebuild_rpc_endpoints() {
    rpc_json=$(jq -n '{
        l2rn: $l2rn, arbt: $arbt, bast: $bast, blst: $blst,
        opst: $opst, unit: $unit, mont: $mont, seit: $seit
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

install_executor() {
    echo ""
    echo "====== Executor Version Selection ======"
    echo ""
    echo "[1] Install latest version"
    echo "[2] Install specific version"
    echo ""
    echo "[0] Back to main menu"
    echo ""
    read -p "Select an option [0–2]: " ver_choice

    case $ver_choice in
        0) return ;;
        1) TAG=$(curl -s https://api.github.com/repos/t3rn/executor-release/releases/latest | grep -Po '"tag_name": "\K.*?(?=")') ;;
        2)
            input_version=$(prompt_input "🔢 Enter version (e.g. 0.60.0): ")
            if [[ -z "$input_version" ]]; then
                echo "↩️ No version entered. Returning."
                return
            fi
            TAG="${input_version#v}"
            TAG="v$TAG"
            ;;
        *) echo "❌ Invalid option."; return ;;
    esac

    if [[ -z "$TAG" ]]; then
        echo "❌ Failed to determine version tag. Aborting."
        return
    fi

    for dir in "$HOME/t3rn" "$HOME/executor"; do
        if [[ -d "$dir" ]]; then
            echo "📁 Directory $(basename "$dir") exists."
            if confirm_prompt "❓ Remove it?"; then
                [[ "$(pwd)" == "$dir"* ]] && cd ~
                rm -rf "$dir"
            else
                echo "🚫 Installation cancelled."
                return
            fi
        fi
    done

    if lsof -i :9090 &>/dev/null; then
        pid_9090=$(lsof -ti :9090)
        kill -9 "$pid_9090"
        sleep 1
    fi

    mkdir -p "$HOME/t3rn" && cd "$HOME/t3rn" || exit 1
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
    export EXECUTOR_ENABLED_ASSETS=${EXECUTOR_ENABLED_ASSETS:-eth,t3eth,t3mon,t3sei,mon,sei}
    while true; do
        private_key=$(prompt_input "🔑 Enter PRIVATE_KEY_LOCAL: ")
        private_key=$(echo "$private_key" | sed 's/^0x//')
        if [[ -n "$private_key" ]]; then
            break
        fi

        echo ""
        echo "❓ Continue without private key?"
        echo "[1] 🔁 Retry"
        echo "[2] ⏩ Continue without key"
        echo ""
        echo "[0] ❌ Cancel"
        echo ""
        read -p "Select option [0–2]: " pk_choice
        case $pk_choice in
            1) continue ;;
            2) break ;;
            0) echo "❌ Cancelled."; return ;;
            *) echo "❌ Invalid option." ;;
        esac
    done

    export PRIVATE_KEY_LOCAL=$private_key
    rebuild_rpc_endpoints
    rebuild_network_lists

    if ! validate_config_before_start; then
        echo "❌ Invalid configuration. Aborting."
        return
    fi

    save_env_file
    sudo systemctl disable --now t3rn-executor.service 2>/dev/null
    sudo rm -f /etc/systemd/system/t3rn-executor.service
    sudo systemctl daemon-reload
    create_systemd_unit
}

validate_config_before_start() {
    echo ""
    echo "🧪 Validating configuration..."
    local error=false

    [[ -z "$PRIVATE_KEY_LOCAL" || ! "$PRIVATE_KEY_LOCAL" =~ ^[a-fA-F0-9]{64}$ ]] && { echo "❌ Invalid PRIVATE_KEY_LOCAL."; error=true; }
    [[ -z "$RPC_ENDPOINTS" ]] && { echo "❌ RPC_ENDPOINTS is empty."; error=true; }
    ! echo "$RPC_ENDPOINTS" | jq empty &>/dev/null && { echo "❌ RPC_ENDPOINTS is not valid JSON."; error=true; }
    [[ -z "$EXECUTOR_ENABLED_NETWORKS" ]] && { echo "❌ No networks enabled."; error=true; }

    local bin_path="$HOME/t3rn/executor/executor/bin/executor"
    [[ ! -f "$bin_path" ]] && { echo "❌ Executor binary missing."; error=true; }
    [[ ! -x "$bin_path" ]] && { echo "❌ Executor binary not executable."; error=true; }

    for flag in EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API EXECUTOR_PROCESS_ORDERS_API_ENABLED; do
        [[ "${!flag}" != "true" && "${!flag}" != "false" ]] && { echo "❌ $flag must be true/false."; error=true; }
    done

    available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    ((available_space < 500000)) && echo "⚠️ Less than 500MB free space."

    ! command -v systemctl &>/dev/null && { echo "❌ systemctl not found."; error=true; }
    ! sudo -n true 2>/dev/null && echo "⚠️ Sudo password might be required during setup."

    [[ "$error" == true ]] && return 1 || echo "✅ Configuration OK." && return 0
}

save_env_file() {
    mkdir -p "$HOME/t3rn"
    rebuild_network_lists
    cat >"$ENV_FILE" <<EOF
#Your PRIVATE KEY is stored at the bottom

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

EXECUTOR_ENABLED_ASSETS=${EXECUTOR_ENABLED_ASSETS:-eth,t3eth,t3mon,t3sei,mon,sei}

### This comment was created for convenience. It does not affect the operation of the Executor.

## EXECUTOR_ENABLED_ASSETS=eth,t3eth,t3mon,t3sei,mon,sei

EXECUTOR_ENABLED_NETWORKS=${EXECUTOR_ENABLED_NETWORKS}

NETWORKS_DISABLED=${NETWORKS_DISABLED}

### This comment was created for convenience. It does not affect the operation of the Executor.

## l2rn,arbitrum-sepolia,base-sepolia,unichain-sepolia,optimism-sepolia,blast-sepolia,sei-testnet,monad-testnet,optimism,arbitrum,base

# optimism,arbitrum,base - Mainnet Chain

RPC_ENDPOINTS='${RPC_ENDPOINTS}'



PRIVATE_KEY_LOCAL=${PRIVATE_KEY_LOCAL:-""}
EOF
}

create_systemd_unit() {
    local unit_path="/etc/systemd/system/t3rn-executor.service"
    local exec_path="$HOME/t3rn/executor/executor/bin/executor"
    sudo bash -c "cat > $unit_path" <<EOF
[Unit]
Description=T3rn Executor Service
After=network.target

[Service]
Type=simple
User=${SUDO_USER:-$USER}
WorkingDirectory=$(dirname "$exec_path")
EnvironmentFile=$ENV_FILE
ExecStart=$exec_path
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now t3rn-executor
    systemctl is-active --quiet t3rn-executor && echo "🚀 Executor is running." && echo "📜 View Executor Logs select [3]." || echo "❌ Executor failed to start."
}

rebuild_network_lists() {
    local default_disabled=(optimism arbitrum base blast-sepolia)

    if [[ ! -f "$ENV_FILE" ]]; then
        NETWORKS_DISABLED="$(IFS=','; echo "${default_disabled[*]}")"
    else
        NETWORKS_DISABLED="${NETWORKS_DISABLED:-}"
    fi

    NETWORKS_DISABLED=$(echo "$NETWORKS_DISABLED" | tr ',' '\n' | awk '!seen[$0]++' | paste -sd, -)

    declare -A disabled_map_final
    IFS=',' read -ra disabled_arr <<<"$NETWORKS_DISABLED"
    for net in "${disabled_arr[@]}"; do
        disabled_map_final["$net"]=1
    done

    declare -A seen
    local enabled_networks=()
    for key in "${!executor_ids[@]}"; do
        executor_id="${executor_ids[$key]}"
        if [[ -z "${disabled_map_final[$executor_id]}" && -z "${seen[$executor_id]}" ]]; then
            enabled_networks+=("$executor_id")
            seen[$executor_id]=1
        fi
    done

    EXECUTOR_ENABLED_NETWORKS="$(IFS=','; echo "${enabled_networks[*]}")"
}

configure_disabled_networks() {
    echo ""
    echo "🛑 Disable Networks"
    echo ""

    IFS=',' read -ra already_disabled <<<"$NETWORKS_DISABLED"
    declare -A already_disabled_lookup
    for net in "${already_disabled[@]}"; do
        already_disabled_lookup["$net"]=1
    done

    local i=1
    declare -A index_to_key
    for key in "${!executor_ids[@]}"; do
        exec_name="${executor_ids[$key]}"

        [[ -n "${already_disabled_lookup[$exec_name]}" ]] && continue
        echo "[$i] ${network_names[$key]}"
        index_to_key[$i]="$key"
        ((i++))
    done

    echo ""
    read -p "➡️ Enter numbers: " input
    [[ -z "$input" ]] && echo "ℹ️ No changes." && return

    declare -A selected
    for d in $input; do
        if ! is_number "$d" || [[ -z "${index_to_key[$d]}" ]]; then
            echo "❌ Invalid input: '$d'."
            return
        fi
        selected[$d]=1
    done

    local final_disabled=("${already_disabled[@]}")
    local newly_disabled=()
    for idx in "${!selected[@]}"; do
        key="${index_to_key[$idx]}"
        exec_name="${executor_ids[$key]}"
        final_disabled+=("$exec_name")
        newly_disabled+=("$exec_name")
    done

    if [[ ${#newly_disabled[@]} -eq 0 ]]; then
        echo "ℹ️ No networks selected to disable."
        return
    fi

    final_disabled_unique=($(echo "${final_disabled[@]}" | tr ' ' '\n' | awk '!seen[$0]++'))

    export NETWORKS_DISABLED="$(IFS=','; echo "${final_disabled_unique[*]}")"
    rebuild_network_lists
    save_env_file

    echo ""
    echo "✅ Newly disabled networks:"
    for exec_id in "${newly_disabled[@]}"; do
        for key in "${!executor_ids[@]}"; do
            if [[ "${executor_ids[$key]}" == "$exec_id" ]]; then
                echo "   • ${network_names[$key]}"
                break
            fi
        done
    done
    echo ""
    echo "🔄 Restart executor to apply changes. Select [11] to restart."
}

enable_networks() {
    echo ""
    echo "✅ Enable Networks"
    echo ""
    [[ -z "$NETWORKS_DISABLED" ]] && echo "ℹ️ No networks disabled." && return
    IFS=',' read -ra disabled <<<"$NETWORKS_DISABLED"
    local i=1
    declare -A index_to_network

    for key in "${!executor_ids[@]}"; do
        exec_name="${executor_ids[$key]}"
        for disabled_net in "${disabled[@]}"; do
            if [[ "$exec_name" == "$disabled_net" ]]; then
                echo "[$i] ${network_names[$key]}"
                index_to_network[$i]="$disabled_net"
                ((i++))
                break
            fi
        done
    done

    echo ""
    read -p "➡️ Enter numbers to enable: " input
    [[ -z "$input" ]] && echo "ℹ️ No changes." && return

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
    for idx in "${!index_to_network[@]}"; do
        if [[ -n "${selected[$idx]}" ]]; then
            reenabled+=("${index_to_network[$idx]}")
        else
            remaining+=("${index_to_network[$idx]}")
        fi
    done

    if [[ ${#reenabled[@]} -eq 0 ]]; then
        echo "ℹ️ No networks selected to enable."
        return
    fi

    if [[ ${#remaining[@]} -eq 0 ]]; then
        export NETWORKS_DISABLED=""
        echo "✅ All networks enabled."
    else
        export NETWORKS_DISABLED="$(IFS=','; echo "${remaining[*]}")"
    fi

    rebuild_network_lists
    save_env_file

    echo ""
    echo "✅ Networks enabled:"
    for exec_id in "${reenabled[@]}"; do
        for key in "${!executor_ids[@]}"; do
            if [[ "${executor_ids[$key]}" == "$exec_id" ]]; then
                echo "   • ${network_names[$key]}"
                break
            fi
        done
    done
}

uninstall_t3rn() {
    if ! confirm_prompt "❗ Completely remove Executor?"; then
        echo "🚫 Uninstall cancelled."
        return
    fi

    echo "🗑️ Uninstalling..."

    rm -f "$ENV_FILE"
    sudo systemctl disable --now t3rn-executor.service 2>/dev/null
    sudo rm -f /etc/systemd/system/t3rn-executor.service
    sudo systemctl daemon-reload

    for dir in "$HOME/t3rn" "$HOME/executor"; do
        [[ -d "$dir" ]] && { [[ "$(pwd)" == "$dir"* ]] && cd ~; rm -rf "$dir"; }
    done

    sudo journalctl --rotate
    sudo journalctl --vacuum-time=1s
    rpcs=()
    initialize_default_rpcs

    unset ENVIRONMENT LOG_LEVEL LOG_PRETTY EXECUTOR_PROCESS_BIDS_ENABLED \
          EXECUTOR_PROCESS_ORDERS_ENABLED EXECUTOR_PROCESS_CLAIMS_ENABLED \
          EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API EXECUTOR_PROCESS_ORDERS_API_ENABLED \
          EXECUTOR_MAX_L3_GAS_PRICE EXECUTOR_PROCESS_BIDS_API_INTERVAL_SEC \
          EXECUTOR_MIN_BALANCE_THRESHOLD_ETH PROMETHEUS_ENABLED PRIVATE_KEY_LOCAL \
          EXECUTOR_ENABLED_NETWORKS NETWORKS_DISABLED EXECUTOR_ENABLED_ASSETS RPC_ENDPOINTS

    echo "✅ Executor removed."
}

initialize_default_rpcs() {
    declare -gA rpcs=(
        ["l2rn"]="https://b2n.rpc.caldera.xyz/http"
        ["arbt"]="https://arbitrum-sepolia-rpc.publicnode.com https://sepolia-rollup.arbitrum.io/rpc"
        ["bast"]="https://base-sepolia-rpc.publicnode.com https://sepolia.base.org"
        ["blst"]="https://sepolia.blast.io"
        ["opst"]="https://optimism-sepolia-rpc.publicnode.com https://sepolia.optimism.io"
        ["unit"]="https://unichain-sepolia-rpc.publicnode.com https://sepolia.unichain.org"
        ["mont"]="https://testnet-rpc.monad.xyz"
        ["seit"]="https://evm-rpc-testnet.sei-apis.com"
    )
}

edit_rpc_menu() {
    echo ""
    echo "🌐 Edit RPC Endpoints"
    local changes_made=false

    declare -A expected_chain_ids=(
        ["l2rn"]="334"
        ["arbt"]="421614"
        ["bast"]="84532"
        ["blst"]="168587773"
        ["opst"]="11155420"
        ["unit"]="1301"
        ["mont"]="10143"
        ["seit"]="1328"
    )

    IFS=',' read -ra disabled_networks <<< "$NETWORKS_DISABLED"
    declare -A disabled_lookup
    for dn in "${disabled_networks[@]}"; do
        disabled_lookup["$dn"]=1
    done

    for net in l2rn arbt bast blst opst unit mont seit; do
        executor_id="${executor_ids[$net]}"

        if [[ -n "${disabled_lookup[$executor_id]}" ]]; then
            continue
        fi

        name=${network_names[$net]}
        echo "🔗 $name"
        echo "Current: ${rpcs[$net]}"

        while true; do
            read -p "➡️ Enter new RPC URLs (space-separated, or Enter to skip): " input

            if [[ -z "$input" ]]; then
                echo "ℹ️ Skipped updating $name."
                break
            fi

            local valid_urls=()
            local invalid=false

            for url in $input; do
                if [[ "$url" =~ ^https?:// ]]; then
                    echo "⏳ Checking RPC: $url ..."
                    local response=$(curl --silent --max-time 5 -X POST "$url" \
                        -H "Content-Type: application/json" \
                        --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}')

                    local actual_chain_id_hex=$(echo "$response" | jq -r '.result')

                    if [[ "$actual_chain_id_hex" == "null" || -z "$actual_chain_id_hex" ]]; then
                        echo "❌ Invalid or empty response from RPC: $url"
                        invalid=true
                        continue
                    fi

                    local actual_chain_id_dec=$((16#${actual_chain_id_hex#0x}))
                    local expected_chain_id="${expected_chain_ids[$net]}"

                    if [[ "$actual_chain_id_dec" == "$expected_chain_id" ]]; then
                        valid_urls+=("$url")
                    else
                        echo "❌ Wrong ChainID: expected $expected_chain_id, got $actual_chain_id_dec."
                        invalid=true
                    fi
                else
                    echo "❌ Invalid URL format (must start with http:// or https://): $url"
                    invalid=true
                fi
            done

            if [[ "$invalid" == false && "${#valid_urls[@]}" -gt 0 ]]; then
                rpcs[$net]="${valid_urls[*]}"
                changes_made=true
                echo "✅ Updated $name."
                break
            else
                echo "🚫 One or more URLs were invalid. Please re-enter RPCs for $name."
            fi
        done

        echo ""
    done

    if [[ "$changes_made" == true ]]; then
        rebuild_rpc_endpoints
        save_env_file
        echo "✅ RPC endpoints updated and saved."
        echo "🔄 Restart executor to apply changes. Select [11] to restart."
    else
        echo "ℹ️ No RPC changes made."
    fi
}

edit_env_file() {
    echo ""
    echo "📝 Edit Environment (.env) File"

    if [[ ! -f "$ENV_FILE" ]]; then
        echo "❌ .env file does not exist: $ENV_FILE"
        return
    fi

    echo ""
    echo "⚠️ WARNING: The .env file contains your PRIVATE KEY."
    echo "   Be careful not to share or leak this file."
    echo ""
    echo "ℹ️ After editing, you must restart the Executor to apply changes."
    echo "   Select [11] to restart."
    echo ""
    if ! confirm_prompt "➡️ Continue editing .env file?"; then
        echo "🚫 Edit cancelled."
        return
    fi

    local editor=""
    if command -v nano &>/dev/null; then
        editor="nano"
    elif command -v vim &>/dev/null; then
        editor="vim"
    elif command -v vi &>/dev/null; then
        editor="vi"
    else
        echo "❌ No text editor found (nano, vim, vi)."
        return
    fi

    $editor "$ENV_FILE"
    echo ""
    echo "🔄 Don't forget to restart the executor using [11] Restart Executor."
}

while true; do
    echo ""
    echo "====== ⚙️  T3rn Installer Menu ======"
    echo ""
    echo "📦  Installation"
    echo "[1] Install / Update Executor"
    echo "[2] Uninstall Executor"
    echo ""
    echo "🛠️  Configuration"
    echo "[3] View Executor Logs"
    echo "[4] Show Configured RPC"
    echo "[5] Edit RPC Endpoints"
    echo "[6] Set Max L3 Gas Price"
    echo "[7] Configure Order API Flags"
    echo "[8] Set / Update Private Key"
    echo "[9] Disable Networks"
    echo "[10] Enable Networks"
    echo ""
    echo "🔁  Executor Control"
    echo "[11] Restart Executor"
    echo "[12] View Executor Status"
    echo "[13] Edit .env File"
    echo ""
    echo "[0] Exit"
    echo ""
    read -p "➡️ Select option [0–13]: " opt

    case $opt in
        1) install_executor ;;
        2) uninstall_t3rn ;;
        3) sudo journalctl -u t3rn-executor -f --no-pager --output=cat ;;
        4)
            echo ""
            echo "🌐 Current RPC Endpoints:"
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
            gas=$(prompt_input "⛽ Enter new Max L3 gas price: ")
            if [[ -n "$gas" && "$(is_number "$gas" && echo true)" == true ]]; then
                export EXECUTOR_MAX_L3_GAS_PRICE=$gas
                save_env_file
                echo "✅ New gas price set to $EXECUTOR_MAX_L3_GAS_PRICE."
                echo "🔄 Restart executor to apply changes. Select [11] to restart."
            else
                echo "❌ Invalid gas price."
            fi
            ;;
        7)
            val1=$(prompt_input "🔧 EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API (true/false): ")
            val2=$(prompt_input "🔧 EXECUTOR_PROCESS_ORDERS_API_ENABLED (true/false): ")
            if [[ "$val1" =~ ^(true|false)$ && "$val2" =~ ^(true|false)$ ]]; then
                export EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API=$val1
                export EXECUTOR_PROCESS_ORDERS_API_ENABLED=$val2
                save_env_file
                echo "✅ Order API flags updated."
                echo "🔄 Restart executor to apply changes. Select [11] to restart."
            else
                echo "❌ Invalid values."
            fi
            ;;
        8)
            pk=$(prompt_input "🔑 Enter new PRIVATE_KEY_LOCAL: ")
            pk=$(echo "$pk" | sed 's/^0x//' | xargs)
            if [[ -n "$pk" ]]; then
                export PRIVATE_KEY_LOCAL=$pk
                save_env_file
                echo "✅ Private key updated."
                echo "🔄 Restart executor to apply changes. Select [11] to restart."
            else
                echo "ℹ️ No input. Private key unchanged."
            fi
            ;;
        9) configure_disabled_networks ;;
        10) enable_networks ;;
        11)
            echo "🔁 Restarting executor..."
            if sudo systemctl restart t3rn-executor; then
                echo "✅ Executor restarted."
            else
                echo "❌ Failed to restart executor."
            fi
            ;;
        12)
            echo "🔍 Checking executor status..."
            systemctl status t3rn-executor --no-pager || echo "❌ Executor not running."
            ;;
        13) edit_env_file
            ;;
        0)
            echo "👋 Goodbye!"
            exit 0
            ;;
        *) echo "❌ Invalid option." ;;
    esac
done
