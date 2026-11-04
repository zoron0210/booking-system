const assert = require('node:assert/strict');
const { Readable } = require('node:stream');
const { test } = require('node:test');
const {
  createSocialMediaStorage,
} = require('../src/social_media_storage');

const pngBytes = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+j0L8AAAAASUVORK5CYII=',
  'base64',
);
const uuid = '11111111-1111-4111-8111-111111111111';

function fakeStorage() {
  const objects = new Map();
  const bucket = {
    file(name) {
      return {
        async getSignedUrl(options) {
          return [
            `https://storage.googleapis.com/test-bucket/${name}?action=${options.action}`,
          ];
        },
        async getMetadata() {
          const object = objects.get(name);
          if (!object) throw Object.assign(new Error('Not found'), { code: 404 });
          return [{ ...object.metadata, size: String(object.bytes.length) }];
        },
        createReadStream() {
          const object = objects.get(name);
          return Readable.from([object.bytes.subarray(0, 12)]);
        },
        async copy(destination, options) {
          const object = objects.get(name);
          objects.set(destination.name, {
            bytes: Buffer.from(object.bytes),
            metadata: options.metadata,
          });
        },
        async delete() {
          objects.delete(name);
        },
        async save(bytes, options) {
          objects.set(name, {
            bytes: Buffer.from(bytes),
            metadata: options.metadata,
          });
        },
        name,
      };
    },
  };
  return { client: { bucket: () => bucket }, objects };
}

test('creates short-lived, content-type-bound upload URLs in the user staging area', async () => {
  const { client } = fakeStorage();
  const mediaStorage = createSocialMediaStorage({
    bucketName: 'test-bucket',
    storageClient: client,
    now: () => 1_000,
    uuid: () => uuid,
  });

  const upload = await mediaStorage.createUpload(7, 'image/png', pngBytes.length);

  assert.equal(upload.key, `gcs://social-media-staging/7/${uuid}-${pngBytes.length}`);
  assert.equal(upload.headers['Content-Type'], 'image/png');
  assert.equal(upload.expiresAt, new Date(301_000).toISOString());
  assert.match(upload.uploadUrl, /^https:\/\/storage\.googleapis\.com\//);
  assert.equal(await mediaStorage.createUpload(7, 'image/gif', 100), null);
  assert.equal(await mediaStorage.createUpload(7, 'image/png', 0), null);
});

test('promotes only owner-scoped images with matching content and signs stored objects', async () => {
  const { client, objects } = fakeStorage();
  const mediaStorage = createSocialMediaStorage({
    bucketName: 'test-bucket',
    storageClient: client,
    uuid: () => uuid,
  });
  const stagedKey = `gcs://social-media-staging/7/${uuid}-${pngBytes.length}`;
  objects.set(stagedKey.slice('gcs://'.length), {
    bytes: pngBytes,
    metadata: { contentType: 'image/png' },
  });

  assert.equal(await mediaStorage.promoteUpload(stagedKey, 8), null);
  const promotedKey = await mediaStorage.promoteUpload(stagedKey, 7);

  assert.equal(promotedKey, `gcs://social-posts/7/${uuid}.png`);
  assert.equal(objects.has(stagedKey.slice('gcs://'.length)), false);
  assert.deepEqual(await mediaStorage.signImages([
    promotedKey,
    'https://media.tenor.com/hash/sports.gif',
  ]), [
    `https://storage.googleapis.com/test-bucket/social-posts/7/${uuid}.png?action=read`,
    'https://media.tenor.com/hash/sports.gif',
  ]);
  assert.equal(
    await mediaStorage.promoteUpload(
      'gcs://social-media-staging/8/not-a-uuid',
      8,
    ),
    null,
  );
});

test('rejects storage keys outside the permanent post namespace', async () => {
  const { client } = fakeStorage();
  const mediaStorage = createSocialMediaStorage({
    bucketName: 'test-bucket',
    storageClient: client,
  });

  await assert.rejects(
    mediaStorage.signImages(['gcs://other-users/private.png']),
    /key is invalid/,
  );
  assert.equal(createSocialMediaStorage({ bucketName: '' }), null);
});

test('stores migrated legacy photos at a stable object key', async () => {
  const { client, objects } = fakeStorage();
  const mediaStorage = createSocialMediaStorage({
    bucketName: 'test-bucket',
    storageClient: client,
  });

  const firstKey = await mediaStorage.storeLegacyImage(
    7,
    35,
    0,
    'image/png',
    pngBytes,
  );
  const secondKey = await mediaStorage.storeLegacyImage(
    7,
    35,
    0,
    'image/png',
    pngBytes,
  );

  assert.equal(firstKey, 'gcs://social-posts/7/legacy-35-0.png');
  assert.equal(secondKey, firstKey);
  assert.deepEqual(
    objects.get(firstKey.slice('gcs://'.length)).bytes,
    pngBytes,
  );
  await assert.rejects(
    mediaStorage.storeLegacyImage(7, 35, 1, 'image/png', Buffer.from('bad')),
    /is invalid/,
  );
});
