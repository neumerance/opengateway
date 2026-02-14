#!/usr/bin/env node
/**
 * Send one inference_request to the cluster, wait for inference_response, print and exit.
 * Usage: node send-prompt.js "What is 2+2?"
 *        Requires OPENGATEWAY_POC_ROOT and POC_CLUSTER_ID (or defaults).
 */

const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

const POC_ROOT = process.env.OPENGATEWAY_POC_ROOT || path.join(process.env.HOME || '', '.opengateway-poc');
const CLUSTER_ID = process.env.POC_CLUSTER_ID || (() => {
  try {
    const state = JSON.parse(fs.readFileSync(path.join(POC_ROOT, 'state.json'), 'utf8'));
    if (state.clusters && state.clusters[0]) return state.clusters[0].id;
  } catch (_) {}
  return 'gatewayai-poc';
})();

const prompt = process.argv[2] || process.env.POC_PROMPT || 'What is 2+2?';
const request_id = crypto.randomUUID();

const topic = crypto.createHash('sha256').update(CLUSTER_ID).digest();

function send(socket, obj) {
  socket.write(JSON.stringify(obj) + '\n');
}

async function main() {
  const Hyperswarm = require('hyperswarm');
  const swarm = new Hyperswarm();

  const done = new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      swarm.destroy().catch(() => {});
      reject(new Error('Timeout waiting for response'));
    }, 30000);

    swarm.on('connection', (socket, info) => {
      let buf = '';
      socket.setEncoding('utf8');
      send(socket, { type: 'inference_request', request_id, prompt });
      socket.on('data', (chunk) => {
        buf += chunk;
        const lines = buf.split('\n');
        buf = lines.pop() || '';
        for (const line of lines) {
          if (!line.trim()) continue;
          try {
            const msg = JSON.parse(line);
            if (msg.type === 'inference_response' && msg.request_id === request_id) {
              clearTimeout(timeout);
              console.log(msg.response);
              swarm.destroy().then(() => resolve()).catch(() => resolve());
              return;
            }
          } catch (_) {}
        }
      });
      socket.on('error', () => {});
      socket.on('close', () => {});
    });
  });

  swarm.join(topic, { server: false, client: true });
  await done;
}

main().catch((err) => {
  console.error(err.message || err);
  process.exit(1);
});
