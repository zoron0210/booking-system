const { randomUUID } = require('node:crypto');
const { Storage } = require('@google-cloud/storage');

const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const UPLOAD_URL_TTL_MS = 5 * 60 * 1000;
const READ_URL_TTL_MS = 24 * 60 * 60 * 1000;
const STORAGE_URI_PREFIX = 'gcs://';
const IMAGE_TYPES = new Map([
  ['image/jpeg', { extension: 'jpg', signature: 'jpeg' }],
  ['image/png', { extension: 'png', signature: 'png' }],
  ['image/webp', { extension: 'webp', signature: 'webp' }],
]);

function createSocialMediaStorage({
  bucketName = process.env.SOCIAL_MEDIA_BUCKET,
  storageClient,
  now = Date.now,
  uuid = randomUUID,
} = {}) {
  if (!bucketName) return null;

  const bucket = (storageClient ?? createStorageClient()).bucket(bucketName);

  return {
    async createUpload(userId, contentType, size) {
      const imageType = IMAGE_TYPES.get(contentType);
      if (!imageType || !Number.isInteger(size) || size < 1 || size > MAX_IMAGE_BYTES) {
        return null;
      }

      const key = `social-media-staging/${userId}/${uuid()}-${size}`;
      const expiresAt = now() + UPLOAD_URL_TTL_MS;
      const [uploadUrl] = await bucket.file(key).getSignedUrl({
        version: 'v4',
        action: 'write',
        expires: expiresAt,
        contentType,
      });
      return {
        uploadUrl,
        key: `${STORAGE_URI_PREFIX}${key}`,
        headers: { 'Content-Type': contentType },
        expiresAt: new Date(expiresAt).toISOString(),
      };
    },

    async promoteUpload(uri, userId) {
      const stagedObject = stagedObjectName(uri, userId);
      if (!stagedObject) return null;

      const source = bucket.file(stagedObject.name);
      let metadata;
      try {
        [metadata] = await source.getMetadata();
      } catch (error) {
        if (Number(error.code) === 404) return null;
        throw error;
      }
      const contentType = metadata.contentType?.toLowerCase();
      const imageType = IMAGE_TYPES.get(contentType);
      const size = Number(metadata.size);
      if (
        !imageType ||
        !Number.isSafeInteger(size) ||
        size < 1 ||
        size > MAX_IMAGE_BYTES ||
        size !== stagedObject.expectedSize
      ) {
        return null;
      }

      const header = await readHeader(source);
      if (!matchesImageType(header, imageType.signature)) return null;

      const destinationName =
        `social-posts/${userId}/${uuid()}.${imageType.extension}`;
      const destination = bucket.file(destinationName);
      try {
        await source.copy(destination, {
          contentType,
          cacheControl: 'private, max-age=86400',
        });
        await source.delete({ ignoreNotFound: true });
      } catch (error) {
        await destination.delete({ ignoreNotFound: true }).catch((cleanupError) => {
          console.error('Could not clean up an incomplete social media copy.', {
            destinationName,
            error: cleanupError,
          });
        });
        throw error;
      }
      return `${STORAGE_URI_PREFIX}${destinationName}`;
    },

    async signImages(images) {
      return Promise.all(images.map(async (image) => {
        if (!image.startsWith(STORAGE_URI_PREFIX)) return image;
        const objectName = permanentObjectName(image);
        if (!objectName) {
          throw new Error('Stored social media key is invalid.');
        }
        const [url] = await bucket.file(objectName).getSignedUrl({
          version: 'v4',
          action: 'read',
          expires: now() + READ_URL_TTL_MS,
        });
        return url;
      }));
    },

    async storeLegacyImage(userId, postId, index, contentType, bytes) {
      const imageType = IMAGE_TYPES.get(contentType);
      if (
        !imageType ||
        bytes.length < 1 ||
        bytes.length > MAX_IMAGE_BYTES ||
        !matchesImageType(bytes, imageType.signature)
      ) {
        throw new Error(`Legacy social image ${postId}:${index} is invalid.`);
      }
      const objectName =
        `social-posts/${userId}/legacy-${postId}-${index}.${imageType.extension}`;
      await bucket.file(objectName).save(bytes, {
        resumable: false,
        metadata: {
          contentType,
          cacheControl: 'private, max-age=86400',
        },
      });
      return `${STORAGE_URI_PREFIX}${objectName}`;
    },

    async deleteImages(images) {
      await Promise.all(images.map(async (image) => {
        const objectName = permanentObjectName(image);
        if (objectName) {
          await bucket.file(objectName).delete({ ignoreNotFound: true });
        }
      }));
    },
  };
}

function createStorageClient() {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) return new Storage();

  const serviceAccount = JSON.parse(serviceAccountJson);
  if (
    typeof serviceAccount.project_id !== 'string' ||
    typeof serviceAccount.client_email !== 'string' ||
    typeof serviceAccount.private_key !== 'string'
  ) {
    throw new Error(
      'FIREBASE_SERVICE_ACCOUNT_JSON must contain project_id, client_email, and private_key.',
    );
  }
  return new Storage({
    projectId: serviceAccount.project_id,
    credentials: {
      client_email: serviceAccount.client_email,
      private_key: serviceAccount.private_key,
    },
  });
}

function stagedObjectName(uri, userId) {
  if (typeof uri !== 'string' || !uri.startsWith(STORAGE_URI_PREFIX)) return null;
  const name = uri.slice(STORAGE_URI_PREFIX.length);
  const match = new RegExp(
    `^social-media-staging/${String(userId)}/[0-9a-f-]{36}-([1-9]\\d*)$`,
    'i',
  ).exec(name);
  if (!match) return null;
  const expectedSize = Number(match[1]);
  return Number.isSafeInteger(expectedSize) && expectedSize <= MAX_IMAGE_BYTES
    ? { name, expectedSize }
    : null;
}

function permanentObjectName(uri) {
  if (typeof uri !== 'string' || !uri.startsWith(STORAGE_URI_PREFIX)) return null;
  const name = uri.slice(STORAGE_URI_PREFIX.length);
  return /^social-posts\/[1-9]\d*\/[a-z0-9-]+\.(jpg|png|webp)$/i.test(name)
    ? name
    : null;
}

async function readHeader(file) {
  const chunks = [];
  let length = 0;
  for await (const chunk of file.createReadStream({ start: 0, end: 11 })) {
    const remaining = 12 - length;
    const bytes = chunk.subarray(0, remaining);
    chunks.push(bytes);
    length += bytes.length;
    if (length >= 12) break;
  }
  return Buffer.concat(chunks, length);
}

function matchesImageType(bytes, type) {
  if (type === 'png') {
    return bytes.subarray(0, 8).equals(
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    );
  }
  if (type === 'jpeg') {
    return bytes.length >= 3 &&
      bytes[0] === 0xff &&
      bytes[1] === 0xd8 &&
      bytes[2] === 0xff;
  }
  return type === 'webp' &&
    bytes.length >= 12 &&
    bytes.toString('ascii', 0, 4) === 'RIFF' &&
    bytes.toString('ascii', 8, 12) === 'WEBP';
}

module.exports = {
  MAX_IMAGE_BYTES,
  createSocialMediaStorage,
};
