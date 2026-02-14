# OpenGateway: Decentralized AI Inference Network

## Vision

**OpenGateway** is a fully peer-to-peer, decentralized AI inference network that democratizes access to AI by enabling anyone to contribute compute resources and anyone to use AI for free.

### Core Principles

- **Contribute to Use**: Share your compute to earn AI usage - no free riders
- **Truly Decentralized**: No central servers - nodes communicate peer-to-peer
- **Community Powered**: Your gaming PC's idle time helps someone across the world, and theirs helps you
- **Geographic Intelligence**: Requests go local → nearest nodes → country nodes (they work hand in hand); the search keeps expanding and the request is distributed across that growing set until there is enough capacity to process it
- **Fair Exchange**: Usage credits proportional to contribution - not profit-driven

### The Value Proposition

**Contribute-to-Use Model:**
- Contribute your compute resources → Earn usage credits
- Use those credits to run AI inference
- No money required - just share your idle computing power
- The more you contribute, the more you can use

**For Contributors:**
- Exchange idle compute for AI access (not cash)
- Be part of democratizing AI infrastructure
- Community recognition and reputation
- Higher-resource contributions earn more credits

**Why This Works:**
- No free riders - everyone contributes
- Sustainable network growth
- Natural load balancing
- Community-driven, not profit-driven
- No gatekeepers, no vendor lock-in
- Privacy-conscious alternative to centralized providers

---

## How It Works

At a high level, a node measures local machine resources, maps supported models, resolves cluster IDs for its region, and joins those clusters over Hyperswarm.

## Setup and Run a Node

### 1) Install on Linux

On a Linux machine (VPS or home), run:

```bash
curl -fsSL https://raw.githubusercontent.com/neumerance/opengateway/main/scripts/install.sh | REPO_RAW_URL=https://raw.githubusercontent.com/neumerance/opengateway/main bash
```

This installs:
- Python/Node/Ollama dependencies
- OpenGateway CLI (`opengateway`)
- Node runtime files in `~/.opengateway-poc/`

### 2) Configure region (important)

Set node region in `~/.opengateway-poc/config.json` to your AWS-style region code (keep any existing keys such as `cluster_registry_url`), for example:

```json
{
  "region": "us-east-1"
}
```

Cluster mapping uses:
- `region`
- node supported models (from resource gauge)
- cluster registry mapping (`clusters.<region>.<model>`)

### 3) Start the node

```bash
opengateway start
```

`start` and `restart` automatically:
- gauge system resources
- determine eligible models
- map cluster IDs from registry
- run node as daemon and join mapped clusters

### 4) Check status and cluster mapping

```bash
opengateway status
```

Look for:
- `Clusters:` mapped cluster IDs
- `Models:` supported model tiers
- `Node: running (pid ...)`

### 5) See peers in a cluster

```bash
opengateway peers <cluster-id>
```

If omitted, `opengateway peers` uses your default/first connected cluster.

### 6) Run a prompt

One-shot:

```bash
opengateway prompt "What is 2+2?"
```

Interactive:

```bash
opengateway prompt
```

### 7) Restart / stop

```bash
opengateway restart
opengateway stop
```

## Multi-node quick check (NodeA + NodeB)

1. Install on both nodes.
2. Use the same `region` in both configs.
3. Run `opengateway restart` on both.
4. On either node, run `opengateway status` and confirm overlapping cluster IDs.
5. Run `opengateway peers <cluster-id>` to confirm peer visibility.

For deeper implementation details, see `docs/BUILDING_POC.md` and `docs/architecture/CLUSTER_DISCOVERY_FLOW.md`.
