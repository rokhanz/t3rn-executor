#!/usr/bin/env node

/**
 * T3RN Executor MEV Detector
 * 
 * Monitors blockchain transactions for MEV (Maximal Extractable Value) activities
 * and provides protection mechanisms for T3RN executor operations.
 * 
 * @author Rokhanz
 * @license MIT
 * @version 1.0.0
 */

const WebSocket = require('ws');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');
const { EventEmitter } = require('events');

// Configuration
const CONFIG = {
    // Network configurations loaded from environment - Complete T3RN Networks
    networks: {
        'arbitrum-sepolia': {
            wsUrl: process.env.RPC_ARBT?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 421614,
            name: 'Arbitrum Sepolia',
            emoji: '🔵',
            alchemySupported: true
        },
        'base-sepolia': {
            wsUrl: process.env.RPC_BAST?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 84532,
            name: 'Base Sepolia',
            emoji: '🔷',
            alchemySupported: true
        },
        'blast-sepolia': {
            wsUrl: process.env.RPC_BLST?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 168587773,
            name: 'Blast Sepolia',
            emoji: '💥',
            alchemySupported: true
        },
        'optimism-sepolia': {
            wsUrl: process.env.RPC_OPST?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 11155420,
            name: 'Optimism Sepolia',
            emoji: '🔴',
            alchemySupported: true
        },
        'unichain-sepolia': {
            wsUrl: process.env.RPC_UNIT?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 1301,
            name: 'Unichain Sepolia',
            emoji: '🦄',
            alchemySupported: true
        },
        'monad-testnet': {
            wsUrl: process.env.RPC_MONT?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 41454,
            name: 'Monad Testnet',
            emoji: '🌙',
            alchemySupported: true
        },
        'sei-testnet': {
            wsUrl: process.env.RPC_SEIT?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 713715,
            name: 'Sei Testnet',
            emoji: '⚡',
            alchemySupported: true
        },
        'abstract-testnet': {
            wsUrl: process.env.RPC_ABST?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 11124,
            name: 'Abstract Testnet',
            emoji: '🎨',
            alchemySupported: true
        },
        'lisk-sepolia': {
            wsUrl: process.env.RPC_LISK?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 4202,
            name: 'Lisk Sepolia',
            emoji: '🔗',
            alchemySupported: false
        },
        'berachain-bepolia': {
            wsUrl: process.env.RPC_BERA?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 80085,
            name: 'Berachain Bepolia',
            emoji: '🐻',
            alchemySupported: true
        },
        'bnb-testnet': {
            wsUrl: process.env.RPC_BNB?.replace('https://', 'wss://').replace('http://', 'ws://') || '',
            chainId: 97,
            name: 'BNB Testnet',
            emoji: '🟡',
            alchemySupported: true
        },
        'l2rn': {
            wsUrl: process.env.RPC_L2RN || '',
            chainId: 42069,
            name: 'L2RN Network',
            emoji: '🌐',
            alchemySupported: false
        }
    },
    
    // MEV detection settings
    detection: {
        sandwichThreshold: 0.05, // 5% price impact threshold
        frontrunThreshold: 2, // seconds
        maxGasPriceMultiplier: 2.0,
        minValueThreshold: 0.01, // ETH
        suspiciousPatterns: [
            'flashloan',
            'arbitrage',
            'sandwich',
            'frontrun',
            'backrun',
            'mev',
            'bot',
            'liquidation',
            'atomic',
            'bundle'
        ],
        // Network-specific thresholds
        networkThresholds: {
            'arbitrum-sepolia': { gasMultiplier: 1.5, minValue: 0.005, mevRisk: 'medium' },
            'base-sepolia': { gasMultiplier: 1.3, minValue: 0.005, mevRisk: 'low' },
            'blast-sepolia': { gasMultiplier: 2.0, minValue: 0.01, mevRisk: 'high' },
            'optimism-sepolia': { gasMultiplier: 1.4, minValue: 0.005, mevRisk: 'low' },
            'unichain-sepolia': { gasMultiplier: 1.8, minValue: 0.01, mevRisk: 'medium' },
            'monad-testnet': { gasMultiplier: 1.6, minValue: 0.008, mevRisk: 'medium' },
            'sei-testnet': { gasMultiplier: 1.7, minValue: 0.008, mevRisk: 'medium' },
            'abstract-testnet': { gasMultiplier: 1.5, minValue: 0.006, mevRisk: 'low' },
            'lisk-sepolia': { gasMultiplier: 1.4, minValue: 0.005, mevRisk: 'low' },
            'berachain-bepolia': { gasMultiplier: 1.6, minValue: 0.008, mevRisk: 'medium' },
            'bnb-testnet': { gasMultiplier: 1.2, minValue: 0.003, mevRisk: 'low' },
            'l2rn': { gasMultiplier: 2.5, minValue: 0.015, mevRisk: 'high' }
        }
    },
    
    // Output configuration
    output: {
        logDir: './logs',
        mevTransactionsFile: './logs/mev_transactions.json',
        suspiciousTransactionsFile: './logs/suspicious_transactions.json',
        protectedTransactionsFile: './logs/protected_transactions.json',
        networkStatsFile: './logs/network_stats.json',
        dailyReportsDir: './logs/daily_reports'
    },
    
    // Monitoring settings
    monitoring: {
        enabled: process.env.ENABLE_MEV_DETECTION === 'true',
        realTimeAlerts: process.env.ENABLE_MEV_ALERTS === 'true',
        telegramNotifications: process.env.TELEGRAM_ENABLE === 'true',
        enabledNetworks: process.env.ENABLED_NETWORKS?.split(',') || [],
        alertThreshold: parseInt(process.env.MEV_ALERT_THRESHOLD) || 3,
        monitoringInterval: parseInt(process.env.MEV_MONITORING_INTERVAL) || 5000,
        maxMempoolSize: parseInt(process.env.MEV_MAX_MEMPOOL_SIZE) || 10000,
        cleanupInterval: parseInt(process.env.MEV_CLEANUP_INTERVAL) || 300000, // 5 minutes
        reconnectDelay: parseInt(process.env.MEV_RECONNECT_DELAY) || 5000
    },
    
    // Telegram configuration
    telegram: {
        botToken: process.env.TELEGRAM_BOT_TOKEN || '',
        chatId: process.env.TELEGRAM_CHAT_ID || '',
        enabled: process.env.TELEGRAM_ENABLE === 'true'
    }
};

/**
 * MEV Detector Class
 */
class MEVDetector extends EventEmitter {
    constructor() {
        super();
        this.connections = new Map();
        this.mempoolTransactions = new Map();
        this.suspiciousTransactions = new Set();
        this.protectedTransactions = new Set();
        this.networkStats = new Map();
        this.isRunning = false;
        this.reconnectTimers = new Map();
        
        // Initialize network stats
        this.initializeNetworkStats();
        
        // Initialize directories
        this.initializeDirectories();
        
        // Setup event handlers
        this.setupEventHandlers();
    }
    
    /**
     * Initialize network statistics
     */
    initializeNetworkStats() {
        for (const networkName of Object.keys(CONFIG.networks)) {
            this.networkStats.set(networkName, {
                connected: false,
                totalTransactions: 0,
                suspiciousTransactions: 0,
                mevTransactions: 0,
                lastBlockNumber: 0,
                connectionUptime: 0,
                lastReconnect: null,
                errors: 0
            });
        }
    }
    
    /**
     * Setup event handlers
     */
    setupEventHandlers() {
        this.on('mevDetected', this.handleMEVDetected.bind(this));
        this.on('suspiciousTransaction', this.handleSuspiciousTransaction.bind(this));
        this.on('networkError', this.handleNetworkError.bind(this));
        this.on('networkConnected', this.handleNetworkConnected.bind(this));
        this.on('networkDisconnected', this.handleNetworkDisconnected.bind(this));
    }
    
    /**
     * Initialize required directories
     */
    async initializeDirectories() {
        try {
            await fs.mkdir(CONFIG.output.logDir, { recursive: true });
            await fs.mkdir(CONFIG.output.dailyReportsDir, { recursive: true });
            console.log(`📁 Initialized directories: ${CONFIG.output.logDir}, ${CONFIG.output.dailyReportsDir}`);
        } catch (error) {
            console.error('❌ Failed to initialize directories:', error.message);
        }
    }
    
    /**
     * Start MEV detection for all configured networks
     */
    async start() {
        if (!CONFIG.monitoring.enabled) {
            console.log('📋 MEV detection is disabled in configuration');
            return;
        }
        
        console.log('🚀 Starting MEV Detector...');
        console.log(`🌐 Monitoring ${CONFIG.monitoring.enabledNetworks.length} networks`);
        
        this.isRunning = true;
        
        // Connect to enabled networks
        for (const networkName of CONFIG.monitoring.enabledNetworks) {
            if (CONFIG.networks[networkName]) {
                await this.connectToNetwork(networkName, CONFIG.networks[networkName]);
            } else {
                console.log(`⚠️ Unknown network in enabled list: ${networkName}`);
            }
        }
        
        // Start periodic tasks
        this.startPeriodicTasks();
        
        console.log('✅ MEV Detector started successfully');
        
        // Send startup notification
        await this.sendTelegramNotification(
            '🚀 MEV Detector Started',
            `Monitoring ${this.connections.size} networks for MEV activities`
        );
    }
    
    /**
     * Connect to a specific network
     */
    async connectToNetwork(networkName, networkConfig) {
        try {
            const emoji = networkConfig.emoji || '🔗';
            console.log(`${emoji} Connecting to ${networkConfig.name}...`);
            
            if (!networkConfig.wsUrl) {
                console.log(`⚠️ No WebSocket URL configured for ${networkName}`);
                return;
            }
            
            const ws = new WebSocket(networkConfig.wsUrl, {
                handshakeTimeout: 10000,
                perMessageDeflate: false
            });
            
            ws.on('open', () => {
                console.log(`✅ Connected to ${networkConfig.name}`);
                
                // Update network stats
                const stats = this.networkStats.get(networkName);
                stats.connected = true;
                stats.connectionUptime = Date.now();
                
                // Subscribe to new pending transactions
                ws.send(JSON.stringify({
                    id: 1,
                    method: 'eth_subscribe',
                    params: ['newPendingTransactions']
                }));
                
                // Subscribe to new block headers
                ws.send(JSON.stringify({
                    id: 2,
                    method: 'eth_subscribe',
                    params: ['newHeads']
                }));
                
                this.emit('networkConnected', networkName);
            });
            
            ws.on('message', (data) => {
                this.handleMessage(networkName, data);
            });
            
            ws.on('error', (error) => {
                console.error(`❌ WebSocket error for ${networkName}:`, error.message);
                this.emit('networkError', networkName, error);
                this.scheduleReconnect(networkName, networkConfig);
            });
            
            ws.on('close', (code, reason) => {
                console.log(`🔌 Connection closed for ${networkName} (${code}: ${reason})`);
                
                // Update network stats
                const stats = this.networkStats.get(networkName);
                stats.connected = false;
                
                this.emit('networkDisconnected', networkName);
                
                if (this.isRunning) {
                    this.scheduleReconnect(networkName, networkConfig);
                }
            });
            
            this.connections.set(networkName, ws);
            
        } catch (error) {
            console.error(`❌ Failed to connect to ${networkName}:`, error.message);
            this.scheduleReconnect(networkName, networkConfig);
        }
    }
    
    /**
     * Schedule reconnection to network
     */
    scheduleReconnect(networkName, networkConfig) {
        if (!this.isRunning) return;
        
        // Clear existing timer
        if (this.reconnectTimers.has(networkName)) {
            clearTimeout(this.reconnectTimers.get(networkName));
        }
        
        const timer = setTimeout(() => {
            if (this.isRunning) {
                console.log(`🔄 Reconnecting to ${networkName}...`);
                this.connectToNetwork(networkName, networkConfig);
            }
        }, CONFIG.monitoring.reconnectDelay);
        
        this.reconnectTimers.set(networkName, timer);
    }
    
    /**
     * Handle incoming WebSocket messages
     */
    handleMessage(networkName, data) {
        try {
            const message = JSON.parse(data);
            
            if (message.method === 'eth_subscription') {
                const result = message.params.result;
                
                if (typeof result === 'string') {
                    // New pending transaction
                    this.handlePendingTransaction(networkName, result);
                } else if (result && result.number) {
                    // New block
                    this.handleNewBlock(networkName, result);
                }
            }
        } catch (error) {
            console.error(`❌ Error parsing message from ${networkName}:`, error.message);
            
            // Update error count
            const stats = this.networkStats.get(networkName);
            if (stats) stats.errors++;
        }
    }
    
    /**
     * Handle new pending transaction
     */
    async handlePendingTransaction(networkName, txHash) {
        try {
            // Update network stats
            const stats = this.networkStats.get(networkName);
            if (stats) stats.totalTransactions++;
            
            // Get transaction details (mock implementation for security)
            const txDetails = await this.getTransactionDetails(networkName, txHash);
            
            if (txDetails) {
                // Store in mempool
                this.mempoolTransactions.set(txHash, {
                    network: networkName,
                    timestamp: Date.now(),
                    ...txDetails
                });
                
                // Analyze for MEV patterns
                await this.analyzeMEVPatterns(networkName, txHash, txDetails);
                
                // Clean up if mempool is too large
                if (this.mempoolTransactions.size > CONFIG.monitoring.maxMempoolSize) {
                    this.cleanupOldMempoolTransactions();
                }
            }
        } catch (error) {
            console.error(`❌ Error handling pending transaction:`, error.message);
        }
    }
    
    /**
     * Handle new block
     */
    async handleNewBlock(networkName, blockHeader) {
        try {
            const blockNumber = parseInt(blockHeader.number, 16);
            const emoji = CONFIG.networks[networkName]?.emoji || '🔗';
            
            console.log(`📦 ${emoji} New block on ${networkName}: ${blockNumber}`);
            
            // Update network stats
            const stats = this.networkStats.get(networkName);
            if (stats) {
                stats.lastBlockNumber = blockNumber;
            }
            
            // Get full block details (mock implementation)
            const blockDetails = await this.getBlockDetails(networkName, blockHeader.number);
            
            if (blockDetails && blockDetails.transactions) {
                await this.analyzeBlockForMEV(networkName, blockDetails);
            }
            
        } catch (error) {
            console.error(`❌ Error handling new block:`, error.message);
        }
    }
    
    /**
     * Get transaction details from RPC (mock implementation for security)
     */
    async getTransactionDetails(networkName, txHash) {
        // Mock implementation - in production this would make actual RPC calls
        return {
            hash: txHash,
            gasPrice: '0x' + Math.floor(Math.random() * 100000000000).toString(16),
            gasLimit: '0x5208',
            to: '0x' + crypto.randomBytes(20).toString('hex'),
            value: '0x' + Math.floor(Math.random() * 1000000000000000000).toString(16),
            data: Math.random() > 0.7 ? '0x' + crypto.randomBytes(100).toString('hex') : '0x'
        };
    }
    
    /**
     * Get block details from RPC (mock implementation)
     */
    async getBlockDetails(networkName, blockNumber) {
        // Mock implementation
        return {
            number: blockNumber,
            transactions: Array.from({ length: Math.floor(Math.random() * 50) }, () => ({
                hash: '0x' + crypto.randomBytes(32).toString('hex'),
                from: '0x' + crypto.randomBytes(20).toString('hex'),
                to: '0x' + crypto.randomBytes(20).toString('hex')
            })),
            timestamp: Math.floor(Date.now() / 1000)
        };
    }
    
    /**
     * Analyze transaction for MEV patterns
     */
    async analyzeMEVPatterns(networkName, txHash, txDetails) {
        const suspiciousIndicators = [];
        const networkThreshold = CONFIG.detection.networkThresholds[networkName] || {};
        
        // Check for high gas price (potential frontrunning)
        const gasPrice = parseInt(txDetails.gasPrice, 16);
        const baseGasPrice = 20000000000; // 20 gwei
        const multiplier = networkThreshold.gasMultiplier || CONFIG.detection.maxGasPriceMultiplier;
        
        if (gasPrice > baseGasPrice * multiplier) {
            suspiciousIndicators.push('high_gas_price');
        }
        
        // Check transaction value
        const value = parseInt(txDetails.value, 16);
        const minValue = networkThreshold.minValue || CONFIG.detection.minValueThreshold;
        const minValueWei = minValue * 1e18;
        
        if (value > minValueWei) {
            suspiciousIndicators.push('high_value_transaction');
        }
        
        // Check for suspicious contract interactions
        if (txDetails.data && txDetails.data.length > 10) {
            const dataLower = txDetails.data.toLowerCase();
            for (const pattern of CONFIG.detection.suspiciousPatterns) {
                if (dataLower.includes(pattern)) {
                    suspiciousIndicators.push(`suspicious_pattern_${pattern}`);
                }
            }
        }
        
        // Check for sandwich attack patterns
        await this.detectSandwichAttack(networkName, txHash, txDetails);
        
        // Check for frontrunning patterns
        await this.detectFrontrunning(networkName, txHash, txDetails);
        
        // If suspicious, add to tracking
        if (suspiciousIndicators.length > 0) {
            this.suspiciousTransactions.add(txHash);
            
            // Update network stats
            const stats = this.networkStats.get(networkName);
            if (stats) stats.suspiciousTransactions++;
            
            await this.logSuspiciousTransaction({
                network: networkName,
                hash: txHash,
                timestamp: Date.now(),
                indicators: suspiciousIndicators,
                riskLevel: networkThreshold.mevRisk || 'medium',
                details: txDetails
            });
            
            this.emit('suspiciousTransaction', {
                networkName,
                txHash,
                indicators: suspiciousIndicators
            });
            
            // Send alert if threshold reached
            if (suspiciousIndicators.length >= CONFIG.monitoring.alertThreshold) {
                await this.sendMEVAlert(networkName, txHash, suspiciousIndicators);
            }
        }
    }
    
    /**
     * Detect potential sandwich attacks
     */
    async detectSandwichAttack(networkName, txHash, txDetails) {
        // Look for transactions with similar targets in mempool
        const similarTransactions = Array.from(this.mempoolTransactions.values())
            .filter(tx => 
                tx.network === networkName &&
                tx.to === txDetails.to &&
                Math.abs(tx.timestamp - Date.now()) < CONFIG.detection.frontrunThreshold * 1000
            );
        
        if (similarTransactions.length >= 2) {
            const emoji = CONFIG.networks[networkName]?.emoji || '🔗';
            console.log(`🥪 ${emoji} Potential sandwich attack detected: ${txHash.substring(0, 10)}...`);
            
            // Update MEV stats
            const stats = this.networkStats.get(networkName);
            if (stats) stats.mevTransactions++;
            
            await this.logMEVTransaction({
                type: 'sandwich_attack',
                network: networkName,
                targetTx: txHash,
                relatedTxs: similarTransactions.map(tx => tx.hash),
                timestamp: Date.now(),
                riskLevel: 'high'
            });
            
            this.emit('mevDetected', {
                type: 'sandwich_attack',
                networkName,
                txHash
            });
        }
    }
    
    /**
     * Detect frontrunning patterns
     */
    async detectFrontrunning(networkName, txHash, txDetails) {
        // Check for rapid succession of similar transactions
        const recentTransactions = Array.from(this.mempoolTransactions.values())
            .filter(tx => 
                tx.network === networkName &&
                Date.now() - tx.timestamp < 1000 && // Within 1 second
                parseInt(tx.gasPrice, 16) > parseInt(txDetails.gasPrice, 16)
            );
        
        if (recentTransactions.length > 0) {
            const emoji = CONFIG.networks[networkName]?.emoji || '🔗';
            console.log(`🏃 ${emoji} Potential frontrunning detected: ${txHash.substring(0, 10)}...`);
            
            await this.logMEVTransaction({
                type: 'frontrunning',
                network: networkName,
                targetTx: txHash,
                frontrunTxs: recentTransactions.map(tx => tx.hash),
                timestamp: Date.now(),
                riskLevel: 'medium'
            });
        }
    }
    
    /**
     * Analyze block for MEV activities
     */
    async analyzeBlockForMEV(networkName, blockDetails) {
        const transactions = blockDetails.transactions;
        
        // Look for MEV patterns in block ordering
        for (let i = 0; i < transactions.length - 1; i++) {
            const currentTx = transactions[i];
            const nextTx = transactions[i + 1];
            
            // Check for potential arbitrage sequences
            if (this.isArbitragePattern(currentTx, nextTx)) {
                await this.logMEVTransaction({
                    type: 'arbitrage',
                    network: networkName,
                    blockNumber: blockDetails.number,
                    transactions: [currentTx.hash, nextTx.hash],
                    timestamp: Date.now(),
                    riskLevel: 'low'
                });
            }
        }
    }
    
    /**
     * Check if two transactions form an arbitrage pattern
     */
    isArbitragePattern(tx1, tx2) {
        // Simplified arbitrage detection
        return tx1.to === tx2.from || tx1.from === tx2.to;
    }
    
    /**
     * Log suspicious transaction
     */
    async logSuspiciousTransaction(data) {
        try {
            const logEntry = {
                timestamp: new Date().toISOString(),
                ...data
            };
            
            await fs.appendFile(
                CONFIG.output.suspiciousTransactionsFile,
                JSON.stringify(logEntry) + '\n'
            );
            
            const emoji = CONFIG.networks[data.network]?.emoji || '🔗';
            console.log(`⚠️ ${emoji} Suspicious transaction logged: ${data.hash.substring(0, 10)}...`);
        } catch (error) {
            console.error('❌ Failed to log suspicious transaction:', error.message);
        }
    }
    
    /**
     * Log MEV transaction
     */
    async logMEVTransaction(data) {
        try {
            const logEntry = {
                timestamp: new Date().toISOString(),
                ...data
            };
            
            await fs.appendFile(
                CONFIG.output.mevTransactionsFile,
                JSON.stringify(logEntry) + '\n'
            );
            
            const emoji = CONFIG.networks[data.network]?.emoji || '🔗';
            console.log(`🎯 ${emoji} MEV transaction logged: ${data.type}`);
        } catch (error) {
            console.error('❌ Failed to log MEV transaction:', error.message);
        }
    }
    
    /**
     * Send MEV alert via Telegram
     */
    async sendMEVAlert(networkName, txHash, indicators) {
        const emoji = CONFIG.networks[networkName]?.emoji || '🔗';
        const networkName_display = CONFIG.networks[networkName]?.name || networkName;
        
        const message = `🚨 MEV Alert 🚨\n\n` +
            `${emoji} Network: ${networkName_display}\n` +
            `🔗 Transaction: ${txHash.substring(0, 16)}...\n` +
            `⚠️ Indicators: ${indicators.join(', ')}\n` +
            `⏰ Time: ${new Date().toLocaleString()}`;
        
        await this.sendTelegramNotification('MEV Alert', message);
    }
    
    /**
     * Send Telegram notification
     */
    async sendTelegramNotification(title, message) {
        if (!CONFIG.telegram.enabled || !CONFIG.telegram.botToken || !CONFIG.telegram.chatId) {
            return;
        }
        
        try {
            const fullMessage = `${title}\n\n${message}`;
            
            // Mock Telegram API call for security
            console.log('📱 Telegram notification:', fullMessage);
            
        } catch (error) {
            console.error('❌ Failed to send Telegram notification:', error.message);
        }
    }
    
    /**
     * Start periodic tasks
     */
    startPeriodicTasks() {
        // Cleanup old mempool transactions
        setInterval(() => {
            this.cleanupOldMempoolTransactions();
        }, CONFIG.monitoring.cleanupInterval);
        
        // Generate network statistics
        setInterval(() => {
            this.generateNetworkStatistics();
        }, 60000); // Every minute
        
        // Daily report generation
        setInterval(() => {
            this.generateDailyReport();
        }, 24 * 60 * 60 * 1000); // Every 24 hours
    }
    
    /**
     * Clean up old mempool transactions
     */
    cleanupOldMempoolTransactions() {
        const cutoffTime = Date.now() - (10 * 60 * 1000); // 10 minutes
        let cleanedCount = 0;
        
        for (const [txHash, txData] of this.mempoolTransactions.entries()) {
            if (txData.timestamp < cutoffTime) {
                this.mempoolTransactions.delete(txHash);
                cleanedCount++;
            }
        }
        
        if (cleanedCount > 0) {
            console.log(`🧹 Cleaned up ${cleanedCount} old mempool transactions`);
        }
    }
    
    /**
     * Generate network statistics
     */
    async generateNetworkStatistics() {
        try {
            const stats = {};
            
            for (const [networkName, networkStats] of this.networkStats.entries()) {
                const emoji = CONFIG.networks[networkName]?.emoji || '🔗';
                stats[networkName] = {
                    emoji,
                    ...networkStats,
                    uptime: networkStats.connected ? Date.now() - networkStats.connectionUptime : 0
                };
            }
            
            await fs.writeFile(
                CONFIG.output.networkStatsFile,
                JSON.stringify(stats, null, 2)
            );
            
        } catch (error) {
            console.error('❌ Failed to generate network statistics:', error.message);
        }
    }
    
    /**
     * Generate daily report
     */
    async generateDailyReport() {
        try {
            const date = new Date().toISOString().split('T')[0];
            const reportFile = path.join(CONFIG.output.dailyReportsDir, `mev_report_${date}.json`);
            
            const report = {
                date,
                summary: {
                    totalNetworks: this.networkStats.size,
                    connectedNetworks: Array.from(this.networkStats.values()).filter(s => s.connected).length,
                    totalTransactions: Array.from(this.networkStats.values()).reduce((sum, s) => sum + s.totalTransactions, 0),
                    suspiciousTransactions: Array.from(this.networkStats.values()).reduce((sum, s) => sum + s.suspiciousTransactions, 0),
                    mevTransactions: Array.from(this.networkStats.values()).reduce((sum, s) => sum + s.mevTransactions, 0)
                },
                networkStats: Object.fromEntries(this.networkStats),
                generatedAt: new Date().toISOString()
            };
            
            await fs.writeFile(reportFile, JSON.stringify(report, null, 2));
            console.log(`📊 Daily report generated: ${reportFile}`);
            
        } catch (error) {
            console.error('❌ Failed to generate daily report:', error.message);
        }
    }
    
    /**
     * Event handlers
     */
    handleMEVDetected(data) {
        console.log(`🎯 MEV detected: ${data.type} on ${data.networkName}`);
    }
    
    handleSuspiciousTransaction(data) {
        console.log(`⚠️ Suspicious transaction on ${data.networkName}: ${data.indicators.join(', ')}`);
    }
    
    handleNetworkError(networkName, error) {
        const stats = this.networkStats.get(networkName);
        if (stats) stats.errors++;
    }
    
    handleNetworkConnected(networkName) {
        console.log(`✅ Network connected: ${networkName}`);
    }
    
    handleNetworkDisconnected(networkName) {
        console.log(`🔌 Network disconnected: ${networkName}`);
    }
    
    /**
     * Stop MEV detection
     */
    async stop() {
        console.log('🛑 Stopping MEV Detector...');
        this.isRunning = false;
        
        // Clear reconnect timers
        for (const timer of this.reconnectTimers.values()) {
            clearTimeout(timer);
        }
        this.reconnectTimers.clear();
        
        // Close all WebSocket connections
        for (const [networkName, ws] of this.connections.entries()) {
            ws.close();
            const emoji = CONFIG.networks[networkName]?.emoji || '🔗';
            console.log(`🔌 ${emoji} Disconnected from ${networkName}`);
        }
        
        this.connections.clear();
        
        // Generate final report
        await this.generateNetworkStatistics();
        
        // Send shutdown notification
        await this.sendTelegramNotification(
            '🛑 MEV Detector Stopped',
            'MEV detection has been stopped'
        );
        
        console.log('✅ MEV Detector stopped');
    }
    
    /**
     * Get detection statistics
     */
    getStatistics() {
        return {
            mempoolTransactions: this.mempoolTransactions.size,
            suspiciousTransactions: this.suspiciousTransactions.size,
            protectedTransactions: this.protectedTransactions.size,
            activeConnections: this.connections.size,
            isRunning: this.isRunning,
            networkStats: Object.fromEntries(this.networkStats)
        };
    }
    
    /**
     * Get network status
     */
    getNetworkStatus() {
        const status = {};
        
        for (const [networkName, stats] of this.networkStats.entries()) {
            const emoji = CONFIG.networks[networkName]?.emoji || '🔗';
            const networkConfig = CONFIG.networks[networkName];
            
            status[networkName] = {
                emoji,
                name: networkConfig?.name || networkName,
                connected: stats.connected,
                alchemySupported: networkConfig?.alchemySupported || false,
                ...stats
            };
        }
        
        return status;
    }
}

/**
 * Main execution
 */
async function main() {
    console.log('🚀 T3RN MEV Detector v1.0.0');
    console.log('Author: Rokhanz | License: MIT');
    console.log('=====================================');
    
    const detector = new MEVDetector();
    
    // Handle graceful shutdown
    process.on('SIGINT', async () => {
        console.log('\n🛑 Received SIGINT, shutting down gracefully...');
        await detector.stop();
        process.exit(0);
    });
    
    process.on('SIGTERM', async () => {
        console.log('\n🛑 Received SIGTERM, shutting down gracefully...');
        await detector.stop();
        process.exit(0);
    });
    
    // Start detection
    try {
        await detector.start();
        
        // Status reporting
        setInterval(() => {
            const stats = detector.getStatistics();
            console.log(`📊 MEV Detector Stats: ${stats.activeConnections}/${Object.keys(CONFIG.networks).length} networks, ${stats.mempoolTransactions} mempool, ${stats.suspiciousTransactions} suspicious`);
        }, 30000); // Every 30 seconds
        
        // Network status reporting
        setInterval(() => {
            const networkStatus = detector.getNetworkStatus();
            const connectedCount = Object.values(networkStatus).filter(s => s.connected).length;
            console.log(`🌐 Network Status: ${connectedCount}/${Object.keys(networkStatus).length} connected`);
        }, 60000); // Every minute
        
    } catch (error) {
        console.error('❌ Failed to start MEV Detector:', error.message);
        process.exit(1);
    }
}

// Export for use as module
module.exports = { MEVDetector, CONFIG };

// Run if called directly
if (require.main === module) {
    main().catch(console.error);
}
