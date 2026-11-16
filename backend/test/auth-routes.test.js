const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
const crypto = require('node:crypto');
const Module = require('node:module');
const path = require('node:path');
const express = require('express');
const jwt = require('jsonwebtoken');

const serverFile = path.join(__dirname, '..', 'src', 'server.js');
const originalLoad = Module._load;
const originalListen = express.application.listen;
let server;
let accessToken;
let originalJwtSecret;
let originalGoogleClientId;
let originalFetch;
let onboardingUser;
let googleSuspendedUser;
let authUserStatus;
let invalidateUserStatusCache;
let refreshSessions;

before(async () => {
  originalJwtSecret = process.env.JWT_SECRET;
  originalGoogleClientId = process.env.GOOGLE_CLIENT_ID;
  originalFetch = global.fetch;
  process.env.JWT_SECRET = 'backend-test-only-secret';
  process.env.GOOGLE_CLIENT_ID = 'backend-test-google-client';
  authUserStatus = 'active';
  refreshSessions = new Map();
  googleSuspendedUser = {
    id: 99,
    email: 'suspended@example.test',
    first_name: 'Taylor',
    last_name: null,
    role: 'customer',
    status: 'suspended',
  };
  global.fetch = async () => ({
    ok: true,
    json: async () => ({
      aud: 'backend-test-google-client',
      email: 'suspended@example.test',
      email_verified: true,
      given_name: 'Taylor',
      sub: 'google-subject-99',
    }),
  });

  const fakePool = {
    execute: async (sql, params = []) => {
      if (sql.includes('UPDATE refresh_tokens') && sql.includes('WHERE token_hash')) {
        const row = refreshSessions.get(params[0]);
        if (row && !row.revoked_at) row.revoked_at = new Date();
        return [{ affectedRows: row ? 1 : 0 }, []];
      }
      if (sql.includes('INSERT INTO refresh_tokens')) {
        const id = refreshSessions.size + 1;
        refreshSessions.set(params[1], {
          id,
          refresh_token_id: id,
          user_id: params[0],
          revoked_at: null,
          is_unexpired: 1,
          email: 'customer@example.test',
          first_name: 'Sam',
          last_name: null,
          role: 'customer',
          status: 'active',
          gender: null,
          player_type: null,
          onboarding_completed: 0,
        });
        return [{ affectedRows: 1, insertId: id }, []];
      }
      if (sql.includes('SELECT status FROM users WHERE id = ? LIMIT 1')) {
        return [[{ status: authUserStatus }], []];
      }
      if (sql.includes('FROM users WHERE email = ? LIMIT 1')) {
        return params[0] === googleSuspendedUser.email
          ? [[googleSuspendedUser], []]
          : [[], []];
      }
      if (sql.includes('UPDATE users SET status = ?')) {
        googleSuspendedUser.status = params[0];
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes('SELECT role, status FROM users WHERE id = ? LIMIT 1')) {
        return params[0] === '88'
          ? [[{ role: 'merchant', status: 'active' }], []]
          : params[0] === '42'
          ? [[{ role: 'customer', status: 'active' }], []]
          : [[], []];
      }
      if (
        sql.includes('SELECT id, email, role, status') &&
        sql.includes('FROM users')
      ) {
        if (params[0] === '88') {
          return [[{
            id: 88,
            email: 'merchant@example.test',
            role: 'merchant',
            status: 'active',
          }], []];
        }
        return params[0] === '42'
          ? [[{
            id: 42,
            email: 'customer@example.test',
            role: 'customer',
            status: 'active',
          }], []]
          : [[], []];
      }
      if (sql.includes('UPDATE users') && sql.includes('onboarding_completed = 1')) {
        onboardingUser = {
          ...onboardingUser,
          gender: params[0],
          player_type: params[1],
          hobby: params[2],
          onboarding_completed: 1,
        };
        return [{ affectedRows: 1 }, []];
      }
      if (sql.includes('FROM users WHERE id = ? LIMIT 1')) {
        return onboardingUser ? [[onboardingUser], []] : [[], []];
      }
      if (sql.includes('FROM venue_hearts WHERE user_id = ?')) return [[], []];
      return [[], []];
    },
    getConnection: async () => ({
      beginTransaction: async () => {},
      commit: async () => {},
      rollback: async () => {},
      release: () => {},
      execute: async (sql, params = []) => {
        if (sql.includes('FROM refresh_tokens rt')) {
          const row = refreshSessions.get(params[0]);
          return [row ? [{ ...row }] : [], []];
        }
        if (sql.includes('UPDATE refresh_tokens') && sql.includes('WHERE id = ?')) {
          const row = [...refreshSessions.values()].find(
            (value) => value.id === params[0],
          );
          if (row && !row.revoked_at) {
            row.revoked_at = new Date();
            return [{ affectedRows: 1 }, []];
          }
          return [{ affectedRows: 0 }, []];
        }
        if (sql.includes('INSERT INTO refresh_tokens')) {
          const id = refreshSessions.size + 1;
          refreshSessions.set(params[1], {
            id,
            refresh_token_id: id,
            user_id: params[0],
            revoked_at: null,
            is_unexpired: 1,
            email: 'customer@example.test',
            first_name: 'Sam',
            last_name: null,
            role: 'customer',
            status: 'active',
            gender: null,
            player_type: null,
            onboarding_completed: 0,
          });
          return [{ affectedRows: 1, insertId: id }, []];
        }
        return [[], []];
      },
    }),
    query: async () => [[], []],
  };
  let resolveListening;
  const listening = new Promise((resolve) => {
    resolveListening = resolve;
  });

  Module._load = function (request, parent, isMain) {
    if (request === 'dotenv' && parent.filename === serverFile) {
      return { config: () => ({}) };
    }
    if (request === './db' && parent.filename === serverFile) {
      return fakePool;
    }
    return originalLoad.call(this, request, parent, isMain);
  };
  express.application.listen = function () {
    server = originalListen.call(this, 0, () => resolveListening());
    return server;
  };

  try {
    const serverExports = require(serverFile);
    invalidateUserStatusCache = serverExports.invalidateUserStatusCache;
    await listening;
  } finally {
    Module._load = originalLoad;
    express.application.listen = originalListen;
    global.fetch = originalFetch;
  }

  accessToken = jwt.sign({
    sub: '42',
    email: 'customer@example.test',
    role: 'customer',
  }, process.env.JWT_SECRET);
  onboardingUser = {
    id: 42,
    email: 'customer@example.test',
    first_name: 'Sam',
    last_name: null,
    role: 'customer',
    status: 'active',
  };
});

after(async () => {
  if (server) {
    await new Promise((resolve, reject) => {
      server.close((error) => error ? reject(error) : resolve());
    });
  }
  if (originalJwtSecret === undefined) delete process.env.JWT_SECRET;
  else process.env.JWT_SECRET = originalJwtSecret;
  if (originalGoogleClientId === undefined) delete process.env.GOOGLE_CLIENT_ID;
  else process.env.GOOGLE_CLIENT_ID = originalGoogleClientId;
});

test('protected routes reject requests without a bearer token', async () => {
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/me`,
  );

  assert.equal(response.status, 401);
  const body = await response.json();
  assert.equal(typeof body.error, 'string');
  assert.ok(body.error.length > 0);
});

test('refresh rotates the token and logout revokes the active session', async () => {
  const originalRefreshToken = crypto.randomBytes(32).toString('base64url');
  const originalHash = crypto
    .createHash('sha256')
    .update(originalRefreshToken)
    .digest('hex');
  refreshSessions.set(originalHash, {
    id: 1,
    refresh_token_id: 1,
    user_id: 42,
    revoked_at: null,
    is_unexpired: 1,
    email: 'customer@example.test',
    first_name: 'Sam',
    last_name: null,
    role: 'customer',
    status: 'active',
    gender: null,
    player_type: null,
    onboarding_completed: 0,
  });

  const refreshResponse = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/refresh`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: originalRefreshToken }),
    },
  );
  assert.equal(refreshResponse.status, 200);
  const refreshed = await refreshResponse.json();
  assert.match(refreshed.refreshToken, /^[A-Za-z0-9_-]{43}$/);
  const accessTokenPayload = jwt.decode(refreshed.token);
  assert.equal(accessTokenPayload.exp - accessTokenPayload.iat, 15 * 60);
  assert.ok(refreshSessions.get(originalHash).revoked_at);

  const replayResponse = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/refresh`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: originalRefreshToken }),
    },
  );
  assert.equal(replayResponse.status, 401);

  const logoutResponse = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/logout`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: refreshed.refreshToken }),
    },
  );
  assert.equal(logoutResponse.status, 204);
  const refreshedHash = crypto
    .createHash('sha256')
    .update(refreshed.refreshToken)
    .digest('hex');
  assert.ok(refreshSessions.get(refreshedHash).revoked_at);
});

test('refresh preserves the merchant customer-portal mode', async () => {
  const refreshToken = crypto.randomBytes(32).toString('base64url');
  const refreshHash = crypto
    .createHash('sha256')
    .update(refreshToken)
    .digest('hex');
  refreshSessions.set(refreshHash, {
    id: 700,
    refresh_token_id: 700,
    user_id: 88,
    revoked_at: null,
    is_unexpired: 1,
    email: 'merchant@example.test',
    first_name: 'Merchant',
    last_name: 'Owner',
    role: 'merchant',
    status: 'active',
    gender: null,
    player_type: null,
    onboarding_completed: 0,
  });

  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/refresh`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken, portalMode: 'customer' }),
    },
  );

  assert.equal(response.status, 200);
  const body = await response.json();
  const claims = jwt.verify(body.token, process.env.JWT_SECRET);
  assert.equal(claims.role, 'customer');
  assert.equal(claims.accountRole, 'merchant');
  assert.equal(claims.portalMode, 'customer');
  assert.equal(claims.portalVersion, 1);
});

test('authenticated routes reject accounts that became inactive after token issuance', async () => {
  authUserStatus = 'suspended';
  invalidateUserStatusCache('42');
  try {
    const response = await fetch(
      `http://127.0.0.1:${server.address().port}/api/auth/me`,
      { headers: { authorization: ['Bearer', accessToken].join(' ') } },
    );

    assert.equal(response.status, 403);
    assert.deepEqual(await response.json(), {
      error: 'This account is not active.',
    });
  } finally {
    authUserStatus = 'active';
    invalidateUserStatusCache('42');
  }
});

test('Google sign-in does not reactivate suspended accounts', async () => {
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/oauth/google`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ idToken: 'test-google-token' }),
    },
  );

  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), {
    error: 'This account is suspended.',
  });
  assert.equal(googleSuspendedUser.status, 'suspended');
});

test('merchant routes reject a valid token for an account without active merchant access', async () => {
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/merchant/news`,
    { headers: { authorization: `Bearer ${accessToken}` } },
  );

  assert.equal(response.status, 403);
  assert.deepEqual(await response.json(), {
    error: 'Only active merchant accounts can access this endpoint.',
  });
});

test('merchant accounts can enter a scoped customer portal without role escalation', async () => {
  const merchantToken = jwt.sign({
    sub: '88',
    email: 'merchant@example.test',
    role: 'merchant',
  }, process.env.JWT_SECRET);
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/portal-mode`,
    {
      method: 'POST',
      headers: {
        authorization: ['Bearer', merchantToken].join(' '),
        'content-type': 'application/json',
      },
      body: JSON.stringify({ mode: 'customer' }),
    },
  );

  assert.equal(response.status, 200);
  const portal = await response.json();
  assert.equal(portal.mode, 'customer');
  assert.equal(portal.user.role, 'customer');
  assert.equal(portal.user.accountRole, 'merchant');
  const portalClaims = jwt.verify(portal.token, process.env.JWT_SECRET);
  assert.equal(portalClaims.role, 'customer');
  assert.equal(portalClaims.accountRole, 'merchant');
  assert.equal(portalClaims.portalMode, 'customer');
  assert.equal(portalClaims.portalVersion, 1);
  const customerEndpoint = await fetch(
    `http://127.0.0.1:${server.address().port}/api/customer/venue-hearts`,
    { headers: { authorization: ['Bearer', portal.token].join(' ') } },
  );
  assert.equal(customerEndpoint.status, 200);
  const merchantEndpoint = await fetch(
    `http://127.0.0.1:${server.address().port}/api/merchant/news`,
    { headers: { authorization: ['Bearer', portal.token].join(' ') } },
  );
  assert.equal(merchantEndpoint.status, 403);

  const legacyCustomerToken = jwt.sign({
    sub: '88',
    email: 'merchant@example.test',
    role: 'customer',
    accountRole: 'merchant',
    portalMode: 'customer',
  }, process.env.JWT_SECRET);
  const legacyCustomerEndpoint = await fetch(
    `http://127.0.0.1:${server.address().port}/api/customer/venue-hearts`,
    { headers: { authorization: ['Bearer', legacyCustomerToken].join(' ') } },
  );
  assert.equal(legacyCustomerEndpoint.status, 403);
});

test('customer accounts cannot request a merchant portal token', async () => {
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/portal-mode`,
    {
      method: 'POST',
      headers: {
        authorization: ['Bearer', accessToken].join(' '),
        'content-type': 'application/json',
      },
      body: JSON.stringify({ mode: 'merchant' }),
    },
  );

  assert.equal(response.status, 403);
});

test('customer onboarding requires a supported gender choice', async () => {
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/onboarding`,
    {
      method: 'PUT',
      headers: {
        authorization: ['Bearer', accessToken].join(' '),
        'content-type': 'application/json',
      },
      body: JSON.stringify({ gender: 'unspecified' }),
    },
  );

  assert.equal(response.status, 400);
  assert.equal((await response.json()).error, 'One or more onboarding answers are invalid.');
});

test('customers can save onboarding answers and mark onboarding complete', async () => {
  const response = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/onboarding`,
    {
      method: 'PUT',
      headers: {
        authorization: ['Bearer', accessToken].join(' '),
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        gender: 'prefer_not_to_say',
        playerType: 'New player',
        hobby: 'Basketball, Badminton',
      }),
    },
  );

  assert.equal(response.status, 200);
  const { user } = await response.json();
  assert.equal(user.gender, 'prefer_not_to_say');
  assert.equal(user.playerType, 'New player');
  assert.equal(user.hobby, 'Basketball, Badminton');
  assert.equal(user.onboardingCompleted, true);
});
