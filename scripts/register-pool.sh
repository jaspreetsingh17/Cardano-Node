#!/bin/bash

# Cardano Stake Pool Registration Script
# This script guides through the stake pool registration process

set -e

KEYS_DIR="/home/cardano/keys"
NETWORK="--mainnet"

echo "Cardano Stake Pool Registration"
echo "================================"
echo ""
echo "This script will guide you through creating the necessary keys"
echo "and registering a stake pool on Cardano mainnet."
echo ""
echo "WARNING: This involves real ADA. Make sure you understand the process."
echo ""

# Check if node is synced
export CARDANO_NODE_SOCKET_PATH=/var/lib/cardano/socket/node.socket

TIP=$(cardano-cli query tip ${NETWORK} 2>/dev/null)
SYNC=$(echo $TIP | jq -r '.syncProgress')

if [ "$SYNC" != "100.00" ]; then
    echo "ERROR: Node is not fully synced. Current progress: ${SYNC}%"
    echo "Please wait for full synchronization before registering a pool."
    exit 1
fi

echo "Node is fully synced."
echo ""

# Create directory for keys
mkdir -p ${KEYS_DIR}
cd ${KEYS_DIR}

echo "Step 1: Generate Cold Keys (Offline Key Pair)"
echo "----------------------------------------------"

if [ ! -f "cold.skey" ]; then
    cardano-cli node key-gen \
        --cold-verification-key-file cold.vkey \
        --cold-signing-key-file cold.skey \
        --operational-certificate-issue-counter-file cold.counter
    echo "Cold keys generated."
else
    echo "Cold keys already exist. Skipping."
fi

echo ""
echo "Step 2: Generate VRF Keys"
echo "-------------------------"

if [ ! -f "vrf.skey" ]; then
    cardano-cli node key-gen-VRF \
        --verification-key-file vrf.vkey \
        --signing-key-file vrf.skey
    chmod 400 vrf.skey
    echo "VRF keys generated."
else
    echo "VRF keys already exist. Skipping."
fi

echo ""
echo "Step 3: Generate KES Keys"
echo "-------------------------"

if [ ! -f "kes.skey" ]; then
    cardano-cli node key-gen-KES \
        --verification-key-file kes.vkey \
        --signing-key-file kes.skey
    echo "KES keys generated."
else
    echo "KES keys already exist. Skipping."
fi

echo ""
echo "Step 4: Generate Stake Pool Operational Certificate"
echo "----------------------------------------------------"

# Get current KES period
SLOT=$(cardano-cli query tip ${NETWORK} | jq -r '.slot')
SLOTS_PER_KES_PERIOD=$(cat /etc/cardano/mainnet-shelley-genesis.json | jq -r '.slotsPerKESPeriod')
KES_PERIOD=$((SLOT / SLOTS_PER_KES_PERIOD))

echo "Current KES Period: ${KES_PERIOD}"

cardano-cli node issue-op-cert \
    --kes-verification-key-file kes.vkey \
    --cold-signing-key-file cold.skey \
    --operational-certificate-issue-counter cold.counter \
    --kes-period ${KES_PERIOD} \
    --out-file node.cert

echo "Operational certificate generated."

echo ""
echo "Step 5: Generate Stake Address Keys"
echo "------------------------------------"

if [ ! -f "stake.skey" ]; then
    cardano-cli stake-address key-gen \
        --verification-key-file stake.vkey \
        --signing-key-file stake.skey
    echo "Stake keys generated."
else
    echo "Stake keys already exist. Skipping."
fi

echo ""
echo "Keys generated successfully!"
echo ""
echo "Next steps:"
echo "1. Create payment address and fund it with ADA"
echo "2. Register stake address on chain"
echo "3. Create and submit pool registration certificate"
echo "4. Create and submit pool metadata"
echo ""
echo "See docs/stake-pool.md for detailed instructions."
echo ""
echo "IMPORTANT: Backup all keys in ${KEYS_DIR} to secure offline storage!"
