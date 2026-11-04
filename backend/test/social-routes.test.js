const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  MAX_POSTS_PER_24_HOURS,
  registerSocialRoutes,
  validateImages,
} = require('../src/routes/social_routes');

function createRouteHarness(pool, options = {}) {
  const routes = new Map();
  const app = {
    get(path, ...handlers) {
      routes.set(`GET ${path}`, handlers);
    },
    post(path, ...handlers) {
      routes.set(`POST ${path}`, handlers);
    },
    delete(path, ...handlers) {
      routes.set(`DELETE ${path}`, handlers);
    },
    patch(path, ...handlers) {
      routes.set(`PATCH ${path}`, handlers);
    },
  };
  registerSocialRoutes({
    app,
    pool,
    ...options,
    requireAuth(req, res, next) {
      if (!req.headers.authorization) {
        return res.status(401).json({ error: 'Authentication required.' });
      }
      return next();
    },
  });
  return routes;
}

function response() {
  return {
    statusCode: 200,
    body: undefined,
    set() {
      return this;
    },
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
  const req = {
    auth: { sub: 7, role: 'customer' },
    body: {},
    params: {},
    query: {},
    headers: { authorization: 'Bearer test-token' },
    ...request,
  };
  const handlers = routes.get(key);
  let index = 0;
  const next = (error) => {
    if (error) throw error;
    const handler = handlers[index++];
    return handler?.(req, res, next);
  };
  await next();
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
  const tenMiBPhoto = `data:image/jpeg;base64,${Buffer.concat([
    Buffer.from([0xff, 0xd8, 0xff]),
    Buffer.alloc(10 * 1024 * 1024 - 3),
  ]).toString('base64')}`;
  assert.equal(validateImages([tenMiBPhoto]).valid, true);
  const oversizedPhoto = `data:image/jpeg;base64,${Buffer.concat([
    Buffer.from([0xff, 0xd8, 0xff]),
    Buffer.alloc(10 * 1024 * 1024 - 2),
  ]).toString('base64')}`;
  assert.equal(validateImages([oversizedPhoto]).valid, false);
  assert.equal(
    validateImages(['https://media.tenor.com/hash/sports.gif']).valid,
    true,
  );
  assert.equal(
    validateImages(['https://media.tenor.com:8443/hash/sports.gif']).valid,
    false,
  );
  assert.equal(validateImages(null).valid, true);
});

test('creates an authenticated upload URL only for bounded supported photos', async () => {
  const uploadCalls = [];
  const routes = createRouteHarness({}, {
    mediaStorage: {
      async createUpload(...args) {
        uploadCalls.push(args);
        return {
          uploadUrl: 'https://storage.googleapis.com/test-bucket/upload',
          key: 'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-1024',
          headers: { 'Content-Type': 'image/png' },
        };
      },
    },
  });
  const valid = await call(routes, 'POST /api/social/uploads', {
    body: { contentType: 'image/png', size: 1024 },
  });
  const invalid = await call(routes, 'POST /api/social/uploads', {
    body: { contentType: 'image/svg+xml', size: 1024 },
  });

  assert.equal(valid.statusCode, 201);
  assert.match(valid.body.uploadUrl, /^https:\/\/storage\.googleapis\.com\//);
  assert.equal(invalid.statusCode, 400);
  assert.deepEqual(uploadCalls, [[7, 'image/png', 1024]]);

  const unconfigured = createRouteHarness({});
  const unavailable = await call(unconfigured, 'POST /api/social/uploads', {
    body: { contentType: 'image/png', size: 1024 },
  });
  assert.equal(unavailable.statusCode, 503);
});

test('social feeds return expiring read URLs for stored media keys', async () => {
  const mediaKey = 'gcs://social-posts/42/11111111-1111-4111-8111-111111111111.png';
  const readUrl = 'https://storage.googleapis.com/test-bucket/photo?signature=read';
  const routes = createRouteHarness({
    async execute(sql) {
      if (sql.includes('FROM social_posts p')) {
        return [[{
          id: 20,
          userId: 42,
          caption: 'Community experience',
          imagesJson: JSON.stringify([mediaKey]),
          createdAt: new Date('2026-10-26T08:00:00.000Z'),
          firstName: 'Alex',
          lastName: 'Player',
          role: 'customer',
        }], []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  }, {
    mediaStorage: {
      async signImages(images) {
        assert.deepEqual(images, [mediaKey]);
        return [readUrl];
      },
    },
  });

  const result = await call(routes, 'GET /api/social/feed', {
    query: { scope: 'public' },
  });

  assert.equal(result.statusCode, 200);
  assert.deepEqual(result.body.posts[0].images, [readUrl]);
});

test('social notifications are scoped to the signed-in user and include unread count', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('COUNT(*) AS unreadCount')) {
        return [[{ unreadCount: 2 }], []];
      }
      if (sql.includes('FROM social_notifications n')) {
        return [[{
          id: 8,
          type: 'comment',
          postId: 35,
          postOwnerId: 7,
          actorUserId: 12,
          actorFirstName: 'Alex',
          actorLastName: 'Player',
          actorAvatarUrl: null,
          postCaption: 'Game day',
          commentText: 'Great game!',
          createdAt: new Date('2026-10-28T08:00:00.000Z'),
          readAt: null,
        }], []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  });

  const res = await call(routes, 'GET /api/social/notifications', {});

  assert.equal(res.body.unreadCount, 2);
  assert.deepEqual(res.body.notifications[0], {
    id: 8,
    type: 'comment',
    postId: 35,
    postOwnerId: 7,
    actorUserId: 12,
    actorFirstName: 'Alex',
    actorLastName: 'Player',
    actorAvatarUrl: null,
    postCaption: 'Game day',
    commentText: 'Great game!',
    createdAt: '2026-10-28T08:00:00.000Z',
    readAt: null,
  });
  assert.deepEqual(calls.map(({ params }) => params), [[7], [7]]);
  assert.match(calls[0].sql, /n\.recipient_user_id = \?/);
  assert.match(calls[1].sql, /n\.recipient_user_id = \?/);
  assert.match(calls[1].sql, /FROM user_blocks/);
});

test('notification read updates are limited to the authenticated user', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      return [{ affectedRows: 1 }, []];
    },
  });

  const readOne = await call(
    routes,
    'PATCH /api/social/notifications/:notificationId/read',
    { params: { notificationId: '8' } },
  );
  assert.deepEqual(readOne.body, { read: true });
  assert.deepEqual(calls[0].params, [8, 7]);
  assert.match(calls[0].sql, /WHERE id = \? AND recipient_user_id = \?/);

  const readAll = await call(routes, 'POST /api/social/notifications/read-all', {});
  assert.deepEqual(readAll.body, { read: true });
  assert.deepEqual(calls[1].params, [7]);
  assert.match(calls[1].sql, /WHERE recipient_user_id = \? AND read_at IS NULL/);
});

test('comments, reactions, and follows create recipient-specific notifications', async () => {
  const notifications = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      if (sql.includes('SELECT p.id')) {
        return [[{ id: 35, ownerId: 42 }], []];
      }
      if (sql.includes('SELECT id FROM users')) return [[{ id: 42 }], []];
      if (sql.includes('INSERT INTO social_post_comments')) {
        return [{ insertId: 91 }, []];
      }
      if (sql.includes('INSERT IGNORE INTO social_post_likes')) {
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes('INSERT IGNORE INTO user_follows')) {
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes('INSERT IGNORE INTO social_notifications')) {
        notifications.push(params);
        return [{ affectedRows: 1 }, []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  });

  await call(routes, 'POST /api/social/posts/:postId/comments', {
    params: { postId: '35' },
    body: { text: 'Great game!' },
  });
  await call(routes, 'POST /api/social/posts/:postId/likes', {
    params: { postId: '35' },
  });
  await call(routes, 'POST /api/social/follows/:userId', {
    params: { userId: '42' },
  });

  assert.deepEqual(notifications, [
    [42, 7, 'comment', 35, 91],
    [42, 7, 'like', 35, 35],
    [42, 7, 'follow', null, 42],
  ]);
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
          hobby: 'Tennis, Hiking',
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
  assert.equal(res.body.profile.hobby, 'Tennis, Hiking');
  const profileQuery = calls.find(({ sql }) => sql.includes('postsCount'));
  assert.match(profileQuery.sql, /u\.hobby/);
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
    [7, 7, 7, 7, 7],
    [7, 7, 7, 7, 7],
  ]);
});

test('guests can read public feed, search results, profiles, and connections', async () => {
  const routes = createRouteHarness({
    async execute(sql) {
      if (sql.includes('FROM social_posts p')) {
        return [[{
          id: 19,
          userId: 42,
          caption: 'Public match',
          imagesJson: '[]',
          createdAt: new Date('2026-05-01T12:00:00.000Z'),
          firstName: 'Alex',
          lastName: 'Player',
          role: 'customer',
        }], []];
      }
      if (sql.includes('postsCount')) {
        return [[{
          id: 42,
          firstName: 'Alex',
          lastName: 'Player',
          role: 'customer',
          followersCount: 4,
          followingCount: 2,
          postsCount: 1,
        }], []];
      }
      if (sql.includes('FROM social_posts')) return [[], []];
      if (sql.includes('FROM merchant_businesses b')) return [[], []];
      if (sql.includes('FROM user_follows f')) {
        return [[{
          id: 42,
          firstName: 'Alex',
          lastName: 'Player',
          role: 'customer',
          followersCount: 4,
        }], []];
      }
      if (sql.includes('FROM users u')) {
        return [[{
          id: 42,
          firstName: 'Alex',
          lastName: 'Player',
          role: 'customer',
          followersCount: 4,
          isFollowing: 0,
        }], []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  });

  test('authenticated public feed includes all posts but keeps block filtering', async () => {
    let feedQuery;
    const routes = createRouteHarness({
      async execute(sql, params) {
        if (sql.includes('FROM social_posts p')) {
          feedQuery = { sql, params };
          return [[{
            id: 20,
            userId: 42,
            caption: 'Community experience',
            imagesJson: '[]',
            createdAt: new Date('2026-10-26T08:00:00.000Z'),
            firstName: 'Alex',
            lastName: 'Player',
            role: 'customer',
          }], []];
        }
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    });

    const result = await call(routes, 'GET /api/social/feed', {
      query: { scope: 'public' },
    });

    assert.equal(result.statusCode, 200);
    assert.equal(result.body.posts[0].caption, 'Community experience');
    assert.match(feedQuery.sql, /\? = 'public'/);
    assert.match(feedQuery.sql, /FROM user_blocks b/);
    assert.deepEqual(feedQuery.params, [
      7,
      7,
      'public',
      'public',
      7,
      7,
      7,
      'public',
      7,
      7,
      7,
      7,
      7,
      7,
      '',
      '',
      null,
      null,
      21,
    ]);
  });

  test('public feed search matches post captions and author names', async () => {
    let feedQuery;
    const routes = createRouteHarness({
      async execute(sql, params) {
        if (sql.includes('FROM social_posts p')) {
          feedQuery = { sql, params };
          return [[], []];
        }
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    });

    const result = await call(routes, 'GET /api/social/feed', {
      query: { scope: 'public', q: '  Alex   match  ' },
    });

    assert.equal(result.statusCode, 200);
    assert.match(feedQuery.sql, /CONCAT_WS\(' ', u\.first_name, u\.last_name, p\.caption\)/);
    assert.deepEqual(feedQuery.params.slice(-5, -3), ['Alex match', 'Alex match']);
  });

  test('following feed only returns posts from followed users', async () => {
    let feedQuery;
    const routes = createRouteHarness({
      async execute(sql, params) {
        if (sql.includes('FROM social_posts p')) {
          feedQuery = { sql, params };
          return [[], []];
        }
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    });

    const result = await call(routes, 'GET /api/social/feed', {
      query: { scope: 'following' },
    });

    assert.equal(result.statusCode, 200);
    assert.match(feedQuery.sql, /\? = 'following'/);
    assert.match(feedQuery.sql, /p\.user_id <> \?/);
    assert.match(feedQuery.sql, /f\.follower_id = \? AND f\.followed_id = p\.user_id/);
    assert.deepEqual(feedQuery.params, [
      7,
      7,
      'following',
      'following',
      7,
      7,
      7,
      'following',
      7,
      7,
      7,
      7,
      7,
      7,
      '',
      '',
      null,
      null,
      21,
    ]);
  });

  test('social feed supports bounded cursor pagination', async () => {
    let feedQuery;
    const routes = createRouteHarness({
      async execute(sql, params) {
        if (sql.includes('FROM social_posts p')) {
          feedQuery = { sql, params };
          return [[], []];
        }
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    });

    const result = await call(routes, 'GET /api/social/feed', {
      query: { before_id: '42', limit: '75' },
    });

    assert.equal(result.statusCode, 200);
    assert.match(feedQuery.sql, /p\.id < \?/);
    assert.deepEqual(feedQuery.params.slice(-3), [42, 42, 51]);
    assert.deepEqual(result.body, {
      posts: [],
      hasMore: false,
      nextCursor: null,
    });
  });

  test('social feed rejects malformed pagination inputs', async () => {
    const routes = createRouteHarness({
      async execute() {
        throw new Error('Invalid pagination must not query the database.');
      },
    });

    const invalidLimit = await call(routes, 'GET /api/social/feed', {
      query: { limit: '0' },
    });
    const invalidCursor = await call(routes, 'GET /api/social/feed', {
      query: { before_id: 'not-an-id' },
    });

    assert.equal(invalidLimit.statusCode, 400);
    assert.equal(invalidCursor.statusCode, 400);
  });

  test('guests cannot request the following feed', async () => {
    const routes = createRouteHarness({
      async execute() {
        throw new Error('The following feed must require authentication.');
      },
    });
    const result = await call(routes, 'GET /api/social/feed', {
      query: { scope: 'following' },
      auth: null,
      headers: {},
    });

    assert.equal(result.statusCode, 401);
    assert.match(result.body.error, /Sign in/);
  });

  const guestRequest = { headers: {}, auth: undefined };
  const feed = await call(routes, 'GET /api/social/feed', guestRequest);
  assert.equal(feed.statusCode, 200);
  assert.equal(feed.body.posts[0].caption, 'Public match');

  const users = await call(routes, 'GET /api/social/users', guestRequest);
  assert.equal(users.statusCode, 200);
  assert.equal(users.body.users[0].displayName, 'Alex Player');
  assert.equal(users.body.users[0].isFollowing, false);

  const profile = await call(routes, 'GET /api/social/users/:userId', {
    ...guestRequest,
    params: { userId: '42' },
  });
  assert.equal(profile.statusCode, 200);
  assert.equal(profile.body.profile.displayName, 'Alex Player');

  const connections = await call(
    routes,
    'GET /api/social/users/:userId/followers',
    { ...guestRequest, params: { userId: '42' } },
  );
  assert.equal(connections.statusCode, 200);
  assert.equal(connections.body.users[0].displayName, 'Alex Player');
});

test('guests cannot create posts or change follows', async () => {
  const routes = createRouteHarness({
    async execute() {
      throw new Error('Unauthenticated mutations must not query the database.');
    },
    async getConnection() {
      throw new Error('Unauthenticated mutations must not open a transaction.');
    },
  });

  const guestRequest = { headers: {}, auth: undefined };
  const post = await call(routes, 'POST /api/social/posts', {
    ...guestRequest,
    body: { caption: 'Guest post', images: [] },
  });
  assert.equal(post.statusCode, 401);

  const follow = await call(routes, 'POST /api/social/follows/:userId', {
    ...guestRequest,
    params: { userId: '42' },
  });
  assert.equal(follow.statusCode, 401);

  const unfollow = await call(routes, 'DELETE /api/social/follows/:userId', {
    ...guestRequest,
    params: { userId: '42' },
  });
  assert.equal(unfollow.statusCode, 401);
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
      if (sql.includes('INSERT IGNORE INTO social_notifications')) {
        return [{ affectedRows: 1 }, []];
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
  const newPostNotifications = calls.find(({ sql }) =>
    sql.includes('INSERT IGNORE INTO social_notifications'),
  );
  assert.ok(newPostNotifications);
  assert.match(newPostNotifications.sql, /FROM user_follows f/);
  assert.match(newPostNotifications.sql, /FROM user_blocks b/);
  assert.deepEqual(newPostNotifications.params, [7, 35, 35, 7, 7, 7]);
});

test('promotes owned staged photos before storing a post', async () => {
  const calls = [];
  const stagedKey =
    'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-68';
  const postKey = 'gcs://social-posts/7/22222222-2222-4222-8222-222222222222.png';
  let committed = false;
  const connection = {
    async beginTransaction() {},
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('FROM users')) return [[{ id: 7 }], []];
      if (sql.includes('FROM social_posts')) return [[{ postCount: 0 }], []];
      if (sql.includes('INSERT INTO social_posts')) return [{ insertId: 36 }, []];
      if (sql.includes('INSERT IGNORE INTO social_notifications')) {
        return [{ affectedRows: 0 }, []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
    async rollback() {
      throw new Error('A valid post must not roll back.');
    },
    async commit() {
      committed = true;
    },
    release() {},
  };
  const routes = createRouteHarness({
    async getConnection() {
      return connection;
    },
  }, {
    mediaStorage: {
      async promoteUpload(key, userId) {
        assert.equal(key, stagedKey);
        assert.equal(userId, 7);
        return postKey;
      },
      async signImages(images) {
        assert.deepEqual(images, [postKey]);
        return ['https://storage.googleapis.com/test-bucket/photo?signature=read'];
      },
      async deleteImages() {
        throw new Error('Committed media must not be deleted.');
      },
    },
  });

  const res = await call(routes, 'POST /api/social/posts', {
    body: { caption: 'A new match', images: [stagedKey] },
  });

  assert.equal(res.statusCode, 201);
  assert.deepEqual(res.body.images, [
    'https://storage.googleapis.com/test-bucket/photo?signature=read',
  ]);
  assert.deepEqual(
    JSON.parse(calls.find(({ sql }) => sql.includes('INSERT INTO social_posts')).params[2]),
    [postKey],
  );
  assert.equal(committed, true);
});

test('rejects staged photos that do not belong to the authenticated user', async () => {
  let databaseRequested = false;
  const routes = createRouteHarness({
    async getConnection() {
      databaseRequested = true;
      throw new Error('An unverified upload must not acquire a connection.');
    },
  }, {
    mediaStorage: {
      async promoteUpload() {
        return null;
      },
      async deleteImages() {},
    },
  });

  const res = await call(routes, 'POST /api/social/posts', {
    body: {
      caption: 'A new match',
      images: [
        'gcs://social-media-staging/7/11111111-1111-4111-8111-111111111111-68',
      ],
    },
  });

  assert.equal(res.statusCode, 400);
  assert.equal(databaseRequested, false);
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

test('rejects legacy base64 photos when compatibility mode is disabled', async () => {
  let connectionRequested = false;
  const routes = createRouteHarness({
    async getConnection() {
      connectionRequested = true;
      throw new Error('Rejected legacy content must not acquire a connection.');
    },
  }, {
    allowLegacyBase64: false,
  });

  const res = await call(routes, 'POST /api/social/posts', {
    body: { caption: 'A new match', images: [pngDataUrl] },
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

  test('creates a post comment after verifying visibility and rejects untrusted GIF hosts', async () => {
    const calls = [];
    const routes = createRouteHarness({
      async execute(sql, params) {
        calls.push({ sql, params });
        if (sql.includes('SELECT p.id')) {
          return [[{ id: 35, ownerId: 42 }], []];
        }
        if (sql.includes('INSERT INTO social_post_comments')) {
          return [{ insertId: 91 }, []];
        }
        if (sql.includes('INSERT IGNORE INTO social_notifications')) {
          return [{ affectedRows: 1 }, []];
        }
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    });
    const res = await call(routes, 'POST /api/social/posts/:postId/comments', {
      params: { postId: '35' },
      body: { text: 'Great game! 😀', gifUrl: 'https://media.tenor.com/a1/test.gif' },
    });
    assert.equal(res.statusCode, 201);
    assert.deepEqual(res.body, {
      id: 91,
      postId: 35,
      userId: 7,
      text: 'Great game! 😀',
      gifUrl: 'https://media.tenor.com/a1/test.gif',
    });
    assert.deepEqual(calls[1].params, [
      35,
      7,
      'Great game! 😀',
      'https://media.tenor.com/a1/test.gif',
    ]);
    assert.deepEqual(calls[2].params, [42, 7, 'comment', 35, 91]);

    const invalid = await call(routes, 'POST /api/social/posts/:postId/comments', {
      params: { postId: '35' },
      body: { text: '', gifUrl: 'https://example.com/test.gif' },
    });
    assert.equal(invalid.statusCode, 400);
    assert.equal(calls.length, 3);
  });

  test('likes and saves are idempotent and require a visible post', async () => {
    const calls = [];
    const routes = createRouteHarness({
      async execute(sql, params) {
        calls.push({ sql, params });
        if (sql.includes('SELECT p.id')) return [[{ id: 35 }], []];
        if (sql.includes('INSERT IGNORE INTO social_post_likes')) return [{}, []];
        if (sql.includes('DELETE FROM social_saved_posts')) return [{}, []];
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    });
    const liked = await call(routes, 'POST /api/social/posts/:postId/likes', {
      params: { postId: '35' },
    });
    assert.deepEqual(liked.body, { isLiked: true });
    const unsaved = await call(routes, 'DELETE /api/social/posts/:postId/saves', {
      params: { postId: '35' },
    });
    assert.deepEqual(unsaved.body, { isSaved: false });
    assert.equal(calls.length, 3);
  });

  test('reports a visible post once and validates the report reason', async () => {
    const calls = [];
    const routes = createRouteHarness({
      async execute(sql, params) {
        calls.push({ sql, params });
        if (sql.includes('SELECT p.id')) return [[{ id: 35 }], []];
        if (sql.includes('INSERT IGNORE INTO social_post_reports')) {
          return [{ affectedRows: 1 }, []];
        }
        throw new Error(`Unexpected SQL: ${sql}`);
      },
    });

    const reported = await call(
      routes,
      'POST /api/social/posts/:postId/reports',
      {
        params: { postId: '35' },
        body: { reason: 'spam' },
      },
    );
    assert.equal(reported.statusCode, 201);
    assert.deepEqual(reported.body, { reported: true });
    assert.deepEqual(calls[1].params, [35, 7, 'spam']);

    const invalid = await call(
      routes,
      'POST /api/social/posts/:postId/reports',
      {
        params: { postId: '35' },
        body: { reason: 'not-a-reason' },
      },
    );
    assert.equal(invalid.statusCode, 400);
    assert.equal(calls.length, 2);
  });

  test('Tenor GIF search keeps its API key server-side and returns approved media URLs', async () => {
    let requestedUrl;
    const routes = createRouteHarness(
      { async execute() { throw new Error('GIF search should not query SQL.'); } },
      {
        tenorApiKey: 'server-secret',
        async fetchImpl(url) {
          requestedUrl = new URL(url);
          return {
            ok: true,
            async json() {
              return {
                results: [
                  {
                    content_description: 'Sports',
                    media_formats: {
                      tinygif: { url: 'https://media.tenor.com/hash/sports.gif' },
                    },
                  },
                  {
                    media_formats: {
                      tinygif: { url: 'https://example.com/not-a-tenor.gif' },
                    },
                  },
                ],
              };
            },
          };
        },
      },
    );
    const res = await call(routes, 'GET /api/social/gifs', {
      query: { q: 'sports' },
      auth: null,
      headers: {},
    });
    assert.equal(requestedUrl.searchParams.get('key'), 'server-secret');
    assert.deepEqual(res.body.gifs, [
      { url: 'https://media.tenor.com/hash/sports.gif', title: 'Sports' },
    ]);
  });

  const res = await call(routes, 'POST /api/social/follows/:userId', {
    params: { userId: '42' },
  });

  assert.equal(res.statusCode, 200);
  assert.deepEqual(res.body, { isFollowing: true });
  assert.equal(calls.length, 2);
  assert.deepEqual(calls[1].params, [7, 42]);
});

test('social post comments include reviewer profiles, relative-time data, and replies', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('SELECT p.id')) return [[{ id: 35, ownerId: 42 }], []];
      if (sql.includes('FROM social_post_comments c')) {
        return [[{
          id: 91,
          text: 'Great game!',
          gifUrl: null,
          createdAt: '2026-11-02 08:00:00',
          userId: 12,
          firstName: 'Alex',
          lastName: 'Player',
          avatarUrl: 'https://example.com/avatar.png',
          reactionCount: 2,
          reactedByMe: 1,
        }], []];
      }
      if (sql.includes('FROM social_post_comment_replies r')) {
        return [[{
          id: 92,
          commentId: 91,
          text: 'Thanks!',
          createdAt: '2026-11-02 08:01:00',
          userId: 13,
          firstName: 'Sam',
          lastName: 'Player',
          avatarUrl: 'https://example.com/reply-avatar.png',
        }], []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  });

  const response = await call(
    routes,
    'GET /api/social/posts/:postId/comments',
    { params: { postId: '35' } },
  );

  assert.equal(response.statusCode, 200);
  assert.equal(response.body.comments[0].displayName, 'Alex Player');
  assert.equal(response.body.comments[0].avatarUrl, 'https://example.com/avatar.png');
  assert.equal(response.body.comments[0].reactionCount, 2);
  assert.equal(response.body.comments[0].reactedByMe, 1);
  assert.equal(response.body.comments[0].replies[0].displayName, 'Sam Player');
  assert.equal(
    response.body.comments[0].replies[0].avatarUrl,
    'https://example.com/reply-avatar.png',
  );
  assert.equal(typeof response.body.comments[0].createdAt, 'string');
  assert.equal(typeof response.body.comments[0].replies[0].createdAt, 'string');
  assert.deepEqual(calls[2].params, [91, 7, 7, 7]);
});

test('social post comment reactions and replies are scoped and validated', async () => {
  const calls = [];
  const routes = createRouteHarness({
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('SELECT p.id')) return [[{ id: 35, ownerId: 42 }], []];
      if (sql.includes('SELECT c.id, c.user_id AS ownerId')) {
        return [[{ id: 91, ownerId: 12 }], []];
      }
      if (sql.includes('INSERT IGNORE INTO social_post_comment_reactions')) {
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes('DELETE FROM social_post_comment_reactions')) {
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes('INSERT INTO social_post_comment_replies')) {
        return [{ insertId: 93 }, []];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  });
  const params = {
    postId: '35',
    commentId: '91',
  };

  const reacted = await call(
    routes,
    'POST /api/social/posts/:postId/comments/:commentId/reactions',
    { params },
  );
  assert.deepEqual(reacted.body, { reactedByMe: true });

  const unreacted = await call(
    routes,
    'DELETE /api/social/posts/:postId/comments/:commentId/reactions',
    { params },
  );
  assert.deepEqual(unreacted.body, { reactedByMe: false });

  const reply = await call(
    routes,
    'POST /api/social/posts/:postId/comments/:commentId/replies',
    { params, body: { text: '  Well played!  ' } },
  );
  assert.equal(reply.statusCode, 201);
  assert.deepEqual(reply.body, {
    id: 93,
    commentId: 91,
    userId: 7,
    text: 'Well played!',
  });

  const invalid = await call(
    routes,
    'POST /api/social/posts/:postId/comments/:commentId/replies',
    { params, body: { text: ' '.repeat(2) } },
  );
  assert.equal(invalid.statusCode, 400);
  assert.equal(calls.filter(({ sql }) => sql.includes('SELECT p.id')).length, 3);
});
