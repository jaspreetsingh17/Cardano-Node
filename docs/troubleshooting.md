# Cardano Node Troubleshooting

## Common Issues

### Node Not Syncing

**Symptom**: Sync progress stays at 0% or advances very slowly

**Solutions**:
1. Check network connectivity
2. Verify topology file has correct peers
3. Ensure system time is synchronized (NTP)
4. Check firewall allows port 3001

```bash
# Check sync status
cardano-cli query tip --mainnet

# Check node logs
journalctl -u cardano-node -f
```

### Socket Not Found

**Symptom**: cardano-cli commands fail with socket error

**Solutions**:
1. Verify node is running
2. Check socket path environment variable
3. Verify socket file permissions

```bash
# Set socket path
export CARDANO_NODE_SOCKET_PATH=/var/lib/cardano/socket/node.socket

# Check if socket exists
ls -la /var/lib/cardano/socket/
```

### High Memory Usage

**Symptom**: Node consumes excessive RAM

**Solutions**:
1. Increase system swap
2. Reduce RTS memory options
3. Consider using mithril for fast bootstrap

Add to systemd service:
```
Environment="GHCRTS=-N2 -I0 -A64m -n4m"
```

### Database Corruption

**Symptom**: Node fails to start with database errors

**Solutions**:
1. Stop the node
2. Remove database directory
3. Restart and resync

```bash
sudo systemctl stop cardano-node
rm -rf /var/lib/cardano/db/*
sudo systemctl start cardano-node
```

### No Peers Connecting

**Symptom**: Node shows 0 peers

**Solutions**:
1. Check topology.json configuration
2. Verify P2P is enabled in config
3. Ensure DNS resolution works
4. Check firewall rules

### KES Key Expiration

**Symptom**: Node stops producing blocks

**Solutions**:
1. Check KES period expiration
2. Generate new KES keys
3. Issue new operational certificate

```bash
# Check KES period
cardano-cli query kes-period-info --mainnet \
    --op-cert-file node.cert
```

### Pool Not Producing Blocks

**Symptom**: Assigned slots but no blocks produced

**Solutions**:
1. Verify operational certificate is valid
2. Check VRF key is correct
3. Ensure block producer connects to relays
4. Verify pool is registered correctly

```bash
# Check pool status
cardano-cli query stake-pools --mainnet | grep YOUR_POOL_ID
```

## Performance Tuning

### Recommended GHC RTS Options

For 32GB RAM machine:
```bash
GHCRTS="-N4 -I0 -A64m -n4m -qg -qb"
```

### System Settings

Add to /etc/sysctl.conf:
```
net.core.rmem_max = 16777216
net.core.wmem_max = 16777216
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 87380 16777216
```

### File Descriptors

Add to /etc/security/limits.conf:
```
cardano soft nofile 65535
cardano hard nofile 65535
```

## Fast Sync with Mithril

Instead of full sync, use Mithril snapshots:

```bash
# Install mithril client
wget https://github.com/input-output-hk/mithril/releases/latest/download/mithril-client-linux.tar.gz
tar -xzf mithril-client-linux.tar.gz
sudo mv mithril-client /usr/local/bin/

# Download snapshot
mithril-client snapshot download latest
```

## Useful Commands

```bash
# Query tip
cardano-cli query tip --mainnet

# Query UTxO
cardano-cli query utxo --address $(cat payment.addr) --mainnet

# Query protocol parameters
cardano-cli query protocol-parameters --mainnet --out-file protocol.json

# Check stake distribution
cardano-cli query stake-distribution --mainnet

# Pool parameters
cardano-cli query pool-params --stake-pool-id POOL_ID --mainnet
```

## Log Locations

- Systemd logs: `journalctl -u cardano-node`
- Prometheus metrics: `http://localhost:12798/metrics`
