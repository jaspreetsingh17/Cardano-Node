# Cardano Stake Pool Guide

## Overview

Running a Cardano stake pool allows you to participate in block production and earn rewards for yourself and your delegators. This guide covers the complete process.

## Requirements

### Hardware
- Dedicated server or VPS
- 8+ CPU cores
- 32GB RAM
- 200GB+ SSD
- 1 Gbps network
- Static IP address

### Financial
- Approximately 505 ADA for registration
  - 500 ADA refundable pool deposit
  - ~5 ADA for transaction fees
- Pledge amount (optional but recommended)

## Architecture

For production, run at least two nodes:

```
                Internet
                    |
            +-------+-------+
            |               |
      +-----+-----+   +-----+-----+
      |   Relay   |   |   Relay   |
      |   Node 1  |   |   Node 2  |
      +-----+-----+   +-----+-----+
            |               |
            +-------+-------+
                    |
            +-------+-------+
            |    Block      |
            |   Producer    |
            +---------------+
```

## Key Types

### Cold Keys
- Most secure keys
- Never on online machine
- Used to sign pool certificates

### VRF Keys
- Verifiable Random Function
- Used for leader election
- Must be on block producer

### KES Keys
- Key Evolving Signature
- Rotated periodically (every 90 days)
- On block producer

### Operational Certificate
- Links KES keys to cold keys
- Must be regenerated when KES keys rotate

## Registration Process

### 1. Generate Keys

Run on air-gapped machine:
```bash
# Cold keys
cardano-cli node key-gen \
    --cold-verification-key-file cold.vkey \
    --cold-signing-key-file cold.skey \
    --operational-certificate-issue-counter-file cold.counter

# VRF keys
cardano-cli node key-gen-VRF \
    --verification-key-file vrf.vkey \
    --signing-key-file vrf.skey

# Stake keys
cardano-cli stake-address key-gen \
    --verification-key-file stake.vkey \
    --signing-key-file stake.skey
```

### 2. Create Payment Address

```bash
# Generate payment keys
cardano-cli address key-gen \
    --verification-key-file payment.vkey \
    --signing-key-file payment.skey

# Build address
cardano-cli address build \
    --payment-verification-key-file payment.vkey \
    --stake-verification-key-file stake.vkey \
    --out-file payment.addr \
    --mainnet
```

### 3. Register Stake Address

```bash
# Create registration certificate
cardano-cli stake-address registration-certificate \
    --stake-verification-key-file stake.vkey \
    --out-file stake.cert

# Submit transaction with certificate
# (requires funded payment address)
```

### 4. Generate Pool Registration Certificate

```bash
cardano-cli stake-pool registration-certificate \
    --cold-verification-key-file cold.vkey \
    --vrf-verification-key-file vrf.vkey \
    --pool-pledge 100000000000 \
    --pool-cost 340000000 \
    --pool-margin 0.05 \
    --pool-reward-account-verification-key-file stake.vkey \
    --pool-owner-stake-verification-key-file stake.vkey \
    --mainnet \
    --pool-relay-ipv4 YOUR_IP \
    --pool-relay-port 3001 \
    --metadata-url https://your-domain.com/poolMetaData.json \
    --metadata-hash HASH \
    --out-file pool-registration.cert
```

### 5. Submit Registration

Build and submit transaction containing the pool registration certificate.

## Pool Metadata

Create a JSON file hosted at a public URL:

```json
{
    "name": "Your Pool Name",
    "description": "Description of your pool",
    "ticker": "TICK",
    "homepage": "https://your-pool-website.com"
}
```

Generate metadata hash:
```bash
cardano-cli stake-pool metadata-hash --pool-metadata-file poolMetaData.json
```

## KES Key Rotation

KES keys expire after 62 periods (about 90 days). Rotate before expiration:

```bash
# Generate new KES keys
cardano-cli node key-gen-KES \
    --verification-key-file kes.vkey \
    --signing-key-file kes.skey

# Issue new operational certificate
cardano-cli node issue-op-cert \
    --kes-verification-key-file kes.vkey \
    --cold-signing-key-file cold.skey \
    --operational-certificate-issue-counter cold.counter \
    --kes-period CURRENT_KES_PERIOD \
    --out-file node.cert
```

## Monitoring

Key metrics to monitor:
- Block production (slots assigned vs produced)
- Uptime
- Peer connections
- Memory and CPU usage
- Sync status

## Security Best Practices

1. Keep cold keys offline
2. Use separate relay and block producer nodes
3. Never expose block producer to internet
4. Regular key rotation
5. Monitor for attacks
6. Keep software updated
