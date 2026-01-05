#!/bin/bash

# Cardano Node Monitoring Script

SOCKET_PATH="/var/lib/cardano/socket/node.socket"
export CARDANO_NODE_SOCKET_PATH=${SOCKET_PATH}

while true; do
    clear
    echo "=========================================="
    echo "       Cardano Node Monitor"
    echo "=========================================="
    echo ""
    
    # Check if node is running
    if ! systemctl is-active --quiet cardano-node; then
        echo "WARNING: Cardano node is not running!"
        sleep 5
        continue
    fi
    
    echo "Status: Running"
    echo ""
    
    # Check socket
    if [ ! -S "${SOCKET_PATH}" ]; then
        echo "Socket not available yet. Node may still be starting..."
        sleep 10
        continue
    fi
    
    # Get tip info
    echo "BLOCKCHAIN STATUS"
    echo "-----------------"
    
    TIP=$(cardano-cli query tip --mainnet 2>/dev/null)
    
    if [ -n "$TIP" ]; then
        SLOT=$(echo $TIP | jq -r '.slot')
        BLOCK=$(echo $TIP | jq -r '.block')
        EPOCH=$(echo $TIP | jq -r '.epoch')
        SYNC=$(echo $TIP | jq -r '.syncProgress')
        HASH=$(echo $TIP | jq -r '.hash' | cut -c1-16)
        
        echo "Epoch: ${EPOCH}"
        echo "Slot: ${SLOT}"
        echo "Block: ${BLOCK}"
        echo "Block Hash: ${HASH}..."
        echo "Sync Progress: ${SYNC}%"
    else
        echo "Unable to query tip. Node may still be syncing."
    fi
    
    echo ""
    
    # Protocol parameters
    echo "NETWORK INFO"
    echo "------------"
    echo "Network: Mainnet"
    
    # Get protocol version from tip if available
    if [ -n "$TIP" ]; then
        ERA=$(echo $TIP | jq -r '.era // "unknown"')
        echo "Current Era: ${ERA}"
    fi
    
    echo ""
    
    # System Resources
    echo "SYSTEM RESOURCES"
    echo "----------------"
    
    NODE_PID=$(pgrep -x cardano-node)
    if [ -n "$NODE_PID" ]; then
        ps -p $NODE_PID -o %cpu,%mem,rss --no-headers | while read cpu mem rss; do
            echo "CPU: ${cpu}%"
            echo "Memory: ${mem}%"
            echo "RSS: $((rss/1024)) MB"
        done
    fi
    
    echo ""
    echo "STORAGE"
    echo "-------"
    du -sh /var/lib/cardano/db 2>/dev/null | awk '{print "Database: " $1}'
    df -h /var/lib/cardano | tail -1 | awk '{print "Disk Free: " $4}'
    
    echo ""
    
    # Prometheus metrics if available
    METRICS=$(curl -s http://localhost:12798/metrics 2>/dev/null | head -20)
    if [ -n "$METRICS" ]; then
        echo "METRICS SAMPLE"
        echo "--------------"
        echo "$METRICS" | grep -E "cardano_node_metrics_epoch|cardano_node_metrics_slotNum" | head -5
    fi
    
    echo ""
    echo "Last updated: $(date)"
    echo "Press Ctrl+C to exit"
    
    sleep 30
done
