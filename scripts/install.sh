#!/bin/bash

# Cardano Node Installation Script
# Tested on Ubuntu 22.04 LTS

set -e

CARDANO_VERSION="8.7.3"
DATA_DIR="/var/lib/cardano"
CONFIG_DIR="/etc/cardano"
NETWORK="mainnet"

echo "Installing Cardano Node ${CARDANO_VERSION}..."

# Update system
sudo apt update && sudo apt upgrade -y

# Install dependencies
sudo apt install -y \
    automake \
    build-essential \
    pkg-config \
    libffi-dev \
    libgmp-dev \
    libssl-dev \
    libtinfo-dev \
    libsystemd-dev \
    zlib1g-dev \
    make \
    g++ \
    tmux \
    git \
    jq \
    wget \
    libncursesw5 \
    libtool \
    autoconf \
    curl

# Create cardano user
if ! id "cardano" &>/dev/null; then
    sudo useradd -r -m -s /bin/bash cardano
fi

# Create directories
sudo mkdir -p ${DATA_DIR}/db
sudo mkdir -p ${DATA_DIR}/socket
sudo mkdir -p ${CONFIG_DIR}
sudo mkdir -p /home/cardano/keys

# Download pre-built binaries
cd /tmp
wget https://github.com/IntersectMBO/cardano-node/releases/download/${CARDANO_VERSION}/cardano-node-${CARDANO_VERSION}-linux.tar.gz

tar -xzf cardano-node-${CARDANO_VERSION}-linux.tar.gz
sudo mv bin/cardano-node /usr/local/bin/
sudo mv bin/cardano-cli /usr/local/bin/
sudo chmod +x /usr/local/bin/cardano-node
sudo chmod +x /usr/local/bin/cardano-cli

# Verify installation
cardano-node --version
cardano-cli --version

# Download configuration files
cd ${CONFIG_DIR}
sudo wget https://book.world.dev.cardano.org/environments/mainnet/config.json -O mainnet-config.json
sudo wget https://book.world.dev.cardano.org/environments/mainnet/topology.json -O mainnet-topology.json
sudo wget https://book.world.dev.cardano.org/environments/mainnet/byron-genesis.json -O mainnet-byron-genesis.json
sudo wget https://book.world.dev.cardano.org/environments/mainnet/shelley-genesis.json -O mainnet-shelley-genesis.json
sudo wget https://book.world.dev.cardano.org/environments/mainnet/alonzo-genesis.json -O mainnet-alonzo-genesis.json
sudo wget https://book.world.dev.cardano.org/environments/mainnet/conway-genesis.json -O mainnet-conway-genesis.json

# Set environment variables
echo 'export CARDANO_NODE_SOCKET_PATH=/var/lib/cardano/socket/node.socket' | sudo tee /etc/profile.d/cardano.sh
echo 'export PATH=$PATH:/usr/local/bin' | sudo tee -a /etc/profile.d/cardano.sh
source /etc/profile.d/cardano.sh

# Set permissions
sudo chown -R cardano:cardano ${DATA_DIR}
sudo chown -R cardano:cardano ${CONFIG_DIR}
sudo chown -R cardano:cardano /home/cardano

# Install systemd service
sudo cp ../systemd/cardano-node.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable cardano-node

# Configure firewall
sudo ufw allow 3001/tcp

# Cleanup
rm -rf /tmp/cardano-*

echo ""
echo "Installation complete!"
echo ""
echo "Configuration files are in: ${CONFIG_DIR}"
echo "Database will be stored in: ${DATA_DIR}/db"
echo "Socket path: ${DATA_DIR}/socket/node.socket"
echo ""
echo "Start the node with: sudo systemctl start cardano-node"
echo "Check sync status with: cardano-cli query tip --mainnet"
