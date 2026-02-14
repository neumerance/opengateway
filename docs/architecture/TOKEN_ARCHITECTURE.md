# OpenGateway Token Economy and Security Architecture

## Overview

This document details the complete token economy system and security architecture for OpenGateway. The token system serves as both the usage currency and the anti-abuse mechanism for the decentralized AI inference network.

**Key Principles**:
- **Zero-sum economy**: Every token spent = tokens earned by processors
- **Contribute-to-use**: No free riders - must contribute compute to earn tokens
- **Cryptographic security**: No blockchain required - secured by distributed ledger + reputation
- **Hardware-bound accounts**: Debt persistence via machine fingerprinting

---

## Table of Contents

1. [Token Economy System](#1-token-economy-system)
2. [Security Architecture](#2-security-architecture) - See also: [PROOF_SYSTEM.md](./PROOF_SYSTEM.md)
3. [Machine Identity and Debt Persistence](#3-machine-identity-and-debt-persistence)
4. [Security Properties](#4-security-properties)

## Related Documents

- **[PROOF_SYSTEM.md](./PROOF_SYSTEM.md)** - Complete cryptographic proof system architecture
  - Cryptographic identity and key management
  - Request proof flow (5-step process)
  - Multi-signature completion proofs
  - Distributed ledger with Merkle trees
  - Verification, auditing, and fraud detection
  - Proof-of-work bootstrap
  
- **[ONBOARDING_NODES.md](./ONBOARDING_NODES.md)** - Node installation and CLI documentation

---

## 1. Token Economy System

### 1.1 Token-Based Usage Model

**Core Principle**: Tokens are the universal currency for compute usage and contribution.

**Zero-Sum Economy**:
- Every token spent by a user is earned by the nodes that process the request
- No token creation or destruction (except initial bootstrap)
- Self-regulating and sustainable

**Token Flow**:
```
UserA makes request → Request costs 10,000 tokens
→ UserA balance: -10,000 tokens
→ Processing nodes: +10,000 tokens (distributed by contribution)
```

**Network Capacity Calculation**:
```
Regional Capacity = Σ (Node Compute Power × Availability) per model cluster
Global Capacity = Σ (All Regional Capacities)
```

---

### 1.2 Token Cost Calculation

**Basis**: Total tokens (input + output combined)

**Cost Formula**:
```
Request Cost = Input Tokens + Output Tokens
```

**Example**:
```
User prompt: "Explain quantum computing" (5 tokens)
Model response: "Quantum computing uses..." (995 tokens)
→ Total Cost: 1,000 tokens
```

**Model-Agnostic Pricing**:
- All models use the same token cost calculation
- Complexity difference handled by node availability and contribution distribution
- Model A (8B) naturally processes more tokens/second → nodes earn more
- Model D (405B) processes fewer tokens/second → but serves fewer requests

---

### 1.3 Token Distribution to Contributing Nodes

**Distribution Method**: Proportional to actual compute contribution

**Primary Method (Preferred)**: Actual tokens processed per second during request
```
Node1: Processed 100 tokens/second → 50% contribution → 5,000 tokens
Node2: Processed 60 tokens/second  → 30% contribution → 3,000 tokens
Node3: Processed 40 tokens/second  → 20% contribution → 2,000 tokens
─────────────────────────────────────────────────────
Total: 200 tokens/second          → 100%            → 10,000 tokens
```

**Fallback Method**: Share of model layers processed (EXO sharding)
```
If direct token/sec measurement not available:
Node1: Processed layers 0-20   (50% of model) → 5,000 tokens
Node2: Processed layers 21-32  (30% of model) → 3,000 tokens
Node3: Processed layers 33-40  (20% of model) → 2,000 tokens
```

**Distribution Timing**:
- Tokens distributed immediately after request completion
- No batching or delayed settlement
- Real-time balance updates

---

### 1.4 Bootstrap and Minimum Balance

**New Node Onboarding**:
```
1. New node joins network
2. Initial balance: 0 tokens
3. Node contributes compute to earn tokens
4. Once balance reaches 1,000 tokens → Can make requests
```

**Minimum Balance Requirement**: 1,000 tokens

**Overdraft Protection**:
- Nodes can go into negative balance without request interruption
- Example scenario:
  ```
  Node balance: 1,000 tokens
  Makes request: 2,000 tokens
  → Request is ALLOWED (not interrupted)
  → New balance: -1,000 tokens
  → Node must earn back to positive before next request
  ```

**Why Overdraft?**
- Prevents wasting partially completed requests
- User experience: Request never fails mid-generation
- Fairness: Processing nodes still get paid full amount
- Accountability: Negative balance prevents further requests

**Negative Balance Rules**:
- Node with negative balance CANNOT make new requests
- Must contribute and earn back to positive
- No grace period - must reach positive balance
- No maximum negative limit (first request always completes)

---

### 1.5 Token Economy as Anti-Abuse Mechanism

**Self-Regulating Rate Limiting**: Tokens serve as the natural rate limiter for the network.

**How It Works**:
```
User wants to make 1000 requests (10M tokens total)
→ Must first contribute enough compute to earn 10M tokens
→ Cannot abuse network without proportional contribution
→ Heavy usage requires heavy contribution
```

**Benefits of Token-Based Rate Limiting**:
- **Self-Regulating**: Heavy users must contribute heavily
- **No Central Authority**: No API keys or rate limit servers needed
- **Fair Distribution**: Resources naturally distributed by contribution
- **Spam Prevention**: Malicious actors run out of tokens quickly
- **DDoS Protection**: Attack requires massive compute contribution first
- **Sustainable Growth**: Usage always proportional to network capacity

**Attack Scenarios Mitigated**:
1. **Spam Requests**: Attacker runs out of tokens quickly
2. **Resource Hoarding**: Can only use what you've earned
3. **Sybil Attacks**: Creating multiple identities requires multiple contributing nodes
4. **Leeching**: Impossible - must contribute to earn tokens

**No Traditional Rate Limits Needed**:
- ❌ No "X requests per minute" API limits
- ❌ No IP-based throttling
- ❌ No account-based quotas
- ✅ Just token balance - simple and fair

---

### 1.6 Token Accounting Example

**Scenario**: PC1 in Manila (Asia-ModelC cluster)

**Day 1 - Bootstrap Phase**:
```
09:00 - Node joins network
      - Balance: 0 tokens
      - Status: Cannot make requests (below 1,000 minimum)

10:00 - Contributes to 5 requests
      - Request 1: Earned 2,000 tokens (50% contribution)
      - Request 2: Earned 1,500 tokens (30% contribution)
      - Request 3: Earned 3,000 tokens (60% contribution)
      - Request 4: Earned 1,000 tokens (25% contribution)
      - Request 5: Earned 2,500 tokens (50% contribution)
      - Balance: 10,000 tokens
      - Status: Can now make requests!
```

**Day 2 - Active Usage**:
```
11:00 - Makes first request (Model C)
      - Cost: 5,000 tokens
      - Balance: 5,000 tokens

12:00 - Makes another request (Model C)
      - Cost: 7,000 tokens (large response)
      - Balance: -2,000 tokens (overdraft)
      - Request completed successfully
      - Status: Cannot make new requests until positive

13:00 - Contributes to 3 requests
      - Earned: 5,000 tokens
      - Balance: 3,000 tokens
      - Status: Can make requests again

14:00 - Makes request (Model A, cheaper/faster)
      - Cost: 1,000 tokens
      - Balance: 2,000 tokens
```

**Summary**:
- Total Earned: 15,000 tokens
- Total Spent: 13,000 tokens
- Net Balance: 2,000 tokens
- Sustainable usage pattern ✅

---

### 1.7 Token Transfers Between Nodes

**Use Case**: Users operating multiple nodes can consolidate tokens into a primary node.

**Scenario**:
```
UserA operates 5 nodes:
- NodeA (primary): Used for making inference requests
- NodeB, NodeC, NodeD, NodeE: Contribute compute, earn tokens

UserA wants to automatically transfer all earnings from NodeB-E → NodeA
```

---

#### 1.7.1 Token Transfer Mechanism

**Direct Node-to-Node Transfer**:
- Tokens can be transferred between any two nodes in the network
- Transfer works **across different model clusters** (NodeB in Asia-ModelD can send to NodeA in Asia-ModelA)
- Transfer works **across different regions** (Phase 2 feature - cross-region transfers)

**Transfer Authorization**:
```
Only the node owner (holding private key) can initiate transfers
Transfer must be cryptographically signed by sending node
```

**Transfer Flow**:
```
1. NodeB earns 5,000 tokens from processing requests
2. NodeB checks configuration: auto_transfer = true, target = NodeA_ID
3. NodeB creates transfer transaction:
   {
     from: "NodeB_public_key",
     to: "NodeA_public_key",
     amount: 5000,
     timestamp: 1707854600,
     nonce: "random_string"
   }
4. NodeB signs with private key
5. Broadcast to cluster via gossip protocol
6. All nodes update ledgers:
   - NodeB balance: -5,000 tokens
   - NodeA balance: +5,000 tokens
```

---

#### 1.7.2 Auto-Transfer Configuration

**Node Configuration File**:
```yaml
# Node configuration
node:
  id: "NodeB_public_key"
  role: "contributor"  # Earns tokens, doesn't make requests
  
token_transfer:
  enabled: true
  auto_transfer: true
  target_node_id: "NodeA_public_key"
  
  # Transfer trigger options
  trigger:
    type: "on_receipt"  # Transfer immediately when tokens earned
    # OR
    # type: "threshold"   # Transfer when balance reaches threshold
    # threshold: 10000
    # OR
    # type: "scheduled"   # Transfer on schedule (hourly, daily)
    # interval: "1h"
  
  # Safety settings
  minimum_balance: 0  # Keep at least this many tokens in source node
  maximum_transfer: null  # Optional cap per transfer
```

**Configuration Examples**:

**Example 1: Immediate Transfer**
```yaml
token_transfer:
  enabled: true
  auto_transfer: true
  target_node_id: "NodeA_public_key"
  trigger:
    type: "on_receipt"  # Transfer immediately
```

**Example 2: Threshold-Based Transfer**
```yaml
token_transfer:
  enabled: true
  auto_transfer: true
  target_node_id: "NodeA_public_key"
  trigger:
    type: "threshold"
    threshold: 10000  # Transfer when balance >= 10,000 tokens
  minimum_balance: 1000  # Always keep 1,000 tokens in NodeB
```

**Example 3: Scheduled Transfer**
```yaml
token_transfer:
  enabled: true
  auto_transfer: true
  target_node_id: "NodeA_public_key"
  trigger:
    type: "scheduled"
    interval: "24h"  # Transfer once per day
```

---

#### 1.7.3 Transfer Transaction Format

**Signed Transfer Proof**:
```json
{
  "type": "token_transfer",
  "from_node": "NodeB_public_key",
  "to_node": "NodeA_public_key",
  "amount": 5000,
  "timestamp": 1707854600,
  "nonce": "unique_random_string",
  "reason": "auto_transfer",
  "signature": "sign(transaction, NodeB_private_key)"
}
```

**Transfer Validation**:
```
Receiving nodes verify:
1. Signature is valid (from_node owns the private key)
2. from_node balance >= amount (sufficient balance)
3. to_node exists in network
4. Nonce hasn't been used (prevent replay)
5. Timestamp is recent (within 5 minutes)

If valid → Execute transfer
If invalid → Reject and broadcast rejection proof
```

**Ledger Update**:
```
Transaction recorded in distributed ledger:
- from_node balance: -amount
- to_node balance: +amount
- Transaction hash added to history
- Merkle root updated
```

---

#### 1.7.4 Cross-Cluster Transfers

**Key Feature**: Transfers work across different model clusters within same region

**Example**:
```
NodeB (Asia-ModelD cluster): 5,000 tokens
→ Transfer to NodeA (Asia-ModelA cluster)
→ NodeA receives 5,000 tokens

Both nodes in Asia region, different model clusters: ✅ Allowed
```

**Cross-Region Transfers** (Phase 2):
```
NodeB (Asia-ModelC): 10,000 tokens
→ Transfer to NodeF (Europe-ModelA)
→ Requires cross-region ledger sync

Phase 1: ❌ Not supported (regional isolation)
Phase 2: ✅ Will be supported with global ledger coordination
```

---

#### 1.7.5 Security Considerations

**Protection Against Token Theft**:

**1. Private Key Required**:
```
Only the node holding the private key can initiate transfers
Attacker cannot transfer tokens without stealing private key
```

**2. No Third-Party Transfers**:
```
❌ NodeC cannot transfer tokens from NodeB to NodeA
✅ Only NodeB can transfer its own tokens

Even if NodeC knows NodeB's public key, cannot initiate transfer
```

**3. Machine Identity Verification**:
```
If auto-transfer configured on NodeB:
- Transfer transaction includes machine_id hash
- Receiving nodes verify machine_id matches from_node history
- Prevents attacker from cloning NodeB config to different hardware
```

**4. Rate Limiting**:
```
Optional: Limit number of transfers per time period
Example: Max 10 transfers per hour
Prevents spam/DoS via excessive transfer transactions
```

**5. Audit Trail**:
```
All transfers recorded in distributed ledger
Full transparency: Can trace token movement across nodes
Suspicious patterns flagged for manual review
```

---

#### 1.7.6 Use Case Examples

**Use Case 1: Home Node Cluster**
```
UserA has:
- Gaming PC (NodeA): High-end GPU, primary use for requests
- Old laptop (NodeB): Contributes during idle time
- Work desktop (NodeC): Contributes overnight

Configuration:
- NodeB and NodeC auto-transfer all tokens → NodeA
- NodeA accumulates tokens from all three nodes
- UserA makes all requests from NodeA
```

**Use Case 2: Geographic Distribution**
```
UserA has nodes in multiple locations:
- NodeA (Home, Manila): Primary node
- NodeB (Office, Manila): Contributes during work hours
- NodeC (Parents' house, Cebu): Contributes 24/7

Configuration:
- NodeB transfers tokens to NodeA every 6 hours
- NodeC transfers tokens to NodeA daily
- Consolidates earnings from distributed nodes
```

**Use Case 3: Specialized Compute Nodes**
```
UserA has:
- NodeA: General-purpose node (ModelA, ModelB clusters)
- NodeB: High-end GPU node (ModelC, ModelD clusters)

Strategy:
- NodeB focuses on earning tokens (high-value compute)
- NodeB transfers all earnings → NodeA
- NodeA uses accumulated tokens for inference requests
- Separation of earning vs. usage
```

---

#### 1.7.7 Implementation Example

**Auto-Transfer Logic**:
```python
class Node:
    def __init__(self, config):
        self.config = config
        self.keypair = load_or_generate_keys()
        self.machine_id = calculate_machine_id()
        self.balance = 0
        
    def on_tokens_received(self, amount, transaction):
        """Called when node earns tokens from processing request"""
        self.balance += amount
        print(f"Earned {amount} tokens. New balance: {self.balance}")
        
        # Check auto-transfer configuration
        if self.should_auto_transfer():
            self.execute_auto_transfer()
    
    def should_auto_transfer(self):
        """Check if auto-transfer should be triggered"""
        if not self.config.token_transfer.enabled:
            return False
        if not self.config.token_transfer.auto_transfer:
            return False
            
        trigger = self.config.token_transfer.trigger
        
        if trigger.type == "on_receipt":
            return True  # Transfer immediately
            
        elif trigger.type == "threshold":
            return self.balance >= trigger.threshold
            
        elif trigger.type == "scheduled":
            return self.is_transfer_schedule_due()
            
        return False
    
    def execute_auto_transfer(self):
        """Execute token transfer to target node"""
        target = self.config.token_transfer.target_node_id
        min_balance = self.config.token_transfer.minimum_balance
        
        # Calculate transfer amount
        amount = self.balance - min_balance
        
        if amount <= 0:
            return  # Nothing to transfer
        
        # Create transfer transaction
        transfer = {
            "type": "token_transfer",
            "from_node": self.keypair.public_key,
            "to_node": target,
            "amount": amount,
            "timestamp": int(time.time()),
            "nonce": generate_nonce(),
            "reason": "auto_transfer",
            "machine_id": self.machine_id
        }
        
        # Sign transaction
        transfer["signature"] = sign(transfer, self.keypair.private_key)
        
        # Broadcast to network
        self.broadcast_transfer(transfer)
        
        # Update local balance (will be confirmed by network)
        self.balance -= amount
        
        print(f"Transferred {amount} tokens to {target[:8]}...")
```

**Transfer Validation**:
```python
def validate_transfer(transfer, ledger):
    """Validate token transfer transaction"""
    
    # 1. Verify signature
    if not verify_signature(transfer, transfer["from_node"]):
        return False, "Invalid signature"
    
    # 2. Check sender balance
    sender_balance = ledger.get_balance(transfer["from_node"])
    if sender_balance < transfer["amount"]:
        return False, f"Insufficient balance: {sender_balance} < {transfer['amount']}"
    
    # 3. Verify target node exists
    if not ledger.node_exists(transfer["to_node"]):
        return False, "Target node not found"
    
    # 4. Check nonce (prevent replay)
    if ledger.nonce_used(transfer["nonce"]):
        return False, "Nonce already used (replay attack)"
    
    # 5. Verify timestamp (within 5 minutes)
    current_time = int(time.time())
    if abs(current_time - transfer["timestamp"]) > 300:
        return False, "Timestamp too old or too far in future"
    
    # 6. Optional: Verify machine_id matches sender history
    if "machine_id" in transfer:
        sender_machine = ledger.get_machine_id(transfer["from_node"])
        if sender_machine != transfer["machine_id"]:
            return False, "Machine ID mismatch (potential theft)"
    
    return True, "Valid transfer"
```

---

#### 1.7.8 Transfer Fees

**Phase 1: Zero Fees**
```
No transfer fees for Phase 1
Encourages token consolidation and network usage
```

**Phase 2: Optional Fee Model** (Future)
```
Potential fee structure:
- Free transfers within same region
- Small fee for cross-region transfers (0.1% of amount)
- Fees burned or redistributed to validators
- Prevents spam while allowing legitimate use
```

---

#### 1.7.9 Limitations and Edge Cases

**Limitation 1: No Multi-Hop Transfers**
```
❌ Cannot do: NodeA → NodeB → NodeC in one transaction
✅ Must do: NodeA → NodeB (separate), then NodeB → NodeC (separate)

Reason: Simplifies validation and prevents complex attack vectors
```

**Limitation 2: No Conditional Transfers**
```
❌ Cannot do: "Transfer if balance > X AND timestamp > Y"
✅ Can do: Configure threshold trigger in node config

Complex conditional logic handled by node software, not protocol
```

**Edge Case 1: Target Node Offline**
```
If target node is offline during transfer:
- Transfer still executes (ledger updated)
- Target node receives tokens when it comes back online
- No retry needed - ledger is authoritative
```

**Edge Case 2: Negative Balance After Transfer**
```
If sender has negative balance:
- Transfer is REJECTED
- Cannot transfer tokens you don't have
- Must earn back to positive first

Example:
NodeB balance: -1,000 tokens
Attempts transfer: ❌ Rejected
```

**Edge Case 3: Target Node Banned/Deleted**
```
If target node is banned or deleted:
- Transfer is REJECTED
- Tokens remain in sender's balance
- Sender must update configuration to new target
```

**Edge Case 4: Simultaneous Transfers**
```
If NodeB attempts two transfers simultaneously:
- Handled by timestamp ordering
- Earlier transaction processed first
- Later transaction validated against updated balance
- May result in insufficient balance rejection for second transfer
```

---

### 1.8 Token Balance Queries

**Real-Time Balance Check**:
```
Any node can query its current balance from distributed ledger:
- Query local ledger copy (instant)
- Optionally verify with 3 random peers (majority consensus)
- Balance includes pending transfers
```

**Balance History**:
```
Nodes can retrieve full transaction history:
- All tokens earned (from processing requests)
- All tokens spent (from making requests)  
- All tokens transferred (in/out)
- Net balance over time
```

**Multi-Node Balance Aggregation**:
```
User managing multiple nodes can query total balance:
- NodeA balance: 5,000 tokens
- NodeB balance: 3,000 tokens
- NodeC balance: 2,000 tokens
→ Total: 10,000 tokens across all nodes
```

---

## 2. Security Architecture

**Note**: The complete cryptographic proof system architecture has been moved to a dedicated document for better organization.

**See**: [`PROOF_SYSTEM.md`](./PROOF_SYSTEM.md)

### 2.1 Security Model Overview

**Approach**: Cryptographic Proof of Work + Reputation-Based Trust

**Core Principle**: No blockchain required. Security through cryptographic signatures, distributed ledger replication, peer validation, and reputation staking.

**Security Layers**:
1. **Cryptographic signatures** (ED25519) for all transactions
2. **Distributed ledger** (each node maintains local copy)
3. **Gossip protocol** for ledger synchronization
4. **Random peer audits** with computation verification
5. **Reputation system** with slashing penalties
6. **Challenge-response** verification

**Key Features**:
- Multi-signature completion proofs
- Merkle tree for state verification
- Proof-of-work bootstrap (anti-Sybil)
- Statistical anomaly detection
- Byzantine fault tolerance (33% malicious nodes)

**For Complete Details**:
- Cryptographic identity and key management → See PROOF_SYSTEM.md Section 2
- Request proof flow (5 steps) → See PROOF_SYSTEM.md Section 3
- Completion proofs → See PROOF_SYSTEM.md Section 4
- Distributed ledger architecture → See PROOF_SYSTEM.md Section 5
- Verification and auditing → See PROOF_SYSTEM.md Section 6
- Proof-of-work bootstrap → See PROOF_SYSTEM.md Section 7
- Fraud detection → See PROOF_SYSTEM.md Section 8

---

### 2.2 Reputation System

**See**: [`PROOF_SYSTEM.md`](./PROOF_SYSTEM.md) for complete reputation system details.

**Reputation Score**: 0-1000
- New nodes: 100
- Trusted: 600+
- Veteran: 900+

**Reputation Tiers**:
- **Probation** (0-99): 100% audit rate
- **New Node** (100-299): 50% audit rate
- **Established** (300-599): 10% audit rate
- **Trusted** (600-899): 2% audit rate
- **Veteran** (900-1000): 0.5% audit rate, can be validator

**Reputation Changes**:
- Earn: +1 per request, +10 per day uptime, +5 per audit pass
- Lose: -500 for fraud, -20 per failed verification, -200 for minor fraud

---

### 2.3 Fraud Detection and Slashing

**See**: [`PROOF_SYSTEM.md`](./PROOF_SYSTEM.md) Section 8 for complete fraud detection system.

**Detection Methods**:
1. **Random audits**: Re-run computation to verify (reputation-based frequency)
2. **Challenge-response**: Any node can challenge with staked reputation
3. **Statistical anomaly detection**: Monitor impossible patterns

**Slashing Penalties**:
- **Minor fraud**: -200 reputation, 7-day token freeze
- **Major fraud**: Reputation reset to 0, tokens confiscated, node banned
- **Severe fraud**: All colluding nodes banned, IP blacklist

---

### 2.4 Dispute Resolution

**See**: [`PROOF_SYSTEM.md`](./PROOF_SYSTEM.md) Section 6.2 for complete challenge-response system.

**Process**:
1. Any node initiates dispute (must stake reputation)
2. 5 random validators selected (reputation ≥600)
3. Validators review evidence and vote
4. 3/5 majority required
5. Winner keeps/gains reputation, loser loses reputation + tokens

**Validators earn**: 100 tokens + 10 reputation per dispute resolved

---

### 2.5 Anti-Sybil Measures

**See**: [`PROOF_SYSTEM.md`](./PROOF_SYSTEM.md) Section 7 for proof-of-work bootstrap details.

**Defense Mechanisms**:
1. **Proof-of-work bootstrap**: Must solve computational challenge (1-2 minutes)
2. **Reputation time-lock**: 18 days minimum to reach Trusted tier
3. **Resource-based voting**: Influence based on contribution, not node count
4. **Network analysis**: Detect coordinated Sybil clusters

---

## 3. Machine Identity and Debt Persistence

### 3.1 The Debt Evasion Problem

**Attack Scenario**:
```
1. Node has -10,000 token balance
2. User uninstalls node software
3. Deletes cryptographic keys
4. Reinstalls software → generates NEW keys
5. New identity = fresh 0 balance (debt erased!)
```

**This MUST be prevented** to maintain token economy integrity.

---

### 3.2 Hardware Fingerprinting

**Solution**: Tie token balance to machine hardware, not just cryptographic keys.

**Machine Identity Components**:
```
machine_id = hash(
  cpu_id,           // Processor serial number
  motherboard_uuid, // Motherboard unique ID
  mac_addresses,    // Primary network interface MAC
  disk_serial,      // Boot disk serial number
  system_uuid       // OS-level machine ID
)
```

**Multi-Layer Identity**:
```
Node has TWO identities:
1. Cryptographic Identity (public key) - Can be rotated
2. Hardware Identity (machine_id) - Cannot change without replacing hardware

Token balance tracked by BOTH:
- Primary: Cryptographic key (for day-to-day operations)
- Secondary: Hardware fingerprint (for debt enforcement)
```

---

### 3.3 Debt Enforcement Mechanism

**New Node Registration Flow**:
```
1. Node starts up
2. Generate/load cryptographic keys
3. Calculate machine_id from hardware
4. Check distributed ledger for machine_id
   
   If machine_id exists with negative balance:
     → Must use existing crypto keys OR
     → New keys inherit the negative balance
     
   If machine_id is new:
     → Register new machine_id + crypto keys
     → Start with 0 balance
```

**Key Rotation with Debt**:
```
Scenario: Node wants to rotate keys but has -5,000 balance

Process:
1. Generate new key pair
2. Old key signs new key (chain of custody)
3. Broadcast key rotation proof to network
4. New key inherits:
   - Token balance: -5,000
   - Reputation score: (same)
   - Transaction history: (linked)
5. machine_id links both old and new keys
```

**Hardware Change Scenario**:
```
Scenario: User upgrades GPU or replaces motherboard

If partial hardware change:
  - machine_id uses fuzzy matching (3/5 components match)
  - Debt still enforced

If complete hardware change (new PC):
  - Considered new machine
  - Old machine debt remains in ledger (unrecoverable)
  - Acceptable: User genuinely bought new hardware
```

---

### 3.4 Debt Ledger

**Persistent Debt Registry**:
```
Distributed ledger maintains:
{
  machine_id: "hash_of_hardware",
  crypto_keys: ["key1", "key2", "key3"],  // All keys used by this machine
  token_balance: -10000,
  reputation: 50,
  last_seen: timestamp,
  status: "debt" | "active" | "banned"
}
```

**Debt Reconciliation**:
```
Every time a node connects:
1. Calculate current machine_id
2. Query cluster for machine_id debt records
3. If debt exists:
   - Load historical balance
   - Cannot make requests until positive
   - Must contribute to earn tokens
4. If no debt:
   - New machine → Start at 0 balance
```

---

### 3.5 Anti-Circumvention Measures

**Attack 1: Spoofing Hardware IDs**
```
Defense:
- Hardware IDs verified during proof-of-work bootstrap
- Cross-reference with actual computational performance
- Statistical fingerprinting (GPU performance signatures unique)
- Trusted Execution Environment (TEE) support where available
```

**Attack 2: Virtual Machines**
```
Problem: VM can be cloned infinitely

Defense:
- Detect virtualization (check CPU flags, hypervisor presence)
- VM instances treated as higher risk:
  - Higher initial proof-of-work requirement
  - Longer reputation building period
  - More frequent audits
- Cloud provider detection (AWS, GCP, Azure IP ranges)
  - Flag for manual review if suspicious
```

**Attack 3: Hardware ID Randomization Tools**
```
Defense:
- Multiple independent hardware checks
- Behavior-based fingerprinting (not just IDs)
  - GPU computation patterns unique to hardware
  - Memory access patterns
  - Timing characteristics
- Require multiple successful audit passes before trust
```

**Attack 4: Borrowing Someone Else's Hardware**
```
Scenario: User with debt borrows friend's PC to bypass

Partial Defense:
- IP address correlation (flag if same IP, different machine_id)
- Geographic location tracking (flag if drastic location change)
- Behavioral patterns (typing speed, usage times)

Note: Cannot fully prevent, but makes attack costly/inconvenient
```

---

### 3.6 Privacy Considerations

**Concern**: Hardware fingerprinting raises privacy issues

**Mitigations**:
```
1. Hash all hardware IDs before storage
   - Original values never leave local machine
   - Network only sees hash(machine_id)
   
2. No centralized hardware database
   - Distributed ledger only (gossip protocol)
   
3. Minimal data collection
   - Only collect what's needed for debt enforcement
   - No tracking of user behavior beyond token usage
   
4. Opt-in disclosure
   - Users informed of hardware fingerprinting during install
   - Required for network participation (can choose not to join)
   
5. Right to be forgotten (limited)
   - Positive balance nodes can request data deletion
   - Debt nodes must clear balance first
```

---

### 3.7 Implementation Example

**Debt Check on Startup**:
```python
def initialize_node():
    # Load or generate crypto keys
    crypto_keypair = load_or_generate_keys()
    
    # Calculate hardware fingerprint
    machine_id = calculate_machine_id()
    
    # Query network for existing debt
    debt_record = query_cluster_ledger(machine_id)
    
    if debt_record:
        print(f"Welcome back! Loading your account...")
        token_balance = debt_record['token_balance']
        reputation = debt_record['reputation']
        
        if token_balance < 0:
            print(f"Your balance is {token_balance} tokens (negative)")
            print(f"You must contribute compute to earn back to positive")
            print(f"Once positive, you can make requests again")
        
        # Link crypto keys to machine_id
        register_key_to_machine(crypto_keypair.public_key, machine_id)
        
    else:
        print("New machine detected! Welcome to OpenGateway")
        token_balance = 0
        reputation = 100
        
        # Register new machine + keys
        register_new_machine(machine_id, crypto_keypair.public_key)
    
    return Node(
        crypto_keypair=crypto_keypair,
        machine_id=machine_id,
        token_balance=token_balance,
        reputation=reputation
    )
```

**Hardware ID Calculation**:
```python
import hashlib
import platform

def calculate_machine_id():
    components = []
    
    # CPU ID
    cpu_id = get_cpu_serial()  # Platform-specific
    components.append(cpu_id)
    
    # Motherboard UUID
    if platform.system() == "Linux":
        mb_uuid = read_file("/sys/class/dmi/id/product_uuid")
    elif platform.system() == "Darwin":  # macOS
        mb_uuid = run_command("ioreg -rd1 -c IOPlatformExpertDevice | grep UUID")
    elif platform.system() == "Windows":
        mb_uuid = run_command("wmic csproduct get UUID")
    components.append(mb_uuid)
    
    # Primary MAC address
    mac = get_primary_mac_address()
    components.append(mac)
    
    # Boot disk serial
    disk_serial = get_boot_disk_serial()
    components.append(disk_serial)
    
    # System UUID (OS level)
    system_uuid = platform.node()  # Hostname/machine ID
    components.append(system_uuid)
    
    # Combine and hash
    combined = "|".join(sorted(components))  # Sort for consistency
    machine_id = hashlib.sha256(combined.encode()).hexdigest()
    
    return machine_id
```

---

### 3.8 Edge Cases

**Case 1: Legitimate Hardware Upgrade**
```
User replaces GPU (machine_id changes partially)

Solution:
- Use fuzzy matching (3/5 components match → same machine)
- Allow user to prove identity via old crypto keys
- Gradual hardware change tolerated
```

**Case 2: Sold/Donated PC**
```
User sells PC with -10,000 debt to new owner

Solution:
- New owner inherits debt (debt tied to hardware)
- New owner can appeal via dispute resolution
- Validators review evidence (proof of ownership change)
- If legitimate → Debt forgiven (special case)
- Original owner's crypto keys blacklisted
```

**Case 3: Stolen/Compromised Keys**
```
Attacker steals user's private keys, racks up debt

Solution:
- User reports key theft via dispute system
- Must prove hardware ownership (machine_id verification)
- Validators review timing/behavior patterns
- If legitimate theft → Generate new keys, preserve reputation
- Debt may be written off if proven malicious third party
```

**Case 4: Persistent Offender**
```
User repeatedly tries to evade debt (multiple reinstalls, VM cloning)

Solution:
- Pattern detection across machine_ids
- IP address tracking (temporary, for fraud detection)
- Persistent negative reputation even with new machine
- Ultimate penalty: IP range ban (temporary, 30 days)
```

---

## 4. Security Properties

### 4.1 Tamper Resistance

- ✅ Cannot fake token balance (need valid signatures)
- ✅ Cannot forge transactions (cryptographic proofs)
- ✅ Cannot double-spend (nonce + gossip prevents replay)
- ✅ Cannot tamper with history (distributed ledger + Merkle trees)
- ✅ **Cannot evade debt by reinstalling (hardware fingerprinting)**

### 4.2 Fault Tolerance

- ✅ Survives up to 33% malicious nodes (with reputation system)
- ✅ No single point of failure (fully distributed)
- ✅ Self-healing (automatic ledger reconciliation)
- ✅ **Debt persistence across node restarts/reinstalls**

### 4.3 Attack Cost

- High: Must acquire real hardware, build reputation, risk slashing
- Time: Minimum weeks to gain trust for meaningful attack
- Detection: Multiple layers of fraud detection
- **Debt Evasion: Requires new hardware purchase (expensive)**

### 4.4 Privacy Trade-offs

- ⚖️ Hardware fingerprinting required for debt enforcement
- ⚖️ Minimal data collected (only hashed hardware IDs)
- ⚖️ No centralized tracking (distributed ledger only)
- ⚖️ Users informed and opt-in during installation

---

## Related Architecture Documents

For complete technical details on specific subsystems, see:

- **[PROOF_SYSTEM.md](./PROOF_SYSTEM.md)** - Cryptographic Proof System Architecture
  - Complete cryptographic identity system
  - Detailed request and completion proof flows
  - Distributed ledger implementation
  - Merkle tree verification
  - Gossip protocol specifications
  - Proof-of-work bootstrap algorithm
  - Fraud detection and auditing mechanisms
  
- **[ONBOARDING_NODES.md](./ONBOARDING_NODES.md)** - Node Onboarding Architecture
  - Installation process
  - Hardware detection and model assignment
  - Initial token grant system
  - CLI and web interface
  - Auto-start configuration

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 0.2 | 2026-02-13 | Separated proof system into PROOF_SYSTEM.md |
| 0.1 | 2026-02-13 | Initial token architecture document |
