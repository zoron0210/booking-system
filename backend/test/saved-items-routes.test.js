const assert = require('node:assert/strict');
const { test } = require('node:test');
const { registerSavedItemsRoutes } = require('../src/routes/saved_items_routes');

function setup({ execute = async () => [[], []], recordUserActivity = async () => {} } = {}) {
  const routes = new Map();
  const app = {
    get: (path, ...handlers) => routes.set(`GET ${path}`, handlers),
    post: (path, ...handlers) => routes.set(`POST ${path}`, handlers),
    delete: (path, ...handlers) => routes.set(`DELETE ${path}`, handlers),
  };
  const pool = { execute };
  const requireAuth = () => {};
  registerSavedItemsRoutes({ app, pool, requireAuth, recordUserActivity });
  return { routes, pool, requireAuth };
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

test('saved item listing is authenticated and scoped to the current user', async () => {
  const calls = [];
  const { routes, requireAuth } = setup({
    execute: async (...args) => {
      calls.push(args);
      return [[{ id: 8, itemKey: 'venue-1' }], []];
    },
  });
  const handlers = routes.get('GET /api/saved-items');
  assert.equal(handlers[0], requireAuth);

  const res = response();
  await handlers.at(-1)({ auth: { sub: 17 } }, res, assert.fail);

  assert.equal(calls.length, 1);
  assert.match(calls[0][0], /WHERE user_id = \?/);
  assert.deepEqual(calls[0][1], [17]);
  assert.equal(res.body.items[0].itemKey, 'venue-1');
});

test('invalid saved-item counts are rejected before querying', async () => {
  let queries = 0;
  const { routes } = setup({
    execute: async () => {
      queries++;
      return [[], []];
    },
  });
  const res = response();
  await routes
    .get('GET /api/saved-item-counts')
    .at(-1)({ query: { itemType: 'invalid' } }, res, assert.fail);

  assert.equal(res.statusCode, 400);
  assert.equal(queries, 0);
});

test('saving validates input, resolves owner details, and records the user', async () => {
  const queries = [];
  const activities = [];
  const { routes, pool, requireAuth } = setup({
    execute: async (...args) => {
      queries.push(args);
      return queries.length === 1
        ? [[{ contactEmail: 'owner@example.test', phone: '555-0100' }], []]
        : [{ affectedRows: 1 }, []];
    },
    recordUserActivity: async (...args) => activities.push(args),
  });
  const handlers = routes.get('POST /api/saved-items');
  assert.equal(handlers[0], requireAuth);

  const invalid = response();
  await handlers.at(-1)(
    { body: { itemType: 'other', itemKey: '', title: '' }, auth: { sub: 5 } },
    invalid,
    assert.fail,
  );
  assert.equal(invalid.statusCode, 400);
  assert.equal(queries.length, 0);

  const res = response();
  await handlers.at(-1)(
    {
      body: {
        itemType: 'sports',
        itemKey: '42',
        title: '  Venue  ',
        subtitle: '  Details  ',
        imageUrl: ' https://image.example.test/venue.jpg ',
      },
      auth: { sub: 5 },
    },
    res,
    assert.fail,
  );

  assert.equal(res.statusCode, 201);
  assert.equal(queries[0][1][0], '42');
  assert.deepEqual(queries[1][1], [
    5,
    'sports',
    '42',
    'Venue',
    'Details',
    'https://image.example.test/venue.jpg',
    'owner@example.test',
    '555-0100',
  ]);
  assert.equal(activities[0][0], pool);
  assert.equal(activities[0][1], 5);
  assert.equal(activities[0][2], 'item_saved');
});

test('saved-item removal is constrained to the authenticated user', async () => {
  const queries = [];
  const activities = [];
  const { routes } = setup({
    execute: async (...args) => {
      queries.push(args);
      return [{ affectedRows: 1 }, []];
    },
    recordUserActivity: async (...args) => activities.push(args),
  });
  const res = response();
  await routes.get('DELETE /api/saved-items/:itemType/:itemKey').at(-1)(
    {
      params: { itemType: 'event', itemKey: 'venue-9' },
      auth: { sub: 22 },
    },
    res,
    assert.fail,
  );

  assert.deepEqual(queries[0][1], [22, 'event', 'venue-9']);
  assert.equal(activities[0][1], 22);
  assert.equal(res.body.message, 'Item removed.');
});
