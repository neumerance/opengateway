#!/usr/bin/env node
/**
 * OpenGateway POC CLI – minimum commands: status, clusters, connect, disconnect, resources, eligible, peers.
 * Usage: node cli.js <command> [args]
 *        opengateway <command> [args]  (wrapper in POC root)
 * Requires: OPENGATEWAY_POC_ROOT or ~/.opengateway-poc
 */

const fs = require('fs');
const path = require('path');

const POC_ROOT = process.env.OPENGATEWAY_POC_ROOT || path.join(process.env.HOME || process.env.USERPROFILE || '', '.opengateway-poc');
const CONFIG_PATH = path.join(POC_ROOT, 'config.json');
const STATE_PATH = path.join(POC_ROOT, 'state.json');
const RESOURCES_PATH = path.join(POC_ROOT, 'resources.json');

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
  return readJson(STATE_PATH, { clusters: [], nodePid: null });
}

function setState(update) {
  const s = getState();
  writeJson(STATE_PATH, { ...s, ...update });
}

function getResources() {
  return readJson(RESOURCES_PATH, null);
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
  console.log('Cluster ID:  ', config.cluster_id || '(none)');
  console.log('Node name:   ', config.node_name || '(auto)');
  console.log('Clusters:    ', state.clusters.length ? state.clusters.map(c => c.id).join(', ') : 'none');
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
  console.log('Connected to', clusterId, '(stored; actual join in Phase 3)');
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
    console.log('Resources not gauged. Run Phase 3 (gauge) first.');
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
    console.log('Resources not gauged. Run Phase 3 (gauge) first.');
    return;
  }
  const cpu = r.cpu_cores ?? r.cpu ?? 0;
  const ram = r.ram_gb ?? r.ram ?? 0;
  const gpu = r.gpu_vram_gb ?? r.gpu ?? 0;
  const disk = r.disk_gb ?? r.disk ?? 0;
  const eligible = TIERS.filter(t => {
    if (cpu < t.cpu || ram < t.ram || disk < t.disk) return false;
    if (t.gpu > 0 && gpu < t.gpu) return false;
    return true;
  });
  if (eligible.length === 0) {
    console.log('No clusters eligible with current resources.');
    return;
  }
  eligible.forEach(t => console.log(t.id));
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
  console.log('Peers: (not available until node is running and joined)');
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
};

function main() {
  const [,, cmd, ...args] = process.argv;
  const fn = cmd && COMMANDS[cmd];
  if (!fn) {
    console.error('Usage: opengateway <command> [args]');
    console.error('Commands: status, clusters, connect, disconnect, resources, eligible, peers');
    console.error('Aliases:  join = connect, leave = disconnect');
    process.exit(1);
  }
  fn(...args);
}

main();
