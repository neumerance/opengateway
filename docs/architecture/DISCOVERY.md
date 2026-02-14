# OpenGateway Discovery Architecture

## Overview

This document describes the **peer-to-peer (P2P) discovery system** for OpenGateway: how nodes find each other and join clusters regardless of location, with no central directory or single point of failure. Discovery is fully **open source** and **decentralized**.

**Related documents**:
- [ARCHITECT.md](../ARCHITECT.md) — High-level architecture, regions, clusters, request routing
- [ONBOARDING_NODES.md](./ONBOARDING_NODES.md) — Node install and config (includes bootstrap node list)
- [BUILDING_POC.md](../BUILDING_POC.md) — POC flow (NodeA/B/C join cluster)

---

## Table of Contents

1. [Requirements](#1-requirements)
2. [How P2P Discovery Works](#2-how-p2p-discovery-works)
3. [Open-Source Discovery Options](#3-open-source-discovery-options)
4. [Recommendation](#4-recommendation)
5. [Bootstrap Nodes](#5-bootstrap-nodes)
6. [Integration with OpenGateway](#6-integration-with-opengateway)

---

## 1. Requirements

- **Any-location join**: Nodes must be able to join a cluster from any network (same LAN, different city, different continent), not only on the same local network.
- **Fully open source**: No proprietary or closed discovery services; the entire stack must be auditable and community-run.
- **Peer-to-peer**: No central discovery server. Bootstrap nodes are only *initial* entry points; after that, discovery is performed by peers from peers (DHT, gossip).
- **Compatibility**: Must work with OpenGateway’s regional and model-based clustering (see [ARCHITECT.md](../ARCHITECT.md)).

---

## 2. How P2P Discovery Works

- **No central directory**: No single server holds the list of all peers. Peers learn about each other through the overlay network.
- **Bootstrap nodes as entry points only**: New nodes contact a small, fixed set of bootstrap nodes (e.g. 4–8) to “get into” the network. Once in, they discover further peers from the nodes they are connected to.
- **DHT (Distributed Hash Table)**: Each node stores a small part of the global routing information. Together, nodes form a distributed lookup: “who is peer X?” and “who has content/topic Y?” are answered by querying the DHT across multiple hops. No single node has the full map.
- **Gossip (optional)**: For cluster membership and liveness, nodes can propagate updates to their neighbors; again, no central broker.

So **P2P discovery** means: discovery is done by peers from peers; bootstrap nodes are the only “fixed” contacts and can be run by the community.

---

## 3. Open-Source Discovery Options

Open-source systems that support **any-location** join and **P2P** discovery:

| Option | License | Description | Best for |
|--------|---------|-------------|----------|
| **[libp2p](https://libp2p.io)** (Kad-DHT) | Apache-2.0 / MIT | Kademlia DHT + bootstrap nodes; peer and content routing. Used by IPFS, Filecoin. Implementations: Go ([go-libp2p-kad-dht](https://github.com/libp2p/go-libp2p-kad-dht)), JS/TS ([@libp2p/kad-dht](https://www.npmjs.com/package/@libp2p/kad-dht)), Rust. | Polyglot stacks; maximum ecosystem and documentation. |
| **[Hyperswarm / HyperDHT](https://github.com/holepunchto/hyperdht)** | MIT | Topic-based discovery over a DHT; built-in NAT traversal (holepunching). JS/Node. | Node-based runtimes; “join by topic” (e.g. cluster ID); NAT-heavy environments. |
| **EXO built-in** | (see EXO repo) | **UDPDiscovery**: LAN-only, automatic same-network discovery. **TailscaleDiscovery**: VPN-based. **ManualDiscovery**: config-file peer list for clouds. | Quick LAN POC; Tailscale for simple cross-location; manual list where UDP is restricted. |

---

## 4. Recommendation

- **Primary**: Use **libp2p** (e.g. go-libp2p-kad-dht or `@libp2p/kad-dht`) for open, standards-based P2P discovery so nodes can join from anywhere. Maintain a small set of **community-operated bootstrap nodes** per region (or one global list) as the only fixed entry points.
- **Alternative**: **Hyperswarm** if the node runtime is Node/JS and topic-based clusters plus NAT traversal are desired with minimal setup.
- **Short term**: Use EXO’s **UDP discovery** for same-LAN; add libp2p (or Hyperswarm) for **cross-location** discovery so the system remains fully open source and location-agnostic.

---

## 5. Bootstrap Nodes

- **Role**: Bootstrap nodes are the initial contacts a new node uses to join the DHT/overlay. They do not hold a global list of peers; they only help the new node find its first few peers.
- **Operation**: Community-operated (decentralized). No single entity must run all bootstrap nodes.
- **Per region**: Each region can maintain its own bootstrap list (see [ARCHITECT.md](../ARCHITECT.md) §7) to favor low-latency first contact; nodes can also use a global list.
- **Configuration**: Node config (e.g. in [ONBOARDING_NODES.md](./ONBOARDING_NODES.md)) includes a list of bootstrap node addresses (host:port or multiaddr). Example: `bootstrap1.opengateway.ai:8333`.

---

## 6. Integration with OpenGateway

- **Regions and clusters**: Discovery provides “who is in the network?” and “who is in topic/cluster X?”. OpenGateway then applies region and model-tier rules (see [ARCHITECT.md](../ARCHITECT.md)) for routing and cluster membership.
- **EXO**: EXO handles inference and clustering; discovery can be EXO’s built-in (LAN/VPN/manual) or an external stack (libp2p/Hyperswarm) that feeds peer lists into EXO or the node’s cluster layer.
- **Onboarding**: The install/onboarding flow (see [ONBOARDING_NODES.md](./ONBOARDING_NODES.md)) configures the node with bootstrap nodes and cluster IDs so it can join via the chosen discovery system.

---

## Summary

| Aspect | Choice |
|--------|--------|
| **Discovery type** | P2P (DHT + optional gossip); no central discovery server. |
| **Open-source stack** | libp2p (recommended) or Hyperswarm; EXO for LAN/simple cases. |
| **Bootstrap** | Small set of community-run nodes; only initial entry points. |
| **Location** | Nodes can join from any network (LAN or internet) using the same discovery stack. |

For the main architecture overview and request routing, see [ARCHITECT.md](../ARCHITECT.md).
