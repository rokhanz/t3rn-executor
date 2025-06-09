# T3RN Executor

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/rokhanz/t3rn-executor)
[![Shell Script](https://img.shields.io/badge/shell-bash-green.svg)](https://www.gnu.org/software/bash/)
[![Node.js](https://img.shields.io/badge/node.js-18+-brightgreen.svg)](https://nodejs.org/)

> **Advanced T3RN Executor with comprehensive monitoring, MEV protection, and automated management**

**Author:** Rokhanz  
**License:** MIT  
**Version:** 1.0.0

## 🌟 Features

### 🚀 Core Features
- **Multi-Network Support** - 12 supported networks with automatic failover
- **Alchemy Integration** - Multiple API key support with load balancing
- **Rich Telegram Notifications** - Detailed transaction reports with wallet info
- **MEV Protection** - Advanced MEV detection and protection mechanisms
- **Auto-Restart** - Intelligent restart with configurable attempts
- **Comprehensive Monitoring** - Real-time system and network monitoring

### 🛡️ Security Features
- **Wallet Security** - Secure private key handling and validation
- **Anti-MEV Protection** - Sandwich attack and frontrunning protection
- **Proxy Support** - SOCKS5/HTTP proxy with rotation and failover
- **Transaction Simulation** - Pre-execution validation
- **Rate Limiting** - Built-in request throttling

### 📊 Monitoring & Reporting
- **Real-time Dashboard** - Live progress bars and status updates
- **Balance Monitoring** - Multi-network balance tracking
- **Performance Metrics** - CPU, memory, and network statistics
- **Log Management** - Automatic log rotation and archival
- **Health Checks** - Continuous system health monitoring

### 🎨 User Experience
- **Progress Bars** - Colorful, animated progress indicators
- **Screen Management** - Background execution with screen sessions
- **Rich CLI** - Interactive command-line interface
- **Auto-Setup** - Automated dependency installation
- **Configuration Validation** - Comprehensive config checking

## 📋 Supported Networks

| Network | Code | Emoji | Chain ID | Alchemy Support |
|---------|------|-------|----------|----------------|
| Arbitrum Sepolia | `arbt` | 🔵 | 421614 | ✅ |
| Base Sepolia | `bast` | 🔷 | 84532 | ✅ |
| Blast Sepolia | `blst` | 💥 | 168587773 | ✅ |
| Optimism Sepolia | `opst` | 🔴 | 11155420 | ✅ |
| Unichain Sepolia | `unit` | 🦄 | 1301 | ✅ |
| Monad Testnet | `mont` | 🌙 | 41454 | ✅ |
| Sei Testnet | `seit` | ⚡ | 713715 | ✅ |
| Abstract Testnet | `abst` | 🎨 | 11124 | ✅ |
| Lisk Sepolia | `lisk` | 🔗 | 4202 | ❌ |
| Berachain Bepolia | `bera` | 🐻 | 80085 | ✅ |
| BNB Testnet | `bnb` | 🟡 | 97 | ✅ |
| L2RN Network | `l2rn` | 🌐 | 42069 | ❌ |

## 🚀 Quick Start

### Prerequisites
Ubuntu/Debian
```
sudo apt update && sudo apt install -y curl tar screen bc netcat-openbsd xxd
```
Optional dependencies for wallet address derivation
Option 1: Foundry (Recommended)
```
curl -L https://foundry.paradigm.xyz | bash
source ~/.bashrc && foundryup
```
Option 2: Node.js + ethers
```
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs
npm install -g ethers
```
Option 3: Python3 + web3
```
sudo apt install -y python3 python3-pip
pip3 install web3 eth-account
```

### Installation

Clone the repository
```
git clone https://github.com/rokhanz/t3rn-executor.git
cd t3rn-executor
```
Make scripts executable
```
chmod +x .sh modules/.sh
```
Copy environment template
```
cp .env.example .env
```
Edit configuration
```
nano .env
```

### Configuration
Edit `.env` file with your settings:
Essential Configuration
```
PRIVATE_KEY_EXECUTOR="your_private_key_without_0x_prefix"
ALCHEMY_KEY_1="your_first_alchemy_api_key"
ALCHEMY_KEY_2="your_second_alchemy_api_key"
ALCHEMY_KEY_3="your_third_alchemy_api_key"

Telegram Notifications
TELEGRAM_BOT_TOKEN="your_bot_token"
TELEGRAM_CHAT_ID="your_chat_id"

Network Selection
ENABLED_NETWORKS="arbitrum-sepolia,base-sepolia,blast-sepolia,optimism-sepolia"
```
### Running
Quick start (recommended)
```
./autorun.sh
```
Run in specific mode
```
./autorun.sh -m screen # Screen session (default)
./autorun.sh -m direct # Direct execution
./autorun.sh -m background # Background daemon
```
Validation and checks
```
./autorun.sh -c # Run checks only
./autorun.sh -v # Validate configuration
./autorun.sh -s # Show status
```

## 📖 Usage Guide

### Basic Commands
Start executor
```
./autorun.sh
```
Check status
```
./autorun.sh -s
```
Attach to screen session
```
screen -r t3rn-executor
```
View logs
```
tail -f logs/executor.log
```
Stop executor
```
pkill -f executor
```

### Advanced Usage
Run with custom settings
```
EXECUTION_MODE=background ./autorun.sh
```
Skip pre-execution checks
```
./autorun.sh --no-checks
```
Force execution despite warnings
```
./autorun.sh --force
```
Run without monitoring services
```
./autorun.sh --no-monitoring
```

### Screen Session Management
```
List all screen sessions
screen -list

Attach to T3RN session
screen -r t3rn-executor

Detach from session (inside screen)
Ctrl+A, then D

Kill session
screen -S t3rn-executor -X quit
```

## 🔧 Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `PRIVATE_KEY_EXECUTOR` | Wallet private key (64 chars, no 0x) | Required |
| `ENABLED_NETWORKS` | Comma-separated network list | All networks |
| `ALCHEMY_KEY_1-8` | Alchemy API keys for redundancy | Optional |
| `TELEGRAM_BOT_TOKEN` | Telegram bot token | Optional |
| `TELEGRAM_CHAT_ID` | Telegram chat ID | Optional |
| `EXECUTOR_MIN_BALANCE_THRESHOLD_ETH` | Minimum balance threshold | 0.5 |
| `NOTIFICATION_LEVEL` | Notification verbosity | all_success |
| `USE_PROXY` | Enable proxy usage | false |
| `ENABLE_ANTI_MEV` | Enable MEV protection | true |

### Network-Specific Settings
```
Balance thresholds per network
BALANCE_THRESHOLD_ARBT="0.3" # Arbitrum Sepolia
BALANCE_THRESHOLD_BAST="0.3" # Base Sepolia
BALANCE_THRESHOLD_BLST="0.5" # Blast Sepolia
BALANCE_THRESHOLD_OPST="0.3" # Optimism Sepolia
BALANCE_THRESHOLD_UNIT="0.5" # Unichain Sepolia

RPC overrides (optional)
RPC_ARBT_OVERRIDE="https://custom-arbitrum-rpc.com"
RPC_BAST_OVERRIDE="https://custom-base-rpc.com"
```

### Proxy Configuration
Enable proxy usage
```
USE_PROXY=true
PROXY_FILE="proxies.txt"
PROXY_FAILOVER_MODE=true
PROXY_ROTATION_INTERVAL=3600

Create proxies.txt file
echo "http://user:pass@proxy1.com:8080" > proxies.txt
echo "socks5://user:pass@proxy2.com:1080" >> proxies.txt
```

## 📊 Monitoring

### Real-time Monitoring

The executor provides comprehensive monitoring:

- **System Resources** - CPU, memory, disk usage
- **Network Health** - RPC connectivity and latency
- **Balance Tracking** - Multi-network balance monitoring
- **Transaction Metrics** - Success rates and performance
- **Error Detection** - Automatic error reporting

### Telegram Notifications

Rich notifications include:

- 🎯 **Bid Success** - Order details with network info
- ⚡ **Execution Success** - Transaction details and rewards
- 💎 **Claim Success** - Reward claims with amounts
- 💰 **Balance Reports** - Periodic balance summaries
- ⚠️ **Error Alerts** - Critical error notifications

### Log Files
```
logs/
├── executor.log # Main executor logs
├── autorun.log # Autorun script logs
├── balance_report.txt # Balance summaries
├── mev_transactions.json # MEV detection logs
├── network_stats.json # Network statistics
└── execution_summary.txt # Final execution report
```

## 🛡️ Security

### Best Practices

1. **Private Key Security**
   - Never share your private key
   - Use hardware wallets when possible
   - Regularly rotate API keys

2. **Environment Security**
   - Set proper file permissions (600 for .env)
   - Use VPN for additional security
   - Monitor for unauthorized access

3. **Network Security**
   - Use trusted RPC endpoints
   - Enable proxy rotation
   - Monitor for suspicious activity

### MEV Protection

The executor includes advanced MEV protection:

- **Sandwich Attack Detection** - Real-time monitoring
- **Frontrunning Protection** - Gas price optimization
- **Slippage Protection** - Configurable tolerance
- **Private Mempool** - Optional private transaction pools

## 🔍 Troubleshooting

### Common Issues

**1. Executor Binary Not Found**
Download manually
```
./modules/downloader.sh latest
```
**2. RPC Connection Failed**
Check network configuration
```
./autorun.sh -v
```
**3. Low Balance Warning**
Check balances
```
./modules/balance_checker.sh
```
**4. Permission Denied**
Fix permissions
```
chmod +x .sh modules/.sh
chmod 600 .env
```

### Debug Mode
Enable debug logging
```
export ENABLE_DEBUG_MODE=true
export LOG_LEVEL=debug
./autorun.sh
```
### Health Checks

Run comprehensive health check
```
./autorun.sh -c
```
Check specific components
```
./modules/validation.sh
./modules/dependency_checker.sh
```

## 📁 Project Structure
```
t3rn_executor/
├── 📄 autorun.sh # Main autorun script
├── 📄 main.sh # Core execution script
├── 📄 .env.example # Configuration template
├── 📄 README.md # This file
├── 📄 proxies.txt # Proxy configuration template
├── 📄 .gitignore # Git ignore rules
├── 📁 modules/ # Core modules
│ ├── 📄 all_monitor.sh # Comprehensive monitoring
│ ├── 📄 anti_mev.sh # MEV protection
│ ├── 📄 balance_checker.sh # Balance monitoring
│ ├── 📄 dependency_checker.sh # System dependencies
│ ├── 📄 downloader.sh # Binary downloader
│ ├── 📄 env_loader.sh # Environment loader
│ ├── 📄 executor_binary.sh # Executor management
│ ├── 📄 log_manager.sh # Log management
│ ├── 📄 progress_*.sh # Progress indicators
│ ├── 📄 proxy_manager.sh # Proxy management
│ ├── 📄 rpc_manager.sh # RPC management
│ ├── 📄 screen_manager.sh # Screen sessions
│ ├── 📄 validation.sh # Configuration validation
│ └── 📄 wallet_manager.sh # Wallet security
├── 📁 config/ # Configuration files
│ ├── 📄 network_code_map.conf # Network mappings
│ └── 📄 network_mappings.conf # Network configuration
├── 📁 anti_mev/ # MEV protection
│ └── 📄 mev_detector.js # MEV detection service
└── 📁 logs/ # Log files (auto-created)
├── 📄 executor.log # Main logs
├── 📄 balance_report.txt # Balance reports
└── 📄 *.json # JSON logs
```

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch** (`git checkout -b feature/amazing-feature`)
3. **Commit your changes** (`git commit -m 'Add amazing feature'`)
4. **Push to the branch** (`git push origin feature/amazing-feature`)
5. **Open a Pull Request**

### Development Setup
Clone for development
```
git clone https://github.com/rokhanz/t3rn-executor.git
cd t3rn-executor
```
Install development dependencies
```
./modules/dependency_checker.sh --install-all
```
Run tests
```
./autorun.sh --dry-run
```

## 🙏 Acknowledgments

- **T3RN Team** - For the amazing T3RN protocol
- **Alchemy** - For reliable RPC infrastructure
- **Community Contributors** - For testing and feedback

## 📞 Support

- **GitHub Issues** - [Report bugs or request features](https://github.com/rokhanz/t3rn-executor/issues)
- **Documentation** - [Wiki](https://github.com/rokhanz/t3rn-executor/wiki)
- **Community** - [Discussions](https://github.com/rokhanz/t3rn-executor/discussions)

## 🔄 Changelog

### v1.0.0 (Latest)
- ✅ Initial release
- ✅ Multi-network support (12 networks)
- ✅ Alchemy integration with failover
- ✅ Rich Telegram notifications
- ✅ MEV protection and detection
- ✅ Comprehensive monitoring
- ✅ Auto-restart functionality
- ✅ Proxy support with rotation
- ✅ Wallet security features
- ✅ Progress bars and UI enhancements

---

**⭐ Star this repository if you find it useful!**

**🚀 Happy Trading with T3RN Executor!**
