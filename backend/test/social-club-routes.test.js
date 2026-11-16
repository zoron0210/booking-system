const assert = require('node:assert/strict');
const { test } = require('node:test');
const { registerSocialClubRoutes } = require('../src/routes/social_club_routes');

function createRouteHarness(pool, options = {}) {
  const routes = new Map();
  const app = {
    get(path, ...handlers) {
      routes.set(`GET ${path}`, handlers);
    },
    post(path, ...handlers) {
      routes.set(`POST ${path}`, handlers);
    },
    patch(path, ...handlers) {
      routes.set(`PATCH ${path}`, handlers);
    },
    delete(path, ...handlers) {
      routes.set(`DELETE ${path}`, handlers);
    },
  };
  registerSocialClubRoutes({
    app,
    pool,
    requireAuth(req, res, next) {
      if (!req.headers.authorization) {
        return res.status(401).json({ error: 'Authentication required.' });
      }
      return next();
    },
    ...options,
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

async function call(routes, key, request = {}) {
  const req = {
    auth: { sub: 7, role: 'customer' },
    body: {},
    params: {},
    query: {},
    headers: { authorization: '******' },
    ...request,
  };
  const res = response();
  const handlers = routes.get(key);
  assert.ok(handlers, `Missing route ${key}`);
  let index = 0;
  const next = (error) => {
    if (error) throw error;
    const handler = handlers[index++];
    return handler?.(req, res, next);
  };
  await next();
  return res;
}

test('creates a club and enrolls its creator as owner in one transaction', async () => {
  const calls = [];
  const stagedLogo =
    'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-128';
  const logoKey =
    'gcs://social-posts/7/22222222-2222-4222-8222-222222222222.png';
  const connection = {
    async beginTransaction() {
      calls.push('begin');
    },
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('SELECT id FROM users')) return [[{ id: 7 }], []];
      if (sql.includes('INSERT INTO social_clubs')) {
        return [{ insertId: 31 }, []];
      }
      return [{ affectedRows: 1 }, []];
    },
    async commit() {
      calls.push('commit');
    },
    async rollback() {
      calls.push('rollback');
    },
    release() {
      calls.push('release');
    },
  };
  const routes = createRouteHarness({
    async getConnection() {
      return connection;
    },
  }, {
    mediaStorage: {
      async promoteUpload(key, userId) {
        assert.equal(key, stagedLogo);
        assert.equal(userId, 7);
        return logoKey;
      },
      async signImages(images) {
        assert.deepEqual(images, [logoKey]);
        return ['https://storage.googleapis.com/club-logo.png'];
      },
      async deleteImages() {},
    },
  });

  const result = await call(routes, 'POST /api/social/clubs', {
    body: {
      name: '  Weekend   Badminton  ',
      description: 'Meet up and play.',
      logoImage: stagedLogo,
    },
  });

  assert.equal(result.statusCode, 201);
  assert.equal(result.body.club.name, 'Weekend Badminton');
  assert.equal(result.body.club.description, 'Meet up and play.');
  assert.equal(
    result.body.club.logoUrl,
    'https://storage.googleapis.com/club-logo.png',
  );
  assert.equal(result.body.club.isMember, true);
  assert.ok(calls.includes('begin'));
  assert.ok(calls.includes('commit'));
  assert.ok(calls.includes('release'));
  assert.equal(calls.includes('rollback'), false);
  assert.deepEqual(
    calls.find((call) => typeof call === 'object' && call.sql.includes('INSERT INTO social_club_members')).params,
    [31, 7],
  );
});

test('rejects invalid club names before opening a database transaction', async () => {
  let connections = 0;
  const routes = createRouteHarness({
    async getConnection() {
      connections += 1;
      throw new Error('Should not connect.');
    },
  });

  const result = await call(routes, 'POST /api/social/clubs', {
    body: {
      name: '  ',
      logoImage:
        'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-1',
    },
  });

  assert.equal(result.statusCode, 400);
  assert.equal(connections, 0);
});

test('requires a logo before accepting club creation', async () => {
  let connections = 0;
  const routes = createRouteHarness({
    async getConnection() {
      connections += 1;
      throw new Error('Should not connect.');
    },
  });

  const result = await call(routes, 'POST /api/social/clubs', {
    body: { name: 'Weekend Badminton', description: '' },
  });

  assert.equal(result.statusCode, 400);
  assert.match(result.body.error, /club logo/i);
  assert.equal(connections, 0);
});

test('lists public clubs with member state scoped to the current user', async () => {
  let query;
  const routes = createRouteHarness({
    async execute(sql, params) {
      query = { sql, params };
      return [[{
        id: 31,
        name: 'Weekend Badminton',
        description: null,
        logoImage: 'gcs://social-posts/7/11111111-1111-4111-8111-111111111111.png',
        ownerUserId: 7,
        ownerName: 'Alex Player',
        memberCount: 2,
        isMember: 1,
        createdAt: new Date('2026-11-06T08:00:00Z'),
      }], []];
    },
  }, {
    mediaStorage: {
      async signImages(images) {
        assert.deepEqual(images, [
          'gcs://social-posts/7/11111111-1111-4111-8111-111111111111.png',
        ]);
        return ['https://storage.googleapis.com/club-logo.png'];
      },
    },
  });

  const result = await call(routes, 'GET /api/social/clubs', {
    query: { q: ' badminton ' },
  });

  assert.equal(result.body.clubs[0].isMember, true);
  assert.equal(result.body.clubs[0].memberCount, 2);
  assert.equal(
    result.body.clubs[0].logoUrl,
    'https://storage.googleapis.com/club-logo.png',
  );
  assert.equal('logoImage' in result.body.clubs[0], false);
  assert.deepEqual(query.params, [7, 7, 7, 'badminton', 'badminton']);
  assert.match(query.sql, /ORDER BY memberCount DESC/);
});

test('club posts use cursor paging and signed media URLs', async () => {
  const mediaKey = 'gcs://social-posts/7/11111111-1111-4111-8111-111111111111.png';
  const routes = createRouteHarness({
    async execute(sql, params) {
      assert.match(sql, /p\.club_id = \?/);
      assert.deepEqual(params, [7, 7, 31, 7, 7, 7, 91, 91, 2]);
      return [[{
        id: 90,
        userId: 12,
        caption: 'Club match day',
        imagesJson: JSON.stringify([mediaKey]),
        createdAt: new Date('2026-11-06T08:00:00Z'),
        firstName: 'Sam',
        lastName: 'Player',
      }, {
        id: 89,
        userId: 13,
        caption: 'Older post',
        imagesJson: '[]',
        createdAt: new Date('2026-11-05T08:00:00Z'),
      }], []];
    },
  }, {
    mediaStorage: {
      async signImages(images) {
        assert.deepEqual(images, [mediaKey]);
        return ['https://storage.googleapis.com/club-post.png'];
      },
    },
  });

  const result = await call(routes, 'GET /api/social/clubs/:clubId/posts', {
    params: { clubId: '31' },
    query: { before_id: '91', limit: '1' },
  });

  assert.equal(result.body.posts.length, 1);
  assert.deepEqual(result.body.posts[0].images, [
    'https://storage.googleapis.com/club-post.png',
  ]);
  assert.equal(result.body.hasMore, true);
  assert.equal(result.body.nextCursor, 90);
});

test('joining is idempotent and club owners cannot leave', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('SELECT requires_join_approval')) {
        return [[{ requiresJoinApproval: 0 }], []];
      }
      if (sql.includes('SELECT membership_status')) {
        return [[{ membershipStatus: 'approved' }], []];
      }
      if (sql.includes('SELECT id FROM social_clubs')) return [[{ id: 31 }], []];
      if (sql.includes('SELECT owner_user_id')) {
        return [[{ ownerUserId: 7 }], []];
      }
      return [{ affectedRows: 1 }, []];
    },
  });

  const joined = await call(routes, 'POST /api/social/clubs/:clubId/join', {
    params: { clubId: '31' },
  });
  const left = await call(routes, 'DELETE /api/social/clubs/:clubId/membership', {
    params: { clubId: '31' },
  });

  assert.equal(joined.body.isMember, true);
  assert.equal(calls.some(({ sql }) => sql.includes('INSERT IGNORE INTO social_club_members')), true);
  assert.equal(left.statusCode, 409);
  assert.equal(calls.some(({ sql }) => sql.startsWith('DELETE FROM social_club_members')), false);
});

test('join requests remain pending when owner approval is enabled', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('SELECT requires_join_approval')) {
        return [[{ requiresJoinApproval: 1 }], []];
      }
      if (sql.includes('SELECT membership_status')) {
        return [[{ membershipStatus: 'pending' }], []];
      }
      return [{ affectedRows: 1 }, []];
    },
  });

  const result = await call(routes, 'POST /api/social/clubs/:clubId/join', {
    params: { clubId: '31' },
  });

  assert.deepEqual(result.body, { isMember: false, isPending: true });
  assert.deepEqual(
    calls.find(({ sql }) => sql.includes('INSERT IGNORE')).params,
    [31, 'pending', 7],
  );
});

test('only the owner can change join settings and review member requests', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('SELECT id FROM social_clubs WHERE id = ? AND owner_user_id')) {
        return [[{ id: 31 }], []];
      }
      if (sql.includes('SELECT m.user_id AS userId')) {
        return [[{
          userId: 42,
          firstName: 'Alex',
          lastName: 'Player',
          requestedAt: new Date('2026-11-06T08:00:00Z'),
        }], []];
      }
      if (sql.includes('UPDATE social_club_members')) {
        return [{ affectedRows: 1 }, []];
      }
      return [{ affectedRows: 1 }, []];
    },
  });

  const settings = await call(
    routes,
    'PATCH /api/social/clubs/:clubId/settings',
    { params: { clubId: '31' }, body: { requiresJoinApproval: true } },
  );
  const requests = await call(
    routes,
    'GET /api/social/clubs/:clubId/join-requests',
    { params: { clubId: '31' } },
  );
  const approval = await call(
    routes,
    'PATCH /api/social/clubs/:clubId/join-requests/:userId',
    {
      params: { clubId: '31', userId: '42' },
      body: { action: 'approve' },
    },
  );

  assert.deepEqual(settings.body, { requiresJoinApproval: true });
  assert.equal(requests.body.requests[0].displayName, 'Alex Player');
  assert.deepEqual(approval.body, { approved: true });
  assert.equal(
    calls.some(({ sql, params }) =>
      sql.includes("SET membership_status = 'approved'") &&
      params[0] === 31 &&
      params[1] === 42,
    ),
    true,
  );
});

test('club owners can edit details and safely remove the previous logo', async () => {
  const calls = [];
  const connection = {
    async beginTransaction() {},
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('SELECT logo_image AS logoImage')) {
        return [[{
          logoImage: 'gcs://social-posts/7/11111111-1111-4111-8111-111111111111.png',
        }], []];
      }
      return [{ affectedRows: 1 }, []];
    },
    async commit() {},
    async rollback() {},
    release() {},
  };
  const routes = createRouteHarness({
    async getConnection() {
      return connection;
    },
  }, {
    mediaStorage: {
      async signImages(images) {
        assert.deepEqual(images, [
          'gcs://social-posts/7/11111111-1111-4111-8111-111111111111.png',
        ]);
        return ['https://storage.googleapis.com/club-logo.png'];
      },
    },
  });

  const result = await call(routes, 'PATCH /api/social/clubs/:clubId', {
    params: { clubId: '31' },
    body: { name: 'Updated Club', description: 'Updated details.' },
  });

  assert.equal(result.body.club.name, 'Updated Club');
  assert.equal(result.body.club.logoUrl, 'https://storage.googleapis.com/club-logo.png');
  assert.deepEqual(
    calls.find(({ sql }) => sql.includes('SET name = ?')).params,
    ['Updated Club', 'Updated details.', 'gcs://social-posts/7/11111111-1111-4111-8111-111111111111.png', 31, 7],
  );
});

test('club deletion removes the club transactionally and cleans up its media', async () => {
  const calls = [];
  let cleanedImages;
  const connection = {
    async beginTransaction() {},
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('SELECT logo_image AS logoImage')) {
        return [[{ logoImage: 'gcs://social-posts/7/logo.png' }], []];
      }
      if (sql.includes('SELECT images_json AS imagesJson')) {
        return [[{ imagesJson: JSON.stringify(['gcs://social-posts/7/post.png']) }], []];
      }
      return [{ affectedRows: 1 }, []];
    },
    async commit() {
      calls.push({ sql: 'commit' });
    },
    async rollback() {},
    release() {},
  };
  const routes = createRouteHarness({
    async getConnection() {
      return connection;
    },
  }, {
    mediaStorage: {
      async deleteImages(images) {
        cleanedImages = images;
      },
    },
  });

  const result = await call(routes, 'DELETE /api/social/clubs/:clubId', {
    params: { clubId: '31' },
  });

  assert.deepEqual(result.body, { deleted: true });
  assert.deepEqual(cleanedImages, [
    'gcs://social-posts/7/logo.png',
    'gcs://social-posts/7/post.png',
  ]);
  assert.ok(calls.some(({ sql }) => sql.startsWith('DELETE FROM social_clubs')));
  assert.ok(calls.some(({ sql }) => sql === 'commit'));
});
