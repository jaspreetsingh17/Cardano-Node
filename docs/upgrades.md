# Cardano Node Upgrade Guide

Guide for safely upgrading cardano-node between versions.

## Pre-Upgrade Checklist

- [ ] Check [release notes](https://github.com/IntersectMBO/cardano-node/releases) for breaking changes
- [ ] Verify new version compatibility with your configuration files
- [ ] Ensure sufficient disk space (at least 50GB free)
- [ ] Backup current installation
- [ ] Plan for downtime (15-30 minutes typical)

## Backup Before Upgrade

```bash
# Stop the node first
sudo systemctl stop cardano-node

# Create backup directory
BACKUP_DIR="/data/cardano-backup-$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Backup database (optional - can be re-synced)
cp -r /data/cardano/db "$BACKUP_DIR/"

# Backup configuration (essential)
cp -r /data/cardano/config "$BACKUP_DIR/"

# Backup keys (critical - for stake pools)
cp -r /data/cardano/keys "$BACKUP_DIR/"

# Verify backup
ls -la "$BACKUP_DIR"
```

## Upgrade Methods

### Method 1: Binary Upgrade (Recommended)

```bash
# 1. Download new version
VERSION="10.1.4"  # Replace with target version
cd /tmp
wget https://github.com/IntersectMBO/cardano-node/releases/download/${VERSION}/cardano-node-${VERSION}-linux.tar.gz

# 2. Verify checksum (check release page for correct hash)
sha256sum cardano-node-${VERSION}-linux.tar.gz

# 3. Stop the node
sudo systemctl stop cardano-node

# 4. Extract and install
tar -xzf cardano-node-${VERSION}-linux.tar.gz
sudo mv cardano-node /usr/local/bin/
sudo mv cardano-cli /usr/local/bin/

# 5. Verify installation
cardano-node --version
cardano-cli --version

# 6. Start the node
sudo systemctl start cardano-node
```

### Method 2: Docker Upgrade

```bash
# 1. Pull new image
docker pull ghcr.io/intersectmbo/cardano-node:10.1.4

# 2. Update docker-compose.yml version
sed -i 's/cardano-node:.*/cardano-node:10.1.4/' docker/docker-compose.yml

# 3. Restart containers
cd docker
docker-compose down
docker-compose up -d
```

## Configuration Updates

Some upgrades require configuration file updates:

```bash
# Download updated configs for mainnet
cd /data/cardano/config
curl -O https://book.play.dev.cardano.org/environments/mainnet/config.json
curl -O https://book.play.dev.cardano.org/environments/mainnet/topology.json
curl -O https://book.play.dev.cardano.org/environments/mainnet/byron-genesis.json
curl -O https://book.play.dev.cardano.org/environments/mainnet/shelley-genesis.json
curl -O https://book.play.dev.cardano.org/environments/mainnet/alonzo-genesis.json
curl -O https://book.play.dev.cardano.org/environments/mainnet/conway-genesis.json
```

## Post-Upgrade Verification

```bash
# 1. Check node is running
sudo systemctl status cardano-node

# 2. Check logs for errors
journalctl -u cardano-node -f --no-pager -n 50

# 3. Verify sync status
cardano-cli query tip --mainnet

# 4. Check node version in logs
journalctl -u cardano-node | grep -i version
```

### Expected Output (Healthy Node)

```json
{
    "block": 11234567,
    "epoch": 520,
    "era": "Conway",
    "hash": "abc123...",
    "slot": 145678901,
    "slotInEpoch": 12345,
    "slotsToEpochEnd": 419055,
    "syncProgress": "100.00"
}
```

## Rollback If Issues Occur

```bash
# 1. Stop the node
sudo systemctl stop cardano-node

# 2. Restore previous binaries
BACKUP_DIR="/data/cardano-backup-YYYYMMDD"
sudo cp "$BACKUP_DIR/cardano-node" /usr/local/bin/
sudo cp "$BACKUP_DIR/cardano-cli" /usr/local/bin/

# 3. Restore configuration if needed
cp "$BACKUP_DIR/config/"* /data/cardano/config/

# 4. Restart
sudo systemctl start cardano-node
```

## Hard Fork Upgrades

Major protocol upgrades (hard forks) require special attention:

1. **Upgrade before the hard fork date** - Check IOG announcements
2. **Update all genesis files** - New eras require new genesis configs
3. **Test on testnet first** - Preview/Preprod networks fork earlier
4. **Monitor community channels** - Follow #stake-pool-operators on Discord

## Stake Pool Specific

For stake pool operators:

```bash
# Check KES key expiration before upgrade
cardano-cli query kes-period-info \
  --mainnet \
  --op-cert-file /data/cardano/keys/node.cert

# If KES expires soon, rotate keys during upgrade window
# See docs/stake-pool.md for key rotation procedure
```

## Version Compatibility Matrix

| Node Version | Era Support | Min Config Version |
|--------------|-------------|-------------------|
| 10.x | Conway | config-10.x |
| 9.x | Babbage | config-9.x |
| 8.x | Babbage | config-8.x |

## Troubleshooting Upgrades

### Node Won't Start After Upgrade

```bash
# Check logs for specific error
journalctl -u cardano-node -n 100 --no-pager

# Common fix: clear ledger state (keeps blockchain data)
rm -rf /data/cardano/db/ledger
sudo systemctl start cardano-node
```

### Database Corruption

```bash
# If database is corrupted, resync from scratch
rm -rf /data/cardano/db/*
sudo systemctl start cardano-node
# Note: Full resync takes 24-48 hours
```

### Config Incompatibility

```bash
# Download fresh configs matching your node version
./scripts/install.sh --config-only
```

## Automation Script

Save as `scripts/update.sh`:

```bash
#!/bin/bash
set -e

VERSION="${1:-latest}"

echo "Upgrading cardano-node to version: $VERSION"

# Backup
./scripts/backup.sh

# Stop
sudo systemctl stop cardano-node

# Download and install
cd /tmp
wget -q "https://github.com/IntersectMBO/cardano-node/releases/download/${VERSION}/cardano-node-${VERSION}-linux.tar.gz"
tar -xzf "cardano-node-${VERSION}-linux.tar.gz"
sudo mv cardano-node cardano-cli /usr/local/bin/

# Start
sudo systemctl start cardano-node

# Verify
sleep 10
cardano-cli query tip --mainnet
echo "Upgrade complete!"
```

## Resources

- [Official Release Notes](https://github.com/IntersectMBO/cardano-node/releases)
- [Cardano Developers Portal](https://developers.cardano.org/)
- [SPO Digest Newsletter](https://cardano-community.github.io/guild-operators/)
