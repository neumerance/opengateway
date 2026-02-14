#!/usr/bin/env node
/**
 * OpenGateway POC CLI – minimum commands: status, clusters, connect, disconnect, resources, eligible, peers.
 * Usage: node cli.js <command> [args]
 *        opengateway <command> [args]  (wrapper in POC root)
 * Requires: OPENGATEWAY_POC_ROOT or ~/.opengateway-poc
 */

const fs = require('fs');
const path = require('path');
const { execSync, spawnSync } = require('child_process');

const POC_ROOT = process.env.OPENGATEWAY_POC_ROOT || path.join(process.env.HOME || process.env.USERPROFILE || '', '.opengateway-poc');
const CONFIG_PATH = path.join(POC_ROOT, 'config.json');
const STATE_PATH = path.join(POC_ROOT, 'state.json');
const RESOURCES_PATH = path.join(POC_ROOT, 'resources.json');
const REGISTRY_PATH = path.join(POC_ROOT, 'cluster-registry.json');
const PEERS_PATH = path.join(POC_ROOT, 'peers.json');

// Resource tiers: real LLM model classes. Machine must meet min CPU, RAM, GPU VRAM (GB), disk (GB).
const TIERS = [
  // Nano/small: 1–2 CPU, 1–4 GB RAM (no GPU)
  { id: 'SmolLM-360M', cpu: 1, ram: 1, gpu: 0, disk: 2 },   // 1C/1G
  { id: 'Qwen2-0.5B', cpu: 1, ram: 2, gpu: 0, disk: 3 },   // 1C/2G
  { id: 'SmolLM-1.7B', cpu: 1, ram: 4, gpu: 0, disk: 5 },  // 1C/4G
  { id: 'TinyLlama-1.1B', cpu: 2, ram: 1, gpu: 0, disk: 2 }, // 2C/1G
  { id: 'Phi-2-2.7B', cpu: 2, ram: 2, gpu: 0, disk: 3 },   // 2C/2G (quantized)
  { id: 'Llama-3.2-1.5B', cpu: 2, ram: 4, gpu: 0, disk: 5 },  // 2C/4G
  // Larger tiers
  { id: 'Llama-3.2-3B', cpu: 4, ram: 8, gpu: 0, disk: 20 },
  { id: 'Llama-3.1-8B', cpu: 4, ram: 12, gpu: 8, disk: 30 },
  { id: 'Llama-3.1-70B', cpu: 8, ram: 32, gpu: 24, disk: 150 },
  { id: 'Llama-3.1-405B', cpu: 16, ram: 64, gpu: 48, disk: 500 },
];

function readJson(p, def = null) {
  try {
    return JSON.parse(fs.readFileSync(p, 'utf8'));
  } catch {
    return def;
  }
}

function writeJson(p, obj) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, JSON.stringify(obj, null, 2) + '\n');
}

function getConfig() {
  return readJson(CONFIG_PATH, { cluster_id: '', node_name: '' });
}

function getState() {
  return readJson(STATE_PATH, { clusters: [], nodePid: null, supportedModels: [], runtime: {} });
}

function setState(update) {
  const s = getState();
  writeJson(STATE_PATH, { ...s, ...update });
}

function getResources() {
  return readJson(RESOURCES_PATH, null);
}

function getNodeRegion() {
  const config = getConfig();
  return process.env.POC_REGION || process.env.NODE_REGION || config.region || 'us-east-1';
}

function fetchClusterRegistry() {
  const config = getConfig();
  const registryUrl = process.env.CLUSTER_REGISTRY_URL || config.cluster_registry_url || '';
  if (registryUrl) {
    try {
      const out = execSync(`curl -fsSL "${registryUrl}"`, { encoding: 'utf8', maxBuffer: 1024 * 1024 });
      return JSON.parse(out);
    } catch (_) {
      return null;
    }
  }
  return readJson(REGISTRY_PATH, null);
}

function deriveClusterIdsFromRegistry(supportedModels) {
  const registry = fetchClusterRegistry();
  if (!registry || typeof registry.clusters !== 'object' || Array.isArray(registry.clusters)) return [];
  const nodeRegion = getNodeRegion();
  const regionClusters = registry.clusters[nodeRegion];
  if (!regionClusters || typeof regionClusters !== 'object' || Array.isArray(regionClusters)) return [];
  const selected = supportedModels
    .map((modelId) => regionClusters[modelId])
    .filter((id) => typeof id === 'string' && id.trim() !== '')
    .map((id) => id.trim());
  return Array.from(new Set(selected));
}

function getEligibleTierIds(resources) {
  if (!resources) return [];
  const cpu = resources.cpu_cores ?? resources.cpu ?? 0;
  const ram = resources.ram_gb ?? resources.ram ?? 0;
  const gpu = resources.gpu_vram_gb ?? resources.gpu ?? 0;
  const disk = resources.disk_gb ?? resources.disk ?? 0;
  return TIERS.filter((t) => {
    if (cpu < t.cpu || ram < t.ram || disk < t.disk) return false;
    if (t.gpu > 0 && gpu < t.gpu) return false;
    return true;
  }).map((t) => t.id);
}

function cmdGauge() {
  if (process.platform !== 'linux') {
    console.error('Gauge is Linux-only for this POC.');
    process.exit(1);
  }
  let cpu_cores = 0;
  let ram_gb = 0;
  let gpu_vram_gb = 0;
  let disk_gb = 0;

  try {
    const cpuinfo = fs.readFileSync('/proc/cpuinfo', 'utf8');
    const match = cpuinfo.match(/^processor\s*:\s*\d+/gm);
    cpu_cores = match ? match.length : 0;
  } catch (_) {}

  try {
    const meminfo = fs.readFileSync('/proc/meminfo', 'utf8');
    const m = meminfo.match(/MemTotal:\s*(\d+)\s*kB/);
    if (m) ram_gb = Math.floor(parseInt(m[1], 10) / 1024 / 1024);
  } catch (_) {}

  try {
    const out = execSync('nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits 2>/dev/null', { encoding: 'utf8', maxBuffer: 4096 });
    const values = out.trim().split(/\r?\n/).map(s => parseInt(s.trim(), 10)).filter(n => !isNaN(n));
    if (values.length) gpu_vram_gb = Math.floor(values.reduce((a, b) => a + b, 0) / 1024);
  } catch (_) {}

  try {
    const out = execSync(`df -k "${POC_ROOT}" 2>/dev/null | tail -1`, { encoding: 'utf8', maxBuffer: 2048 });
    const parts = out.trim().split(/\s+/);
    const availK = parseInt(parts[3], 10);
    if (!isNaN(availK)) disk_gb = Math.floor(availK / 1024 / 1024);
  } catch (_) {}

  const profile = { cpu_cores: cpu_cores || 1, ram_gb: ram_gb || 1, gpu_vram_gb: gpu_vram_gb, disk_gb: disk_gb || 1 };
  writeJson(RESOURCES_PATH, profile);
  console.log('Gauged:', profile);
  console.log('Wrote', RESOURCES_PATH);
}

function cmdStatus() {
  const config = getConfig();
  const state = getState();
  let nodeRunning = false;
  if (state.nodePid) {
    try {
      process.kill(state.nodePid, 0);
      nodeRunning = true;
    } catch (_) {}
  }
  console.log('POC root:    ', POC_ROOT);
  console.log('Node:        ', nodeRunning ? `running (pid ${state.nodePid})` : 'not running');
  console.log('Node name:   ', config.node_name || '(auto)');
  console.log('Clusters:    ', state.clusters.length ? state.clusters.map(c => c.id).join(', ') : 'none');
  if (state.runtime && (state.runtime.backend || state.runtime.model)) {
    console.log('Runtime:     ', `${state.runtime.backend || 'unknown'}${state.runtime.model ? ` (${state.runtime.model})` : ''}`);
  }
  if (state.supportedModels && state.supportedModels.length) {
    console.log('Models:      ', state.supportedModels.join(', '));
  }
}

function cmdClusters() {
  const state = getState();
  if (state.clusters.length === 0) {
    console.log('No clusters connected. Use: opengateway connect <cluster-id>');
    return;
  }
  state.clusters.forEach(c => console.log(c.id));
}

function cmdConnect(clusterId) {
  if (!clusterId) {
    console.error('Usage: opengateway connect <cluster-id>');
    process.exit(1);
  }
  const state = getState();
  if (state.clusters.some(c => c.id === clusterId)) {
    console.log('Already connected to', clusterId);
    return;
  }
  state.clusters.push({ id: clusterId });
  setState({ clusters: state.clusters });
  console.log('Connected to', clusterId, '. Run "opengateway start" to join the cluster.');
}

function cmdDisconnect(clusterId) {
  if (!clusterId) {
    console.error('Usage: opengateway disconnect <cluster-id>');
    process.exit(1);
  }
  const state = getState();
  const next = state.clusters.filter(c => c.id !== clusterId);
  if (next.length === state.clusters.length) {
    console.log('Not connected to', clusterId);
    return;
  }
  setState({ clusters: next });
  console.log('Disconnected from', clusterId);
}

function cmdResources() {
  const r = getResources();
  if (!r) {
    console.log('Resources not gauged. Run: opengateway gauge');
    return;
  }
  console.log('CPU cores:   ', r.cpu_cores ?? r.cpu ?? '?');
  console.log('RAM (GB):    ', r.ram_gb ?? r.ram ?? '?');
  console.log('GPU VRAM (GB):', r.gpu_vram_gb ?? r.gpu ?? '?');
  console.log('Disk (GB):   ', r.disk_gb ?? r.disk ?? '?');
}

function cmdEligible() {
  const r = getResources();
  if (!r) {
    console.log('Resources not gauged. Run: opengateway gauge');
    return;
  }
  const eligible = getEligibleTierIds(r);
  if (eligible.length === 0) {
    console.log('No clusters eligible with current resources.');
    return;
  }
  eligible.forEach((id) => console.log(id));
}

function cmdPeers(clusterId) {
  const state = getState();
  const cluster = clusterId || getConfig().cluster_id || (state.clusters[0] && state.clusters[0].id);
  if (!cluster) {
    console.log('No cluster specified. Use: opengateway peers [cluster-id]');
    return;
  }
  if (!state.clusters.some(c => c.id === cluster)) {
    console.log('Not connected to', cluster);
    return;
  }
  const peersState = readJson(PEERS_PATH, { peers: [] });
  const peers = Array.isArray(peersState.peers) ? peersState.peers : [];
  const peersInCluster = peers.filter((p) => Array.isArray(p.clusters) && p.clusters.includes(cluster));
  if (peersInCluster.length === 0) {
    console.log('No peers currently visible in', cluster);
    return;
  }
  console.log(`Peers in ${cluster} (${peersInCluster.length}):`);
  peersInCluster.forEach((p) => {
    const id = p.peer_id ? String(p.peer_id).slice(0, 16) : '?';
    const name = p.node_name ? String(p.node_name) : 'unknown';
    const seen = p.last_seen_at ? ` last_seen=${p.last_seen_at}` : '';
    console.log(`- ${id} (${name})${seen}`);
  });
}

function cmdStart() {
  const state = getState();
  if (state.nodePid) {
    try {
      process.kill(state.nodePid, 0);
      console.log('Node already running (pid ' + state.nodePid + '). Stop it first.');
      return;
    } catch (_) {}
  }
  const runScript = path.join(POC_ROOT, 'node-run.sh');
  if (!fs.existsSync(runScript)) {
    console.error('node-run.sh not found. Run install.sh Phase 3 first.');
    process.exit(1);
  }
  let clusterIds = state.clusters.map((c) => c.id).filter(Boolean);
  const config = getConfig();
  if (clusterIds.length === 0 && config.cluster_id) clusterIds = [config.cluster_id];
  if (clusterIds.length === 0) clusterIds = ['gatewayai-poc'];
  // Always refresh resources and model eligibility before starting the node.
  cmdGauge();
  const eligible = getEligibleTierIds(getResources());
  const derivedClusterIds = deriveClusterIdsFromRegistry(eligible);
  if (derivedClusterIds.length > 0) {
    clusterIds = derivedClusterIds;
  }
  clusterIds = Array.from(new Set(clusterIds.filter(Boolean)));
  if (clusterIds.length === 0) clusterIds = ['gatewayai-poc'];
  setState({ clusters: clusterIds.map((id) => ({ id })) });
  console.log('Mapped cluster IDs:', clusterIds.join(', '));
  setState({ supportedModels: eligible });
  if (eligible.length === 0) {
    console.log('Eligible models: none');
  } else {
    console.log('Eligible models:', eligible.join(', '));
  }
  const backend = (process.env.POC_INFERENCE_BACKEND || state.runtime?.backend || 'ollama').toLowerCase();
  const model = process.env.OLLAMA_MODEL || state.runtime?.model || 'llama3.2:1b';

  if (backend === 'ollama') {
    const ollamaExists = spawnSync('ollama', ['--version'], { stdio: 'ignore' }).status === 0;
    if (!ollamaExists) {
      console.error('Ollama not found. Install ollama or set POC_INFERENCE_BACKEND=echo.');
      process.exit(1);
    }
    // Start local Ollama server if not running.
    let ollamaReady = false;
    try {
      execSync('curl -fsSL http://127.0.0.1:11434/api/tags >/dev/null', { stdio: 'ignore' });
      ollamaReady = true;
    } catch (_) {}
    if (!ollamaReady) {
      console.log('Starting Ollama server...');
      execSync('nohup ollama serve >/tmp/opengateway-ollama.log 2>&1 &');
      for (let i = 0; i < 10; i += 1) {
        try {
          execSync('curl -fsSL http://127.0.0.1:11434/api/tags >/dev/null', { stdio: 'ignore' });
          ollamaReady = true;
          break;
        } catch (_) {
          execSync('sleep 1');
        }
      }
    }
    if (!ollamaReady) {
      console.error('Ollama server is not reachable at http://127.0.0.1:11434');
      process.exit(1);
    }
    // Ensure selected model exists locally.
    const hasModel = spawnSync('ollama', ['show', model], { stdio: 'ignore' }).status === 0;
    if (!hasModel) {
      console.log(`Pulling Ollama model: ${model} ...`);
      const pull = spawnSync('ollama', ['pull', model], { stdio: 'inherit' });
      if (pull.status !== 0) {
        console.error(`Failed to pull model ${model}.`);
        process.exit(1);
      }
    }
  }

  setState({ runtime: { backend, model } });
  console.log('Starting node daemon for clusters:', clusterIds.join(', '));
  const { spawn } = require('child_process');
  const logsDir = path.join(POC_ROOT, 'logs');
  fs.mkdirSync(logsDir, { recursive: true });
  const outFd = fs.openSync(path.join(logsDir, 'node.out.log'), 'a');
  const errFd = fs.openSync(path.join(logsDir, 'node.err.log'), 'a');
  const child = spawn(runScript, [], {
    env: {
      ...process.env,
      OPENGATEWAY_POC_ROOT: POC_ROOT,
      POC_CLUSTER_ID: clusterIds[0],
      POC_CLUSTER_IDS: clusterIds.join(','),
      POC_SUPPORTED_MODELS: eligible.join(','),
      POC_INFERENCE_BACKEND: backend,
      OLLAMA_MODEL: model,
    },
    detached: true,
    stdio: ['ignore', outFd, errFd],
    cwd: POC_ROOT,
  });
  child.unref();
  setState({ nodePid: child.pid });
  console.log('Node daemon started (pid ' + child.pid + ').');
  console.log('Logs:', path.join(logsDir, 'node.out.log'), path.join(logsDir, 'node.err.log'));
}

function cmdStop() {
  const state = getState();
  if (!state.nodePid) {
    console.log('Node is not running.');
    return;
  }
  try {
    process.kill(state.nodePid, 'SIGTERM');
    setState({ nodePid: null });
    console.log('Stopped node (pid ' + state.nodePid + ').');
  } catch (_) {
    // Stale PID or already stopped
    setState({ nodePid: null });
    console.log('Node process not found. Cleared stale pid.');
  }
}

function cmdRestart() {
  cmdStop();
  try { execSync('sleep 1'); } catch (_) {}
  cmdStart();
}

function runPromptOnce(sendPath, clusterId, model, promptText) {
  const sendArgs = [sendPath, promptText];
  if (model) sendArgs.push(model);
  const r = spawnSync(process.execPath, sendArgs, {
    env: { ...process.env, OPENGATEWAY_POC_ROOT: POC_ROOT, POC_CLUSTER_ID: clusterId, POC_MODEL: model || '' },
    cwd: POC_ROOT,
    stdio: 'inherit',
  });
  return r.status || 0;
}

async function cmdPrompt(...args) {
  const sendPath = path.join(POC_ROOT, 'send-prompt.js');
  if (!fs.existsSync(sendPath)) {
    console.error('send-prompt.js not found. Run install.sh Phase 3 first.');
    process.exit(1);
  }
  let model = '';
  const parts = [];
  for (let i = 0; i < args.length; i += 1) {
    if (args[i] === '--model' && args[i + 1]) {
      model = args[i + 1];
      i += 1;
      continue;
    }
    parts.push(args[i]);
  }
  const state = getState();
  const clusterId = getConfig().cluster_id || (state.clusters[0] && state.clusters[0].id) || 'gatewayai-poc';

  // One-shot mode
  if (parts.length > 0) {
    const status = runPromptOnce(sendPath, clusterId, model, parts.join(' '));
    if (status !== 0) process.exit(status);
    return;
  }

  // Interactive chat mode
  const readline = require('readline');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  console.log('Interactive chat mode. Type /exit to quit.');
  console.log('Commands: /model <model-id> to switch model in this session.');
  if (model) {
    console.log('Current model:', model);
  } else if (state.runtime && state.runtime.model) {
    console.log('Current model:', state.runtime.model, '(node default)');
  }

  for await (const line of rl) {
    const input = String(line || '').trim();
    if (!input) continue;
    if (input === '/exit' || input === '/quit') {
      rl.close();
      break;
    }
    if (input.startsWith('/model ')) {
      model = input.slice('/model '.length).trim();
      console.log('Model set to:', model || '(default)');
      continue;
    }
    const status = runPromptOnce(sendPath, clusterId, model, input);
    if (status !== 0) console.log('Request failed with exit code', status);
  }
}

const COMMANDS = {
  status: cmdStatus,
  clusters: cmdClusters,
  connect: cmdConnect,
  disconnect: cmdDisconnect,
  join: cmdConnect,
  leave: cmdDisconnect,
  resources: cmdResources,
  eligible: cmdEligible,
  peers: cmdPeers,
  gauge: cmdGauge,
  start: cmdStart,
  stop: cmdStop,
  restart: cmdRestart,
  prompt: cmdPrompt,
};

function main() {
  const [,, cmd, ...args] = process.argv;
  const fn = cmd && COMMANDS[cmd];
  if (!fn) {
    console.error('Usage: opengateway <command> [args]');
    console.error('Commands: status, clusters, connect, disconnect, resources, eligible, peers, gauge, start, stop, restart, prompt');
    console.error('Prompt usage: opengateway prompt [\"text\"] [--model <model-id>]');
    console.error('No text => interactive chat mode (/exit to quit)');
    console.error('Aliases:  join = connect, leave = disconnect');
    process.exit(1);
  }
  Promise.resolve(fn(...args)).catch((err) => {
    console.error(err.message || err);
    process.exit(1);
  });
}

main();
