#!/usr/bin/env node
/**
 * OpenGateway POC node – joins cluster via Hyperswarm, handles inference_request (echo).
 * Messages: NDJSON (one JSON object per line). See BUILDING_POC.md § POC message format.
 * Usage: node poc-node.js (run from POC root with OPENGATEWAY_POC_ROOT and POC_CLUSTER_ID set)
 *        or: opengateway start
 */

const crypto = require('crypto');
const path = require('path');
const fs = require('fs');
const http = require('http');
const https = require('https');

const POC_ROOT = process.env.OPENGATEWAY_POC_ROOT || path.join(process.env.HOME || '', '.opengateway-poc');
const CLUSTER_ID = process.env.POC_CLUSTER_ID || (() => {
  try {
    const config = JSON.parse(fs.readFileSync(path.join(POC_ROOT, 'config.json'), 'utf8'));
    if (config.cluster_id) return config.cluster_id;
  } catch (_) {}
  try {
    const state = JSON.parse(fs.readFileSync(path.join(POC_ROOT, 'state.json'), 'utf8'));
    if (state.clusters && state.clusters[0]) return state.clusters[0].id;
  } catch (_) {}
  return 'gatewayai-poc';
})();

const NODE_NAME = process.env.NODE_NAME || 'node';
const POC_INFERENCE_BACKEND = (process.env.POC_INFERENCE_BACKEND || 'auto').toLowerCase(); // auto | ollama | echo
const OLLAMA_URL = process.env.OLLAMA_URL || 'http://127.0.0.1:11434';
const OLLAMA_MODEL = process.env.OLLAMA_MODEL || 'llama3.2:1b';
const SUPPORTED_MODELS = (process.env.POC_SUPPORTED_MODELS || '')
  .split(',')
  .map((s) => s.trim())
  .filter(Boolean);
const MODEL_RUNTIME_MAP = {
  'SmolLM-360M': 'llama3.2:1b',
};

const topic = crypto.createHash('sha256').update(CLUSTER_ID).digest();

function send(socket, obj) {
  try {
    socket.write(JSON.stringify(obj) + '\n');
  } catch (_) {}
}

function postJson(urlString, body, timeoutMs = 30000) {
  return new Promise((resolve, reject) => {
    let url;
    try {
      url = new URL(urlString);
    } catch (e) {
      reject(e);
      return;
    }
    const payload = JSON.stringify(body);
    const client = url.protocol === 'https:' ? https : http;
    const req = client.request({
      hostname: url.hostname,
      port: url.port || (url.protocol === 'https:' ? 443 : 80),
      path: url.pathname + url.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(payload),
      },
      timeout: timeoutMs,
    }, (res) => {
      let data = '';
      res.setEncoding('utf8');
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode < 200 || res.statusCode >= 300) {
          reject(new Error(`HTTP ${res.statusCode}: ${data}`));
          return;
        }
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('timeout', () => req.destroy(new Error('request timeout')));
    req.on('error', reject);
    req.write(payload);
    req.end();
  });
}

async function inferWithOllama(prompt, model) {
  const body = {
    model: model || OLLAMA_MODEL,
    prompt: String(prompt),
    stream: false,
  };
  const out = await postJson(`${OLLAMA_URL}/api/generate`, body, 45000);
  if (!out || typeof out.response !== 'string') {
    throw new Error('Ollama returned no response');
  }
  return out.response.trim();
}

async function inferPrompt(prompt, model) {
  let selected = model ? String(model) : '';
  if (!selected && SUPPORTED_MODELS.length > 0) {
    selected = SUPPORTED_MODELS[0];
  }
  if (
    SUPPORTED_MODELS.length > 0 &&
    selected &&
    !SUPPORTED_MODELS.includes(selected) &&
    selected !== OLLAMA_MODEL
  ) {
    selected = SUPPORTED_MODELS[0];
  }
  const chosenModel = MODEL_RUNTIME_MAP[selected] || selected || OLLAMA_MODEL;
  if (POC_INFERENCE_BACKEND === 'echo') {
    return { text: '[echo] ' + String(prompt), backend: 'echo' };
  }
  if (POC_INFERENCE_BACKEND === 'ollama') {
    const text = await inferWithOllama(prompt, chosenModel);
    return { text, backend: 'ollama' };
  }
  // auto mode: try Ollama, fall back to echo
  try {
    const text = await inferWithOllama(prompt, chosenModel);
    return { text, backend: 'ollama' };
  } catch (_) {
    return { text: '[echo] ' + String(prompt), backend: 'echo' };
  }
}

function handleInferenceRequest(msg, socket) {
  const requestId = msg.request_id != null ? msg.request_id : crypto.randomUUID();
  inferPrompt(msg.prompt, msg.model)
    .then(({ text, backend }) => {
      send(socket, {
        type: 'inference_response',
        request_id: requestId,
        response: text,
        model: msg.model || OLLAMA_MODEL,
      });
      console.log('[request]', requestId, '->', backend);
    })
    .catch((err) => {
      send(socket, {
        type: 'inference_response',
        request_id: requestId,
        response: `[error] ${err.message || String(err)}`,
      });
      console.error('[request]', requestId, '-> error', err.message || err);
    });
}

function setupConnection(socket, info) {
  const key = info.publicKey ? info.publicKey.toString('hex').slice(0, 16) : '?';
  console.log('[peer] connected', key);
  let buf = '';
  socket.setEncoding('utf8');
  socket.on('data', (chunk) => {
    buf += chunk;
    const lines = buf.split('\n');
    buf = lines.pop() || '';
    for (const line of lines) {
      if (!line.trim()) continue;
      try {
        const msg = JSON.parse(line);
        if (msg.type === 'inference_request' && msg.request_id != null && msg.prompt != null) {
          handleInferenceRequest(msg, socket);
        }
      } catch (_) {}
    }
  });
  socket.on('error', () => {});
  socket.on('close', () => {});
}

async function main() {
  const Hyperswarm = require('hyperswarm');
  const swarm = new Hyperswarm();

  swarm.on('connection', (socket, info) => setupConnection(socket, info));

  const discovery = swarm.join(topic, { server: true, client: true });
  await discovery.flushed();
  console.log('Joined cluster:', CLUSTER_ID, '(' + NODE_NAME + ')');
  console.log('Inference backend:', POC_INFERENCE_BACKEND, `(ollama=${OLLAMA_URL}, model=${OLLAMA_MODEL})`);
  if (SUPPORTED_MODELS.length > 0) {
    console.log('Supported models:', SUPPORTED_MODELS.join(', '));
  }

  const shutdown = () => {
    discovery.destroy().then(() => process.exit(0)).catch(() => process.exit(0));
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
