const assert = require('node:assert/strict');
const { test } = require('node:test');
const { runSchemaMigrations } = require('../src/schema_migrations');

test('applied schema versions are skipped while the migration lock is released', async () => {
  const calls = [];
  let released = false;
  const connection = {
    async execute(sql) {
      calls.push(sql);
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[{ version: 1 }], []];
      }
      return [[], []];
    },
    release() {
      released = true;
    },
  };
  const pool = {
    async execute(sql) {
      calls.push(sql);
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(calls.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS schema_migrations')));
  assert.ok(calls.some((sql) => sql.includes('SELECT version FROM schema_migrations')));
  assert.equal(calls.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS merchant_businesses')), false);
  assert.ok(calls.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS booking_check_ins')));
  assert.ok(calls.some((sql) => sql.includes('RELEASE_LOCK')));
  assert.equal(released, true);
});

test('migration lock contention aborts before running schema upgrades', async () => {
  const calls = [];
  let released = false;
  const connection = {
    async execute(sql) {
      calls.push(sql);
      return [[{ acquired: 0 }], []];
    },
    release() {
      released = true;
    },
  };
  const pool = {
    async execute(sql) {
      calls.push(sql);
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await assert.rejects(
    runSchemaMigrations(pool),
    /Could not acquire the database migration lock/,
  );

  assert.equal(calls.some((sql) => sql.includes('CREATE TABLE IF NOT EXISTS merchant_businesses')), false);
  assert.equal(released, true);
});

test('migration 16 creates social follows and experience posts', async () => {
  const calls = [];
  const connection = {
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [Array.from({ length: 15 }, (_, index) => ({
          version: index + 1,
        })), []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      calls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  const followsTable = calls.find(({ sql }) =>
    sql.includes('CREATE TABLE IF NOT EXISTS user_follows'),
  );
  assert.ok(followsTable);
  assert.match(followsTable.sql, /FOREIGN KEY \(follower_id\)/);
  assert.match(followsTable.sql, /FOREIGN KEY \(followed_id\)/);
  assert.doesNotMatch(followsTable.sql, /CHECK\s*\(/i);
  assert.ok(calls.some(({ sql }) =>
    sql.includes('CREATE TABLE IF NOT EXISTS social_posts'),
  ));
  assert.ok(calls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 16 &&
    params[1] === 'social-following-and-experience-posts',
  ));
  assert.ok(calls.some(({ sql }) =>
    sql.includes('CREATE TABLE IF NOT EXISTS social_post_likes'),
  ));
  assert.ok(calls.some(({ sql }) =>
    sql.includes('CREATE TABLE IF NOT EXISTS social_saved_posts'),
  ));
  assert.ok(calls.some(({ sql }) =>
    sql.includes('CREATE TABLE IF NOT EXISTS social_post_comments'),
  ));
  assert.ok(calls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 17 &&
    params[1] === 'social-post-interactions',
  ));
});

test('migration 20 creates recipient-scoped social activity notifications', async () => {
  const calls = [];
  const connection = {
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [Array.from({ length: 19 }, (_, index) => ({
          version: index + 1,
        })), []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      calls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  const notificationsTable = calls.find(({ sql }) =>
    sql.includes('CREATE TABLE IF NOT EXISTS social_notifications'),
  );
  assert.ok(notificationsTable);
  assert.match(notificationsTable.sql, /recipient_user_id BIGINT UNSIGNED NOT NULL/);
  assert.match(notificationsTable.sql, /type ENUM\('like', 'comment', 'follow', 'post'\)/);
  assert.match(notificationsTable.sql, /UNIQUE KEY uq_social_notifications_event/);
  assert.match(notificationsTable.sql, /FOREIGN KEY \(recipient_user_id\)/);
  assert.ok(calls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 20 &&
    params[1] === 'social-activity-notifications',
  ));
});

test('ensures older databases add the missing fitness coach duration column before continuing', async () => {
  const calls = [];
  const connection = {
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[{ version: 1 }], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql) {
      calls.push({ sql });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(calls.some(({ sql }) => sql.includes('ALTER TABLE `bookings` ADD COLUMN `fitness_coach_duration_months`')));
  assert.ok(calls.some(({ sql }) => sql.includes('ALTER TABLE `bookings` ADD COLUMN `slot_numbers_json`')));
  assert.ok(calls.some(({ sql }) =>
    sql.includes("SET paid_amount = total_amount") &&
    sql.includes("payment_status = 'paid'"),
  ));
  assert.ok(calls.some(({ sql }) =>
    sql.includes("ENUM('unpaid', 'partial', 'paid', 'not_required')"),
  ));
  assert.ok(calls.some(({ sql }) => sql.includes('INSERT INTO schema_migrations (version, name)')));
});

test('migration 6 keeps one News Card per business and adds a unique business index', async () => {
  const poolCalls = [];
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql) {
      poolCalls.push(sql);
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  const duplicateCleanup = poolCalls.find((sql) =>
    sql.includes('DELETE duplicate FROM merchant_news duplicate'),
  );
  assert.ok(duplicateCleanup);
  assert.match(duplicateCleanup, /keeper\.status = 'published'/);
  assert.ok(poolCalls.some((sql) =>
    sql.includes('ADD UNIQUE INDEX uq_merchant_news_business (business_id)'),
  ));
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 6 &&
    params[1] === 'single-news-card-per-business',
  ));
});

test('migration 7 adds persistent message deletion scopes', async () => {
  const poolCalls = [];
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
          { version: 6 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      poolCalls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `messages` ADD COLUMN `removed_at`'),
  ));
  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `messages` ADD COLUMN `removed_by`'),
  ));
  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('CREATE TABLE IF NOT EXISTS message_user_deletions'),
  ));
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 7 &&
    params[1] === 'message-delete-scopes',
  ));
});

test('migration 8 adds customer review photo storage', async () => {
  const poolCalls = [];
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
          { version: 6 },
          { version: 7 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      poolCalls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `venue_reviews` ADD COLUMN `image_data` LONGTEXT NULL'),
  ));
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 8 &&
    params[1] === 'venue-review-customer-photo',
  ));
});

test('migration 11 adds the booking approval reminder marker', async () => {
  const poolCalls = [];
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
          { version: 6 },
          { version: 7 },
          { version: 8 },
          { version: 9 },
          { version: 10 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      poolCalls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes(
      'ALTER TABLE `bookings` ADD COLUMN `approval_reminded_at` DATETIME NULL',
    ),
  ));
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 11 &&
    params[1] === 'booking-approval-deadlines',
  ));
});

test('migration 12 adds the post-approval online payment deadline', async () => {
  const poolCalls = [];
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
          { version: 6 },
          { version: 7 },
          { version: 8 },
          { version: 9 },
          { version: 10 },
          { version: 11 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      poolCalls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `bookings` ADD COLUMN `payment_due_at` DATETIME NULL'),
  ));
  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `bookings` ADD COLUMN `payment_expired_at` DATETIME NULL'),
  ));
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 12 &&
    params[1] === 'approval-first-online-booking-payments',
  ));
});

test('migration 13 restores only earlier duplicate payment-expiry approval tickets', async () => {
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
          { version: 6 },
          { version: 7 },
          { version: 8 },
          { version: 9 },
          { version: 10 },
          { version: 11 },
          { version: 12 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute() {
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  const repair = connectionCalls.find(({ sql }) =>
    sql.includes('UPDATE messages approval_message'),
  );
  assert.ok(repair);
  assert.match(repair.sql, /expiry_message\.created_at > approval_message\.created_at/);
  assert.match(repair.sql, /'\$\.status', 'approved'/);
  assert.match(repair.sql, /'\$\.paymentExpiredAt'/);
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 13 &&
    params[1] === 'keep-approval-ticket-separate-from-payment-expiry-ticket',
  ));
});

test('migration 14 snapshots legacy approval deadlines and adds merchant settings', async () => {
  const poolCalls = [];
  const connectionCalls = [];
  const connection = {
    async execute(sql, params) {
      connectionCalls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 },
          { version: 2 },
          { version: 3 },
          { version: 4 },
          { version: 5 },
          { version: 6 },
          { version: 7 },
          { version: 8 },
          { version: 9 },
          { version: 10 },
          { version: 11 },
          { version: 12 },
          { version: 13 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      poolCalls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `bookings` ADD COLUMN `approval_due_at` DATETIME NULL'),
  ));
  assert.ok(poolCalls.some(({ sql }) =>
    sql.includes('ALTER TABLE `merchant_profiles` ADD COLUMN `payment_timeout_minutes`'),
  ));
  assert.ok(connectionCalls.some(({ sql }) =>
    sql.includes('SET approval_due_at = DATE_ADD(created_at, INTERVAL 15 MINUTE)'),
  ));
  assert.ok(connectionCalls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 14 &&
    params[1] === 'merchant-configurable-booking-deadlines',
  ));
});

test('migration 15 creates account-scoped push notification devices', async () => {
  const calls = [];
  const connection = {
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 }, { version: 2 }, { version: 3 }, { version: 4 },
          { version: 5 }, { version: 6 }, { version: 7 }, { version: 8 },
          { version: 9 }, { version: 10 }, { version: 11 }, { version: 12 },
          { version: 13 }, { version: 14 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute() {
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  assert.ok(calls.some(({ sql }) =>
    sql.includes('CREATE TABLE IF NOT EXISTS booking_notification_devices') &&
    sql.includes('FOREIGN KEY (user_id)'),
  ));
  assert.ok(calls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 15 &&
    params[1] === 'booking-push-notification-devices',
  ));
});

test('migration 18 adds customer onboarding fields and preserves existing accounts', async () => {
  const calls = [];
  const connection = {
    async execute(sql, params) {
      calls.push({ sql, params });
      if (sql.includes('GET_LOCK')) return [[{ acquired: 1 }], []];
      if (sql.includes('SELECT version FROM schema_migrations')) {
        return [[
          { version: 1 }, { version: 2 }, { version: 3 }, { version: 4 },
          { version: 5 }, { version: 6 }, { version: 7 }, { version: 8 },
          { version: 9 }, { version: 10 }, { version: 11 }, { version: 12 },
          { version: 13 }, { version: 14 }, { version: 15 }, { version: 16 },
          { version: 17 },
        ], []];
      }
      return [[], []];
    },
    release() {},
  };
  const pool = {
    async execute(sql, params) {
      calls.push({ sql, params });
      return [[], []];
    },
    async getConnection() {
      return connection;
    },
  };

  await runSchemaMigrations(pool);

  for (const column of ['gender', 'player_type', 'onboarding_completed']) {
    assert.ok(calls.some(({ sql }) =>
      sql.includes(`ALTER TABLE \`users\` ADD COLUMN \`${column}\``),
    ));
  }
  assert.ok(calls.some(({ sql }) =>
    sql.includes('UPDATE users SET onboarding_completed = 1'),
  ));
  assert.ok(calls.some(({ sql, params }) =>
    sql.includes('INSERT INTO schema_migrations (version, name)') &&
    params[0] === 18 &&
    params[1] === 'customer-onboarding-profile',
  ));
});
