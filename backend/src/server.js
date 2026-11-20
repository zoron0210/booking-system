require('dotenv').config();

const bcrypt = require('bcryptjs');
const cors = require('cors');
const crypto = require('crypto');
const { AsyncLocalStorage } = require('node:async_hooks');
const express = require('express');
const jwt = require('jsonwebtoken');
const pool = require('./db');
const { createCorsOriginPolicy } = require('./cors_policy');
const { createJsonBodyParser } = require('./json_body_parser');
const { createSocialMediaStorage } = require('./social_media_storage');
const { createMessagingStorage } = require('./messaging_storage');
const {
  createBookingApprovalDeadlineProcessor,
} = require('./booking_approval_deadlines');
const {
  createBookingPaymentDeadlineProcessor,
} = require('./booking_payment_deadlines');
const {
  DEFAULT_BOOKING_DEADLINE_MINUTES,
  MAX_BOOKING_DEADLINE_MINUTES,
  formatBookingDeadlineDuration,
  isValidBookingDeadlineMinutes,
} = require('./booking_deadline_settings');
const { sendPasswordResetCode, sendVerificationCode } = require('./mailer');
const {
  createBookingNotificationService,
  createMatchDiscoveryNotificationService,
  notificationTokenHash,
} = require('./booking_notification_service');
const { createRateLimiter } = require('./rate_limit');
const readCache = require('./read_cache');
const {
  fitnessDetailsFromBody,
  saveEventDetails,
  saveFitnessDetails,
} = require('./business_details');
const {
  createBookingToken,
  createVerificationCode,
  hashBookingToken,
  hashVerificationCode,
  isNumericInput,
  isValidEmail,
  isValidRole,
  normalizeEmail,
  normalizeText,
  parseBusinessCoordinates,
  parseJsonArray,
  publicUser,
} = require('./normalizers');

const {
  newsPostResponse,
  registerMerchantNewsRoutes,
} = require('./routes/merchant_news_routes');
const { registerAuthRoutes } = require('./routes/auth_routes');
const { registerSocialRoutes } = require('./routes/social_routes');
const { registerSocialClubRoutes } = require('./routes/social_club_routes');
const { registerSystemRoutes } = require('./routes/system_routes');
const { registerMessagingRoutes } = require('./routes/messaging_routes');
const { registerSavedItemsRoutes } = require('./routes/saved_items_routes');
const { registerActivityLogRoutes } = require('./routes/activity_log_routes');
const { registerCustomerVenueRoutes } = require('./routes/customer_venue_routes');
const { registerMerchantBusinessRoutes } = require('./routes/merchant_business_routes');
const {
  registerMerchantBusinessWriteRoutes,
} = require('./routes/merchant_business_write_routes');
const { registerMerchantProfileRoutes } = require('./routes/merchant_profile_routes');
const { registerPaymentRoutes } = require('./routes/payment_routes');
const { registerBookingRoutes } = require('./routes/booking_routes');
const { registerMatchmakingRoutes } = require('./routes/matchmaking_routes');
const { createWebSocketHub } = require('./websocket_hub');

const app = express();
const socialMediaStorage = createSocialMediaStorage();
const messagingStorage = createMessagingStorage();
app.set('json escape', true);
const auditContextStorage = new AsyncLocalStorage();
const port = Number(process.env.PORT || 3000);
const customerBusinessesCacheKey = 'customer-businesses';
const customerBusinessesCacheTtlMs = 30_000;
const userStatusCacheTtlMs = 5_000;
const maxUserStatusCacheEntries = 5_000;
const userStatusCache = new Map();
const pendingUserStatusChecks = new Map();
const userStatusCacheVersions = new Map();
const notifyBookingParticipants = createBookingNotificationService({ pool });
const notifyMatchDiscovery = createMatchDiscoveryNotificationService({ pool });
const liveUpdates = createWebSocketHub({
  jwt,
  pool,
  secret: process.env.JWT_SECRET,
  allowedOrigins: (process.env.CLIENT_ORIGIN || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean),
});

function queueBookingNotifications(details) {
  for (const userId of details.userIds || []) {
    liveUpdates.publishToUser(userId, { type: 'dashboard.updated' });
  }
  notifyBookingParticipants(details).catch((error) => {
    console.error('Could not prepare booking notifications.', {
      bookingId: details.booking?.id,
      event: details.event,
      error,
    });
  });
}

function bookingTransactionId(bookingId) {
  return `TP-TXN-${String(bookingId).padStart(8, '0')}`;
}

function positiveIntegerId(value) {
  if (
    (typeof value !== 'string' && typeof value !== 'number') ||
    (typeof value === 'string' && !/^[1-9]\d*$/.test(value))
  ) {
    return null;
  }
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function venueCheckInCode(venueId) {
  const issuedAt = Math.floor(Date.now() / 60_000) * 60_000;
  const payload = `v1:${venueId}:${issuedAt}`;
  const signature = crypto
    .createHmac('sha256', process.env.JWT_SECRET)
    .update(payload)
    .digest('hex');
  return {
    type: 'tinkerpro.checkin',
    version: 1,
    venueId,
    issuedAt,
    signature,
  };
}

function verifyVenueCheckInCode(value) {
  if (typeof value !== 'string' || value.length > 512) return null;
  let code;
  try {
    code = JSON.parse(value);
  } catch {
    return null;
  }
  if (
    !code ||
    code.type !== 'tinkerpro.checkin' ||
    code.version !== 1 ||
    !Number.isSafeInteger(code.venueId) ||
    code.venueId <= 0 ||
    !Number.isSafeInteger(code.issuedAt) ||
    code.issuedAt % 60_000 !== 0 ||
    typeof code.signature !== 'string' ||
    !/^[a-f0-9]{64}$/i.test(code.signature)
  ) {
    return null;
  }
  const now = Date.now();
  if (code.issuedAt > now + 30_000 || now - code.issuedAt > 120_000) {
    return null;
  }
  const expected = crypto
    .createHmac('sha256', process.env.JWT_SECRET)
    .update(`v1:${code.venueId}:${code.issuedAt}`)
    .digest();
  const supplied = Buffer.from(code.signature, 'hex');
  if (!crypto.timingSafeEqual(expected, supplied)) return null;
  return { venueId: code.venueId, issuedAt: code.issuedAt };
}

function manilaDateTime(date = new Date()) {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: 'Asia/Manila',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(date);
  const values = Object.fromEntries(parts.map(({ type, value }) => [type, value]));
  return {
    date: `${values.year}-${values.month}-${values.day}`,
    minutes: Number(values.hour) * 60 + Number(values.minute),
  };
}

function bookingCheckInWindowIncludesNow(booking, currentMinutes) {
  const time = String(booking.startTime ?? '').match(/^([01]\d|2[0-3]):([0-5]\d)/);
  const durationHours = Number(booking.durationHours);
  if (!time || !Number.isFinite(durationHours) || durationHours <= 0) {
    return false;
  }
  const startMinutes = Number(time[1]) * 60 + Number(time[2]);
  return currentMinutes >= startMinutes - 30 &&
    currentMinutes <= startMinutes + durationHours * 60 + 15;
}

function normalizeBusinessType(value) {
  if (typeof value !== 'string') return null;
  return {
    sports: 'sports',
    sport: 'sports',
    fitness: 'fitness & wellness',
    wellness: 'fitness & wellness',
    'fitness & wellness': 'fitness & wellness',
    'fitness wellness': 'fitness & wellness',
    fitness_wellness: 'fitness & wellness',
    event: 'event',
    events: 'event',
  }[value.trim().toLowerCase()] ?? null;
}

function invalidateCustomerBusinesses() {
  readCache.invalidate(customerBusinessesCacheKey);
}

function setAuditActor(userId, role) {
  const auditContext = auditContextStorage.getStore();
  if (!auditContext) return;
  auditContext.actorUserId = userId == null ? null : String(userId);
  auditContext.actorRole = typeof role === 'string' ? role : null;
}

if (!process.env.JWT_SECRET) {
  throw new Error('JWT_SECRET must be set in the backend .env file.');
}
app.use((req, res, next) => {
  res.set('X-Content-Type-Options', 'nosniff');
  const userAgent = (req.get('user-agent') || '')
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const context = {
    requestId: crypto.randomUUID(),
    actorUserId: null,
    actorRole: null,
    ipAddress: typeof req.ip === 'string' ? req.ip.slice(0, 45) : null,
    userAgent: userAgent.slice(0, 500) || null,
  };
  res.set('X-Request-Id', context.requestId);
  auditContextStorage.run(context, next);
});
app.use(cors({
  origin: createCorsOriginPolicy(),
  exposedHeaders: ['X-Request-Id'],
}));
app.use(createJsonBodyParser(
  express,
  process.env.SOCIAL_ALLOW_LEGACY_BASE64 === 'false'
    ? { socialPostLimit: '1mb' }
    : undefined,
));
app.use((req, res, next) => {
  if (
    req.body === undefined &&
    req.path.startsWith('/api/') &&
    ['POST', 'PUT', 'PATCH'].includes(req.method)
  ) {
    req.body = {};
  }
  if (
    req.body !== undefined &&
    (req.body === null ||
      typeof req.body !== 'object' ||
      Array.isArray(req.body))
  ) {
    return res.status(400).json({
      error: 'The request body must be a JSON object.',
    });
  }
  next();
});

function validateBusinessPayload(body) {
  const errors = [];
  const textLimits = {
    businessType: 50,
    name: 255,
    category: 100,
    address: 500,
    facilityType: 50,
    hours: 100,
    availability: 255,
    visitUrl: 1000,
    details: 1000,
    businessLogoUrl: 10 * 1024 * 1024,
    imageUrl: 10 * 1024 * 1024,
  };
  for (const [field, limit] of Object.entries(textLimits)) {
    const value = body[field];
    if (value !== undefined && value !== null &&
        (typeof value !== 'string' || value.length > limit)) {
      errors.push(field);
    }
  }

  for (const field of ['pricePerHour', 'eventFee', 'additionalPlayerFee']) {
    const value = body[field];
    if (
      value !== undefined &&
      value !== null &&
      value !== '' &&
      (!isNumericInput(value) ||
        Number(value) < 0 ||
        Number(value) > 99999999.99)
    ) {
      errors.push(field);
    }
  }
  for (const [field, min, max] of [
    ['includedPlayers', 0, 30],
    ['slotCount', 1, 100],
    ['attendanceMin', 1, 100000],
    ['attendanceMax', 1, 100000],
  ]) {
    const value = body[field];
    if (
      value !== undefined &&
      value !== null &&
      value !== '' &&
      (!isNumericInput(value) ||
        !Number.isInteger(Number(value)) ||
        Number(value) < min ||
        Number(value) > max)
    ) {
      errors.push(field);
    }
  }
  if (
    isNumericInput(body.attendanceMin) &&
    isNumericInput(body.attendanceMax) &&
    Number(body.attendanceMin) > Number(body.attendanceMax)
  ) {
    errors.push('attendanceMin', 'attendanceMax');
  }

  for (const [field, maxItems, maxLength] of [
    ['tags', 20, 255],
    ['imageUrls', 20, 10 * 1024 * 1024],
    ['eventTypes', 20, 100],
    ['accessibilityNeeds', 20, 255],
    ['parkingNeeds', 20, 255],
    ['securityNeeds', 20, 255],
  ]) {
    const value = body[field];
    if (
      value !== undefined &&
      (!Array.isArray(value) ||
        value.length > maxItems ||
        value.some(
          (item) => typeof item !== 'string' || item.length > maxLength,
        ))
    ) {
      errors.push(field);
    }
  }
  for (const field of ['ratePeriods', 'sportsSlots', 'fitnessCategories', 'fitnessCoaches']) {
    const value = body[field];
    if (value !== undefined && (!Array.isArray(value) || value.length > 20)) {
      errors.push(field);
    }
  }
  if (body.ratePeriods !== undefined && Array.isArray(body.ratePeriods)) {
    for (const period of body.ratePeriods) {
      if (
        !period ||
        typeof period !== 'object' ||
        Array.isArray(period) ||
        typeof period.start !== 'string' ||
        !/^([01]\d|2[0-3]):[0-5]\d$/.test(period.start) ||
        typeof period.end !== 'string' ||
        !/^([01]\d|2[0-3]):[0-5]\d$/.test(period.end) ||
        Number(period.end.replace(':', '')) <=
          Number(period.start.replace(':', '')) ||
        !isNumericInput(period.pricePerHour) ||
        Number(period.pricePerHour) <= 0 ||
        Number(period.pricePerHour) > 99999999.99
      ) {
        errors.push('ratePeriods');
        break;
      }
    }
  }
  if (
    body.visitUrl !== undefined &&
    body.visitUrl !== null &&
    body.visitUrl !== ''
  ) {
    try {
      const url = new URL(body.visitUrl);
      if (!['http:', 'https:'].includes(url.protocol) || !url.hostname) {
        errors.push('visitUrl');
      }
    } catch {
      errors.push('visitUrl');
    }
  }
  return [...new Set(errors)];
}

function hasValidPaymongoSignature(rawBody, signatureHeader, liveMode, secret) {
  if (!rawBody || !signatureHeader || !secret) return false;
  const signatureParts = Object.fromEntries(
    signatureHeader
      .split(',')
      .map((part) => part.trim().split('=', 2))
      .filter(([key, value]) => key && value),
  );
  const timestamp = signatureParts.t;
  const providedSignature = signatureParts[liveMode ? 'li' : 'te'];
  if (!timestamp || !providedSignature) return false;

  const expectedSignature = crypto
    .createHmac('sha256', secret)
    .update(`${timestamp}.${rawBody.toString('utf8')}`)
    .digest('hex');
  const expected = Buffer.from(expectedSignature, 'hex');
  const provided = Buffer.from(providedSignature, 'hex');
  return expected.length === provided.length &&
    crypto.timingSafeEqual(expected, provided);
}

function isConfiguredPaymentValue(value) {
  return typeof value === 'string' &&
    value.trim().length > 0 &&
    !/^(your_|replace-with|sk_test_your|whsk_your)/i.test(value.trim());
}

function paymongoIsConfigured() {
  const secretKey = process.env.PAYMONGO_SECRET_KEY?.trim() ?? '';
  if (
    /^sk_live_/i.test(secretKey) &&
    process.env.PAYMONGO_LIVE_ENABLED !== 'true'
  ) {
    return false;
  }
  return [
    process.env.PAYMONGO_SECRET_KEY,
    process.env.PAYMONGO_WEBHOOK_SECRET,
    process.env.PAYMONGO_SUCCESS_URL,
    process.env.PAYMONGO_CANCEL_URL,
  ].every(isConfiguredPaymentValue);
}

function bookingStartsAtLeastSixHoursAway(booking, now = new Date()) {
  const date = dateOnly(booking.bookingDate);
  const time = String(booking.startTime ?? '').slice(0, 8);
  if (!validCalendarDate(date) || !/^\d{2}:\d{2}:\d{2}$/.test(time)) {
    return false;
  }
  const startTimestamp = Date.parse(`${date}T${time}+08:00`);
  return Number.isFinite(startTimestamp) &&
    startTimestamp - now.getTime() >= 6 * 60 * 60 * 1000;
}

async function requestPaymongoBookingRefund(booking) {
  const bookingId = Number(booking.id);
  const paymentReference = String(booking.paymentReference ?? '');
  const amount = Number(booking.paidAmount);
  try {
    const secretKey = process.env.PAYMONGO_SECRET_KEY?.trim() ?? '';
    if (
      !isConfiguredPaymentValue(secretKey) ||
      (/^sk_live_/i.test(secretKey) &&
        process.env.PAYMONGO_LIVE_ENABLED !== 'true')
    ) {
      throw new Error('PayMongo refunds are not configured.');
    }
    if (!/^pay_[A-Za-z0-9_-]+$/.test(paymentReference)) {
      throw new Error('The booking has no refundable PayMongo payment reference.');
    }
    if (!Number.isFinite(amount) || amount <= 0) {
      throw new Error('The booking has no paid amount to refund.');
    }
    const response = await fetch('https://api.paymongo.com/v1/refunds', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${process.env.PAYMONGO_SECRET_KEY}:`).toString('base64')}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'Idempotency-Key': `booking-cancellation-refund-${bookingId}`,
      },
      body: JSON.stringify({
        data: {
          attributes: {
            amount: Math.round(amount * 100),
            payment_id: paymentReference,
            reason: 'others',
            notes: `Customer cancelled booking ${bookingId}.`,
          },
        },
      }),
    });
    const payload = await response.json();
    if (!response.ok) {
      throw new Error(
        payload?.errors?.[0]?.detail || 'PayMongo could not process the refund.',
      );
    }
    const refundId = payload?.data?.id;
    if (typeof refundId !== 'string' || refundId.trim().length === 0) {
      throw new Error('PayMongo returned no refund reference.');
    }
    const refundStatus =
      payload?.data?.attributes?.status === 'succeeded' ? 'succeeded' : 'pending';
    await pool.execute(
      `UPDATE bookings
       SET payment_refund_status = ?, payment_refund_id = ?
       WHERE id = ? AND payment_refund_status = 'pending'`,
      [refundStatus, refundId, bookingId],
    );
    return refundStatus;
  } catch (error) {
    console.error('Booking payment refund failed.', {
      bookingId,
      error,
    });
    await pool.execute(
      `UPDATE bookings
       SET payment_refund_status = 'failed'
       WHERE id = ? AND payment_refund_status = 'pending'`,
      [bookingId],
    );
    return 'failed';
  }
}

async function recordUserActivity(
  executor,
  userId,
  activityType,
  title,
  description,
  venueDetails = null,
  { systemGenerated = false } = {},
) {
  const auditContext = systemGenerated
    ? {}
    : auditContextStorage.getStore() || {};
  await executor.execute(
    `INSERT INTO user_activity_logs
       (user_id, activity_type, title, description, venue_id, venue_name,
        sport_type, details_json, actor_user_id, actor_role, request_id,
        ip_address, user_agent)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    [
      userId,
      activityType,
      title,
      description,
      venueDetails?.venueId ?? null,
      venueDetails?.venueName ?? null,
      venueDetails?.sportType ?? null,
      venueDetails ? JSON.stringify(venueDetails.details ?? {}) : null,
      auditContext.actorUserId ?? null,
      auditContext.actorRole ?? null,
      auditContext.requestId ?? null,
      auditContext.ipAddress ?? null,
      auditContext.userAgent ?? null,
    ],
  );
}

const processBookingApprovalDeadlines =
  createBookingApprovalDeadlineProcessor({
    pool,
    recordUserActivity,
    notifyBookingParticipants: queueBookingNotifications,
  });
const processBookingPaymentDeadlines =
  createBookingPaymentDeadlineProcessor({
    pool,
    recordUserActivity,
    notifyBookingParticipants: queueBookingNotifications,
  });

async function requireAuth(req, res, next) {
  const header = req.get('authorization') || '';
  const [scheme, value] = header.split(' ');

  if (scheme !== 'Bearer' || !value) {
    return res.status(401).json({ error: 'A Bearer token is required.' });
  }

  try {
    req.auth = jwt.verify(value, process.env.JWT_SECRET);
  } catch (error) {
    return res.status(401).json({ error: 'The access token is invalid or expired.' });
  }

  try {
    if (!(await isActiveUser(req.auth.sub))) {
      return res.status(403).json({ error: 'This account is not active.' });
    }
    setAuditActor(req.auth.sub, req.auth.role);
    return next();
  } catch (error) {
    return next(error);
  }
}

async function isActiveUser(userId) {
  const cacheKey = String(userId);
  const cached = userStatusCache.get(cacheKey);
  if (cached && cached.expiresAt > Date.now()) {
    return cached.status === 'active';
  }
  if (cached) userStatusCache.delete(cacheKey);

  const pending = pendingUserStatusChecks.get(cacheKey);
  if (pending) return pending;

  const version = userStatusCacheVersions.get(cacheKey) || 0;
  const check = (async () => {
    const [users] = await pool.execute(
      'SELECT status FROM users WHERE id = ? LIMIT 1',
      [userId],
    );
    if (version !== (userStatusCacheVersions.get(cacheKey) || 0)) {
      return isActiveUser(userId);
    }
    const status = users[0]?.status ?? null;
    if (status !== null) {
      userStatusCache.set(cacheKey, {
        status,
        expiresAt: Date.now() + userStatusCacheTtlMs,
      });
      while (userStatusCache.size > maxUserStatusCacheEntries) {
        userStatusCache.delete(userStatusCache.keys().next().value);
      }
    }
    return status === 'active';
  })();
  pendingUserStatusChecks.set(cacheKey, check);
  try {
    return await check;
  } finally {
    if (pendingUserStatusChecks.get(cacheKey) === check) {
      pendingUserStatusChecks.delete(cacheKey);
    }
  }
}

function invalidateUserStatusCache(userId) {
  const cacheKey = String(userId);
  userStatusCache.delete(cacheKey);
  pendingUserStatusChecks.delete(cacheKey);
  userStatusCacheVersions.set(
    cacheKey,
    (userStatusCacheVersions.get(cacheKey) || 0) + 1,
  );
  liveUpdates.closeUser(cacheKey);
}

registerSystemRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  notificationTokenHash,
});

registerAuthRoutes({
  app,
  pool,
  bcrypt,
  jwt,
  createRateLimiter,
  sendPasswordResetCode,
  sendVerificationCode,
  requireAuth,
  normalizeEmail,
  isValidEmail,
  isValidRole,
  createVerificationCode,
  hashVerificationCode,
  normalizeText,
  publicUser,
  recordUserActivity,
  setAuditActor,
  invalidateCustomerBusinesses,
  invalidateUserStatusCache,
  fetch,
  googleClientId: process.env.GOOGLE_CLIENT_ID ||
    '451592121635-f7hgfk7plbi3mngvor1eenrup21mlbg5.apps.googleusercontent.com',
  environment: process.env,
});

registerSocialRoutes({
  app,
  pool,
  requireAuth,
  mediaStorage: socialMediaStorage,
  allowLegacyBase64: process.env.SOCIAL_ALLOW_LEGACY_BASE64 !== 'false',
});
registerSocialClubRoutes({
  app,
  pool,
  requireAuth,
  mediaStorage: socialMediaStorage,
});

registerMessagingRoutes({
  app,
  pool,
  requireAuth,
  positiveIntegerId,
  normalizeBusinessType,
  recordUserActivity,
  publishToUser: liveUpdates.publishToUser,
  messagingStorage,
});
registerSavedItemsRoutes({
  app,
  pool,
  requireAuth,
  recordUserActivity,
});
registerActivityLogRoutes({ app, pool, requireAuth });
registerMatchmakingRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  publishToUser: liveUpdates.publishToUser,
  recordUserActivity,
  notifyBookingParticipants,
});
registerMerchantProfileRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  invalidateCustomerBusinesses,
  recordUserActivity,
  isValidBookingDeadlineMinutes,
  DEFAULT_BOOKING_DEADLINE_MINUTES,
  MAX_BOOKING_DEADLINE_MINUTES,
  isValidEmail,
});
registerMerchantBusinessRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  parseJsonArray,
  readCache,
  customerBusinessesCacheKey,
  customerBusinessesCacheTtlMs,
});
registerMerchantBusinessWriteRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  positiveIntegerId,
  validateBusinessPayload,
  invalidateCustomerBusinesses,
  recordUserActivity,
  parseBusinessCoordinates,
  normalizeSportsSlots,
  fitnessDetailsFromBody,
  saveEventDetails,
  saveFitnessDetails,
});

function requireRole(role) {
  return async (req, res, next) => {
    try {
      const [users] = await pool.execute(
        'SELECT role, status FROM users WHERE id = ? LIMIT 1',
        [req.auth.sub],
      );
      const merchantCustomerPortal =
        role === 'customer' &&
        users[0]?.role === 'merchant' &&
        req.auth.role === 'customer' &&
        req.auth.accountRole === 'merchant' &&
        req.auth.portalMode === 'customer' &&
        req.auth.portalVersion === 1;
      const roleMatches =
        (users[0]?.role === role && req.auth.role === role) ||
        merchantCustomerPortal;
      if (!users[0] || !roleMatches || users[0].status !== 'active') {
        return res.status(403).json({ error: `Only active ${role} accounts can access this endpoint.` });
      }
      return next();
    } catch (error) {
      return next(error);
    }
  };
}

function validDate(value) {
  return typeof value === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(value);
}

function validCalendarDate(value) {
  if (!validDate(value)) return false;
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(parsed.getTime()) &&
    parsed.toISOString().slice(0, 10) === value;
}

function dateOnly(value) {
  return value instanceof Date
    ? value.toISOString().slice(0, 10)
    : String(value).slice(0, 10);
}

function fitnessPlanEndDate(startDate, planType, durationDays = null) {
  const start = new Date(`${dateOnly(startDate)}T00:00:00.000Z`);
  const days = Number.isSafeInteger(Number(durationDays)) && Number(durationDays) > 0
    ? Number(durationDays)
    : planType === 'monthly'
    ? 30
    : planType === 'yearly'
    ? 365
    : 1;
  start.setUTCDate(start.getUTCDate() + days - 1);
  return start.toISOString().slice(0, 10);
}

function fitnessPlanDurationDays(planType, category) {
  if (planType === 'monthly') return 30;
  if (planType === 'yearly') {
    const freeMonths = category?.yearlyDiscountType === 'freeMonths'
      ? Number(category.yearlyDiscountValue)
      : 0;
    return 365 + (Number.isSafeInteger(freeMonths) && freeMonths > 0
      ? freeMonths * 30
      : 0);
  }
  return planType === 'session' ? 1 : null;
}

function fitnessAvailabilityIncludesDate(availability, date) {
  const normalized = String(availability ?? '').trim().toLowerCase();
  if (!normalized || normalized === 'any') return true;
  const availableDays = new Set(
    normalized.split(/[,;]/).map((day) => day.trim()).filter(Boolean),
  );
  if (availableDays.size === 0) return true;
  const weekdayNames = [
    'sunday',
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
  ];
  const weekday = new Date(`${date}T00:00:00.000Z`).getUTCDay();
  const name = weekdayNames[weekday];
  const abbreviation = name.slice(0, 3);
  return availableDays.has(name) || availableDays.has(abbreviation);
}

function validTime(value) {
  return typeof value === 'string' && /^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(value);
}

function venueHours(value, { allowMidnightClosing = false } = {}) {
  const match = String(value ?? '').match(
    /^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\s*[-–]\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\s*$/i,
  );
  if (!match) return null;
  const toMinutes = (hourText, minuteText, period) => {
    const hour = Number(hourText);
    const minute = Number(minuteText ?? 0);
    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;
    return (hour % 12 + (period.toUpperCase() === 'PM' ? 12 : 0)) * 60 +
      minute;
  };
  const opening = toMinutes(match[1], match[2], match[3]);
  let closing = toMinutes(match[4], match[5], match[6]);
  if (
    allowMidnightClosing &&
    Number(match[4]) === 12 &&
    Number(match[5] ?? 0) === 0 &&
    match[6].toUpperCase() === 'AM'
  ) {
    closing = 24 * 60;
  }
  if (opening === null || closing === null || closing <= opening) return null;
  return { opening, closing };
}

function normalizeSportsSlots(value, totalSlots) {
  if (!Array.isArray(value) || value.length < 1 || value.length > 20 ||
      !Number.isInteger(totalSlots) || totalSlots < 1 || totalSlots > 100) {
    return null;
  }
  const names = new Set();
  const normalized = [];
  for (const item of value) {
    if (!item || typeof item !== 'object' || Array.isArray(item)) return null;
    const sportType = typeof item.sportType === 'string'
      ? item.sportType.trim() : '';
    if (
      typeof item.sportType !== 'string' ||
      item.sportType.length > 100 ||
      (item.fullStudio !== undefined &&
        typeof item.fullStudio !== 'boolean') ||
      !isNumericInput(item.pricePerHour) ||
      !isNumericInput(item.slotCount) ||
      (item.includedPlayers !== undefined &&
        !isNumericInput(item.includedPlayers)) ||
      (item.additionalPlayerFee !== undefined &&
        !isNumericInput(item.additionalPlayerFee))
    ) {
      return null;
    }
    const pricePerHour = Number(item.pricePerHour);
    const fullStudio = item.fullStudio === true;
    const slotCount = Number(item.slotCount);
    const includedPlayers = Number(item.includedPlayers ?? 0);
    const additionalPlayerFee = Number(item.additionalPlayerFee ?? 0);
    const key = sportType.toLowerCase();
    if (!sportType || names.has(key) || !Number.isFinite(pricePerHour) ||
        pricePerHour <= 0 || !Number.isInteger(slotCount) ||
        slotCount < 1 || slotCount > totalSlots ||
        (fullStudio && slotCount !== totalSlots) ||
        !Number.isInteger(includedPlayers) || includedPlayers < 0 ||
        includedPlayers > 1000 || !Number.isFinite(additionalPlayerFee) ||
        additionalPlayerFee < 0 || additionalPlayerFee > 99999999.99 ||
        (additionalPlayerFee > 0 && includedPlayers < 1)) {
      return null;
    }
    names.add(key);
    normalized.push({
      sportType,
      pricePerHour,
      fullStudio,
      slotCount,
      includedPlayers,
      additionalPlayerFee,
    });
  }
  return normalized;
}

function configuredSportsSlots(venue) {
  let sportsSlots = venue.sports_slots_json ?? venue.sportsSlots;
  if (typeof sportsSlots === 'string') {
    try {
      sportsSlots = JSON.parse(sportsSlots);
    } catch {
      sportsSlots = null;
    }
  }
  if (Array.isArray(sportsSlots) && sportsSlots.length > 0) {
    return sportsSlots;
  }
  return [{
    sportType: venue.category || 'Sports',
    pricePerHour: Number(venue.price_per_hour ?? venue.pricePerHour),
    fullStudio: true,
    slotCount: 1,
  }];
}

function bookingSlotNumbers(value, fallback = null) {
  let slotNumbers = value;
  if (typeof slotNumbers === 'string') {
    try {
      slotNumbers = JSON.parse(slotNumbers);
    } catch {
      slotNumbers = null;
    }
  }
  if (Array.isArray(slotNumbers)) {
    const validSlots = [...new Set(slotNumbers.map(Number).filter((slot) =>
      Number.isSafeInteger(slot) && slot > 0,
    ))].sort((a, b) => a - b);
    if (validSlots.length > 0) return validSlots;
  }
  const slotNumber = Number(fallback);
  return Number.isSafeInteger(slotNumber) && slotNumber > 0
    ? [slotNumber]
    : [];
}

app.get('/api/bookings/availability', requireAuth, requireRole('customer'), async (req, res, next) => {
  const venueId = Number(req.query.venueId);
  const bookingDate = req.query.date;
  if (!isNumericInput(req.query.venueId) ||
      !Number.isSafeInteger(venueId) || venueId <= 0 || !validDate(bookingDate)) {
    return res.status(400).json({ error: 'venueId and a valid date are required.' });
  }
  try {
    const [bookings] = await pool.execute(
      `SELECT b.start_time AS startTime, b.duration_hours AS durationHours,
              b.sport_type AS sportType, b.slot_number AS slotNumber,
              b.slot_numbers_json AS slotNumbers,
              b.occupies_full_studio AS occupiesFullStudio,
              b.status AS status
       FROM bookings b
       WHERE b.venue_id = ? AND b.booking_date = ?
         AND b.status IN (
           'pending', 'approved',
           'matchmaking_pending_merchant', 'matchmaking_open'
         )
       ORDER BY b.start_time`,
      [venueId, bookingDate],
    );
    for (const booking of bookings) {
      booking.slotNumbers = bookingSlotNumbers(
        booking.slotNumbers,
        booking.slotNumber,
      );
    }
    return res.json({ bookings });
  } catch (error) {
    return next(error);
  }
});

app.get(
  '/api/payments/paymongo/config',
  requireAuth,
  requireRole('customer'),
  (_req, res) => {
    return res.json({ onlinePaymentsEnabled: paymongoIsConfigured() });
  },
);

registerPaymentRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  isNumericInput,
  bookingSlotNumbers,
  bookingTransactionId,
  formatBookingDeadlineDuration,
  hasValidPaymongoSignature,
  notifyBookingParticipants,
  notifyMatchDiscovery,
  paymongoIsConfigured,
  queueBookingNotifications,
  recordUserActivity,
  requestPaymongoBookingRefund,
  liveUpdates,
});

const completeDueBookings = registerBookingRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  positiveIntegerId,
  bookingCheckInWindowIncludesNow,
  bookingSlotNumbers,
  bookingStartsAtLeastSixHoursAway,
  bookingTransactionId,
  configuredSportsSlots,
  createBookingToken,
  dateOnly,
  fitnessAvailabilityIncludesDate,
  fitnessPlanDurationDays,
  fitnessPlanEndDate,
  formatBookingDeadlineDuration,
  hashBookingToken,
  isNumericInput,
  manilaDateTime,
  normalizeBusinessType,
  parseJsonArray,
  processBookingApprovalDeadlines,
  processBookingPaymentDeadlines,
  DEFAULT_BOOKING_DEADLINE_MINUTES,
  queueBookingNotifications,
  recordUserActivity,
  requestPaymongoBookingRefund,
  validCalendarDate,
  validDate,
  validTime,
  venueCheckInCode,
  venueHours,
  verifyVenueCheckInCode,
  liveUpdates,
  notifyMatchDiscovery,
  notifyBookingParticipants,
  crypto,
});

registerMerchantNewsRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  positiveIntegerId,
  normalizeText,
  invalidateCustomerBusinesses,
  recordUserActivity,
});

registerCustomerVenueRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  positiveIntegerId,
  normalizeBusinessType,
  normalizeText,
  isNumericInput,
  invalidateCustomerBusinesses,
  recordUserActivity,
  newsPostResponse,
  jwt,
});

app.use((error, req, res, next) => {
  const requestId = auditContextStorage.getStore()?.requestId;
  console.error('API request failed.', {
    requestId,
    method: req.method,
    path: req.path,
    error,
  });
  if (error.type === 'entity.too.large') {
    return res.status(413).json({
      error: 'The selected images are too large. Choose fewer or smaller images.',
    });
  }
  if (error.type === 'entity.parse.failed') {
    return res.status(400).json({ error: 'The request body contains invalid JSON.' });
  }
  if (
    error.code === 'EAUTH' ||
    error.code === 'ESOCKET' ||
    error.code === 'ECONNECTION' ||
    error.responseCode === 535
  ) {
    return res.status(503).json({
      error: 'We could not send the verification email. Please try again later.',
    });
  }
  return res.status(500).json({ error: 'An unexpected server error occurred.' });
});

function startServer() {
  const server = app.listen(port, '0.0.0.0', () => {
    console.log(`SpotGo Sports API listening on http://0.0.0.0:${port}`);
  });
  liveUpdates.attach(server);
  const completionInterval = setInterval(() => {
    processBookingApprovalDeadlines().catch((error) => {
      console.error('Could not process booking approval deadlines.', error);
    });
    processBookingPaymentDeadlines().catch((error) => {
      console.error('Could not process booking payment deadlines.', error);
    });
    completeDueBookings().catch((error) => {
      console.error('Could not automatically finish due bookings.', error);
    });
  }, 10_000);
  completionInterval.unref();
  processBookingApprovalDeadlines().catch((error) => {
    console.error('Could not process booking approval deadlines.', error);
  });
  processBookingPaymentDeadlines().catch((error) => {
    console.error('Could not process booking payment deadlines.', error);
  });
  completeDueBookings().catch((error) => {
    console.error('Could not automatically finish due bookings.', error);
  });
  return server;
}

startServer();

module.exports = { invalidateUserStatusCache };
