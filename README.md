# 🚀 T3RN Executor Pro

[![MIT License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/rokhanz/t3rn-executor)
[![Bash](https://img.shields.io/badge/shell-bash-brightgreen.svg)](https://www.gnu.org/software/bash/)
[![Node.js](https://img.shields.io/badge/node.js-18+-orange.svg)](https://nodejs.org/)

> **✨ Advanced T3RN Executor with MEV protection, rich Telegram notifications, and intelligent automation**

**👨‍💻 Author:** [Rokhanz](https://github.com/rokhanz) | **📅 Year:** 2025 | **📜 License:** MIT

---

## 🌟 Why This Repository?

**Tahun 2025** - T3RN ecosystem berkembang pesat, dan executor standar sudah tidak cukup. Repository ini hadir dengan:

- 🛡️ **MEV Protection** - Lindungi transaksi dari sandwich attacks
- 📱 **Rich Telegram Notifications** - Laporan detail dengan wallet address
- 🌐 **12 Networks Support** - Semua testnet T3RN dengan auto-failover
- ⚡ **Alchemy Integration** - Multiple API keys dengan load balancing
- 🎨 **Beautiful UI** - Progress bars berwarna dan animasi
- 🔄 **Auto-Restart** - Intelligent restart dengan monitoring

**Mengapa 2025?** Karena T3RN mainnet sudah dekat, kompetisi semakin ketat, dan tools standar tidak lagi memadai untuk menghadapi MEV bots yang semakin canggih.

---
## 🖥️ VPS Requirements

| Spec | Minimum | Recommended |
|------|---------|-------------|
| **RAM** | 4GB | 8GB+ |
| **CPU** | 2 cores | 4+ cores |
| **Storage** | 50GB SSD | 100GB+ SSD |
| **Network** | 100 Mbps | 1 Gbps |
| **OS** | Ubuntu 20.04+ | Ubuntu 22.04 LTS |

**💡 Recommended VPS Providers:**
- **Contabo** - €4.99/month (Best value)
- **Hetzner** - €4.15/month (EU servers)
- **DigitalOcean** - $6/month (Global)
- **Vultr** - $6/month (High performance)

---

## ⚡ Quick Install

### 1️⃣ **VPS Setup** (5 minutes)
```
#Update system
sudo apt update && sudo apt upgrade -y

#Install essentials
sudo apt install -y curl git screen bc netcat-openbsd xxd

#Install Node.js (for MEV detector)
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs

#Install Foundry (for wallet operations)
curl -L https://foundry.paradigm.xyz | bash && source ~/.bashrc && foundryup

```

### 2️⃣ **Clone & Setup** (2 minutes)
```
#Clone repository
git clone https://github.com/rokhanz/t3rn-executor.git
cd t3rn-executor

#Setup permissions
chmod +x .sh modules/.sh

#Install dependencies
npm install

#Create configuration
cp .env.example .env

```

### 3️⃣ **Configuration** (3 minutes)
```
nano .env
```
**Essential settings:**
```
#===🔑 Your wallet private key (64 chars, no 0x)
PRIVATE_KEY_EXECUTOR="your_private_key_here"

#===⚡ Alchemy API keys (get from alchemy.com)
ALCHEMY_KEY_1="your_alchemy_key_1"
ALCHEMY_KEY_2="your_alchemy_key_2"
ALCHEMY_KEY_3="your_alchemy_key_3"

#===📱 Telegram (create bot with @BotFather)
TELEGRAM_BOT_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"

#===🌐 Networks to run
ENABLED_NETWORKS="arbitrum-sepolia,base-sepolia,blast-sepolia,optimism-sepolia"
```

### 4️⃣ **Launch** (1 command)
```
./autorun.sh
```
**🎉 Done! Your executor is running with full monitoring.**

---

## 📱 Telegram Notifications

Rich notifications with wallet info:
```
🎯 BID SUCCESS! 🎯

📋 Order Details:
🆔 Order ID: 0x1234...abcd
🌉 Route: 🔵 Arbitrum ➡️ 🔷 Base
💰 Amount: 0.1 ETH
🔑 Wallet: 0x1234...5678

⚡ Latency: 45ms
⏰ Time: 14:30:25
```
undefined
```
💰 BALANCE REPORT 💰

🔑 Wallet: 0x1234...5678

🔵 Arbitrum: 0.850 ETH
🔷 Base: 0.750 ETH
💥 Blast: 1.200 ETH
🔴 Optimism: 0.650 ETH

💎 Total: 3.450 ETH
✅ Status: Healthy

```

---

## 🌐 Supported Networks

| Network | Code | Status | Alchemy |
|---------|------|--------|---------|
| 🔵 Arbitrum Sepolia | `arbt` | ✅ Active | ✅ |
| 🔷 Base Sepolia | `bast` | ✅ Active | ✅ |
| 💥 Blast Sepolia | `blst` | ✅ Active | ✅ |
| 🔴 Optimism Sepolia | `opst` | ✅ Active | ✅ |
| 🦄 Unichain Sepolia | `unit` | ✅ Active | ✅ |
| 🌙 Monad Testnet | `mont` | ✅ Active | ✅ |
| ⚡ Sei Testnet | `seit` | ✅ Active | ✅ |
| 🎨 Abstract Testnet | `abst` | ✅ Active | ✅ |
| 🔗 Lisk Sepolia | `lisk` | ✅ Active | ❌ |
| 🐻 Berachain Bepolia | `bera` | ✅ Active | ✅ |
| 🟡 BNB Testnet | `bnb` | ✅ Active | ✅ |
| 🌐 L2RN Network | `l2rn` | ✅ Active | ❌ |

---

## 🛡️ Security Features

- **🥪 Anti-Sandwich** - Detect and prevent sandwich attacks
- **🏃 Anti-Frontrun** - Dynamic gas pricing protection
- **🔄 Proxy Support** - SOCKS5/HTTP with rotation
- **🔐 Wallet Security** - Secure private key handling
- **🧪 Tx Simulation** - Pre-execution validation

---

## 📊 Management Commands
```
#Check status
./autorun.sh -s

#View logs
tail -f logs/executor.log

#Attach to screen
screen -r t3rn-executor

#Health check
./autorun.sh -c

#Balance check
./modules/balance_checker.sh

```

---

## 🔧 Advanced Features

### 🔄 **Auto-Restart**
- Intelligent restart on failures
- Configurable retry attempts
- Health monitoring

### 📊 **Rich Monitoring**
- Real-time progress bars
- System resource tracking
- Network latency monitoring

### 🎨 **Beautiful UI**
- Colorful progress indicators
- Emoji-rich logging
- Animated spinners

### 🌐 **Multi-Network**
- 12 testnet networks
- Automatic failover
- Load balancing

---

## 🚀 Why Choose This Executor?

| Feature | Standard Executor | This Repository |
|---------|-------------------|-----------------|
| Networks | 4-5 basic | 12 with failover |
| Notifications | None | Rich Telegram |
| MEV Protection | None | Advanced |
| UI/UX | Basic logs | Colorful progress |
| Monitoring | None | Comprehensive |
| Auto-restart | Manual | Intelligent |
| Documentation | Minimal | Complete |

---

## 🤝 Special Thanks

### 🏗️ **T3RN Team**
Terima kasih kepada tim T3RN yang telah membangun protokol revolusioner untuk cross-chain interoperability. Tanpa visi dan kerja keras mereka, executor ini tidak akan ada.

### ⚡ **Alchemy**
Appreciation to Alchemy for providing reliable and fast RPC infrastructure that makes multi-network execution possible with minimal latency.

### 🤖 **Telegram**
Thanks to Telegram for the excellent Bot API that enables rich, real-time notifications with beautiful formatting and instant delivery.

### 🔧 **Foundry Team**
Gratitude to the Foundry team for creating powerful blockchain development tools that make wallet operations and address derivation seamless.

### 🌐 **Open Source Community**
Special recognition to the countless developers who created the tools, libraries, and frameworks that make this project possible.

### 💎 **Early Adopters**
Thanks to the brave souls who will test this executor in 2025 and provide feedback to make it even better for the T3RN mainnet launch.

---

## 📞 Support

- 🐛 **Issues:** [GitHub Issues](https://github.com/rokhanz/t3rn-executor/issues)
- 💬 **Discussions:** [GitHub Discussions](https://github.com/rokhanz/t3rn-executor/discussions)
- ⭐ **Star:** Show your support!

---

**⭐ Star this repository if you find it useful!**

**🚀 Ready for T3RN Mainnet 2025!**

---

*Built with ❤️ for the T3RN community | Last updated: June 2025*
