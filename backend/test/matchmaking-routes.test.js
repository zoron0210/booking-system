const assert = require('node:assert/strict');
const { test } = require('node:test');
const { registerMatchmakingRoutes } = require('../src/routes/matchmaking_routes');

function setup({ pool = {}, publishToUser = () => {} } = {}) {
  const routes = new Map();
  const roles = [];
  const app = {
    get: (path, ...handlers) => routes.set(`GET ${path}`, handlers),
    post: (path, ...handlers) => routes.set(`POST ${path}`, handlers),
    delete: (path, ...handlers) => routes.set(`DELETE ${path}`, handlers),
  };
  const requireAuth = () => {};
  const requireRole = (role) => {
    roles.push(role);
    return { role };
  };
  registerMatchmakingRoutes({
    app,
    pool,
    requireAuth,
    requireRole,
    publishToUser,
  });
  return { routes, requireAuth, roles };
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

function futureDate() {
  const date = new Date(Date.now() + 2 * 24 * 60 * 60 * 1000);
  return date.toISOString().slice(0, 10);
}

test('lobby routes require authenticated customer access', () => {
  const { routes, requireAuth, roles } = setup();
  const handlers = routes.get('GET /api/matchmaking/lobbies');

  assert.equal(handlers[0], requireAuth);
  assert.deepEqual(handlers[1], { role: 'customer' });
  assert.deepEqual(roles, ['customer', 'merchant']);
});

test('merchant approval is protected and starts the host downpayment deadline', async () => {
  const calls = [];
  const events = [];
  let committed = false;
  const connection = {
    async beginTransaction() {},
    async commit() {
      committed = true;
    },
    async rollback() {
      assert.fail('Unexpected rollback');
    },
    release() {},
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('FROM matchmaking_lobbies l')) {
        return [[{
          id: 17,
          hostUserId: 8,
          bookingId: 51,
          venueId: 4,
          status: 'pending_merchant_approval',
          venueName: 'North Courts',
          hostShareAmount: '125.00',
        }], []];
      }
      return [{ affectedRows: 1 }, []];
    },
  };
  const { routes, requireAuth } = setup({
    pool: { getConnection: async () => connection },
    publishToUser: (...args) => events.push(args),
  });
  const handlers = routes.get(
    'POST /api/matchmaking/lobbies/:id/merchant-approve',
  );
  assert.equal(handlers[0], requireAuth);
  assert.deepEqual(handlers[1], { role: 'merchant' });
  const res = response();
  await handlers.at(-1)(
    { params: { id: '17' }, auth: { sub: 22 } },
    res,
    assert.fail,
  );

  assert.equal(committed, true);
  assert.ok(calls.some(({ sql }) =>
    sql.includes("status = 'matchmaking_open'") &&
    sql.includes('INTERVAL 15 MINUTE'),
  ));
  assert.ok(calls.some(({ sql }) =>
    sql.includes("status = 'awaiting_host_downpayment'"),
  ));
  const approvalEvent = events.find(
    ([, payload]) =>
      payload.type === 'matchmaking.merchant-request.approved',
  );
  assert.equal(approvalEvent[0], 8);
  assert.equal(approvalEvent[1].hostShareAmount, 125);
  const ticketUpdate = calls.find(({ sql }) =>
    sql.includes('UPDATE messages m'),
  );
  assert.equal(ticketUpdate.params[0], 'approved');
  assert.match(ticketUpdate.sql, /matchmaking_booking_request_ticket/);
});

test('merchant decline cancels the reservation and updates the request ticket', async () => {
  const calls = [];
  const connection = {
    async beginTransaction() {},
    async commit() {},
    async rollback() {
      assert.fail('Unexpected rollback');
    },
    release() {},
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('FROM matchmaking_lobbies l')) {
        return [[{
          id: 17,
          hostUserId: 8,
          bookingId: 51,
          venueId: 4,
          status: 'pending_merchant_approval',
          venueName: 'North Courts',
          hostShareAmount: '125.00',
        }], []];
      }
      return [{ affectedRows: 1 }, []];
    },
  };
  const { routes } = setup({
    pool: { getConnection: async () => connection },
  });
  const res = response();
  await routes.get(
    'POST /api/matchmaking/lobbies/:id/merchant-decline',
  ).at(-1)(
    { params: { id: '17' }, auth: { sub: 22 } },
    res,
    assert.fail,
  );

  assert.equal(res.statusCode, 200);
  assert.ok(calls.some(({ sql }) =>
    sql.includes("SET status = 'cancelled'") &&
    sql.includes("status = 'matchmaking_pending_merchant'"),
  ));
  const ticketUpdate = calls.find(({ sql }) =>
    sql.includes('UPDATE messages m'),
  );
  assert.equal(ticketUpdate.params[0], 'declined');
});

test('lobby listing validates filters and applies visibility and cursor constraints', async () => {
  const calls = [];
  const { routes } = setup({
    pool: {
      execute: async (...args) => {
        calls.push(args);
        return [[{ id: 21 }, { id: 20 }, { id: 19 }], []];
      },
    },
  });
  const handler = routes.get('GET /api/matchmaking/lobbies').at(-1);
  const invalid = response();
  await handler(
    { query: { limit: '51' }, auth: { sub: 8 } },
    invalid,
    assert.fail,
  );
  assert.equal(invalid.statusCode, 400);
  assert.equal(calls.length, 0);

  const invalidLobbyId = response();
  await handler(
    { query: { lobbyId: '0' }, auth: { sub: 8 } },
    invalidLobbyId,
    assert.fail,
  );
  assert.equal(invalidLobbyId.statusCode, 400);
  assert.equal(calls.length, 0);

  const res = response();
  await handler(
    {
      query: {
        sport: 'Badminton',
        venueId: '4',
        date: futureDate(),
        skillLevel: 'open',
        limit: '2',
        cursor: '22',
      },
      auth: { sub: 8 },
    },
    res,
    assert.fail,
  );

  assert.equal(calls.length, 1);
  assert.match(calls[0][0], /b\.allow_matchmaking = 1/);
  assert.match(calls[0][0], /b\.enabled = 1/);
  assert.match(calls[0][0], /l\.id < \?/);
  assert.deepEqual(calls[0][1], [
    8,
    'Badminton',
    4,
    futureDate(),
    'open',
    22,
    3,
  ]);
  assert.equal(res.body.lobbies.length, 2);
  assert.equal(res.body.hasMore, true);
  assert.equal(res.body.nextCursor, '20');

  const singleLobby = response();
  await handler(
    { query: { lobbyId: '21', limit: '1' }, auth: { sub: 8 } },
    singleLobby,
    assert.fail,
  );
  assert.match(calls[1][0], /l\.id = \?/);
  assert.deepEqual(calls[1][1], [8, 21, 2]);
});

test('lobby creation rejects invalid dates and disabled venues', async () => {
  const calls = [];
  const { routes } = setup({
    pool: {
      getConnection: async () => ({
        async beginTransaction() {},
        async commit() {},
        async rollback() {},
        release() {},
        async execute(sql, params) {
          calls.push([sql, params]);
          return [[], []];
        },
      }),
    },
  });
  const handler = routes.get('POST /api/matchmaking/lobbies').at(-1);
  const invalid = response();
  await handler(
    {
      body: {
        venueId: 7,
        slotNumber: 1,
        sportType: 'Badminton',
        matchDate: '2020-01-01',
        startTime: '18:00',
      },
      auth: { sub: 8 },
    },
    invalid,
    assert.fail,
  );
  assert.equal(invalid.statusCode, 400);
  assert.equal(calls.length, 0);

  const disabled = response();
  await handler(
    {
      body: {
        venueId: 7,
        slotNumber: 1,
        sportType: 'Badminton',
        matchDate: futureDate(),
        startTime: '18:00',
        durationHours: 1,
        skillLevel: 'intermediate',
        opponentCriteria: 'Bring rackets',
      },
      auth: { sub: 8 },
    },
    disabled,
    assert.fail,
  );
  assert.equal(disabled.statusCode, 400);
  assert.match(calls[0][0], /FROM merchant_businesses b/);
});

test('lobby creation persists validated fields for an enabled sports venue', async () => {
  const calls = [];
  const { routes } = setup({
    pool: {
      getConnection: async () => ({
        async beginTransaction() {},
        async commit() {},
        async rollback() {},
        release() {},
        async execute(sql, params) {
          calls.push([sql, params]);
          if (sql.includes('FROM merchant_businesses b')) {
            return [[{
              id: 7,
              merchantId: 20,
              name: 'North Courts',
              category: 'Badminton',
              openingHours: '8:00 AM - 10:00 PM',
              pricePerHour: 250,
              slotCount: 2,
              sportsSlots: JSON.stringify([{
                sportType: 'Badminton',
                pricePerHour: 250,
                slotCount: 2,
                fullStudio: false,
              }]),
              enabled: 1,
              allowMatchmaking: 1,
              merchantStatus: 'active',
            }], []];
          }
          if (sql.includes('SELECT id FROM bookings')) return [[], []];
          if (sql.includes('INSERT INTO bookings')) return [{ insertId: 52 }, []];
          if (sql.includes('INSERT INTO conversations')) return [{ insertId: 63 }, []];
          if (sql.includes('INSERT INTO matchmaking_lobbies')) return [{ insertId: 31 }, []];
          return [{ affectedRows: 1 }, []];
        },
      }),
    },
  });
  const res = response();
  await routes.get('POST /api/matchmaking/lobbies').at(-1)(
    {
      body: {
        venueId: 7,
        slotNumber: 2,
        sportType: 'Badminton',
        matchDate: futureDate(),
        startTime: '18:30',
        durationHours: 1.5,
        skillLevel: 'intermediate',
        paymentMethod: 'cash_on_arrival',
        paymentPolicy: 'host_covers_remaining',
        opponentCriteria: '  Bring rackets  ',
      },
      auth: { sub: 8 },
    },
    res,
    assert.fail,
  );

  assert.equal(res.statusCode, 201);
  assert.deepEqual(res.body, {
    lobbyId: 31,
    bookingId: 52,
    totalPrice: 375,
    hostShareAmount: 187.5,
    hostBalanceAmount: 187.5,
    opponentShareAmount: 0,
    paymentMethod: 'cash_on_arrival',
    paymentPolicy: 'host_covers_remaining',
  });
  const bookingInsert = calls.find(([sql]) => sql.includes('INSERT INTO bookings'));
  assert.ok(bookingInsert[0].includes("'unpaid'"));
  assert.ok(bookingInsert[0].includes("'matchmaking'"));
  assert.ok(bookingInsert[0].includes("'matchmaking_pending_merchant'"));
  assert.equal(bookingInsert[1][5], 'cash_on_arrival');
  const lobbyInsert = calls.find(([sql]) =>
    sql.includes('INSERT INTO matchmaking_lobbies'),
  );
  assert.deepEqual(lobbyInsert[1], [
    8,
    7,
    52,
    'Badminton',
    2,
    futureDate(),
    '18:30:00',
    1.5,
    375,
    187.5,
    187.5,
    0,
    'host_covers_remaining',
    'cash_on_arrival',
    'intermediate',
    'Bring rackets',
  ]);
  const ticketInsert = calls.find(([sql]) => sql.includes('INSERT INTO messages'));
  const ticket = JSON.parse(ticketInsert[1][3]);
  assert.equal(ticket.type, 'matchmaking_booking_request_ticket');
  assert.equal(ticket.lobbyId, 31);
  assert.equal(ticket.bookingId, 52);
  assert.equal(ticket.status, 'pending_merchant_approval');
});

test('lobby creation blocks overlapping reservations for full-court sports', async () => {
  const calls = [];
  const connection = {
    async beginTransaction() {},
    async commit() {
      assert.fail('Conflicting request must not commit');
    },
    async rollback() {},
    release() {},
    async execute(sql, params) {
      calls.push([sql, params]);
      if (sql.includes('FROM merchant_businesses b')) {
        return [[{
          id: 7,
          merchantId: 20,
          name: 'North Courts',
          category: 'Basketball',
          openingHours: '8:00 AM - 10:00 PM',
          pricePerHour: 500,
          slotCount: 4,
          sportsSlots: JSON.stringify([{
            sportType: 'Basketball',
            pricePerHour: 500,
            slotCount: 4,
            fullStudio: true,
          }]),
          enabled: 1,
          allowMatchmaking: 1,
          merchantStatus: 'active',
        }], []];
      }
      if (sql.includes('SELECT id FROM bookings')) return [[{ id: 61 }], []];
      return [{ affectedRows: 1 }, []];
    },
  };
  const { routes } = setup({
    pool: { getConnection: async () => connection },
  });
  const handler = routes.get('POST /api/matchmaking/lobbies').at(-1);
  const body = {
    venueId: 7,
    slotNumber: 1,
    sportType: 'Basketball',
    matchDate: futureDate(),
    startTime: '18:30',
    durationHours: 1.5,
    skillLevel: 'open',
  };

  const conflicting = response();
  await handler({ body, auth: { sub: 8 } }, conflicting, assert.fail);
  assert.equal(conflicting.statusCode, 409);
  assert.equal(calls.some(([sql]) => sql.includes('INSERT INTO bookings')), false);
  const conflictCheck = calls.find(([sql]) =>
    sql.includes('SELECT id FROM bookings'),
  );
  assert.match(conflictCheck[0], /\? = 1 OR occupies_full_studio = 1/);
  assert.deepEqual(conflictCheck[1], [
    7,
    futureDate(),
    '18:30',
    1.5,
    '18:30',
    1,
    1,
    1,
  ]);

  const invalidSlot = response();
  await handler(
    { body: { ...body, slotNumber: 2 }, auth: { sub: 8 } },
    invalidSlot,
    assert.fail,
  );
  assert.equal(invalidSlot.statusCode, 400);
});

test('lobby cancellation is scoped to the authenticated host', async () => {
  const calls = [];
  const { routes } = setup({
    pool: {
      execute: async (...args) => {
        calls.push(args);
        return [{ affectedRows: 1 }, []];
      },
    },
  });
  const res = response();
  await routes.get('DELETE /api/matchmaking/lobbies/:id').at(-1)(
    { params: { id: '12' }, auth: { sub: 9 } },
    res,
    assert.fail,
  );

  assert.match(calls[0][0], /host_user_id = \?/);
  assert.deepEqual(calls[0][1], [12, 9]);
  assert.equal(res.body.message, 'Matchmaking lobby cancelled.');
});

test('joining creates a request and a direct in-chat ticket for the host', async () => {
  const calls = [];
  const events = [];
  const connection = {
    async beginTransaction() {},
    async commit() {},
    async rollback() {
      assert.fail('Unexpected rollback');
    },
    release() {},
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('FROM matchmaking_lobbies l')) {
        return [[{
          id: 12,
          hostUserId: 9,
          bookingId: 52,
          sportType: 'Badminton',
          matchDate: futureDate(),
          startTime: '18:00',
          skillLevel: 'open',
          status: 'open',
          opponentShareAmount: 125,
          hostBalanceAmount: 125,
          paymentPolicy: 'split_remaining',
          paymentMethod: 'online',
          allowMatchmaking: 1,
          enabled: 1,
          venueName: 'North Courts',
        }], []];
      }
      if (sql.includes('FROM matchmaking_requests')) return [[], []];
      if (sql.includes('FROM user_blocks')) return [[], []];
      if (sql.includes('FROM users WHERE id IN')) {
        return [[
          { id: 9, firstName: 'Host', lastName: 'One' },
          {
            id: 10,
            firstName: 'John',
            lastName: 'Doe',
            avatarUrl: 'https://example.test/avatar.png',
          },
        ], []];
      }
      if (sql.includes('SELECT c.id')) return [[], []];
      if (sql.includes('INSERT INTO conversations')) return [{ insertId: 44 }, []];
      if (sql.includes('INSERT INTO matchmaking_requests')) return [{ insertId: 34 }, []];
      return [{ affectedRows: 1 }, []];
    },
  };
  const { routes } = setup({
    pool: { getConnection: async () => connection },
    publishToUser: (...args) => events.push(args),
  });
  const res = response();
  await routes.get('POST /api/matchmaking/lobbies/:id/join').at(-1)(
    {
      params: { id: '12' },
      body: { message: '  I would like to join  ' },
      auth: { sub: 10 },
    },
    res,
    assert.fail,
  );

  assert.equal(res.statusCode, 201);
  assert.deepEqual(res.body, { requestId: 34, conversationId: 44 });
  const ticketInsert = calls.find(({ sql }) => sql.includes('INSERT INTO messages'));
  const ticket = JSON.parse(ticketInsert.params[3]);
  assert.deepEqual(ticket, {
    type: 'matchmaking_ticket',
    lobbyId: 12,
    bookingId: 52,
    requestId: 34,
    applicantId: 10,
    applicantName: 'John Doe',
    applicantAvatarUrl: 'https://example.test/avatar.png',
    sportType: 'Badminton',
    venueName: 'North Courts',
    matchDate: futureDate(),
    startTime: '18:00',
    skillLevel: 'open',
    opponentShareAmount: 125,
    hostBalanceAmount: 125,
    paymentMethod: 'online',
    paymentPolicy: 'split_remaining',
    status: 'pending',
  });
  assert.equal(ticketInsert.params[2], 'I would like to join');
  assert.equal(events[0][0], 9);
  assert.equal(events[0][1].type, 'message.created');
  assert.equal(events[1][1].type, 'matchmaking.request.created');
});

test('opponent cash-on-arrival selection is rejected', async () => {
  const { routes } = setup({
    pool: {
      getConnection: async () => {
        assert.fail('Cash selection must not access the database.');
      },
    },
  });
  const handler = routes.get(
    'POST /api/matchmaking/lobbies/:id/opponent-payment',
  ).at(-1);
  const res = response();
  await handler(
    {
      params: { id: '12' },
      body: { paymentMethod: 'cash_on_arrival' },
      auth: { sub: 10 },
    },
    res,
    assert.fail,
  );

  assert.equal(res.statusCode, 409);
  assert.deepEqual(res.body, {
    error: 'Online payment is required for this match.',
  });
});

test('host acceptance locks the lobby and notifies the applicant after commit', async () => {
  const calls = [];
  const events = [];
  let committed = false;
  const connection = {
    async beginTransaction() {},
    async commit() {
      committed = true;
    },
    async rollback() {
      assert.fail('Unexpected rollback');
    },
    release() {},
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('FROM matchmaking_lobbies')) {
        return [[{
          id: 12,
          hostUserId: 9,
          opponentShareAmount: 125,
          hostBalanceAmount: 125,
          paymentPolicy: 'split_remaining',
          paymentMethod: 'online',
          status: 'open',
        }], []];
      }
      if (sql.includes('FROM matchmaking_requests')) {
        return [[{
          id: 34,
          opponentUserId: 10,
          conversationId: 44,
          status: 'pending',
        }], []];
      }
      return [{ affectedRows: 1 }, []];
    },
  };
  const { routes } = setup({
    pool: { getConnection: async () => connection },
    publishToUser: (...args) => events.push(args),
  });
  const res = response();
  await routes
    .get('POST /api/matchmaking/lobbies/:id/requests/:requestId/accept')
    .at(-1)(
      {
        params: { id: '12', requestId: '34' },
        auth: { sub: 9 },
      },
      res,
      assert.fail,
    );

  assert.ok(calls.some(({ sql }) =>
    sql.includes('FROM matchmaking_lobbies') && /FOR UPDATE/.test(sql),
  ));
  assert.ok(calls.some(({ sql, params }) =>
    sql.includes('UPDATE matchmaking_lobbies') &&
    params[0] === 10 &&
    params[2] === 12 &&
    sql.includes("status = 'matched'"),
  ));
  assert.ok(calls.some(({ sql }) =>
    sql.includes("$.status', 'matched'") &&
    sql.includes('opponentPaymentStatus'),
  ));
  assert.equal(committed, true);
  assert.equal(events[0][0], 10);
  assert.equal(events[0][1].type, 'message.created');
  assert.equal(events[1][1].status, 'matched');
});

test('host cannot accept a request that exceeds lobby capacity', async () => {
  let updates = 0;
  let rolledBack = false;
  const connection = {
    async beginTransaction() {},
    async commit() {
      assert.fail('Unexpected commit');
    },
    async rollback() {
      rolledBack = true;
    },
    release() {},
    async execute(sql) {
      if (sql.includes('FROM matchmaking_lobbies')) {
        return [[{
          id: 12,
          hostUserId: 9,
          status: 'matched',
        }], []];
      }
      if (sql.includes('FROM matchmaking_requests')) {
        return [[{ id: 34, opponentUserId: 10, status: 'pending' }], []];
      }
      updates++;
      return [{ affectedRows: 1 }, []];
    },
  };
  const { routes } = setup({ pool: { getConnection: async () => connection } });
  const res = response();
  await routes
    .get('POST /api/matchmaking/lobbies/:id/requests/:requestId/accept')
    .at(-1)(
      {
        params: { id: '12', requestId: '34' },
        auth: { sub: 9 },
      },
      res,
      assert.fail,
    );

  assert.equal(res.statusCode, 409);
  assert.equal(rolledBack, true);
  assert.equal(updates, 0);
});
