const {
  MAX_IMAGE_BYTES,
  validateImages,
} = require('../src/routes/social_routes');

async function migrateSocialMedia({
  pool,
  mediaStorage,
  apply = false,
  logger = console,
}) {
  if (!pool || typeof pool.execute !== 'function') {
    throw new TypeError('A database pool is required.');
  }
  if (typeof apply !== 'boolean') {
    throw new TypeError('The apply option must be a boolean.');
  }
  if (apply && !mediaStorage) {
    throw new Error('Social media storage is required when applying the migration.');
  }

  let lastId = '0';
  let scannedPosts = 0;
  let plannedImages = 0;
  let migratedImages = 0;
  while (true) {
    const [rows] = await pool.execute(
      `SELECT id, user_id AS userId, images_json AS imagesJson
       FROM social_posts
       WHERE id > ?
       ORDER BY id
       LIMIT 1`,
      [lastId],
    );
    if (rows.length === 0) break;

    const post = rows[0];
    lastId = String(post.id);
    scannedPosts += 1;
    const originalImages = Array.isArray(post.imagesJson)
      ? post.imagesJson
      : JSON.parse(post.imagesJson);
    if (!Array.isArray(originalImages)) {
      throw new Error(`Social post ${lastId} has invalid image data.`);
    }

    const images = [...originalImages];
    let updated = false;
    for (let index = 0; index < images.length; index += 1) {
      const image = images[index];
      if (typeof image !== 'string' || !image.startsWith('data:image/')) {
        continue;
      }
      const match = /^data:(image\/(?:jpeg|png|webp));base64,([A-Za-z0-9+/]+={0,2})$/i
        .exec(image);
      if (!match || !validateImages([image]).valid) {
        throw new Error(`Social post ${lastId} contains an invalid photo.`);
      }
      const bytes = Buffer.from(match[2], 'base64');
      if (bytes.length > MAX_IMAGE_BYTES) {
        throw new Error(`Social post ${lastId} contains a photo over 10 MiB.`);
      }

      plannedImages += 1;
      if (!apply) continue;

      const uri = await mediaStorage.storeLegacyImage(
        post.userId,
        lastId,
        index,
        match[1].toLowerCase(),
        bytes,
      );
      if (!(await mediaStorage.verifyLegacyImage(uri, bytes))) {
        throw new Error(
          `Social post ${lastId} photo ${index} failed storage verification.`,
        );
      }
      images[index] = uri;
      migratedImages += 1;
      updated = true;
    }

    if (updated) {
      const originalJson = JSON.stringify(originalImages);
      const [result] = await pool.execute(
        `UPDATE social_posts
         SET images_json = ?
         WHERE id = ? AND images_json = CAST(? AS JSON)`,
        [JSON.stringify(images), lastId, originalJson],
      );
      if (result.affectedRows !== 1) {
        throw new Error(
          `Social post ${lastId} changed during migration; rerun after reviewing the post.`,
        );
      }
      logger.info(`Migrated photos for social post ${lastId}.`);
    }
  }

  const result = { apply, scannedPosts, plannedImages, migratedImages };
  logger.info(
    apply
      ? `Migrated ${migratedImages} social photo(s) across ${scannedPosts} post(s).`
      : `Dry run: found ${plannedImages} legacy photo(s) across ${scannedPosts} post(s). No data was changed.`,
  );
  return result;
}

function parseArgs(args) {
  const unknownArguments = args.filter(
    (argument) => !['--apply', '--backup-confirmed'].includes(argument),
  );
  if (unknownArguments.length > 0) {
    throw new Error(`Unknown migration argument: ${unknownArguments[0]}`);
  }
  const apply = args.includes('--apply');
  const backupConfirmed = args.includes('--backup-confirmed');
  if (apply !== backupConfirmed) {
    throw new Error(
      'Applying requires both --apply and --backup-confirmed; without them the migration is a dry run.',
    );
  }
  return { apply };
}

async function run() {
  require('dotenv').config();
  const { apply } = parseArgs(process.argv.slice(2));
  const pool = require('../src/db');
  try {
    const mediaStorage = apply
      ? require('../src/social_media_storage').createSocialMediaStorage()
      : null;
    if (apply && !mediaStorage) {
      throw new Error('Set SOCIAL_MEDIA_BUCKET before applying the migration.');
    }
    await migrateSocialMedia({ pool, mediaStorage, apply });
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  run().catch((error) => {
    console.error('Social photo migration failed.', error);
    process.exitCode = 1;
  });
}

module.exports = { migrateSocialMedia, parseArgs };
