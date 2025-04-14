### ⚙️ T3rn Executor Installer

> **Note:** This is an **unofficial Bash-based installer** for the [T3rn Executor](https://github.com/t3rn/executor-release), designed to simplify installation and configuration.  
> It does **not** modify or replace any official binaries or releases from the T3rn team.

---

### 🚀 What It Does

This script provides an interactive CLI interface for managing the T3rn Executor with features like:

- Installing latest or specific executor versions
- Automatic `.env` generation with RPCs, gas limits, keys, flags
- Live systemd integration
- Enable/Disable supported networks
- Log monitoring, restarting, and full uninstall

---

#### 📥 Quick Start

#### Option 1 – Run the latest version [`v1.1.1`]:
```bash
bash <(wget -qO - https://github.com/Zikett/t3rn-installer/releases/download/v1.1.1/t3rn-installer.sh)
```
- **Old version  [`v1.0.0`] :**
```bash
bash <(wget -qO - https://raw.githubusercontent.com/Zikett/t3rn-installer/v1.0.0/t3rn-installer.sh)
```
#### Option 2 – Clone & run manually:
```bash
git clone https://github.com/Zikett/t3rn-installer.git
cd t3rn-installer
chmod +x t3rn-installer.sh
./t3rn-installer.sh
```

---

### ✅ Requirements

These tools must be available (installed automatically if missing):

```bash
sudo apt install -y sudo curl wget tar jq lsof
```

---

### 🖥️ Compatibility

Tested and confirmed to work on:

- Ubuntu 18.04+
- Debian 10+
- Fedora 34+
- CentOS 7+
- Rocky Linux / AlmaLinux
- WSL (Ubuntu/Debian-based)

> `systemd` is required to run the executor as a service. Not supported in minimal containers or Alpine.

---

### 🔧 Features Overview

- 🧠 **Interactive Menu System**
- 🔧 Configure `.env` with dynamic values
- ⚙️ Systemd auto-setup and service management
- 🔐 Private key prompt & validation
- 🌐 RPC editing per supported network
- 🔁 Enable/Disable network sets
- ⛽ Set max gas price
- ✅ Validate config before start
- 📜 View real-time logs
- 🔄 Restart service
- 🧹 Full uninstall

---

### 🧩 Menu Walkthrough

#### 📦 Installation
- **[1] Install / Update Executor**  
  Choose version, enter private key, build config, and install.

- **[2] Uninstall Installer & Executor**  
  Fully remove the executor, its config, directories, and systemd service.

#### 🛠️ Configuration
- **[3] View Logs** — Show live logs from `journalctl`  
- **[4] Show Configured RPCs**  
- **[5] Edit RPC Endpoints**  
- **[6] Set Max L3 Gas Price**  
- **[7] Configure API Flags** (`true/false`)  
- **[8] Update Private Key**  
- **[9] Disable Networks**  
- **[10] Enable Networks**

#### 🔁 Executor Control
- **[11] Restart Executor** — Restart the systemd service  
- **[12] View Status** — Run `systemctl status` on the service  

#### ❌ Exit
- **[0] Exit Menu**

---

### 🔐 Security Notes

- Your **private key** is stored in a `.env` file in `~/t3rn/`  
- Ensure your system is secure and restrict access to this file (`chmod 600 ~/.t3rn/.env`)
- This script performs **no remote logging**, tracking, or external data submission

---

### 📄 License

[MIT License](./LICENSE)
