# Building Proof of Concept: GatewayAI (OpenGateway)

## Purpose

Rough implementation to validate the core flow: **nodes join a cluster**, **discover each other**, and **one node can issue a prompt** that is served by the network. No full token economy, proofs, or production hardening—just enough to demonstrate the idea.

---

## POC Scope

| In scope | Out of scope (for POC) |
|----------|-------------------------|
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
- **Discovery**: EXO (or minimal DHT/pubsub) so NodeB and NodeC find NodeA and each other.
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

## Run the POC script

Simple script you can curl and execute to print cluster ID, repo path, and Phase 1 env checks:

**From repo (local):**
```bash
./scripts/run-poc.sh
```

**Curled and executed (once repo is cloneable via raw URL):**
```bash
curl -fsSL https://raw.githubusercontent.com/<org>/opengateway/main/scripts/run-poc.sh | bash
```

**Download then run:**
```bash
curl -fsSL <url-to-run-poc.sh> -o run-poc.sh && chmod +x run-poc.sh && ./run-poc.sh
```

Override cluster ID: `POC_CLUSTER_ID=my-cluster ./scripts/run-poc.sh`

---

## Execution Guidelines

Progress checklist: phases → tasks → subtasks. Mark checkboxes as you complete them.

### Phase 1: Environment & cluster identity

- [ ] **Task 1.1: Prepare development environment**
  - [ ] 1.1.1 Install/verify EXO (or chosen P2P stack) and docs
  - [ ] 1.1.2 Choose cluster identity (e.g. cluster name / topic / DHT key)
  - [ ] 1.1.3 Document bootstrap endpoint or bootstrap node for POC

- [ ] **Task 1.2: Define POC message format**
  - [ ] 1.2.1 Define "join cluster" / peer advertisement format
  - [ ] 1.2.2 Define "inference_request" and "inference_response" (or echo) message format
  - [ ] 1.2.3 Optional: define request_id for matching responses

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
