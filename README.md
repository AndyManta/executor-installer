# 🌐 T3rn Installer

> **Note:** This script is an unofficial installer that helps you install and manage the [T3rn Executor](https://github.com/t3rn/executor-release) — an open-source project by the T3rn team.
> It does not modify or replace the official binaries

A simple and interactive Bash installer for the **T3rn Executor**, designed to streamline installation, configuration, and systemd integration in just a few clicks.

---

## ⚡ One-liner Installation

Run the installer directly from GitHub:

```bash
bash <(wget -O - https://raw.githubusercontent.com/Zikett/t3rn-installer/main/t3rn-installer.sh)
```

> This will automatically download and run the latest version of the script.

---

## 🚀 Features

- One-command install or update of T3rn Executor
- Automatic systemd service setup
- RPC endpoint editing for all supported networks
- Configurable max gas price and API behavior
- Private key management
- Real-time executor logs
- Safe uninstall option
- Built-in status check and safety confirmations

---

## 📦 Requirements

The following tools must be available in your system:

- `bash`
- `curl`
- `wget`
- `jq`
- `tar`

---

## ⚙️ Usage (manual)

### 1. Clone the repository

```bash
git clone https://github.com/Zikett/t3rn-installer.git
cd t3rn-installer
```

### 2. Make the script executable

```bash
chmod +x t3rn-installer.sh
```

### 3. Run the installer

```bash
./t3rn-installer.sh
```

---

## 🧭 Menu Options

```
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

Each option is interactive and safe — empty inputs won’t overwrite existing values unless confirmed.

---

## 🔐 Security & Config

- RPC endpoints are defined per network and can be customized
- Gas price and private key can be updated at any time
- All values are passed securely via systemd `Environment=` variables
- Configuration changes require a manual restart (option 9)

---

## 📄 Systemd Integration

The installer automatically creates a systemd service file:

```ini
/etc/systemd/system/t3rn-executor.service
```

You can manage it manually too:

```bash
sudo systemctl status t3rn-executor
sudo systemctl restart t3rn-executor
```

---

## 🗑️ Uninstall

To completely remove the executor and its service:

```bash
# Inside the menu
2) Uninstall T3rn Installer and Executor
```

The script will ask for confirmation before deleting any files or services.

---

# 🔐 Security & Privacy

This script is **100% local** and:

- ❌ **Does not send** any data to external servers  
- 💾 Stores configuration only **in your system memory or local files**  
- 🔐 Private keys and RPCs are only used to generate a local systemd service  
- 🚫 No third-party tracking, telemetry, or remote logging  

You are in full control of your environment. The script is open-source and can be audited by anyone at any time.

---

## 📝 License

This project is licensed under the MIT License.  
See the [LICENSE](LICENSE) file for details.
