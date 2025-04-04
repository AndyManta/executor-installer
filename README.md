# ⚙️ T3rn Executor Installer

> **Note:** This script is an unofficial installer that helps you install and manage the [T3rn Executor](https://github.com/t3rn/executor-release) — an open-source project by the T3rn team.
> It does not modify or replace the official binaries
---

## 🚀 Features

- ✅ Checks required dependencies (`curl`, `wget`, `tar`, `jq`)
- 📦 Install latest or custom Executor version
- ⚙️ Creates a `systemd` service for background execution
- 🌐 RPC Manager
- 🔐 Set or update `PRIVATE_KEY_LOCAL`
- ⛽ Configure `EXECUTOR_MAX_L3_GAS_PRICE`
- 🧠 Toggle flags:
  - `EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API`
  - `EXECUTOR_PROCESS_ORDERS_API_ENABLED`
- 📜 Live log viewer via `journalctl`
- 🔁 Restart executor
- 🧹 Full uninstall
- 📋 `systemd` status check

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
```
📦 Installation
1) Install / Update Executor
2) Uninstall Installer & Executor

🛠️ Configuration
3) View Executor Logs
4) Show Configured RPCs
5) Edit RPC Endpoints
6) Set Max L3 Gas Price
7) Configure Order API Flags
8) Set / Update Private Key

🔁 Executor Control
9) Restart Executor
10) View Executor Status [systemd]

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
