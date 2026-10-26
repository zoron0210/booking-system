const assert = require('node:assert/strict');
const { test } = require('node:test');
const { registerSystemRoutes } = require('../src/routes/system_routes');

function setup({ pool = {}, notificationTokenHash = (token) => `hash:${token}` } = {}) {
  const routes = new Map();
  const app = {
    get: (path, ...handlers) => routes.set(`GET ${path}`, handlers),
    put: (path, ...handlers) => routes.set(`PUT ${path}`, handlers),
    delete: (path, ...handlers) => routes.set(`DELETE ${path}`, handlers),
  };
  const requireAuth = () => {};
  registerSystemRoutes({ app, pool, requireAuth, notificationTokenHash });
  return { routes, requireAuth };
}

function response() {
  return {
    statusCode: 200,
    body: null,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(body) {
      this.body = body;
      return this;
    },
  };
}

test('health route reports database connectivity and forwards query errors', async () => {
  const setupSuccess = setup({ pool: { query: async () => {} } });
  const success = response();
  await setupSuccess.routes.get('GET /health').at(-1)({}, success, assert.fail);
  assert.deepEqual(success.body, { status: 'ok', database: 'connected' });

  const failure = new Error('database unavailable');
  const setupFailure = setup({ pool: { query: async () => { throw failure; } } });
  let forwarded;
  await setupFailure.routes.get('GET /health').at(-1)({}, response(), (error) => {
    forwarded = error;
  });
  assert.equal(forwarded, failure);
});

test('device registration validates and stores the authenticated token', async () => {
  const calls = [];
  const { routes, requireAuth } = setup({
    pool: { execute: async (...args) => calls.push(args) },
  });
  const handlers = routes.get('PUT /api/notifications/device');
  assert.equal(handlers[0], requireAuth);

  const invalid = response();
  await handlers.at(-1)(
    { body: { fcmToken: 'short', sound: 'system' } },
    invalid,
    assert.fail,
  );
  assert.equal(invalid.statusCode, 400);
  assert.equal(calls.length, 0);

  const token = `  ${'device-token-'.repeat(3)}  `;
  const success = response();
  await handlers.at(-1)(
    { body: { fcmToken: token, sound: 'tinker_bell' }, auth: { sub: 42 } },
    success,
    assert.fail,
  );
  assert.deepEqual(calls[0][1], [
    `hash:${token.trim()}`,
    42,
    token.trim(),
    'tinker_bell',
  ]);
  assert.deepEqual(success.body, {
    message: 'Booking push notifications are enabled.',
  });
});

test('device removal only removes the authenticated user token', async () => {
  const calls = [];
  const { routes, requireAuth } = setup({
    pool: { execute: async (...args) => calls.push(args) },
  });
  const handlers = routes.get('DELETE /api/notifications/device');
  assert.equal(handlers[0], requireAuth);

  const token = 'device-token-'.repeat(3);
  const success = response();
  await handlers.at(-1)(
    { body: { fcmToken: token }, auth: { sub: 19 } },
    success,
    assert.fail,
  );
  assert.deepEqual(calls[0][1], [`hash:${token}`, 19]);
  assert.deepEqual(success.body, {
    message: 'Booking push notifications are disabled.',
  });
});
