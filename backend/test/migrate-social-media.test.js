const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  migrateSocialMedia,
  parseArgs,
} = require('../scripts/migrate-social-media');

const legacyPng = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j0L8AAAAASUVORK5CYII=';

function fakePool({ affectedRows = 1 } = {}) {
  const post = {
    id: 35,
    userId: 7,
    imagesJson: [legacyPng],
  };
  const updates = [];
  return {
    post,
    updates,
    async execute(sql, params) {
      if (sql.includes('SELECT id, user_id AS userId')) {
        return [Number(params[0]) < post.id ? [{ ...post }] : []];
      }
      if (sql.includes('UPDATE social_posts')) {
        updates.push({ sql, params });
        if (affectedRows === 1) {
          post.imagesJson = JSON.parse(params[0]);
        }
        return [{ affectedRows }];
      }
      throw new Error(`Unexpected SQL: ${sql}`);
    },
  };
}

function silentLogger() {
  return { info() {} };
}

test('social media migration defaults to a non-mutating dry run', async () => {
  const pool = fakePool();
  const result = await migrateSocialMedia({
    pool,
    logger: silentLogger(),
  });

  assert.deepEqual(result, {
    apply: false,
    scannedPosts: 1,
    plannedImages: 1,
    migratedImages: 0,
  });
  assert.deepEqual(pool.post.imagesJson, [legacyPng]);
  assert.equal(pool.updates.length, 0);
});

test('social media migration writes only with explicit apply dependencies', async () => {
  const pool = fakePool();
  const stored = [];
  const result = await migrateSocialMedia({
    pool,
    mediaStorage: {
      async storeLegacyImage(...args) {
        stored.push(args);
        return 'gcs://social-posts/7/legacy-35-0.png';
      },
      async verifyLegacyImage() {
        return true;
      },
    },
    apply: true,
    logger: silentLogger(),
  });

  assert.deepEqual(result, {
    apply: true,
    scannedPosts: 1,
    plannedImages: 1,
    migratedImages: 1,
  });
  assert.equal(stored.length, 1);
  assert.equal(stored[0][0], 7);
  assert.equal(stored[0][1], '35');
  assert.deepEqual(pool.post.imagesJson, [
    'gcs://social-posts/7/legacy-35-0.png',
  ]);
  assert.match(pool.updates[0].sql, /images_json = CAST\(\? AS JSON\)/);
});

test('social media migration refuses to overwrite a concurrently changed post', async () => {
  const pool = fakePool({ affectedRows: 0 });

  await assert.rejects(
    migrateSocialMedia({
      pool,
      mediaStorage: {
        async storeLegacyImage() {
          return 'gcs://social-posts/7/legacy-35-0.png';
        },
        async verifyLegacyImage() {
          return true;
        },
      },
      apply: true,
      logger: silentLogger(),
    }),
    /changed during migration/,
  );
});

test('social media migration does not update a post when object verification fails', async () => {
  const pool = fakePool();

  await assert.rejects(
    migrateSocialMedia({
      pool,
      mediaStorage: {
        async storeLegacyImage() {
          return 'gcs://social-posts/7/legacy-35-0.png';
        },
        async verifyLegacyImage() {
          return false;
        },
      },
      apply: true,
      logger: silentLogger(),
    }),
    /failed storage verification/,
  );
  assert.equal(pool.updates.length, 0);
  assert.deepEqual(pool.post.imagesJson, [legacyPng]);
});

test('applying requires both explicit migration and backup confirmation flags', () => {
  assert.deepEqual(parseArgs([]), { apply: false });
  assert.throws(() => parseArgs(['--apply']), /requires both --apply/);
  assert.throws(
    () => parseArgs(['--backup-confirmed']),
    /requires both --apply/,
  );
  assert.deepEqual(
    parseArgs(['--apply', '--backup-confirmed']),
    { apply: true },
  );
  assert.throws(() => parseArgs(['--force']), /Unknown migration argument/);
});
