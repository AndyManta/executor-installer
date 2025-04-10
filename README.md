## ⚙️ T3rn Executor Installer

> **Note:** This script is an unofficial installer that helps you install and manage the [T3rn Executor](https://github.com/t3rn/executor-release) — an open-source project by the T3rn team.
> It does not modify or replace the official binaries
---

A quick setup script for installing and configuring the T3rn Executor with ease.

### 🚀 Usage

### Run the stable version from `main` branch:
```bash
bash <(wget -qO - https://raw.githubusercontent.com/Zikett/t3rn-installer/main/t3rn-installer.sh)
```

### Run a specific version (tagged release):
```bash
bash <(wget -qO - https://raw.githubusercontent.com/Zikett/t3rn-installer/v1.0.0/t3rn-installer.sh)
```

Replace `v1.0.0` with the desired version tag.

### ⚡ Option 2: Clone & Run

```bash
git clone https://github.com/Zikett/t3rn-installer.git
cd t3rn-installer
chmod +x t3rn-installer.sh
./t3rn-installer.sh
```

### ✅ Requirements

Make sure these tools are installed:

```bash
sudo apt update && sudo apt install -y curl wget tar jq
```
## 🖥️ Compatibility

This script is built to run on **most mainstream Linux distributions** with no modifications. It automatically checks for required dependencies and installs them if needed (upon confirmation).

### ✅ Verified to work on:
- **Ubuntu** 18.04+
- **Debian** 10+
- **Fedora** 34+
- **CentOS** 7+
- **Rocky Linux**, **AlmaLinux**
- **WSL** (Windows Subsystem for Linux using the above distros)

> ℹ️ If you're using a minimal or containerized image, the script will attempt to install missing tools like `sudo`, `curl`, `jq`, `wget`, and `tar`.

> ❗ `systemd` is required to run the executor as a service. Make sure your environment supports it.

### 🚀 Features

- 📦 **Executor Installation**  
  Install the latest or a specific version of the Executor from GitHub
- ⚙️ **Systemd Integration**  
  Creates and manages a `systemd` service for background execution
- 🌐 **RPC Management**  
  View and edit RPC endpoints for supported networks
- 🔐 **Private Key Setup**  
  Set or update the `PRIVATE_KEY_LOCAL` environment variable
- ⛽ **Gas Price Configuration**  
  Define the `EXECUTOR_MAX_L3_GAS_PRICE` limit
- 🧠 **true/false Executor Flags**  
  Easily switch:
  - `EXECUTOR_PROCESS_PENDING_ORDERS_FROM_API`
  - `EXECUTOR_PROCESS_ORDERS_API_ENABLED`
- 🌐 **Enable/Disable Networks**
- 📜 **Live Logs Viewer**  
  Stream real-time logs using `journalctl`
- 🔁 **Executor Restart**  
  Restart the service to apply configuration changes
- 🧹 **Complete Uninstall**  
  Remove the executor, configs, service, and logs
- 📋 **Status Monitoring**  
  Check current status `systemd`

---

### 🛡️ Privacy & Security

> Your data stays **completely local**.

- 🔐 **Private keys** are only stored in-memory as environment variables and **never saved to disk**.
- 📡 **No data is transmitted externally** except direct calls to public APIs (e.g. GitHub for release versions).
- 📝 **No persistent logs** or local log files are created by the script.
- 📁 All files and configurations are stored under your `$HOME/t3rn/` directory.
- ❌ Nothing is uploaded, shared, or tracked. This tool is fully offline and privacy-respecting by design.

---
![image](https://github.com/user-attachments/assets/6cc59c8c-ef48-4790-8d79-77f935d17b48)

### 📋 Menu Options Overview

### 📦 Installation
- **1) Install / Update Executor**  
  Downloads and installs the Executor (latest or specific version), configures it, and sets it up as a systemd service.

- **2) Uninstall Installer & Executor**  
  Completely removes the T3rn installation, including configuration and systemd service.

### 🛠️ Configuration

- **3) View Executor Logs**  
  Streams the latest logs from the executor service via `journalctl`.

- **4) Show Configured RPCs**  
  Displays the currently configured RPC endpoints for supported networks.

- **5) Edit RPC Endpoints**  
  Allows you to update the RPC URLs for each supported network.
  
  ⚠️ **Note:** Custom RPC endpoints set via this option are temporary — they are not saved between script runs.  
  They are applied to the currently running executor and will remain active until you restart it.  
  **If you restart the executor later, you'll need to re-apply the custom RPCs using this menu option again.**

- **6) Set Max L3 Gas Price**  
  Changes the maximum allowed L3 gas price for the executor.

- **7) Configure Order API Flags**  
  Enables or disables flags related to processing orders via the API.

- **8) Set / Update Private Key**  
  Sets or updates the private key used by the executor (without `0x` prefix).

- **9) Disable Networks**

- **10) Enable Networks**

### 🔁 Executor Control

- **11) Restart Executor**  
  Rebuilds the configuration and restarts the T3rn executor systemd service.

- **12) View Executor Status [systemd]**  
  Shows the current status of the executor using `systemctl`.

### 🔚 Exit
- **0) Exit**  
  Closes the installer menu.

---

### 📄 License

[MIT LICENSE](./LICENSE)
