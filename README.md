# NEAR Node - Multi-Network & Type Installer

![NEAR Protocol](https://img.shields.io/badge/NEAR-Protocol-black?style=for-the-badge&logo=near)
![License](https://img.shields.io/badge/License-MIT-green?style=for-the-badge)
![Ubuntu](https://img.shields.io/badge/Ubuntu-20.04%2B-orange?style=for-the-badge&logo=ubuntu)

A powerful, interactive bash script designed to simplify the deployment of a **NEAR Protocol Validator Node** or **RPC Node**. This script automates the environment setup, dependency installation, and node configuration for **Mainnet**, **Testnet**, or **Custom Networks**.

## 🚀 Features

* **Multi-Network Support:** Choose between Mainnet, Testnet, or a Custom network environment.
* **Node Type Selection:** Easily configure either a **Validator Node** (low storage requirement) or an **RPC Node** (full shard tracking).
* **Automatic RPC Configuration:** Pre-configured with high-performance RPCs (FastNEAR) for P2P state sync boot nodes.
* **Build from Source:** Automatically clones `nearcore`, checks out your specified version, and builds the binary.
* **NEAR CLI Included:** Installs the latest `near-cli-rs` and `near-validator-cli-rs` tools.
* **Systemd Integration:** Sets up `neard` as a background service with auto-restart on failure.
* **Performance Tuning:** Includes kernel-level network optimizations (`sysctl`) for stable validation.
* **Smart Config:** Automatically reduces `gc_num_epochs_to_keep` to save disk space and configures `tracked_shards` based on the selected node type.

## 📋 Prerequisites

Before running the script, ensure your machine meets the minimum requirements:
* **OS:** Ubuntu 22.04 or newer.
* **CPU:** 8-Core (with CMPXCHG16B, POPCNT, SSE4.1, SSE4.2, AVX, SHA-NI).
* **RAM:** 8GB+ (16GB recommended, 4GB could work but not recommended).
* **Storage (Validator):** 80GB+ NVMe SSD.
* **Storage (RPC):** ~2TB NVMe SSD (Required to track all shards).

## 🛠️ Usage

Download the script, make it executable, and run it:

```bash
chmod +x near_node_auto_installer.sh
./near_node_auto_installer.sh
```

Follow the interactive prompts to:
1. Select the Network (Mainnet, Testnet, or Custom).
2. Select the Node Type (Validator or RPC).
3. Enter the `nearcore` version you wish to build (e.g., `2.4.0`).
4. Enter your Pool ID (e.g., `yourpool.poolv1.mainnet`).

## 🔧 Post-Installation Steps

Once the script completes, follow these steps to start your node:
1. **Authorize Wallet:** Run `near login` to link your account.
2. **Start Node:** `sudo systemctl start neard`
3. **Monitor Logs:** `journalctl -n 100 -f -u neard | ccze -A`
4. **Track node:** [https://t.me/nearvalidatorwatcherbot](https://t.me/nearvalidatorwatcherbot)
