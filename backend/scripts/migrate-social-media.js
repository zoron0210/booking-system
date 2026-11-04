require('dotenv').config();

const pool = require('../src/db');
const {
  MAX_IMAGE_BYTES,
  validateImages,
} = require('../src/routes/social_routes');
const { createSocialMediaStorage } = require('../src/social_media_storage');

async function migrateSocialMedia() {
  const mediaStorage = createSocialMediaStorage();
  if (!mediaStorage) {
    throw new Error('Set SOCIAL_MEDIA_BUCKET before migrating social photos.');
  }

  let lastId = '0';
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
    lastId = post.id;
    const images = Array.isArray(post.imagesJson)
      ? post.imagesJson
      : JSON.parse(post.imagesJson);
    if (!Array.isArray(images)) {
      throw new Error(`Social post ${lastId} has invalid image data.`);
    }

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
      images[index] = await mediaStorage.storeLegacyImage(
        post.userId,
        lastId,
        index,
        match[1].toLowerCase(),
        bytes,
      );
      migratedImages += 1;
      updated = true;
    }

    if (updated) {
      await pool.execute(
        'UPDATE social_posts SET images_json = ? WHERE id = ?',
        [JSON.stringify(images), lastId],
      );
      console.log(`Migrated photos for social post ${lastId}.`);
    }
  }
  console.log(`Migrated ${migratedImages} social photo(s).`);
}

migrateSocialMedia()
  .catch((error) => {
    console.error('Social photo migration failed.', error);
    process.exitCode = 1;
  })
  .finally(() => pool.end());
