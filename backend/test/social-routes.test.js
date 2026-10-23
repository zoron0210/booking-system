const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  MAX_POSTS_PER_24_HOURS,
  registerSocialRoutes,
  validateImages,
} = require('../src/routes/social_routes');

function createRouteHarness(pool) {
  const routes = new Map();
  const app = {
    get(path, ...handlers) {
      routes.set(`GET ${path}`, handlers.at(-1));
    },
    post(path, ...handlers) {
      routes.set(`POST ${path}`, handlers.at(-1));
    },
    delete(path, ...handlers) {
      routes.set(`DELETE ${path}`, handlers.at(-1));
    },
  };
  registerSocialRoutes({
    app,
    pool,
    requireAuth(_req, _res, next) {
      return next();
    },
  });
  return routes;
}

function response() {
  return {
    statusCode: 200,
    body: undefined,
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(value) {
      this.body = value;
      return this;
    },
  };
}

async function call(routes, key, request, res = response()) {
  let nextError;
  await routes.get(key)(
    { auth: { sub: 7, role: 'customer' }, body: {}, params: {}, query: {}, ...request },
    res,
    (error) => {
      nextError = error;
    },
  );
  if (nextError) throw nextError;
  return res;
}

const pngDataUrl =
  'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j0L8AAAAASUVORK5CYII=';

test('validates supported photos and rejects mismatched content and excessive files', () => {
  assert.deepEqual(validateImages([pngDataUrl]), {
    valid: true,
    images: [pngDataUrl],
  });
  assert.equal(validateImages(['data:image/png;base64,YWJj']).valid, false);
  assert.equal(validateImages(Array(6).fill(pngDataUrl)).valid, false);
  assert.equal(validateImages(null).valid, true);
});

test('merchant profiles include only currently enabled published venues', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('postsCount')) {
        return [[{
          id: 7,
          firstName: 'Morgan',
          lastName: 'Merchant',
          role: 'merchant',
          postsCount: 0,
        }], []];
      }
      if (sql.includes('FROM social_posts')) return [[], []];
      if (sql.includes('FROM merchant_businesses b')) {
        return [[{
          businessId: 23,
          businessName: 'Northside Courts',
          businessType: 'Sports',
          enabled: 1,
          title: 'New court',
          body: 'Now open',
          imageUrl: '["https://example.test/legacy-court.jpg"]',
          imageUrls: ['https://example.test/court.jpg'],
        }], []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  });

  const res = await call(routes, 'GET /api/social/users/:userId', {
    params: { userId: '7' },
  });

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body.businesses, [{
    businessId: 23,
    businessName: 'Northside Courts',
    businessType: 'Sports',
    enabled: true,
    title: 'New court',
    body: 'Now open',
    imageUrl: 'https://example.test/legacy-court.jpg',
    imageUrls: ['https://example.test/court.jpg'],
  }]);
  assert.equal(res.body.profile.postsCount, 0);
  const profileQuery = calls.find(({ sql }) => sql.includes('postsCount'));
  assert.match(
    profileQuery.sql,
    /\(SELECT COUNT\(\*\) FROM social_posts p\s+WHERE p\.user_id = u\.id\) AS postsCount/,
  );
  assert.doesNotMatch(profileQuery.sql, /merchant_news/);
  const venueQuery = calls.find(({ sql }) => sql.includes('FROM merchant_businesses b'));
  assert.match(venueQuery.sql, /b\.enabled = 1/);
  assert.match(venueQuery.sql, /n\.status = 'published'/);
  assert.match(venueQuery.sql, /JSON_LENGTH\(b\.image_urls\)/);
});

test('social connection lists expose public follower and following profiles', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      return [[{
        id: 12,
        firstName: 'Taylor',
        lastName: 'Player',
        avatarUrl: 'https://example.test/avatar.jpg',
        role: 'customer',
        followersCount: 3,
        isFollowing: 1,
      }], []];
    },
  });

  for (const type of ['followers', 'following']) {
    const result = await call(
      routes,
      `GET /api/social/users/:userId/${type}`,
      { params: { userId: '7' } },
    );
    assert.deepEqual(result.body.users, [{
      id: 12,
      displayName: 'Taylor Player',
      avatarUrl: 'https://example.test/avatar.jpg',
      role: 'customer',
      followersCount: 3,
      isFollowing: true,
    }]);
  }

  assert.match(calls[0].sql, /f\.followed_id = \? AND f\.follower_id = u\.id/);
  assert.match(calls[1].sql, /f\.follower_id = \? AND f\.followed_id = u\.id/);
  assert.deepEqual(calls.map(({ params }) => params), [
    [7, 7, 7, 7],
    [7, 7, 7, 7],
  ]);
});

test('limits experience posts to five in a rolling 24-hour window', async () => {
  const calls = [];
  let rolledBack = false;
  let released = false;
  const connection = {
    async beginTransaction() {
      calls.push('begin');
    },
    async execute(sql) {
      calls.push(sql);
      if (sql.includes('FROM users')) return [[{ id: 7 }], []];
      if (sql.includes('FROM social_posts')) {
        return [[
          {
            postCount: MAX_POSTS_PER_24_HOURS,
            oldestPostAt: new Date('2026-10-18T12:00:00.000Z'),
          },
        ], []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
    async rollback() {
      rolledBack = true;
    },
    async commit() {
      throw new Error('A limited post must not commit.');
    },
    release() {
      released = true;
    },
  };
  const routes = createRouteHarness({
    async getConnection() {
      return connection;
    },
    async execute() {
      throw new Error('Unexpected pool query.');
    },
  });

  const res = await call(routes, 'POST /api/social/posts', {
    body: { caption: 'My game today', images: [] },
  });

  assert.equal(res.statusCode, 429);
  assert.equal(res.body.limit, 5);
  assert.equal(res.body.availableAt, '2026-10-19T12:00:00.000Z');
  assert.equal(rolledBack, true);
  assert.equal(released, true);
  assert.equal(calls.some((sql) => String(sql).includes('INSERT INTO social_posts')), false);
});

test('saves a caption and valid photos in one transaction', async () => {
  const calls = [];
  let committed = false;
  let released = false;
  const connection = {
    async beginTransaction() {},
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('FROM users')) return [[{ id: 7 }], []];
      if (sql.includes('FROM social_posts')) return [[{ postCount: 0 }], []];
      if (sql.includes('INSERT INTO social_posts')) {
        return [{ insertId: 35 }, []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
    async rollback() {
      throw new Error('A valid post must not roll back.');
    },
    async commit() {
      committed = true;
    },
    release() {
      released = true;
    },
  };
  const routes = createRouteHarness({
    async getConnection() {
      return connection;
    },
    async execute() {
      throw new Error('Unexpected pool query.');
    },
  });

  const res = await call(routes, 'POST /api/social/posts', {
    body: { caption: 'A great match', images: [pngDataUrl] },
  });

  assert.equal(res.statusCode, 201);
  assert.equal(res.body.id, 35);
  assert.equal(res.body.caption, 'A great match');
  assert.deepEqual(res.body.images, [pngDataUrl]);
  assert.equal(committed, true);
  assert.equal(released, true);
  assert.ok(calls.some(({ sql }) => sql.includes('FOR UPDATE')));
});

test('rejects posts without content before acquiring a database connection', async () => {
  let connectionRequested = false;
  const routes = createRouteHarness({
    async getConnection() {
      connectionRequested = true;
      throw new Error('Should not reach database.');
    },
  });

  const res = await call(routes, 'POST /api/social/posts', {
    body: { caption: '   ', images: [] },
  });

  assert.equal(res.statusCode, 400);
  assert.equal(connectionRequested, false);
});

test('does not permit following the authenticated user', async () => {
  let queryCount = 0;
  const routes = createRouteHarness({
    async execute() {
      queryCount += 1;
      return [[], []];
    },
  });

  const res = await call(routes, 'POST /api/social/follows/:userId', {
    params: { userId: '7' },
  });

  assert.equal(res.statusCode, 400);
  assert.equal(queryCount, 0);
});

test('creates a one-way follow after checking the target account and block list', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('SELECT id FROM users')) return [[{ id: 42 }], []];
      if (sql.includes('INSERT IGNORE INTO user_follows')) return [{}, []];
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  });

  const res = await call(routes, 'POST /api/social/follows/:userId', {
    params: { userId: '42' },
  });

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, { isFollowing: true });
  assert.equal(calls.length, 2);
  assert.deepEqual(calls[1].params, [7, 42]);
});
