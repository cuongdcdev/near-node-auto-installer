#!/bin/bash
# Exit immediately if a command exits with a non-zero status
set -e

echo "============================================================"
echo "      NEAR Node - Multi-Network & Type Installer"
echo "============================================================"

# 1. Network & Node Type Selection
echo "Select the Network Environment:"
echo "1) mainnet (default)"
echo "2) testnet"
echo "3) custom network"
read -p "Choose an option [1-3]: " NET_CHOICE

case $NET_CHOICE in
    2)
        NEAR_ENV="testnet"
        RPC_URL="https://rpc.testnet.fastnear.com"
        ;;
    3)
        read -p "Enter custom network name: " NEAR_ENV
        read -p "Enter your custom RPC URL: " RPC_URL
        ;;
    *)
        NEAR_ENV="mainnet"
        RPC_URL="https://free.rpc.fastnear.com"
        ;;
esac

echo -e "\nSelect the Node Type:"
echo "1) Validator Node (Low storage, tracked_shards: NoShards)"
echo "2) RPC Node (Requires ~2TB NVMe, tracked_shards: AllShards)"
read -p "Choose an option [1-2]: " TYPE_CHOICE

if [ "$TYPE_CHOICE" == "2" ]; then
    NODE_TYPE="RPC"
    SHARD_CONFIG="AllShards"
else
    NODE_TYPE="Validator"
    SHARD_CONFIG="NoShards"
fi

echo -e "\n>>> Targeted Network: $NEAR_ENV"
echo ">>> Node Purpose: $NODE_TYPE"
echo ">>> Using RPC for Sync: $RPC_URL"

# 2. Collect user input
while [ -z "$NEAR_VERSION" ]; do
    read -p "Enter nearcore version (e.g., 2.4.0). Check: https://github.com/near/nearcore/releases: " NEAR_VERSION
done

read -p "Enter your Full Pool ID (e.g., lncvalidator.poolv1.$NEAR_ENV): " POOL_ID

echo -e "\nStarting installation for $NEAR_ENV ($NODE_TYPE)... All data in $HOME\n"

# 3. Update System and Install Dependencies
echo ">>> Updating OS and installing dependencies..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y git binutils-dev libcurl4-openssl-dev zlib1g-dev libdw-dev libiberty-dev \
cmake gcc g++ python3 protobuf-compiler libssl-dev pkg-config clang llvm \
docker.io awscli tmux jq ccze rclone build-essential make curl wget unzip

# 4. Install Rust (Non-interactive mode)
echo ">>> Installing Rust..."
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source "$HOME/.cargo/env"

# 5. Install NEAR CLI and Validator Extension
echo ">>> Installing NEAR CLI tools..."
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/near/near-cli-rs/releases/latest/download/near-cli-rs-installer.sh | sh
curl --proto '=https' --tlsv1.2 -LsSf https://github.com/near-cli-rs/near-validator-cli-rs/releases/latest/download/near-validator-installer.sh | sh

# 6. Build nearcore from Source
echo ">>> Cloning and building nearcore version $NEAR_VERSION..."
cd "$HOME"
if [ ! -d "nearcore" ]; then
    git clone https://github.com/near/nearcore
fi
cd nearcore
git fetch
git checkout "$NEAR_VERSION"
make release

# 7. Set Environment Variables
sed -i '/export NEAR_ENV=/d' "$HOME/.bashrc"
echo "export NEAR_ENV=$NEAR_ENV" >> "$HOME/.bashrc"
export NEAR_ENV=$NEAR_ENV

# 8. Initialize the Node
echo ">>> Initializing Node with Pool ID: $POOL_ID on $NEAR_ENV..."
cd "$HOME/nearcore"
target/release/neard init --chain-id="$NEAR_ENV" --account-id="$POOL_ID"

# 9. Optimize config.json based on Node Type
echo ">>> Optimizing config.json (gc_num_epochs_to_keep=3, tracked_shards=$SHARD_CONFIG)..."
jq --arg shards "$SHARD_CONFIG" '.gc_num_epochs_to_keep = 3 | .tracked_shards_config = $shards' "$HOME/.near/config.json" > "$HOME/.near/config.tmp" && mv "$HOME/.near/config.tmp" "$HOME/.near/config.json"

# 10. Configure P2P State Sync Boot Nodes
echo ">>> Updating boot nodes for $NEAR_ENV p2p state sync via $RPC_URL..."
BOOT_NODES=$(curl -s -X POST "$RPC_URL" -H "Content-Type: application/json" -d '{ "jsonrpc": "2.0", "method": "network_info", "params": [], "id": "dontcare" }' | \
jq -r '.result.active_peers as $list1 | .result.known_producers as $list2 | $list1[] as $active_peer | $list2[] | select(.peer_id == $active_peer.id) | "\(.peer_id)@\($active_peer.addr)"' | paste -sd "," -)

if [ ! -z "$BOOT_NODES" ]; then
    jq --arg newNodes "$BOOT_NODES" '.network.boot_nodes = $newNodes' "$HOME/.near/config.json" > "$HOME/.near/config.tmp" && mv "$HOME/.near/config.tmp" "$HOME/.near/config.json"
    echo ">>> Successfully updated boot nodes."
else
    echo ">>> WARNING: Could not fetch boot nodes. Using default config."
fi

# 11. Create Systemd Service
echo ">>> Setting up Systemd service..."
sudo tee /etc/systemd/system/neard.service > /dev/null <<EOF
[Unit]
Description=NEARd Daemon Service ($NEAR_ENV - $NODE_TYPE)

[Service]
Type=simple
User=$USER
WorkingDirectory=$HOME/.near
ExecStart=$HOME/nearcore/target/release/neard run
Restart=on-failure
RestartSec=30
KillSignal=SIGINT
TimeoutStopSec=45
KillMode=mixed

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable neard

# 12. Apply Network Optimizations (sysctl)
echo ">>> Applying network performance optimizations..."
sudo tee /etc/sysctl.d/local.conf > /dev/null <<EOF
net.core.rmem_max = 8388608
net.core.wmem_max = 8388608
net.ipv4.tcp_rmem = 4096 87380 8388608
net.ipv4.tcp_wmem = 4096 16384 8388608
net.ipv4.tcp_slow_start_after_idle = 0
EOF
sudo sysctl -p /etc/sysctl.d/local.conf || true

echo "============================================================"
echo " INSTALLATION COMPLETE! NETWORK: $NEAR_ENV | TYPE: $NODE_TYPE"
echo "============================================================"
echo "1. Authorize Wallet: Run 'near login'."
echo "2. Start Node: sudo systemctl start neard"
echo "3. Monitor Logs: journalctl -n 100 -f -u neard | ccze -A"
echo "4. Track node: https://t.me/nearvalidatorwatcherbot"
echo "============================================================"