# ⚙️ T3rn Executor Installer

> **Note:** This script is an unofficial installer that helps you install and manage the [T3rn Executor](https://github.com/t3rn/executor-release) — an open-source project by the T3rn team.
> It does not modify or replace the official binaries
---

## 🚀 Features

- ✅ Dependency check for required tools (`curl`, `wget`, `tar`, `jq`)
- 📦 Install or update the T3rn Executor (latest or custom version)
- ⚙️ Create a `systemd` service to run the Executor in the background
- 🔄 Restart the executor anytime via the menu
- 🌐 Manage and edit custom RPC endpoints for various networks
- 🔐 Input and update your private key (`PRIVATE_KEY_LOCAL`)
- ⛽ Customize the maximum L3 gas price
- 🧠 Toggle executor flags such as:
  - `EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API`
  - `EXECUTOR_PROCESS_ORDERS_API_ENABLED`
- 📜 View live logs from the Executor service
- 🧹 Uninstall the entire setup with a single command
- 📋 Live status check of the Executor process

---

## 🛡️ Privacy & Security

> Your data stays **completely local**.

- 🔐 **Private keys** are only stored in-memory as environment variables and **never saved to disk**.
- 📡 **No data is transmitted externally** except direct calls to public APIs (e.g. GitHub for release versions).
- 📝 **No persistent logs** or local log files are created by the script.
- 📁 All files and configurations are stored under your `$HOME/t3rn/` directory.
- ❌ Nothing is uploaded, shared, or tracked. This tool is fully offline and privacy-respecting by design.

---

## 📦 Installation & Usage

### 🔧 Option 1: One-Liner Quick Install

You can run the installer instantly with a single command:

```bash
bash <(wget -qO - https://raw.githubusercontent.com/Zikett/t3rn-installer/main/t3rn-installer.sh)
```

### ⚡ Option 2: Clone & Run

```bash
git clone https://github.com/Zikett/t3rn-installer.git
cd t3rn-installer
chmod +x t3rn-installer.sh
./t3rn-installer.sh
```
---

## 📋 Menu Options

```text
====== T3rn Installer Menu ======
1) Install or Update Executor
2) Uninstall T3rn Installer and Executor
3) View Executor Logs
4) Show All Current RPCs
5) Edit RPC Endpoints
6) Change Max L3 Gas Price
7) Toggle Order API Flags
8) Set Private Key
9) Restart Executor
10) Check Executor Status
0) Exit
```

## ✅ Requirements

Make sure these tools are installed:

```bash
sudo apt update && sudo apt install -y curl wget tar jq
```

---

## 📄 License

MIT License
