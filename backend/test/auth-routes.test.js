const assert = require('node:assert/strict');
const { after, before, test } = require('node:test');
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

before(async () => {
  originalJwtSecret = process.env.JWT_SECRET;
  originalGoogleClientId = process.env.GOOGLE_CLIENT_ID;
  originalFetch = global.fetch;
  process.env.JWT_SECRET = 'backend-test-only-secret';
  process.env.GOOGLE_CLIENT_ID = 'backend-test-google-client';
  authUserStatus = 'active';
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
      if (sql.includes('SELECT id, email, role, status FROM users')) {
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
      if (sql.includes('SELECT role, status FROM users WHERE id = ?')) {
        return params[0] === '88'
          ? [[{ role: 'merchant', status: 'active' }], []]
          : [[], []];
      }
      if (sql.includes('FROM venue_hearts WHERE user_id = ?')) return [[], []];
      return [[], []];
    },
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
    require(serverFile);
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

test('authenticated routes reject accounts that became inactive after token issuance', async () => {
  authUserStatus = 'suspended';
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

test('merchants can switch into a customer portal without merchant privileges', async () => {
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
  const { token } = await response.json();
  const claims = jwt.verify(token, process.env.JWT_SECRET);
  assert.equal(claims.sub, '88');
  assert.equal(claims.role, 'customer');
  assert.equal(claims.accountRole, 'merchant');
  assert.equal(claims.portalMode, 'customer');

  const customerEndpoint = await fetch(
    `http://127.0.0.1:${server.address().port}/api/customer/venue-hearts`,
    { headers: { authorization: ['Bearer', token].join(' ') } },
  );
  assert.equal(customerEndpoint.status, 200);

  const merchantEndpoint = await fetch(
    `http://127.0.0.1:${server.address().port}/api/merchant/news`,
    { headers: { authorization: ['Bearer', token].join(' ') } },
  );
  assert.equal(merchantEndpoint.status, 403);

  const returnToMerchant = await fetch(
    `http://127.0.0.1:${server.address().port}/api/auth/portal-mode`,
    {
      method: 'POST',
      headers: {
        authorization: ['Bearer', token].join(' '),
        'content-type': 'application/json',
      },
      body: JSON.stringify({ mode: 'merchant' }),
    },
  );
  assert.equal(returnToMerchant.status, 200);
  const merchantMode = await returnToMerchant.json();
  const merchantClaims = jwt.verify(merchantMode.token, process.env.JWT_SECRET);
  assert.equal(merchantClaims.role, 'merchant');
  assert.equal(merchantClaims.accountRole, 'merchant');
  assert.equal(merchantClaims.portalMode, 'merchant');
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
