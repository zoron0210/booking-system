const assert = require('node:assert/strict');
const { createServer } = require('node:http');
const { test } = require('node:test');
const { WebSocket } = require('ws');
const { createWebSocketHub } = require('../src/websocket_hub');

function nextMessage(socket) {
  return new Promise((resolve, reject) => {
    socket.once('message', (data) => resolve(JSON.parse(data.toString())));
    socket.once('error', reject);
  });
}

test('live WebSocket authenticates users and broadcasts only to that user', async () => {
  const server = createServer();
  const hub = createWebSocketHub({
    jwt: {
      verify(token) {
        if (token !== 'valid-access-token') throw new Error('Invalid token.');
        return {
          sub: '42',
          exp: Math.floor(Date.now() / 1000) + 60,
        };
      },
    },
    pool: {
      async execute(_sql, params) {
        return [params[0] === '42' ? [{ status: 'active' }] : [], []];
      },
    },
    secret: 'test-secret',
  });
  hub.attach(server);
  await new Promise((resolve) => server.listen(0, '127.0.0.1', resolve));

  const socket = new WebSocket(
    `ws://127.0.0.1:${server.address().port}/api/live`,
  );
  await new Promise((resolve, reject) => {
    socket.once('open', resolve);
    socket.once('error', reject);
  });
  const readyMessage = nextMessage(socket);
  socket.send(JSON.stringify({
    type: 'authenticate',
    token: 'valid-access-token',
  }));
  assert.deepEqual(await readyMessage, { type: 'ready' });

  const liveMessage = nextMessage(socket);
  hub.publishToUser('43', { type: 'dashboard.updated' });
  hub.publishToUser('42', {
    type: 'message.created',
    conversationId: 7,
  });
  assert.deepEqual(await liveMessage, {
    type: 'message.created',
    conversationId: 7,
  });

  const closeCode = new Promise((resolve) => {
    socket.once('close', (code) => resolve(code));
  });
  hub.closeUser('42');
  assert.equal(await closeCode, 4403);
  await new Promise((resolve, reject) => {
    server.close((error) => error ? reject(error) : resolve());
  });
});
