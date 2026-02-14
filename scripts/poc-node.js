#!/usr/bin/env node
/**
 * OpenGateway POC node – joins cluster via Hyperswarm, stays running, discoverable.
 * Usage: node poc-node.js (run from POC root with OPENGATEWAY_POC_ROOT and POC_CLUSTER_ID set)
 *        or: opengateway start
 */

const crypto = require('crypto');
const path = require('path');
const fs = require('fs');

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

const topic = crypto.createHash('sha256').update(CLUSTER_ID).digest();

async function main() {
  const Hyperswarm = require('hyperswarm');
  const swarm = new Hyperswarm();

  swarm.on('connection', (socket, info) => {
    const key = info.publicKey ? info.publicKey.toString('hex').slice(0, 16) : '?';
    console.log('[peer] connected', key);
    socket.on('error', () => {});
    socket.on('close', () => {});
  });

  const discovery = swarm.join(topic, { server: true, client: true });
  await discovery.flushed();
  console.log('Joined cluster:', CLUSTER_ID);

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
