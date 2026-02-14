# OpenGateway Node Onboarding Architecture

## Overview

This document details the complete node onboarding process - from a single curl command to a fully functional node contributing to the network and ready to make inference requests.

**Vision**: One command. Zero configuration. Anyone can join the network.

---

## Table of Contents

1. [Installation Flow](#1-installation-flow)
2. [System Requirements Detection](#2-system-requirements-detection)
3. [Dependency Management](#3-dependency-management)
4. [Initial Token Credit](#4-initial-token-credit)
5. [Security Setup](#5-security-setup)
6. [System Optimization](#6-system-optimization)
7. [Web Interface](#7-web-interface)
8. [Auto-Start Configuration](#8-auto-start-configuration)

---

## 1. Installation Flow

### 1.1 One-Command Install

**User Experience**:
```bash
curl -fsSL https://get.opengateway.ai/install.sh | bash
```

**What Happens**:
```
1. Download install script
2. Detect operating system
3. Check prerequisites
4. Install OpenGateway node + client
5. Configure auto-start
6. Launch web interface
7. Display setup instructions
```

**Expected Duration**: 3-10 minutes (depending on internet speed and system)

---

### 1.2 OS Detection and Platform Support

**Supported Platforms**:
- ✅ Linux (Ubuntu, Debian, Fedora, Arch, etc.)
- ✅ macOS (Intel and Apple Silicon)
- ✅ Windows (via WSL2)

**Detection Logic**:
```bash
#!/bin/bash

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    DISTRO=$(cat /etc/os-release | grep ^ID= | cut -d'=' -f2)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    ARCH=$(uname -m)  # x86_64 or arm64
elif [[ "$OSTYPE" == "msys" || "$OSTYPE" == "win32" ]]; then
    OS="windows"
    echo "Windows detected. Installing WSL2..."
else
    echo "Unsupported OS: $OSTYPE"
    exit 1
fi
```

---

### 1.3 Windows WSL2 Handling

**Windows Installation Flow**:
```
1. Detect Windows environment
2. Check if WSL2 is installed
   - If not: Prompt user to install WSL2
   - Provide instructions + auto-install script
3. Install Ubuntu 22.04 LTS in WSL2
4. Continue installation inside WSL2 environment
5. Configure WSL2 to auto-start on boot
6. Setup port forwarding for web interface
```

**WSL2 Auto-Install**:
```powershell
# PowerShell script (elevated)
wsl --install -d Ubuntu-22.04
wsl --set-default-version 2

# Configure WSL2 memory/CPU limits
cat > %USERPROFILE%\.wslconfig << EOF
[wsl2]
memory=8GB       # Adjust based on system RAM
processors=4     # Adjust based on CPU cores
swap=2GB
EOF

# Restart WSL
wsl --shutdown
```

---

## 2. System Requirements Detection

### 2.1 Hardware Profiling

**Detection Script**:
```bash
#!/bin/bash

echo "🔍 Detecting system resources..."

# CPU Detection
CPU_CORES=$(nproc)
CPU_MODEL=$(lscpu | grep "Model name" | cut -d':' -f2 | xargs)
CPU_ARCH=$(uname -m)

# RAM Detection
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

# GPU Detection
if command -v nvidia-smi &> /dev/null; then
    GPU_COUNT=$(nvidia-smi --list-gpus | wc -l)
    GPU_MODEL=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1)
    GPU_VRAM=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -n1)
    GPU_VRAM_GB=$((GPU_VRAM / 1024))
    HAS_GPU=true
else
    HAS_GPU=false
fi

# Disk Space Detection
DISK_AVAILABLE=$(df -BG / | tail -1 | awk '{print $4}' | sed 's/G//')

echo "✅ System Profile:"
echo "   CPU: $CPU_MODEL ($CPU_CORES cores)"
echo "   RAM: ${TOTAL_RAM_GB}GB"
if [ "$HAS_GPU" = true ]; then
    echo "   GPU: $GPU_MODEL (${GPU_VRAM_GB}GB VRAM)"
else
    echo "   GPU: None detected (CPU-only mode)"
fi
echo "   Disk: ${DISK_AVAILABLE}GB available"
```

---

### 2.2 Model Capability Assessment

**Capability Matrix** (from ARCHITECT.md):

| Model Tier | Model Example | CPU | RAM | GPU VRAM | Disk |
|------------|--------------|-----|-----|----------|------|
| **Model A** | Llama 3.1 8B, Phi-3 Mini | 4+ cores | 8GB+ | Optional | 20GB+ |
| **Model B** | Mistral 7B, Gemma 7B | 4+ cores | 12GB+ | 8GB+ | 30GB+ |
| **Model C** | Llama 3.1 70B, Mixtral 8x7B | 8+ cores | 32GB+ | 24GB+ | 150GB+ |
| **Model D** | DeepSeek V3, Llama 3.1 405B | 16+ cores | 64GB+ | 48GB+ | 500GB+ |

**Assessment Logic**:
```bash
#!/bin/bash

# Determine which model clusters this node can join
SUPPORTED_MODELS=()

# Check Model A (Llama 3.1 8B)
if [ $CPU_CORES -ge 4 ] && [ $TOTAL_RAM_GB -ge 8 ] && [ $DISK_AVAILABLE -ge 20 ]; then
    SUPPORTED_MODELS+=("ModelA")
fi

# Check Model B (Mistral 7B)
if [ $CPU_CORES -ge 4 ] && [ $TOTAL_RAM_GB -ge 12 ] && [ $DISK_AVAILABLE -ge 30 ]; then
    if [ "$HAS_GPU" = true ] && [ $GPU_VRAM_GB -ge 8 ]; then
        SUPPORTED_MODELS+=("ModelB")
    fi
fi

# Check Model C (Llama 3.1 70B)
if [ $CPU_CORES -ge 8 ] && [ $TOTAL_RAM_GB -ge 32 ] && [ $DISK_AVAILABLE -ge 150 ]; then
    if [ "$HAS_GPU" = true ] && [ $GPU_VRAM_GB -ge 24 ]; then
        SUPPORTED_MODELS+=("ModelC")
    fi
fi

# Check Model D (DeepSeek V3)
if [ $CPU_CORES -ge 16 ] && [ $TOTAL_RAM_GB -ge 64 ] && [ $DISK_AVAILABLE -ge 500 ]; then
    if [ "$HAS_GPU" = true ] && [ $GPU_VRAM_GB -ge 48 ]; then
        SUPPORTED_MODELS+=("ModelD")
    fi
fi

echo "✅ This node can support: ${SUPPORTED_MODELS[*]}"

# Save to config file
cat > ~/.opengateway/node-config.yaml << EOF
node:
  supported_models: [${SUPPORTED_MODELS[*]}]
  hardware:
    cpu_cores: $CPU_CORES
    ram_gb: $TOTAL_RAM_GB
    gpu_model: "$GPU_MODEL"
    gpu_vram_gb: $GPU_VRAM_GB
    disk_available_gb: $DISK_AVAILABLE
EOF
```

---

### 2.3 Geographic Region Detection

**IP-based Geolocation**:
```bash
#!/bin/bash

# Use ipinfo.io for geolocation
GEO_DATA=$(curl -s https://ipinfo.io/json)
COUNTRY=$(echo $GEO_DATA | jq -r '.country')
REGION_NAME=$(echo $GEO_DATA | jq -r '.region')
CITY=$(echo $GEO_DATA | jq -r '.city')

# Map country to OpenGateway region
case $COUNTRY in
    CN|JP|KR|TW|HK|SG|MY|TH|PH|ID|VN|IN)
        REGION="Asia"
        ;;
    US|CA|MX)
        REGION="NorthAmerica"
        ;;
    GB|DE|FR|IT|ES|NL|SE|NO|FI|PL)
        REGION="Europe"
        ;;
    AU|NZ)
        REGION="Oceania"
        ;;
    BR|AR|CL|CO|PE)
        REGION="SouthAmerica"
        ;;
    ZA|NG|EG|KE)
        REGION="Africa"
        ;;
    AE|SA|IL|TR)
        REGION="MiddleEast"
        ;;
    *)
        REGION="Unknown"
        ;;
esac

echo "📍 Geographic Region: $REGION ($COUNTRY, $CITY)"

# Save to config
echo "region: $REGION" >> ~/.opengateway/node-config.yaml
```

---

## 3. Dependency Management

### 3.1 Core Dependencies

**Required Software**:
1. **Python 3.10+** - Runtime for node software
2. **EXO** - Distributed inference framework
3. **Docker** (optional) - For containerized model weights
4. **CUDA Toolkit** (if GPU) - For GPU acceleration
5. **Node.js 18+** - For web interface
6. **nginx** - Reverse proxy for web interface

---

### 3.2 Automated Installation

**Linux (Ubuntu/Debian)**:
```bash
#!/bin/bash

echo "📦 Installing dependencies..."

# Update package list
sudo apt-get update

# Install Python 3.10+
sudo apt-get install -y python3.10 python3-pip python3-venv

# Install Node.js 18+
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install nginx
sudo apt-get install -y nginx

# Install GPU drivers (if NVIDIA GPU detected)
if [ "$HAS_GPU" = true ]; then
    echo "🎮 Installing NVIDIA drivers and CUDA..."
    sudo apt-get install -y nvidia-driver-535 nvidia-cuda-toolkit
fi

# Install Docker (optional, for model weight management)
if ! command -v docker &> /dev/null; then
    echo "🐳 Installing Docker..."
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
fi

# Install EXO
echo "🚀 Installing EXO framework..."
pip3 install exo-lang

# Install OpenGateway node software
echo "🌐 Installing OpenGateway..."
pip3 install opengateway-node

echo "✅ All dependencies installed successfully!"
```

**macOS**:
```bash
#!/bin/bash

echo "📦 Installing dependencies..."

# Install Homebrew if not present
if ! command -v brew &> /dev/null; then
    echo "🍺 Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Install Python
brew install python@3.10

# Install Node.js
brew install node@18

# Install nginx
brew install nginx

# Install EXO
pip3 install exo-lang

# Install OpenGateway
pip3 install opengateway-node

echo "✅ All dependencies installed successfully!"
```

---

### 3.3 Model Weight Management

**Initial Download Strategy**:
```
Option 1: Download on-demand
- Node doesn't download any models initially
- Downloads model weights when first request comes in
- Pros: Fast initial setup
- Cons: Slow first request

Option 2: Download smallest model (RECOMMENDED)
- Download Model A (Llama 3.1 8B) during setup
- Node can start earning tokens immediately
- Download larger models in background
- Pros: Fast setup + immediate earning capability
- Cons: Still requires 20GB download

Option 3: Pre-download all supported models
- Download all models node can support
- Node ready for any request immediately
- Pros: Maximum earning potential
- Cons: Very slow setup (100GB-500GB download)
```

**Recommendation**: **Option 2** - Download smallest model, background download others

**Implementation**:
```bash
#!/bin/bash

echo "📥 Downloading model weights..."

# Download Model A (always, if supported)
if [[ " ${SUPPORTED_MODELS[@]} " =~ " ModelA " ]]; then
    echo "Downloading Model A (Llama 3.1 8B)..."
    exo-download-model llama-3.1-8b
fi

# Background download other models
for model in "${SUPPORTED_MODELS[@]}"; do
    if [ "$model" != "ModelA" ]; then
        echo "Queuing $model for background download..."
        nohup exo-download-model $model &
    fi
done

echo "✅ Initial model ready. Other models downloading in background."
```

---

## 4. Initial Token Credit

### 4.1 Free Tier Token Grant

**ChatGPT Free Tier Equivalent**:
```
ChatGPT Free (estimated):
- ~50 messages per day
- ~500 tokens per message (average)
- = 25,000 tokens per day
- = 175,000 tokens per week
- = 750,000 tokens per month

OpenGateway Initial Grant: 100,000 tokens
```

**Why 100,000 tokens?**
- Allows ~4 days of ChatGPT free tier usage
- Enough to test the system thoroughly
- Incentive to contribute compute to earn more
- Not too generous (prevents abuse)

---

### 4.2 Initial Token Distribution Mechanism

**Challenge**: How to prevent abuse of free tokens?

**Solution: Proof-of-Work Bootstrap + Time-Lock**

```bash
#!/bin/bash

echo "🎁 Generating initial token grant..."

# Step 1: Solve computational challenge
echo "Solving proof-of-work challenge (this may take 1-2 minutes)..."
CHALLENGE_RESULT=$(opengateway-pow-solve --difficulty=medium)

if [ $? -eq 0 ]; then
    echo "✅ Proof-of-work completed!"
    
    # Step 2: Register node with proof
    NODE_ID=$(opengateway-register --pow-proof="$CHALLENGE_RESULT")
    
    # Step 3: Receive initial token grant
    INITIAL_TOKENS=100000
    echo "🎉 You've received $INITIAL_TOKENS tokens!"
    
    # Step 4: Time-lock tokens (cannot transfer for 24 hours)
    echo "⏰ Tokens are time-locked for 24 hours (anti-abuse measure)"
    echo "   You can use them for inference requests immediately"
    echo "   You can transfer them after 24 hours"
    
else
    echo "❌ Proof-of-work failed. Please try again."
    exit 1
fi
```

**Token Grant Properties**:
```yaml
initial_token_grant:
  amount: 100000
  conditions:
    - proof_of_work_required: true
    - one_per_machine: true  # Tied to machine_id
    - time_lock_hours: 24    # Cannot transfer for 24h
    - no_withdrawal: true    # Cannot convert to external currency
  
  usage_allowed:
    - inference_requests: true     # ✅ Can use immediately
    - token_transfers: false       # ❌ Locked for 24h
    - reputation_staking: false    # ❌ Must earn reputation first
```

---

### 4.3 Anti-Abuse Measures for Free Tokens

**1. One Grant Per Machine**:
```python
def check_initial_grant_eligibility(machine_id):
    """Check if machine already received initial grant"""
    
    # Query distributed ledger
    grant_record = ledger.query({
        "type": "initial_token_grant",
        "machine_id": machine_id
    })
    
    if grant_record:
        return False, "This machine already received initial token grant"
    
    return True, "Eligible for initial grant"
```

**2. Proof-of-Work Requirement**:
```python
def generate_pow_challenge(machine_id, difficulty="medium"):
    """Generate proof-of-work challenge"""
    
    challenge = {
        "machine_id": machine_id,
        "timestamp": int(time.time()),
        "difficulty": difficulty,
        "target": calculate_target(difficulty)
    }
    
    # Node must find nonce such that:
    # hash(machine_id + timestamp + nonce) < target
    
    return challenge

def verify_pow_solution(challenge, nonce):
    """Verify proof-of-work solution"""
    
    hash_input = f"{challenge['machine_id']}{challenge['timestamp']}{nonce}"
    hash_result = hashlib.sha256(hash_input.encode()).hexdigest()
    
    return int(hash_result, 16) < challenge['target']
```

**3. Time-Lock on Transfers**:
```python
def can_transfer_tokens(user_id, amount):
    """Check if user can transfer tokens"""
    
    # Get initial grant timestamp
    grant_time = ledger.get_initial_grant_time(user_id)
    current_time = int(time.time())
    
    # Check if 24 hours have passed
    if current_time - grant_time < 86400:  # 24 hours in seconds
        granted_tokens = 100000
        earned_tokens = ledger.get_balance(user_id) - granted_tokens
        
        # Can only transfer earned tokens, not granted tokens
        if amount > earned_tokens:
            return False, "Initial tokens are time-locked for 24 hours"
    
    return True, "Transfer allowed"
```

**4. Network Monitoring**:
```python
def detect_grant_abuse():
    """Monitor for suspicious grant claiming patterns"""
    
    suspicious_patterns = [
        # Multiple grants from same IP range
        "same_ip_range_multiple_grants",
        
        # Rapid sequential grant claims
        "rapid_sequential_claims",
        
        # Similar hardware profiles
        "similar_hardware_fingerprints",
        
        # VM/cloud detection
        "cloud_provider_ip_range"
    ]
    
    for pattern in suspicious_patterns:
        if detect_pattern(pattern):
            flag_for_manual_review()
```

---

## 5. Security Setup

### 5.1 Cryptographic Key Generation

**Automatic Key Generation**:
```python
def initialize_node_security():
    """Generate cryptographic keys for node identity"""
    
    print("🔐 Generating cryptographic keys...")
    
    # Generate ED25519 key pair
    from cryptography.hazmat.primitives.asymmetric import ed25519
    
    private_key = ed25519.Ed25519PrivateKey.generate()
    public_key = private_key.public_key()
    
    # Save private key (encrypted)
    save_encrypted_key(private_key, password=ask_user_password())
    
    # Derive node ID from public key
    node_id = hashlib.sha256(
        public_key.public_bytes(
            encoding=serialization.Encoding.Raw,
            format=serialization.PublicFormat.Raw
        )
    ).hexdigest()
    
    print(f"✅ Node ID: {node_id}")
    print(f"   Public Key: {public_key.hex()[:16]}...")
    
    return node_id, private_key, public_key
```

---

### 5.2 Machine Identity (Hardware Fingerprinting)

**From TOKEN_ARCHITECTURE.md**:
```python
def calculate_machine_id():
    """Calculate hardware-bound machine identity"""
    
    components = []
    
    # CPU ID
    cpu_id = get_cpu_serial()
    components.append(cpu_id)
    
    # Motherboard UUID
    mb_uuid = get_motherboard_uuid()
    components.append(mb_uuid)
    
    # Primary MAC address
    mac = get_primary_mac_address()
    components.append(mac)
    
    # Boot disk serial
    disk_serial = get_boot_disk_serial()
    components.append(disk_serial)
    
    # System UUID
    system_uuid = platform.node()
    components.append(system_uuid)
    
    # Combine and hash
    combined = "|".join(sorted(components))
    machine_id = hashlib.sha256(combined.encode()).hexdigest()
    
    print(f"🖥️  Machine ID: {machine_id[:16]}...")
    
    return machine_id
```

---

### 5.3 Firewall and Network Security

**Automatic Firewall Configuration**:
```bash
#!/bin/bash

echo "🔥 Configuring firewall..."

# Allow OpenGateway P2P port (default: 8333)
sudo ufw allow 8333/tcp comment "OpenGateway P2P"

# Allow web interface port (default: 3000)
sudo ufw allow 3000/tcp comment "OpenGateway Web Interface"

# Enable firewall if not already enabled
sudo ufw --force enable

echo "✅ Firewall configured"
```

---

### 5.4 Secure Storage

**Configuration and Key Storage**:
```bash
# Create secure config directory
mkdir -p ~/.opengateway
chmod 700 ~/.opengateway

# Create secure key storage
mkdir -p ~/.opengateway/keys
chmod 600 ~/.opengateway/keys

# Store encrypted private key
opengateway-keygen --output ~/.opengateway/keys/private.key

# Set restrictive permissions
chmod 400 ~/.opengateway/keys/private.key
```

---

## 6. System Optimization

### 6.1 Performance Tuning

**GPU Optimization** (NVIDIA):
```bash
#!/bin/bash

if [ "$HAS_GPU" = true ]; then
    echo "🎮 Optimizing GPU settings..."
    
    # Set GPU persistence mode (keeps driver loaded)
    sudo nvidia-smi -pm 1
    
    # Set power limit to maximum
    MAX_POWER=$(nvidia-smi --query-gpu=power.max_limit --format=csv,noheader,nounits | head -n1)
    sudo nvidia-smi -pl $MAX_POWER
    
    # Set compute mode to exclusive process
    sudo nvidia-smi -c 3
    
    echo "✅ GPU optimized for inference workloads"
fi
```

**CPU Optimization**:
```bash
#!/bin/bash

echo "⚙️  Optimizing CPU settings..."

# Set CPU governor to performance
for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
    echo performance | sudo tee $cpu
done

# Disable CPU sleep states (for maximum performance)
sudo cpupower idle-set -D 0

echo "✅ CPU optimized for maximum performance"
```

**Memory Optimization**:
```bash
#!/bin/bash

echo "💾 Optimizing memory settings..."

# Increase shared memory for model loading
echo "kernel.shmmax = 17179869184" | sudo tee -a /etc/sysctl.conf
echo "kernel.shmall = 4194304" | sudo tee -a /etc/sysctl.conf

# Optimize swap usage
echo "vm.swappiness = 10" | sudo tee -a /etc/sysctl.conf

# Apply settings
sudo sysctl -p

echo "✅ Memory settings optimized"
```

---

### 6.2 Safety Mechanisms

**Temperature Monitoring**:
```python
def monitor_hardware_safety():
    """Monitor hardware temperatures and throttle if needed"""
    
    while True:
        # Check GPU temperature
        if has_gpu():
            gpu_temp = get_gpu_temperature()
            if gpu_temp > 85:  # Critical temperature
                print(f"⚠️  GPU temperature high: {gpu_temp}°C")
                throttle_gpu_workload(0.5)  # Reduce to 50% capacity
            elif gpu_temp > 80:  # Warning temperature
                print(f"⚠️  GPU temperature elevated: {gpu_temp}°C")
                throttle_gpu_workload(0.75)  # Reduce to 75% capacity
        
        # Check CPU temperature
        cpu_temp = get_cpu_temperature()
        if cpu_temp > 90:  # Critical temperature
            print(f"⚠️  CPU temperature high: {cpu_temp}°C")
            throttle_cpu_workload(0.5)
        
        time.sleep(10)  # Check every 10 seconds
```

**Power Limit Safety**:
```python
def configure_safe_power_limits():
    """Set safe power limits to prevent hardware damage"""
    
    if has_gpu():
        # Set to 90% of maximum to prevent overheating
        max_power = get_max_gpu_power()
        safe_power = int(max_power * 0.9)
        
        os.system(f"nvidia-smi -pl {safe_power}")
        print(f"🔋 GPU power limit set to {safe_power}W (safe mode)")
```

---

## 7. Web Interface

### 7.1 Dashboard Features

**Main Dashboard**:
```
┌─────────────────────────────────────────────────────────┐
│  OpenGateway Node Dashboard                             │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  📊 Status: ● Online | Region: Asia | Models: A, B, C   │
│                                                           │
│  💰 Token Balance: 105,234 tokens                        │
│     ├─ Earned: 5,234 tokens                             │
│     └─ Initial Grant: 100,000 tokens                    │
│                                                           │
│  🖥️  Hardware:                                           │
│     ├─ CPU: AMD Ryzen 9 5950X (16 cores) - 45% usage   │
│     ├─ RAM: 64GB - 28GB used                            │
│     ├─ GPU: NVIDIA RTX 4090 (24GB) - 65% usage         │
│     └─ Temp: GPU 72°C, CPU 58°C                        │
│                                                           │
│  📈 Contribution Stats (Last 24h):                       │
│     ├─ Requests Processed: 143                          │
│     ├─ Tokens Earned: 5,234                             │
│     ├─ Uptime: 23h 47m                                  │
│     └─ Reputation: 287 / 1000                           │
│                                                           │
│  🌐 Network:                                             │
│     ├─ Connected Peers: 47                              │
│     ├─ Active Clusters: Asia-ModelA, Asia-ModelB        │
│     └─ Network Latency: 23ms                            │
│                                                           │
└─────────────────────────────────────────────────────────┘

[Start Contributing] [Make Request] [Settings] [Logs]
```

---

### 7.2 LLM Interaction Interface

**Chat Interface**:
```
┌─────────────────────────────────────────────────────────┐
│  💬 OpenGateway Chat                                     │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  Model: [Llama 3.1 70B ▼]  Cost: ~500 tokens/response  │
│                                                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │ You: Explain quantum computing in simple terms    │  │
│  │                                                     │  │
│  │ 🤖 Assistant: Quantum computing is a type of...   │  │
│  │ [Full response here]                               │  │
│  │                                                     │  │
│  │ Cost: 1,247 tokens | Time: 3.2s                   │  │
│  └───────────────────────────────────────────────────┘  │
│                                                           │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Type your message...                               │  │
│  └───────────────────────────────────────────────────┘  │
│                                                           │
│  [Send] [Clear]  Balance: 103,987 tokens remaining     │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

---

### 7.3 Configuration Interface

**Node Settings**:
```
┌─────────────────────────────────────────────────────────┐
│  ⚙️  Node Configuration                                  │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  General Settings:                                        │
│  ├─ Node Name: [My Gaming PC]                           │
│  ├─ Auto-start on boot: [✓]                             │
│  └─ Enable web interface: [✓] Port: [3000]              │
│                                                           │
│  Contribution Settings:                                   │
│  ├─ Enable contribution: [✓]                             │
│  ├─ Max CPU usage: [●────────] 80%                      │
│  ├─ Max GPU usage: [●────────] 90%                      │
│  └─ Contribute when idle only: [ ]                      │
│                                                           │
│  Token Transfer:                                          │
│  ├─ Auto-transfer tokens: [ ]                           │
│  ├─ Target node ID: [________________]                  │
│  └─ Transfer trigger: [Threshold ▼] [10000] tokens     │
│                                                           │
│  Performance:                                             │
│  ├─ GPU optimization: [✓] Enabled                       │
│  ├─ CPU optimization: [✓] Enabled                       │
│  ├─ Thermal throttling: [✓] at 85°C                    │
│  └─ Power limit: [●────────] 90% of max                │
│                                                           │
│  [Save Changes] [Reset to Defaults]                     │
│                                                           │
└─────────────────────────────────────────────────────────┘
```

---

### 7.4 Technology Stack

**Frontend**:
- React 18 + TypeScript
- Tailwind CSS for styling
- Recharts for graphs
- WebSocket for real-time updates

**Backend**:
- Node.js + Express
- WebSocket server for real-time data
- REST API for configuration

**Port Configuration**:
- Web Interface: `http://localhost:3000`
- API: `http://localhost:3001`
- P2P: `tcp://0.0.0.0:8333`

---

## 8. Auto-Start Configuration

### 8.1 Linux (systemd)

**Service File**: `/etc/systemd/system/opengateway.service`
```ini
[Unit]
Description=OpenGateway Node
After=network.target

[Service]
Type=simple
User=%INSTALL_USER%
WorkingDirectory=/home/%INSTALL_USER%/.opengateway
ExecStart=/usr/local/bin/opengateway-node start
Restart=always
RestartSec=10

# Environment
Environment="PATH=/usr/local/bin:/usr/bin:/bin"
Environment="NODE_ENV=production"

# Security
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
```

**Installation**:
```bash
# Copy service file
sudo cp opengateway.service /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable service
sudo systemctl enable opengateway

# Start service
sudo systemctl start opengateway

# Check status
sudo systemctl status opengateway
```

---

### 8.2 macOS (launchd)

**Plist File**: `~/Library/LaunchAgents/ai.opengateway.node.plist`
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" 
    "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>ai.opengateway.node</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/opengateway-node</string>
        <string>start</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <true/>
    
    <key>StandardOutPath</key>
    <string>/tmp/opengateway.log</string>
    
    <key>StandardErrorPath</key>
    <string>/tmp/opengateway.error.log</string>
</dict>
</plist>
```

**Installation**:
```bash
# Copy plist file
cp ai.opengateway.node.plist ~/Library/LaunchAgents/

# Load service
launchctl load ~/Library/LaunchAgents/ai.opengateway.node.plist

# Enable service
launchctl enable gui/$(id -u)/ai.opengateway.node
```

---

### 8.3 Windows (WSL2)

**WSL Auto-Start**:

Create: `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\OpenGateway.bat`
```batch
@echo off
wsl -d Ubuntu-22.04 -u %USERNAME% -- /usr/local/bin/opengateway-node start
```

**Or use Windows Task Scheduler**:
```powershell
# Create scheduled task
$action = New-ScheduledTaskAction -Execute "wsl.exe" -Argument "-d Ubuntu-22.04 -- /usr/local/bin/opengateway-node start"
$trigger = New-ScheduledTaskTrigger -AtLogon
$principal = New-ScheduledTaskPrincipal -UserId "$env:USERNAME" -LogonType Interactive
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries

Register-ScheduledTask -TaskName "OpenGateway Node" -Action $action -Trigger $trigger -Principal $principal -Settings $settings
```

---

## 9. Complete Installation Flow

### 9.1 End-to-End Script

**Full Installation** (`install.sh`):
```bash
#!/bin/bash

set -e  # Exit on error

echo "🌐 OpenGateway Node Installer"
echo "================================"
echo ""

# 1. Detect OS
detect_os

# 2. Check prerequisites
check_prerequisites

# 3. Install dependencies
install_dependencies

# 4. Detect hardware
detect_hardware_capabilities

# 5. Determine supported models
assess_model_capabilities

# 6. Detect geographic region
detect_region

# 7. Generate cryptographic keys
generate_node_identity

# 8. Calculate machine ID
calculate_machine_identity

# 9. Configure security
setup_security

# 10. Optimize system
optimize_system

# 11. Claim initial token grant
claim_initial_tokens

# 12. Download initial model
download_initial_model

# 13. Configure auto-start
configure_autostart

# 14. Start web interface
start_web_interface

# 15. Display success message
echo ""
echo "✅ OpenGateway node installed successfully!"
echo ""
echo "🌐 Web Interface: http://localhost:3000"
echo "💰 Token Balance: 100,000 tokens"
echo "🖥️  Supported Models: ${SUPPORTED_MODELS[*]}"
echo "📍 Region: $REGION"
echo ""
echo "Next steps:"
echo "1. Open http://localhost:3000 in your browser"
echo "2. Complete the setup wizard"
echo "3. Start contributing and earning tokens!"
echo ""
```

---

## 9. Command Line Interface (CLI)

### 9.1 CLI Installation

**Automatic Installation**:
```bash
# CLI is installed automatically with the node
# Binary location: /usr/local/bin/opengateway

# Verify installation
opengateway --version
# Output: OpenGateway CLI v1.0.0

# Check available commands
opengateway --help
```

**Manual Installation** (if needed):
```bash
# Install via package manager
sudo npm install -g @opengateway/cli

# Or download binary directly
curl -fsSL https://get.opengateway.ai/cli/install.sh | bash
```

**Shell Completion** (optional):
```bash
# Bash
opengateway completion bash > /etc/bash_completion.d/opengateway

# Zsh
opengateway completion zsh > ~/.zsh/completion/_opengateway

# Fish
opengateway completion fish > ~/.config/fish/completions/opengateway.fish
```

---

### 9.2 CLI Command Structure

**General Format**:
```bash
opengateway [command] [subcommand] [options]
```

**Global Options**:
```bash
--config PATH       Path to config file (default: ~/.opengateway/config.yaml)
--json              Output in JSON format
--verbose, -v       Verbose output
--quiet, -q         Quiet output (errors only)
--help, -h          Show help
--version           Show version
```

---

### 9.3 Core CLI Commands

#### 9.3.1 Node Management

**Start/Stop Node**:
```bash
# Start node
opengateway node start

# Start with custom config
opengateway node start --config /path/to/config.yaml

# Stop node
opengateway node stop

# Restart node
opengateway node restart

# Check node status
opengateway node status
# Output:
# Status: ● Running
# Uptime: 2d 5h 23m
# Region: Asia
# Models: ModelA, ModelB, ModelC
# Peers: 47 connected
```

**Node Information**:
```bash
# Show node details
opengateway node info

# Output:
# Node ID: 7a3f2e1b8c9d...
# Region: Asia (Philippines, Manila)
# Supported Models: ModelA, ModelB, ModelC
# Hardware:
#   CPU: AMD Ryzen 9 5950X (16 cores)
#   RAM: 64GB
#   GPU: NVIDIA RTX 4090 (24GB VRAM)
# Network:
#   Connected Peers: 47
#   Latency: 23ms
```

**Node Logs**:
```bash
# View logs
opengateway node logs

# Follow logs (like tail -f)
opengateway node logs --follow

# Show last N lines
opengateway node logs --lines 100

# Filter by level
opengateway node logs --level error
```

---

#### 9.3.2 Wallet Management

**Check Balance**:
```bash
# Show current balance
opengateway wallet balance

# Output:
# Token Balance: 105,234 tokens
#   Earned: 5,234 tokens
#   Initial Grant: 100,000 tokens
#   Available: 105,234 tokens

# JSON output
opengateway wallet balance --json
# {"balance": 105234, "earned": 5234, "initial_grant": 100000}
```

**Transaction History**:
```bash
# Show recent transactions
opengateway wallet history

# Show last N transactions
opengateway wallet history --limit 50

# Filter by type
opengateway wallet history --type earned
opengateway wallet history --type spent
opengateway wallet history --type transfer

# Output:
# Date                  Type      Amount      Balance     Description
# 2026-02-13 14:32:15  earned    +2,500      105,234     Processed request req_abc123
# 2026-02-13 14:15:08  spent     -1,200      102,734     Inference request
# 2026-02-13 13:45:22  earned    +3,100      103,934     Processed request req_def456
```

**Transfer Tokens**:
```bash
# Transfer tokens to another node
opengateway wallet transfer \
  --to <target_node_id> \
  --amount 5000 \
  --memo "Optional message"

# Confirm transfer
# Transfer 5,000 tokens to node 9f2e3a1b...?
# Current balance: 105,234 tokens
# New balance: 100,234 tokens
# Confirm? (y/n): y
# ✅ Transfer successful! Transaction ID: tx_abc123

# Transfer all available balance
opengateway wallet transfer \
  --to <target_node_id> \
  --all
```

**Configure Auto-Transfer**:
```bash
# Enable auto-transfer
opengateway wallet auto-transfer enable \
  --target <node_id> \
  --trigger on_receipt

# Configure with threshold
opengateway wallet auto-transfer enable \
  --target <node_id> \
  --trigger threshold \
  --threshold 10000

# Configure scheduled transfer
opengateway wallet auto-transfer enable \
  --target <node_id> \
  --trigger scheduled \
  --interval 24h

# Disable auto-transfer
opengateway wallet auto-transfer disable

# Check auto-transfer status
opengateway wallet auto-transfer status
```

---

#### 9.3.3 Inference Requests

**Make Inference Request**:
```bash
# Simple prompt
opengateway infer "Explain quantum computing"

# Specify model
opengateway infer "Explain quantum computing" --model llama-3.1-70b

# Stream output (default)
opengateway infer "Write a story" --stream

# No streaming (wait for complete response)
opengateway infer "What is 2+2?" --no-stream

# Output:
# 🤖 Model: Llama 3.1 70B
# 💰 Estimated cost: ~500 tokens
# 
# [Response streams here...]
# 
# ✅ Complete
# Cost: 1,247 tokens
# Time: 3.2s
# Balance: 103,987 tokens
```

**Interactive Chat Mode**:
```bash
# Start interactive chat
opengateway chat

# Start with specific model
opengateway chat --model llama-3.1-70b

# Interactive session:
# 💬 OpenGateway Chat (Llama 3.1 70B)
# Type 'exit' to quit, 'clear' to reset conversation
# 
# You: Hello!
# 🤖: Hello! How can I help you today?
# 
# You: What's the weather like?
# 🤖: I don't have access to real-time weather data...
# 
# You: exit
# Session ended. Total cost: 2,450 tokens
```

**Batch Inference**:
```bash
# Process multiple prompts from file
opengateway infer --batch prompts.txt --output results.json

# prompts.txt format:
# Explain quantum computing
# What is machine learning?
# How does blockchain work?
```

---

#### 9.3.4 Configuration Management

**View Configuration**:
```bash
# Show current configuration
opengateway config show

# Show specific setting
opengateway config get node.name
# Output: My Gaming PC

# Show in JSON
opengateway config show --json
```

**Update Configuration**:
```bash
# Set configuration value
opengateway config set node.name "My New Node Name"

# Set contribution limits
opengateway config set contribution.max_cpu_usage 80
opengateway config set contribution.max_gpu_usage 90

# Enable/disable features
opengateway config set contribution.enabled true
opengateway config set web_interface.enabled true

# Set multiple values at once
opengateway config set \
  node.name="Production Node" \
  contribution.max_cpu_usage=75 \
  contribution.max_gpu_usage=85
```

**Configuration File Location**:
```bash
# Default location
~/.opengateway/config.yaml

# Specify custom location
opengateway --config /path/to/custom-config.yaml node start
```

**Export/Import Configuration**:
```bash
# Export configuration
opengateway config export > my-config.yaml

# Import configuration
opengateway config import my-config.yaml

# Validate configuration file
opengateway config validate my-config.yaml
```

---

#### 9.3.5 Network Commands

**Network Status**:
```bash
# Show network status
opengateway network status

# Output:
# Status: Connected
# Region: Asia
# Connected Peers: 47
# Active Clusters: Asia-ModelA, Asia-ModelB, Asia-ModelC
# Network Latency: 23ms (average)
# Uptime: 99.8%
```

**Peer Management**:
```bash
# List connected peers
opengateway network peers

# Output:
# Peer ID          Region  Models      Latency  Reputation
# 9f2e3a1b...      Asia    A,B,C       18ms     650
# 4c7d8e2f...      Asia    A,B         25ms     820
# 1a5b9c3d...      Asia    A,B,C,D     31ms     920

# Show detailed peer info
opengateway network peer <peer_id>

# Connect to specific peer (if not auto-discovered)
opengateway network connect <peer_id>

# Disconnect from peer
opengateway network disconnect <peer_id>
```

**Cluster Information**:
```bash
# List joined clusters
opengateway network clusters

# Output:
# Cluster         Nodes   Status    Your Role
# Asia-ModelA     243     Active    Contributor
# Asia-ModelB     156     Active    Contributor
# Asia-ModelC     89      Active    Contributor

# Show cluster details
opengateway network cluster Asia-ModelC

# Leave cluster
opengateway network cluster leave Asia-ModelB

# Join cluster (if eligible)
opengateway network cluster join Asia-ModelD
```

---

#### 9.3.6 Statistics and Monitoring

**Show Statistics**:
```bash
# Overall stats
opengateway stats

# Output:
# === Contribution Stats (Last 24h) ===
# Requests Processed: 143
# Tokens Earned: 5,234
# Uptime: 23h 47m
# 
# === Hardware Usage ===
# CPU: 45% (avg)
# RAM: 28GB / 64GB (43%)
# GPU: 65% (avg)
# GPU Temp: 72°C (current)
# CPU Temp: 58°C (current)
# 
# === Reputation ===
# Current Score: 287 / 1000
# Tier: New Node
# Audit Pass Rate: 100%

# Stats for specific time period
opengateway stats --period 7d    # Last 7 days
opengateway stats --period 30d   # Last 30 days
opengateway stats --period all   # All time

# Export stats to file
opengateway stats --export stats.json
```

**Real-time Monitoring**:
```bash
# Monitor in real-time (like htop)
opengateway monitor

# Output (updates every second):
# ╔════════════════════════════════════════════════╗
# ║  OpenGateway Node Monitor                      ║
# ╠════════════════════════════════════════════════╣
# ║  Status: ● Running                             ║
# ║  Uptime: 2d 5h 23m                            ║
# ╠════════════════════════════════════════════════╣
# ║  Hardware:                                     ║
# ║    CPU: [████████░░░░░░░░] 45%  58°C         ║
# ║    RAM: [██████░░░░░░░░░░] 43%  28GB/64GB    ║
# ║    GPU: [█████████░░░░░░░] 65%  72°C         ║
# ╠════════════════════════════════════════════════╣
# ║  Network:                                      ║
# ║    Peers: 47                                   ║
# ║    Requests: 143 (last 24h)                   ║
# ╠════════════════════════════════════════════════╣
# ║  Tokens:                                       ║
# ║    Balance: 105,234                           ║
# ║    Earned: +5,234 (last 24h)                  ║
# ╚════════════════════════════════════════════════╝
# 
# Press 'q' to quit
```

---

#### 9.3.7 Model Management

**List Models**:
```bash
# List available models
opengateway models list

# Output:
# Model              Status        Size    Downloaded
# Llama 3.1 8B       ✅ Ready      20GB    Yes
# Mistral 7B         ✅ Ready      30GB    Yes
# Llama 3.1 70B      ✅ Ready      150GB   Yes
# DeepSeek V3        ⏳ Downloading 500GB   45% (225GB)

# List only downloaded models
opengateway models list --downloaded

# List only supported models (based on hardware)
opengateway models list --supported
```

**Download Models**:
```bash
# Download specific model
opengateway models download llama-3.1-70b

# Download all supported models
opengateway models download --all

# Check download progress
opengateway models download status
```

**Model Information**:
```bash
# Show model details
opengateway models info llama-3.1-70b

# Output:
# Model: Llama 3.1 70B
# Size: 150GB
# Parameters: 70 billion
# Context Length: 128k tokens
# Status: ✅ Ready
# Location: ~/.opengateway/models/llama-3.1-70b
# Cluster: Asia-ModelC
```

---

#### 9.3.8 Security and Identity

**Show Identity**:
```bash
# Show node identity
opengateway identity show

# Output:
# Node ID: 7a3f2e1b8c9d4f5a...
# Public Key: 0x9f2e3a1b4c7d8e...
# Machine ID: b4c8d2f9e1a7... (hashed)
# Created: 2026-02-13 10:15:30
# Last Key Rotation: Never
```

**Key Rotation**:
```bash
# Rotate cryptographic keys
opengateway identity rotate-keys

# Confirm rotation:
# ⚠️  This will generate new cryptographic keys
# Your old keys will be linked to new keys via chain of custody
# Token balance and reputation will be preserved
# Continue? (y/n): y
# 
# 🔐 Generating new keys...
# ✅ Keys rotated successfully!
# New Node ID: 4c7d8e2f1a5b...
```

**Export Identity** (for backup):
```bash
# Export encrypted identity
opengateway identity export --output identity-backup.enc

# ⚠️  Enter passphrase to encrypt backup:
# [passphrase input]
# ✅ Identity exported to identity-backup.enc
# 
# ⚠️  IMPORTANT: Store this file securely!
# It contains your private keys and can be used to restore your node.

# Import identity (on new machine)
opengateway identity import identity-backup.enc

# Enter passphrase:
# [passphrase input]
# ✅ Identity restored
```

---

#### 9.3.9 Maintenance Commands

**Update Node Software**:
```bash
# Check for updates
opengateway update check

# Output:
# Current version: 1.0.0
# Latest version: 1.1.0
# 
# Changelog:
# - Added cross-region transfers
# - Improved GPU optimization
# - Bug fixes and performance improvements

# Update to latest version
opengateway update install

# Update to specific version
opengateway update install --version 1.1.0
```

**Health Check**:
```bash
# Run health check
opengateway health check

# Output:
# ✅ Node service: Running
# ✅ Web interface: Accessible
# ✅ Network connectivity: Connected (47 peers)
# ✅ Models: 3 ready, 1 downloading
# ✅ Token balance: Positive (105,234)
# ✅ Hardware: Normal temperatures
# ⚠️  Disk space: 45GB remaining (consider cleanup)
# 
# Overall: Healthy (1 warning)

# Auto-fix common issues
opengateway health fix
```

**Database Management**:
```bash
# Show database info
opengateway db info

# Output:
# Ledger Size: 245MB
# Transactions: 15,432
# Last Sync: 2 seconds ago
# Merkle Root: 0x8f3d2e1c...

# Verify database integrity
opengateway db verify

# Compact database (if large)
opengateway db compact

# Clear cache
opengateway cache clear
```

---

### 9.4 CLI Configuration File

**Config File Location**: `~/.opengateway/config.yaml`

**Example Configuration**:
```yaml
# Node Configuration
node:
  name: "My Gaming PC"
  region: "Asia"
  auto_start: true
  supported_models:
    - ModelA
    - ModelB
    - ModelC

# Network Configuration
# Bootstrap nodes: initial entry points for P2P discovery. See DISCOVERY.md for design and options.
network:
  p2p_port: 8333
  max_peers: 50
  enable_upnp: true
  bootstrap_nodes:
    - "bootstrap1.opengateway.ai:8333"
    - "bootstrap2.opengateway.ai:8333"

# Contribution Settings
contribution:
  enabled: true
  max_cpu_usage: 80  # percent
  max_gpu_usage: 90  # percent
  idle_only: false
  temperature_limit:
    gpu: 85  # celsius
    cpu: 90  # celsius

# Web Interface
web_interface:
  enabled: true
  port: 3000
  api_port: 3001
  enable_auth: false  # Set to true for password protection
  # password: "hashed_password"

# Token Transfer
token_transfer:
  enabled: false
  auto_transfer: false
  target_node_id: ""
  trigger:
    type: "on_receipt"  # on_receipt | threshold | scheduled
    threshold: 10000
    interval: "24h"
  minimum_balance: 0

# Performance
performance:
  gpu_optimization: true
  cpu_optimization: true
  power_limit_percentage: 90

# Security
security:
  enable_firewall: true
  allowed_ips: []  # Empty = allow all
  rate_limiting:
    enabled: true
    max_requests_per_hour: 1000

# Logging
logging:
  level: "info"  # debug | info | warn | error
  file: "~/.opengateway/logs/node.log"
  max_size: "100MB"
  max_age: 30  # days
```

---

### 9.5 CLI Automation and Scripting

**Batch Operations**:
```bash
#!/bin/bash

# Script: daily-stats.sh
# Report daily statistics

echo "=== OpenGateway Daily Report ==="
echo ""

# Get balance
BALANCE=$(opengateway wallet balance --json | jq -r '.balance')
echo "Token Balance: $BALANCE"

# Get stats
STATS=$(opengateway stats --period 24h --json)
EARNED=$(echo $STATS | jq -r '.tokens_earned')
REQUESTS=$(echo $STATS | jq -r '.requests_processed')

echo "Tokens Earned (24h): $EARNED"
echo "Requests Processed (24h): $REQUESTS"

# Get node status
STATUS=$(opengateway node status --json)
UPTIME=$(echo $STATUS | jq -r '.uptime')
PEERS=$(echo $STATUS | jq -r '.peers')

echo "Uptime: $UPTIME"
echo "Connected Peers: $PEERS"

echo ""
echo "=== End of Report ==="
```

**Monitoring Script**:
```bash
#!/bin/bash

# Script: monitor-health.sh
# Monitor node health and alert on issues

while true; do
    # Check health
    HEALTH=$(opengateway health check --json)
    STATUS=$(echo $HEALTH | jq -r '.overall')
    
    if [ "$STATUS" != "healthy" ]; then
        # Send alert (e.g., email, slack, etc.)
        echo "ALERT: Node health is $STATUS"
        
        # Try to auto-fix
        opengateway health fix
    fi
    
    # Check every 5 minutes
    sleep 300
done
```

**Auto-Backup Script**:
```bash
#!/bin/bash

# Script: backup-identity.sh
# Automatically backup node identity

BACKUP_DIR="$HOME/opengateway-backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/identity-$TIMESTAMP.enc"

mkdir -p $BACKUP_DIR

# Export identity
echo "Creating backup..."
opengateway identity export --output "$BACKUP_FILE" --passphrase-file ~/.opengateway/.backup-passphrase

if [ $? -eq 0 ]; then
    echo "✅ Backup created: $BACKUP_FILE"
    
    # Clean up old backups (keep last 7 days)
    find $BACKUP_DIR -name "identity-*.enc" -mtime +7 -delete
else
    echo "❌ Backup failed!"
    exit 1
fi
```

---

### 9.6 CLI vs Web Interface Comparison

| Feature | CLI | Web Interface |
|---------|-----|---------------|
| **Installation** | Automatic | Automatic |
| **Node Management** | ✅ Full control | ✅ Full control |
| **Wallet Operations** | ✅ All operations | ✅ All operations |
| **Inference Requests** | ✅ Text-based | ✅ Chat UI |
| **Configuration** | ✅ YAML editing | ✅ Form-based |
| **Monitoring** | ✅ Real-time TUI | ✅ Dashboard |
| **Statistics** | ✅ JSON export | ✅ Charts/graphs |
| **Automation** | ✅ Scriptable | ❌ Limited |
| **Remote Access** | ✅ SSH | ✅ Web browser |
| **Accessibility** | ✅ Terminal | ✅ Visual |
| **Learning Curve** | Higher | Lower |
| **Power User** | ✅ Preferred | Optional |

**When to Use CLI**:
- ✅ Server/headless deployments
- ✅ Automation and scripting
- ✅ Remote SSH access
- ✅ Batch operations
- ✅ CI/CD integration
- ✅ Power users

**When to Use Web Interface**:
- ✅ First-time setup
- ✅ Visual monitoring
- ✅ Interactive chat
- ✅ Casual users
- ✅ Configuration with validation
- ✅ Graph/chart visualization

---

### 9.7 CLI Quick Reference

**Most Common Commands**:
```bash
# Start/Stop
opengateway node start
opengateway node stop
opengateway node status

# Wallet
opengateway wallet balance
opengateway wallet history
opengateway wallet transfer --to <node_id> --amount 5000

# Inference
opengateway infer "Your prompt here"
opengateway chat

# Configuration
opengateway config show
opengateway config set node.name "New Name"

# Monitoring
opengateway stats
opengateway monitor
opengateway node logs --follow

# Network
opengateway network status
opengateway network peers

# Maintenance
opengateway update check
opengateway health check
```

**Useful Aliases**:
```bash
# Add to ~/.bashrc or ~/.zshrc

alias og='opengateway'
alias ogstart='opengateway node start'
alias ogstop='opengateway node stop'
alias ogstatus='opengateway node status'
alias ogbalance='opengateway wallet balance'
alias oginfer='opengateway infer'
alias oglogs='opengateway node logs --follow'
alias ogstats='opengateway stats'
```

---

## 10. Post-Installation

### 10.1 Setup Wizard

**First-Run Experience** (Web Interface):
```
Step 1: Welcome
  ├─ Show installation summary
  └─ Explain OpenGateway concept

Step 2: Configure Node
  ├─ Set node name
  ├─ Set contribution limits
  └─ Configure auto-transfer (if multiple nodes)

Step 3: Test Connection
  ├─ Connect to network
  ├─ Discover peers
  └─ Join model clusters

Step 4: Test Inference
  ├─ Make first inference request
  ├─ Verify token deduction
  └─ Show result

Step 5: Start Contributing
  ├─ Enable contribution mode
  ├─ Process first request
  └─ Earn first tokens

Step 6: Complete
  ├─ Show dashboard
  └─ Ready to use!
```

---

### 10.2 Verification Checklist

**Post-Install Verification**:
```bash
#!/bin/bash

echo "🔍 Verifying installation..."

# Check node is running
if systemctl is-active --quiet opengateway; then
    echo "✅ Node service is running"
else
    echo "❌ Node service is not running"
fi

# Check web interface
if curl -s http://localhost:3000 > /dev/null; then
    echo "✅ Web interface is accessible"
else
    echo "❌ Web interface is not accessible"
fi

# Check network connectivity
if opengateway-cli network status | grep -q "Connected"; then
    echo "✅ Connected to network"
else
    echo "❌ Not connected to network"
fi

# Check token balance
BALANCE=$(opengateway-cli wallet balance)
echo "💰 Token balance: $BALANCE"

# Check model availability
MODELS=$(opengateway-cli models list)
echo "🤖 Available models: $MODELS"

echo ""
echo "✅ Verification complete!"
```

---

## Revision History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | 2026-02-13 | Initial onboarding architecture |
