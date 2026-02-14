# OpenGateway Architecture Documentation

## Overview

This directory contains the complete architectural documentation for OpenGateway - a fully peer-to-peer, decentralized AI inference network.

---

## Core Architecture Documents

### 📋 [ARCHITECT.md](../ARCHITECT.md)
**Main architectural requirements document**

Topics covered:
- Vision and core principles
- Geographic-based clustering (Asia, North America, Europe, etc.)
- Resource-based model clusters (Models A, B, C, D)
- Multi-cluster participation
- Node onboarding flow example (PC1 in Manila)
- EXO framework integration
- Request routing architecture (Phase 1: regional only)
- Bootstrap and discovery (see [DISCOVERY.md](./DISCOVERY.md))
- Design decisions and rationale

**Start here** for high-level architecture overview.

---

## Detailed Architecture Documents

### 💰 [TOKEN_ARCHITECTURE.md](./TOKEN_ARCHITECTURE.md)
**Token economy and security architecture**

Topics covered:
- **Token Economy System**
  - Zero-sum token model (spent = earned)
  - Token cost calculation (input + output)
  - Token distribution to contributing nodes
  - Bootstrap and minimum balance (1,000 tokens)
  - Overdraft protection
  - Anti-abuse mechanisms
  
- **Token Transfers**
  - Node-to-node transfers
  - Auto-transfer configuration
  - Cross-cluster transfers
  
- **Security Overview**
  - Cryptographic signatures (ED25519)
  - Distributed ledger
  - Reputation system (0-1000 score)
  - Fraud detection and slashing
  - Anti-Sybil measures
  
- **Machine Identity**
  - Hardware fingerprinting
  - Debt persistence (prevents reinstall evasion)
  - Privacy considerations

**Read this** to understand the token economy and how users earn/spend tokens.

---

### 🔐 [PROOF_SYSTEM.md](./PROOF_SYSTEM.md)
**Cryptographic proof system architecture**

Topics covered:
- **Proof System Design**
  - Why proofs instead of blockchain
  - Multi-layer security (5 layers)
  - Byzantine fault tolerance
  
- **Cryptographic Identity**
  - ED25519 key generation
  - Secure key storage (AES-256 encrypted)
  - Key rotation with chain of custody
  
- **Request Proof Flow**
  - Step 1: Request initiation (user signature)
  - Step 2: Request validation
  - Step 3: Processing proof (node contribution tracking)
  - Step 4: Completion proof (multi-signature)
  - Step 5: Peer validation
  
- **Distributed Ledger**
  - Ledger structure (balances, transactions, Merkle tree)
  - Gossip protocol (exponential propagation)
  - Ledger reconciliation (10-minute sync)
  - Fork resolution
  
- **Verification and Auditing**
  - Random audits (reputation-based frequency)
  - Challenge-response mechanism
  - Computation proof verification
  
- **Proof-of-Work Bootstrap**
  - Anti-Sybil registration
  - Difficulty adjustment (scales with network)
  
- **Fraud Detection**
  - Statistical anomaly detection
  - Automated fraud reporting
  - Slashing penalties

**Read this** for deep technical details on cryptographic security and proof verification.

---

### 🌐 [DISCOVERY.md](./DISCOVERY.md)
**P2P discovery architecture (any-location join)**

Topics covered:
- **Requirements** — Any-location join, open source, P2P (no central directory)
- **How P2P discovery works** — Bootstrap nodes as entry points only; DHT and gossip
- **Open-source options** — libp2p (Kad-DHT), Hyperswarm/HyperDHT, EXO built-in
- **Recommendation** — libp2p for cross-location; Hyperswarm for Node/JS; EXO for LAN
- **Bootstrap nodes** — Role, per-region lists, configuration
- **Integration** — Regions/clusters, EXO, onboarding

**Read this** to understand how nodes find each other and join clusters from any network.

---

### 🚀 [ONBOARDING_NODES.md](./ONBOARDING_NODES.md)
**Node installation and onboarding architecture**

Topics covered:
- **Installation Flow**
  - One-command install: `curl | bash`
  - OS detection (Linux, macOS, Windows/WSL2)
  - Expected duration: 3-10 minutes
  
- **System Requirements Detection**
  - Hardware profiling (CPU, RAM, GPU, disk)
  - Model capability assessment
  - Geographic region detection (IP-based)
  
- **Dependency Management**
  - Python, Node.js, nginx, CUDA, Docker
  - Platform-specific installation scripts
  - Model weight download strategy
  
- **Initial Token Credit**
  - 100,000 tokens granted (ChatGPT free tier equivalent)
  - Proof-of-work requirement (1-2 min challenge)
  - 24-hour time-lock on transfers
  - Anti-abuse measures
  
- **Security Setup**
  - Cryptographic key generation
  - Hardware fingerprinting
  - Firewall configuration
  - Secure storage
  
- **System Optimization**
  - GPU optimization (persistence mode, power limits)
  - CPU optimization (performance governor)
  - Memory optimization
  - Safety mechanisms (temperature monitoring, throttling)
  
- **Web Interface**
  - Dashboard with live stats
  - Chat interface for LLM interaction
  - Configuration UI
  - Technology stack: React + TypeScript + WebSocket
  
- **Command Line Interface (CLI)**
  - Complete CLI command reference
  - Node management, wallet operations, inference requests
  - Configuration management, monitoring, model management
  - Security and identity commands
  - Automation and scripting examples
  
- **Auto-Start Configuration**
  - Linux: systemd service
  - macOS: launchd plist
  - Windows: WSL2 + Task Scheduler

**Read this** to understand how users install and configure nodes.

---

## Document Relationships

```
ARCHITECT.md (High-level overview)
    │
    ├─→ TOKEN_ARCHITECTURE.md (Token economy + security)
    │       └─→ PROOF_SYSTEM.md (Cryptographic proofs)
    │
    ├─→ DISCOVERY.md (P2P discovery, bootstrap, any-location join)
    │
    └─→ ONBOARDING_NODES.md (Installation + CLI)
```

**Reading Order**:

1. **For Architects/Technical Leads**: Start with ARCHITECT.md → TOKEN_ARCHITECTURE.md → PROOF_SYSTEM.md
2. **For Backend Developers**: Start with TOKEN_ARCHITECTURE.md → PROOF_SYSTEM.md → ARCHITECT.md
3. **For Frontend/DevOps**: Start with ONBOARDING_NODES.md → ARCHITECT.md
4. **For New Contributors**: Start with ARCHITECT.md → ONBOARDING_NODES.md

---

## Quick Links

### By Topic

**Token Economy**:
- Token cost calculation → [TOKEN_ARCHITECTURE.md § 1.2](./TOKEN_ARCHITECTURE.md#12-token-cost-calculation)
- Token distribution → [TOKEN_ARCHITECTURE.md § 1.3](./TOKEN_ARCHITECTURE.md#13-token-distribution-to-contributing-nodes)
- Token transfers → [TOKEN_ARCHITECTURE.md § 1.7](./TOKEN_ARCHITECTURE.md#17-token-transfers-between-nodes)

**Security**:
- Cryptographic identity → [PROOF_SYSTEM.md § 2](./PROOF_SYSTEM.md#2-cryptographic-identity)
- Request proof flow → [PROOF_SYSTEM.md § 3](./PROOF_SYSTEM.md#3-request-proof-flow)
- Fraud detection → [PROOF_SYSTEM.md § 8](./PROOF_SYSTEM.md#8-fraud-detection)

**Node Operations**:
- Installation → [ONBOARDING_NODES.md § 1](./ONBOARDING_NODES.md#1-installation-flow)
- CLI reference → [ONBOARDING_NODES.md § 9](./ONBOARDING_NODES.md#9-command-line-interface-cli)
- Web interface → [ONBOARDING_NODES.md § 7](./ONBOARDING_NODES.md#7-web-interface)

**Architecture**:
- Geographic clustering → [ARCHITECT.md § 1](../ARCHITECT.md#1-geographic-based-clustering)
- Model clusters → [ARCHITECT.md § 2](../ARCHITECT.md#2-resource-based-model-clusters)
- Node onboarding flow → [ARCHITECT.md § 4](../ARCHITECT.md#4-node-onboarding-flow)

---

## Document Status

| Document | Status | Last Updated | Version |
|----------|--------|--------------|---------|
| ARCHITECT.md | ✅ Complete | 2026-02-13 | 0.1 |
| TOKEN_ARCHITECTURE.md | ✅ Complete | 2026-02-13 | 0.2 |
| PROOF_SYSTEM.md | ✅ Complete | 2026-02-13 | 0.1 |
| ONBOARDING_NODES.md | ✅ Complete | 2026-02-13 | 0.1 |

---

## Contributing to Documentation

When updating architecture documents:

1. **Maintain cross-references**: Update links in related documents
2. **Update version history**: Add entry to Revision History section
3. **Keep examples current**: Ensure code examples are runnable
4. **Preserve structure**: Follow existing document organization
5. **Update this index**: Reflect changes in README.md

---

## Future Documentation

Planned architecture documents:

- **REQUEST_ROUTING.md** - Detailed request routing and load balancing
- **NETWORK_PROTOCOL.md** - P2P communication protocol specification
- **MODEL_MANAGEMENT.md** - Model weight distribution and caching
- **MONITORING.md** - Network monitoring and observability
- **API_SPECIFICATION.md** - REST API and WebSocket API specs

---

## Contact

For questions about architecture documentation:
- Open an issue on GitHub
- Discuss in #architecture channel
- Email: architecture@opengateway.ai
