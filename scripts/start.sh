#!/bin/bash

# Start Cardano Node

set -e

DATA_DIR="/var/lib/cardano"
CONFIG_DIR="/etc/cardano"
SOCKET_PATH="${DATA_DIR}/socket/node.socket"

export CARDANO_NODE_SOCKET_PATH=${SOCKET_PATH}

echo "Starting Cardano Node..."

# Start via systemd
sudo systemctl start cardano-node

# Wait for startup
echo "Waiting for node to initialize..."
sleep 30

# Check if running
if systemctl is-active --quiet cardano-node; then
    echo "Cardano node started successfully"
    echo ""
    
    # Wait for socket
    RETRIES=0
    while [ ! -S "${SOCKET_PATH}" ] && [ $RETRIES -lt 30 ]; do
        echo "Waiting for socket..."
        sleep 5
        RETRIES=$((RETRIES+1))
    done
    
    if [ -S "${SOCKET_PATH}" ]; then
        echo "Checking sync status..."
        cardano-cli query tip --mainnet 2>/dev/null || echo "Node still initializing..."
    else
        echo "Socket not ready yet. Check logs with: journalctl -u cardano-node -f"
    fi
else
    echo "Failed to start Cardano node"
    sudo journalctl -u cardano-node --no-pager -n 50
    exit 1
fi
