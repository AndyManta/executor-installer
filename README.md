### ⚙️ Executor Installer

> **Note:** This is an **unofficial Bash-based installer** for the [T3rn Executor](https://github.com/t3rn/executor-release), designed to simplify installation and configuration.  
> It does **not** modify or replace any official binaries or releases from the T3rn team.

---
## 📦 Installation

To run the script, paste this command into your Linux terminal:

```bash
bash <(wget -qO - https://raw.githubusercontent.com/Zikett/executor-installer/main/executor-installer.sh)
```

Follow the interactive menu to install and configure the Executor.

![executor-installer](https://github.com/user-attachments/assets/41749a37-1545-4d1c-9e65-6635c988822a)

---

## 🧪 Requirements

The script automatically installs missing dependencies. Required tools:

- `sudo`, `curl`, `wget`, `tar`
- `jq`, `lsof`, `nano`

---

## ⚡ Features

- Install latest or specific versions of the Executor.
- One-command uninstall option.
- Configure supported networks.
- Automatically sets up systemd service for background operation.
- Manage RPC endpoints per networks.
- Secure `.env` file handling.
- Wallet balance history and view live transactions.
- Interactive terminal UI.

---

## 📁 Environment Configuration

The script generates a `.env` file in `$HOME/t3rn/.env` containing all Executor settings including:

- Enabled networks
- Custom RPCs
- Executor flags
- Local private key

⚠️ The private key is stored locally.

---

## 📜 Systemd Integration

Executor is automatically configured as a `systemd` service.

To view the “Executor” logs, you can select the option in the main script menu “[2] 🔎 View Executor Logs” or use the command:

```bash
sudo journalctl -u t3rn-executor -f
```

To manually uninstall the systemd service, you can use the following commands:

```bash
sudo systemctl stop t3rn-executor
sudo systemctl disable t3rn-executor
sudo rm -f /etc/systemd/system/t3rn-executor.service
```
## 🖥️ Compatibility

Tested and confirmed to work on:

- Ubuntu 18.04+
- Debian 10+
- Fedora 34+
- CentOS 7+
- Rocky Linux / AlmaLinux
- WSL (Ubuntu/Debian-based)

> `systemd` is required to run the executor as a service. Not supported in minimal containers or Alpine.

---

## 🔐 Security Notes

- Your **private key** is stored in a `.env` file in `~/t3rn/`  
- This script performs **no remote logging**, tracking, or external data submission

---

## 📄 License

[MIT License](./LICENSE)
