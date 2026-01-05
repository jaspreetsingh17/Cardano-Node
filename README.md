# Cardano Node Deployment

Complete guide for deploying a Cardano full node using cardano-node.

## Overview

Cardano is a proof-of-stake blockchain platform. This repository provides everything needed to run a Cardano relay node or stake pool. The node software consists of cardano-node for consensus and cardano-cli for interaction.

## Requirements

- Ubuntu 22.04 LTS or Debian 12
- 4 CPU cores (8 recommended for stake pools)
- 24GB RAM minimum (32GB recommended)
- 200GB SSD storage
- Stable internet connection
- Static IP for stake pools

## Architecture

```
                    +------------------+
                    |   Cardano Node   |
                    |   (Relay/Block   |
                    |    Producer)     |
                    +--------+---------+
                             |
                    +--------+---------+
                    |   cardano-cli    |
                    |   (Management)   |
                    +------------------+
```

## Quick Start

```bash
git clone https://github.com/your-username/cardano-node-deployment.git
cd cardano-node-deployment
chmod +x scripts/install.sh
./scripts/install.sh
```

## Directory Structure

```
.
├── config/
│   ├── mainnet-config.json
│   ├── mainnet-topology.json
│   └── mainnet-byron-genesis.json
├── scripts/
│   ├── install.sh
│   ├── start.sh
│   ├── register-pool.sh
│   └── monitor.sh
├── docker/
│   └── docker-compose.yml
├── systemd/
│   └── cardano-node.service
└── docs/
    ├── stake-pool.md
    └── troubleshooting.md
```

## Node Types

### Relay Node
- Connects to other relays and stake pools
- Does not produce blocks
- Public facing, multiple recommended

### Block Producer
- Produces blocks when elected
- Should only connect to your relay nodes
- Never exposed directly to internet
- Requires stake pool registration

## Ports

| Port | Purpose |
|------|---------|
| 3001 | Node P2P communication |
| 12798 | Prometheus metrics |

## Sync Time

Initial synchronization takes approximately 24-48 hours depending on hardware and network conditions. The node must download and verify the entire blockchain history.

## Eras

Cardano has evolved through several eras:
- Byron (legacy)
- Shelley (staking)
- Allegra (token locking)
- Mary (multi-assets)
- Alonzo (smart contracts)
- Babbage (Plutus V2)
- Conway (governance)

## License

MIT License
