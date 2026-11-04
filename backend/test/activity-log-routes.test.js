const assert = require('node:assert/strict');
const { test } = require('node:test');
const { registerActivityLogRoutes } = require('../src/routes/activity_log_routes');

test('activity log route requires auth and queries only the current user', async () => {
  const calls = [];
  const routes = new Map();
  const app = {
    get: (path, ...handlers) => routes.set(`GET ${path}`, handlers),
  };
  const pool = {
    execute: async (...args) => {
      calls.push(args);
      return [[{ id: 4, title: 'Booking created' }], []];
    },
  };
  const requireAuth = () => {};
  registerActivityLogRoutes({ app, pool, requireAuth });

  const handlers = routes.get('GET /api/activity-logs');
  assert.equal(handlers[0], requireAuth);
  const response = {
    json(body) {
      this.body = body;
      return this;
    },
  };
  await handlers.at(-1)({ auth: { sub: 31 } }, response, assert.fail);

  assert.match(calls[0][0], /WHERE user_id = \?/);
  assert.deepEqual(calls[0][1], [31]);
  assert.deepEqual(response.body.activities, [{ id: 4, title: 'Booking created' }]);
});
