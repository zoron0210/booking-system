const { randomUUID } = require('node:crypto');
const { Storage } = require('@google-cloud/storage');

const STORAGE_URI_PREFIX = 'gcs://';
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const MAX_DOCUMENT_BYTES = 10 * 1024 * 1024;
const READ_URL_TTL_MS = 15 * 60 * 1000;

const MIME_TYPES = new Map([
  ['image/jpeg', { extension: 'jpg', category: 'image', signature: 'jpeg' }],
  ['image/png', { extension: 'png', category: 'image', signature: 'png' }],
  ['image/webp', { extension: 'webp', category: 'image', signature: 'webp' }],
  ['application/pdf', { extension: 'pdf', category: 'document' }],
  ['application/msword', { extension: 'doc', category: 'document' }],
  ['application/vnd.openxmlformats-officedocument.wordprocessingml.document', { extension: 'docx', category: 'document' }],
  ['application/vnd.ms-excel', { extension: 'xls', category: 'document' }],
  ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', { extension: 'xlsx', category: 'document' }],
  ['application/vnd.ms-powerpoint', { extension: 'ppt', category: 'document' }],
  ['application/vnd.openxmlformats-officedocument.presentationml.presentation', { extension: 'pptx', category: 'document' }],
]);

function createMessagingStorage({
  bucketName = process.env.MESSAGING_STORAGE_BUCKET,
  storageClient,
  now = Date.now,
  uuid = randomUUID,
} = {}) {
  if (!bucketName) return null;
  const bucket = (storageClient ?? createStorageClient()).bucket(bucketName);

  return {
    async storeAttachment({ conversationId, userId, name, mimeType, bytes }) {
      const type = MIME_TYPES.get(mimeType);
      const safeName = typeof name === 'string' ? name.trim().slice(0, 255) : '';
      if (!type || !safeName || !Buffer.isBuffer(bytes)) return null;
      const limit = type.category === 'image' ? MAX_IMAGE_BYTES : MAX_DOCUMENT_BYTES;
      if (bytes.length < 1 || bytes.length > limit) return null;
      if (type.category === 'image' && !matchesImageType(bytes, type.signature)) return null;

      const key = `message-attachments/${conversationId}/${uuid()}.${type.extension}`;
      await bucket.file(key).save(bytes, {
        resumable: false,
        metadata: {
          contentType: mimeType,
          cacheControl: 'private, max-age=60',
          metadata: { conversationId: String(conversationId), userId: String(userId) },
        },
      });
      return {
        type: type.category === 'image' ? 'image' : 'file',
        name: safeName,
        mimeType,
        size: bytes.length,
        storageUri: `${STORAGE_URI_PREFIX}${key}`,
      };
    },

    async signAttachment(storageUri, conversationId) {
      const objectName = permanentObjectName(storageUri);
      if (
        !objectName ||
        (conversationId != null &&
          !objectName.startsWith(`message-attachments/${conversationId}/`))
      ) return null;
      try {
        const [url] = await bucket.file(objectName).getSignedUrl({
          version: 'v4',
          action: 'read',
          expires: now() + READ_URL_TTL_MS,
        });
        return url;
      } catch {
        return null;
      }
    },

    async deleteAttachment(storageUri) {
      const objectName = permanentObjectName(storageUri);
      if (!objectName) return;
      await bucket.file(objectName).delete({ ignoreNotFound: true });
    },
  };
}

function createStorageClient() {
  const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
  if (!serviceAccountJson) return new Storage();
  const serviceAccount = JSON.parse(serviceAccountJson);
  return new Storage({
    projectId: serviceAccount.project_id,
    credentials: {
      client_email: serviceAccount.client_email,
      private_key: serviceAccount.private_key,
    },
  });
}

function permanentObjectName(uri) {
  if (typeof uri !== 'string' || !uri.startsWith(STORAGE_URI_PREFIX)) return null;
  const name = uri.slice(STORAGE_URI_PREFIX.length);
  return name.startsWith('message-attachments/') ? name : null;
}

function matchesImageType(bytes, signature) {
  if (signature === 'jpeg') return bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  if (signature === 'png') return bytes.length >= 8 && bytes.subarray(0, 8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
  if (signature === 'webp') return bytes.length >= 12 && bytes.subarray(0, 4).toString() === 'RIFF' && bytes.subarray(8, 12).toString() === 'WEBP';
  return false;
}

module.exports = { createMessagingStorage };
