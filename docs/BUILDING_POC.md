# Building Proof of Concept: GatewayAI (OpenGateway)

## Purpose

Rough implementation to validate the core flow: **nodes join a cluster**, **discover each other**, and **one node can issue a prompt** that is served by the network. No full token economy, proofs, or production hardening—just enough to demonstrate the idea.

---

## Do we have enough context to build the POC?

**Yes.** The following is in place; the rest is a few implementation-time choices.

| What we have | Where |
|--------------|--------|
| **Dependencies** — EXO, Python, Node, Hyperswarm, curl (machine can install EXO and be discovered) | [Dependencies](#dependencies-to-build-the-poc-exo--discovery--join-cluster) |
| **Install flow** — Install deps → Install CLI → Gauge resources → Determine clusters → Join cluster | [Install flow](#install-flow-what-installsh-does) |
| **CLI (minimum)** — status, clusters, connect, disconnect, resources, eligible, peers | [CLI (minimum)](#cli-minimum) |
| **Resource tiers** — LLM model tiers (e.g. Llama-3.2-3B … 405B) for “which clusters this machine can join” | [Resource tiers](#resource-tiers-for-cluster-eligibility-poc) |
| **Scope** — 3 nodes, 1 cluster, 1 prompt/response; no tokens, regions, or tiers | This doc, [POC Scope](#poc-scope) |
| **Scenario** — NodeA → NodeB → NodeC + prompt flow and success criteria | [Scenario](#scenario-three-nodes-one-cluster-one-prompt), [Success Criteria](#success-criteria-poc) |
| **Execution plan** — Phases 1–5 with tasks/subtasks and checkboxes | [Execution Guidelines](#execution-guidelines) |
| **Cluster identity** — Default `gatewayai-poc`; overridable via `POC_CLUSTER_ID` | [Run the POC script](#run-the-poc-script), `scripts/run-poc.sh` |
| **Discovery** — P2P options (libp2p, Hyperswarm, EXO), bootstrap, any-location join | [architecture/DISCOVERY.md](architecture/DISCOVERY.md) |
| **Message concepts** — `inference_request` / `inference_response`; optional `request_id` | [Minimal Architecture](#minimal-architecture-poc), [Implementation Notes](#implementation-notes) |
| **High-level architecture** — Regions, clusters, request routing (for later) | [ARCHITECT.md](ARCHITECT.md), [architecture/](architecture/) |

**Decisions to make at implementation start (Phase 1):**

1. **Tech stack** — Language/runtime (Go, Node/JS, or Python) and discovery implementation: EXO (LAN), libp2p (cross-location), or Hyperswarm (Node/JS + NAT). See [DISCOVERY.md](architecture/DISCOVERY.md).
2. **Message wire format** — Define the exact shape of `inference_request` and `inference_response` (e.g. JSON over the P2P channel) and whether to include `request_id`. Task 1.2 in the execution guidelines.
3. **POC bootstrap** — For same-LAN: EXO UDP discovery needs no bootstrap. For cross-location or libp2p: use one known peer as bootstrap (e.g. first node’s address) or a small bootstrap list for the POC.

Once those are chosen, the rest of the POC can be implemented from this doc and the execution checklist.

---

## Before building the install script: what to decide

Things to nail down so the POC install script and CLI can be implemented without drift:

| # | Topic | Question / decision |
|---|--------|----------------------|
| 1 | **EXO install** | Exact install method: `pip install exo-lang` or different package/source? Confirm from EXO docs and stick to it. |
| 2 | **Discovery for POC** | Use **only Hyperswarm** (current), **only EXO** (UDPDiscovery), or **both** (EXO for inference, Hyperswarm for discovery)? One clear choice avoids two stacks. |
| 3 | **CLI ↔ node** | Is the node a **daemon** (CLI talks to it via socket/API) or **foreground process** (user runs it in a terminal; CLI reads config/pid/state file)? Affects how `status` and `clusters` get data. |
| 4 | **CLI entry point** | How is the CLI invoked? e.g. `opengateway` or `og` in PATH (symlink/wrapper in install root), or `node ~/.opengateway-poc/cli.js`? |
| 5 | **Install root layout** | What lives under `OPENGATEWAY_POC_ROOT`? e.g. `config.json`, `resources.json`, `poc-node.js`, `cli.js`, `node_modules/`, `state.json` (current clusters/peers), `logs/`. Document the layout. |
| 6 | **Resource gauge: OS** | **Decided: Linux only for now.** Use /proc, nvidia-smi, df; no macOS/Windows in POC. |
| 7 | **Resource profile path** | Where to write the gauged profile? e.g. `$OPENGATEWAY_POC_ROOT/resources.json`. Same path for CLI `resources` and for “determine eligible clusters”. |
| 8 | **POC: one cluster vs many** | POC joins **one** cluster (e.g. `gatewayai-poc`) only, or multiple (e.g. all eligible A/B/C/D)? Doc says one cluster; `eligible` can still list what the machine *could* join. |
| 9 | **Join at install vs later** | Does install.sh **join a cluster and start the node** at the end (current “run node” behavior), or only **prepare** so the user runs `opengateway connect gatewayai-poc` (or `opengateway start`) after? |
| 10 | **Bootstrap (cross-LAN)** | POC same-LAN only (no bootstrap), or support cross-LAN with a bootstrap list? If cross-LAN, where does the list come from (env, config, default URL)? |
| 11 | **Idempotency** | Can the user re-run install.sh (e.g. upgrade)? Overwrite config, skip existing Node/Python, or prompt? |
| 12 | **Errors** | EXO install fails, or no Python 3.10: fail fast and exit, or best-effort (e.g. install Node + Hyperswarm only and document “EXO optional for POC”)? |

Deciding 1–2 and 3–5 is enough to start; 6 is set (Linux); 7–12 can be fixed during implementation if needed.

---

## POC Scope

| In scope | Out of scope (for POC) |
|----------|-------------------------|
| **Linux** as the target platform (install, CLI, gauge, discovery) | macOS / Windows native (later) |
| Node process that joins a cluster | Full geographic region detection |
| Discovery of other nodes in same cluster | Resource-based model tiers (A/B/C/D) |
| One node sends a prompt; another answers | Token balance, proofs, ledger |
| Minimal EXO (or equivalent) clustering | Multi-region, cross-cluster routing |
| Single cluster for all three nodes | Production install, WSL2, web UI |

---

## Scenario: Three Nodes, One Cluster, One Prompt

```
NodeA (location 1)  →  joins cluster  →  "I'm in the cluster"
NodeB (location 2)  →  joins cluster  →  "I see NodeA"
NodeC (location 3)  →  joins cluster  →  "I see NodeA, NodeB" → sends prompt → gets response
```

### NodeA: First node joins the cluster

**Goal**: Bring up one node that forms (or joins) a cluster and is ready for peers.

**Rough steps**:

1. Start a node process (e.g. single binary or script).
2. Resolve or create a **cluster identity** (e.g. cluster name / topic / DHT namespace).
3. Join the cluster via EXO (or a minimal P2P layer):
   - Connect to bootstrap / discovery (e.g. fixed bootstrap node or EXO bootstrap).
   - Advertise self in that cluster (peer ID, listen address).
4. Node is "in cluster": it can accept connections and will later be discoverable by NodeB and NodeC.

**Done when**: NodeA is running, has joined the cluster, and logs something like "Joined cluster X" or "Listening for peers".

---

### NodeB: Second node (other location) joins the cluster

**Goal**: Another node, ideally from a different machine/network (different "location"), joins the **same** cluster and discovers NodeA.

**Rough steps**:

1. Start a second node process (different machine or different terminal/port).
2. Use the **same** cluster identity / bootstrap as NodeA.
3. Join the cluster; discover peers via EXO (or equivalent) discovery.
4. Establish connection to NodeA (or at least see NodeA in the peer list).

**Done when**: NodeB is in the cluster and "sees" NodeA (e.g. logs "Peers: [NodeA]" or similar). No prompt yet.

---

### NodeC: Third node joins and makes a prompt

**Goal**: Third node joins the same cluster, then **sends a prompt** (e.g. "What is 2+2?") and **receives a response** from the network (e.g. from NodeA or NodeB, or a simple echo for POC).

**Rough steps**:

1. Start a third node process.
2. Join the same cluster; discover NodeA and NodeB.
3. **Prompt path** (minimal):
   - NodeC sends a **request message** into the cluster (e.g. "inference request: model=X, prompt=..." or a single text prompt for POC).
   - Some node in the cluster (e.g. NodeA or NodeB) that can "serve" picks it up:
     - **POC option A**: Any node echoes or returns a fixed response (validates path only).
     - **POC option B**: One node runs a tiny local model (e.g. small LLM or stub) and returns a real completion.
4. Response is routed back to NodeC (same channel or request/response correlation).

**Done when**: NodeC issues a prompt and gets a response (echo or real) from another node in the cluster.

---

## Minimal Architecture (POC)

```
┌─────────────────────────────────────────────────────────────────┐
│  Single cluster (e.g. "gatewayai-poc" or one EXO topic)          │
│                                                                  │
│   NodeA ◄──────► NodeB ◄──────► NodeC                            │
│     │               │               │                             │
│     │   discovery   │   discovery   │   discovery                 │
│     │   (EXO/P2P)   │               │                             │
│     │               │               │                             │
│     └───────────────┴───────────────┘                             │
│                     │                                             │
│            prompt from NodeC ──► handled by NodeA or NodeB        │
│            response ◄────────── back to NodeC                     │
└─────────────────────────────────────────────────────────────────┘
```

- **One cluster** for the POC (no regions, no model tiers).
- **Discovery**: EXO (or minimal DHT/pubsub) so NodeB and NodeC find NodeA and each other. For full discovery design and open-source options (libp2p, Hyperswarm), see [architecture/DISCOVERY.md](architecture/DISCOVERY.md).
- **Prompt/response**: Simple message type (e.g. "inference_request" / "inference_response") over the same P2P layer or a thin RPC on top.

---

## Implementation Notes

- **EXO**: Use EXO’s clustering/discovery so all three nodes share one logical cluster; follow EXO docs for "join cluster" and "discover peers".
- **Locations**: For "other location", run NodeB (and NodeC) on another machine or another network (e.g. second laptop, cloud VM, or different Docker network). Same cluster ID, different IPs.
- **Prompt handling**: For POC, the "serving" node can be:
  - A single designated node (e.g. NodeA), or
  - First node that replies to a broadcast "who can handle this?" (optional for later).
- **No auth/tokens**: POC can skip signatures and token checks; optional: add a minimal "request_id" so NodeC can match response to prompt.

---

## Success Criteria (POC)

1. **NodeA**: Joins cluster and stays up.
2. **NodeB**: Joins same cluster and discovers NodeA.
3. **NodeC**: Joins same cluster, discovers NodeA and NodeB, sends one prompt, receives one response from the cluster.

After that, we can iterate: add region/cluster naming, model tiers, then tokens and proofs as in [ARCHITECT.md](./ARCHITECT.md) and [architecture/](./architecture/).

---

## Dependencies (to build the POC: EXO + discovery + join cluster)

Everything a **machine** needs so it can install EXO, be discovered, and join a cluster:

| Dependency | Purpose | Installed by install.sh? |
|------------|---------|---------------------------|
| **curl** | Fetch install script and assets when run via `curl \| bash`. | No — must be on the machine already. |
| **Python 3.10+** | Runtime for EXO (distributed inference framework). | Yes (or prompt). |
| **pip** | Install EXO and Python deps. | With Python / Yes. |
| **EXO** (exo-lang) | Clustering and inference; join EXO cluster. | Yes — `pip install exo-lang` (or per EXO docs). |
| **Node.js 18+** | Runtime for discovery (Hyperswarm) and POC CLI. | Yes (check / fnm) or prompt. |
| **npm** | Install Hyperswarm and CLI deps. | Bundled with Node.js. |
| **Hyperswarm** (npm) | P2P discovery; machine can be discovered and find peers. | Yes — `npm install` in install root. |
| **CUDA / nvidia-smi** (optional) | GPU detection for resource gauge and cluster eligibility. | No — use if present for GPU VRAM. |

So: **curl** is the only hard prerequisite before running the script. install.sh installs Python 3.10+, pip, EXO, Node.js 18+, npm, and Hyperswarm so the machine can run EXO and join a cluster via discovery.

For the full production node stack, see [architecture/ONBOARDING_NODES.md](architecture/ONBOARDING_NODES.md) §3 (nginx, Docker, etc.).

---

## Install flow (what install.sh does)

The script runs in order:

1. **Install dependencies**  
   Install (or verify) everything in the [Dependencies](#dependencies-to-build-the-poc-exo--discovery--join-cluster) table on the machine: curl check, Python 3.10+, pip, EXO, Node.js 18+, npm, Hyperswarm (and optional GPU tooling if needed).

2. **Install CLI**  
   Install a minimal CLI so the user can control the node and inspect state. Minimum commands: [CLI (minimum)](#cli-minimum).

3. **Gauge machine resources**  
   Detect CPU (cores), RAM, GPU (VRAM if present), and disk. Persist a small resource profile (e.g. under `~/.opengateway-poc` or install root) so the next step and the node can use it. **Linux only for now** (e.g. /proc, nvidia-smi, df).

4. **Determine which clusters this machine can join**  
   Using the resource profile and cluster tier rules (see [Resource tiers](#resource-tiers-for-cluster-eligibility-poc)), compute which clusters this machine qualifies for (e.g. Llama-3.2-3B only, or multiple tiers). For POC, a single cluster ID (e.g. `gatewayai-poc`) is enough; tier logic can still be implemented for “which clusters” in the CLI.

5. **Join the cluster**  
   Using EXO (and/or Hyperswarm for discovery), join the chosen cluster(s) so the machine is discoverable and can participate (e.g. serve or send prompts). For POC this can be “join one cluster by ID”; later, “join all clusters this machine qualifies for”.

---

## CLI (minimum)

The CLI is installed by install.sh and provides at least:

| Command | Description |
|---------|-------------|
| **status** | Check the status of the node: running or not, listening address, uptime, health. |
| **clusters** | List which clusters this node is currently connected to (cluster id and optional role). |
| **connect** \<cluster\> | Connect (join) to a cluster by id. |
| **disconnect** \<cluster\> | Disconnect (leave) from a cluster by id. |
| **resources** | Show the gauged machine resources (CPU, RAM, GPU, disk) and the last profile. |
| **eligible** | List which clusters this machine *can* join based on resources and tier rules (from [Resource tiers](#resource-tiers-for-cluster-eligibility-poc)). |
| **peers** [cluster] | List peers in the given cluster (or current/default cluster). |

Optional for POC: **join** / **leave** as aliases for connect / disconnect; **prompt** \<text\> to send one inference prompt (like current `POC_PROMPT` flow).

---

## Resource tiers (for cluster eligibility, POC)

Used by “gauge resources” and “determine which clusters this machine can join”. Based on [ARCHITECT.md](ARCHITECT.md) §2.2; POC can use a single cluster first, then add tier logic.

| Cluster (LLM tier) | CPU | RAM | GPU VRAM | Disk |
|--------------------|-----|-----|----------|------|
| **SmolLM-360M** | 1+ core | 1GB+ | Optional | 2GB+ |
| **Qwen2-0.5B** | 1+ core | 2GB+ | Optional | 3GB+ |
| **SmolLM-1.7B** | 1+ core | 4GB+ | Optional | 5GB+ |
| **TinyLlama-1.1B** | 2+ cores | 1GB+ | Optional | 2GB+ |
| **Phi-2-2.7B** | 2+ cores | 2GB+ | Optional | 3GB+ |
| **Llama-3.2-1.5B** | 2+ cores | 4GB+ | Optional | 5GB+ |
| **Llama-3.2-3B** | 4+ cores | 8GB+ | Optional | 20GB+ |
| **Llama-3.1-8B** | 4+ cores | 12GB+ | 8GB+ | 30GB+ |
| **Llama-3.1-70B** | 8+ cores | 32GB+ | 24GB+ | 150GB+ |
| **Llama-3.1-405B** | 16+ cores | 64GB+ | 48GB+ | 500GB+ |

The gauge step fills CPU, RAM, GPU VRAM, disk; “eligible” is the set of clusters whose row the machine satisfies.

---

## Run the POC: one command per node

Each **machine** (node) used for testing runs one **curl** of the install script. The script runs the [Install flow](#install-flow-what-installsh-does): install dependencies, install CLI, gauge resources, determine eligible clusters, and join the cluster (and optionally start the node process for the three-node test).

**Install script (curl entry point):** `scripts/install.sh`

**NodeA (first node – must stay running, serves prompts):**
```bash
curl -fsSL https://raw.githubusercontent.com/<org>/opengateway/main/scripts/install.sh | NODE_NAME=NodeA POC_SERVE=1 bash
```
Or from repo: `NODE_NAME=NodeA POC_SERVE=1 ./scripts/install.sh`

**NodeB (second node – joins cluster, can also serve):**
```bash
curl -fsSL https://raw.githubusercontent.com/<org>/opengateway/main/scripts/install.sh | NODE_NAME=NodeB POC_SERVE=1 bash
```

**NodeC (third node – joins and sends one prompt, then exits):**
```bash
curl -fsSL https://raw.githubusercontent.com/<org>/opengateway/main/scripts/install.sh | NODE_NAME=NodeC POC_PROMPT="What is 2+2?" bash
```
Output: the response (e.g. `What is 2+2?` or `4` if you use an echo server).

**Env options:**

| Env | Default | Description |
|-----|---------|-------------|
| `POC_CLUSTER_ID` | `gatewayai-poc` | Cluster/topic all nodes join |
| `NODE_NAME` | auto | Display name (NodeA, NodeB, NodeC) |
| `POC_SERVE` | `0` | Set `1` so this node answers prompts (echo) |
| `POC_PROMPT` | — | If set, send this prompt and print response then exit |
| `OPENGATEWAY_POC_ROOT` | `~/.opengateway-poc` | Install and config directory |

**Same machine (three terminals):** Run NodeA in terminal 1, NodeB in terminal 2, then NodeC in terminal 3. Use the same `POC_CLUSTER_ID` (default is fine).

**Other machine / path to script:** Use the script URL in curl, or a local path:
```bash
curl -fsSL file:///path/to/opengateway/scripts/install.sh | NODE_NAME=NodeA POC_SERVE=1 bash
# or
/path/to/opengateway/scripts/install.sh
```

**Optional – env check only (no node):** `./scripts/run-poc.sh` prints cluster ID and Phase 1 checks.

---

## Execution Guidelines

Progress checklist: phases → tasks → subtasks. Mark checkboxes as you complete them.

### Phase 1: Environment, dependencies, install flow & CLI

- [ ] **Task 1.1: Implement install.sh – dependencies**
  - [ ] 1.1.1 Install/verify curl, Python 3.10+, pip, EXO (exo-lang)
  - [ ] 1.1.2 Install/verify Node.js 18+, npm, Hyperswarm (per [Dependencies](#dependencies-to-build-the-poc-exo--discovery--join-cluster))
  - [ ] 1.1.3 Document bootstrap endpoint or bootstrap node for POC (if needed)

- [ ] **Task 1.2: Implement install.sh – CLI**
  - [ ] 1.2.1 Install minimal CLI (per [CLI (minimum)](#cli-minimum))
  - [ ] 1.2.2 Implement **status** (node running, address, uptime)
  - [ ] 1.2.3 Implement **clusters** (list connected clusters)
  - [ ] 1.2.4 Implement **connect** / **disconnect** (join/leave cluster)
  - [ ] 1.2.5 Implement **resources** (show gauged CPU, RAM, GPU, disk)
  - [ ] 1.2.6 Implement **eligible** (clusters this machine can join from [Resource tiers](#resource-tiers-for-cluster-eligibility-poc))
  - [ ] 1.2.7 Implement **peers** [cluster] (list peers in cluster)

- [ ] **Task 1.3: Implement install.sh – gauge and join**
  - [ ] 1.3.1 Gauge machine resources (CPU, RAM, GPU VRAM, disk); persist profile
  - [ ] 1.3.2 Determine which clusters machine can join (tier rules)
  - [ ] 1.3.3 Join cluster (EXO and/or Hyperswarm) so machine is discoverable

- [ ] **Task 1.4: Define POC message format**
  - [ ] 1.4.1 Define "join cluster" / peer advertisement format
  - [ ] 1.4.2 Define "inference_request" and "inference_response" (or echo) message format
  - [ ] 1.4.3 Optional: define request_id for matching responses

---

### Phase 2: NodeA (first node)

- [ ] **Task 2.1: Implement node process**
  - [ ] 2.1.1 Create minimal node binary/script that starts and binds
  - [ ] 2.1.2 Load or generate cluster identity and config
  - [ ] 2.1.3 Connect to bootstrap / discovery

- [ ] **Task 2.2: Join cluster**
  - [ ] 2.2.1 Join cluster using EXO (or equivalent) with chosen cluster ID
  - [ ] 2.2.2 Advertise self (peer ID, listen address) in cluster
  - [ ] 2.2.3 Log "Joined cluster" or "Listening for peers"

- [ ] **Task 2.3: Verify NodeA**
  - [ ] 2.3.1 Run NodeA; confirm it stays up and logs cluster join
  - [ ] 2.3.2 Confirm it accepts incoming connections (or is discoverable)

---

### Phase 3: NodeB (second node, other location)

- [ ] **Task 3.1: Run second node**
  - [ ] 3.1.1 Start NodeB on different machine or different terminal/port
  - [ ] 3.1.2 Use same cluster identity and bootstrap as NodeA

- [ ] **Task 3.2: Discovery**
  - [ ] 3.2.1 NodeB joins same cluster via EXO (or equivalent)
  - [ ] 3.2.2 NodeB discovers NodeA (peer list or log)
  - [ ] 3.2.3 Establish or verify connection to NodeA

- [ ] **Task 3.3: Verify NodeB**
  - [ ] 3.3.1 NodeB logs "Peers: [NodeA]" or equivalent
  - [ ] 3.3.2 NodeA shows NodeB in its peer list (if applicable)

---

### Phase 4: NodeC (third node + prompt)

- [ ] **Task 4.1: Run third node**
  - [ ] 4.1.1 Start NodeC (third machine or terminal)
  - [ ] 4.1.2 Use same cluster identity and bootstrap
  - [ ] 4.1.3 NodeC joins cluster and discovers NodeA and NodeB

- [ ] **Task 4.2: Prompt request path**
  - [ ] 4.2.1 NodeC sends inference_request (or simple prompt) into cluster
  - [ ] 4.2.2 At least one node (NodeA or NodeB) handles request (echo or stub)
  - [ ] 4.2.3 Response is sent back to NodeC (same channel or request_id)

- [ ] **Task 4.3: Verify end-to-end**
  - [ ] 4.3.1 NodeC sends one prompt (e.g. "What is 2+2?")
  - [ ] 4.3.2 NodeC receives one response from the cluster
  - [ ] 4.3.3 Log or print request and response for verification

---

### Phase 5: Validate & document

- [ ] **Task 5.1: POC validation**
  - [ ] 5.1.1 Confirm all three nodes in same cluster
  - [ ] 5.1.2 Confirm NodeC → prompt → response flow works
  - [ ] 5.1.3 Note any failures or edge cases

- [ ] **Task 5.2: Document and next steps**
  - [ ] 5.2.1 Update this doc with actual commands and cluster ID used
  - [ ] 5.2.2 List follow-up work (regions, model tiers, tokens)
  - [ ] 5.2.3 Optional: record minimal runbook (start NodeA, then NodeB, then NodeC, then prompt)
