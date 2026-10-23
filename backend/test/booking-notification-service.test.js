const test = require('node:test');
const assert = require('node:assert/strict');
const {
  createBookingNotificationService,
  normalizeTwilioPhone,
  sendTwilioSms,
} = require('../src/booking_notification_service');

test('booking events deliver email, SMS, and push to both participants', async () => {
  const delivered = [];
  const pool = {
    async execute(query) {
      if (query.includes('FROM users')) {
        return [[
          { id: 10, email: 'customer@example.com', phone: '+639171234567' },
          { id: 20, email: 'merchant@example.com', phone: '+639181234567' },
        ]];
      }
      return [[
        { userId: 10, fcmToken: 'customer-token', sound: 'system' },
        { userId: 20, fcmToken: 'merchant-token', sound: 'tinker_bell' },
      ]];
    },
  };
  const notify = createBookingNotificationService({
    pool,
    sendEmail: async (payload) => delivered.push(['email', payload]),
    sendSms: async (payload) => delivered.push(['sms', payload]),
    sendPushNotification: async (payload) => delivered.push(['push', payload]),
  });

  await notify({
    userIds: [10, 20, 10],
    event: 'approved',
    booking: { id: 42, venueName: 'Central Court' },
  });

  assert.equal(delivered.length, 6);
  assert.equal(delivered.filter(([channel]) => channel === 'email').length, 2);
  assert.equal(delivered.filter(([channel]) => channel === 'sms').length, 2);
  assert.deepEqual(
    delivered
      .filter(([channel]) => channel === 'push')
      .map(([, payload]) => [payload.token, payload.sound]),
    [['customer-token', 'system'], ['merchant-token', 'tinker_bell']],
  );
  assert.match(delivered[0][1].message, /Central Court/);
});

test('a failed delivery is logged while other channels still complete', async () => {
  const logged = [];
  const delivered = [];
  const pool = {
    async execute(query) {
      return query.includes('FROM users')
        ? [[{ id: 10, email: 'customer@example.com', phone: '+639171234567' }]]
        : [[]];
    },
  };
  const notify = createBookingNotificationService({
    pool,
    sendEmail: async () => {
      throw new Error('SMTP unavailable');
    },
    sendSms: async () => delivered.push('sms'),
    logger: { error: (...entry) => logged.push(entry) },
  });

  await notify({
    userIds: [10],
    event: 'requested',
    booking: {
      id: 42,
      venueName: 'Central Court',
      bookingDate: '2026-09-01',
      startTime: '09:00',
    },
  });

  assert.deepEqual(delivered, ['sms']);
  assert.equal(logged.length, 1);
  assert.equal(logged[0][1].channel, 'email');
});

test('Twilio sender uses credentials from runtime configuration', async () => {
  let captured;
  await sendTwilioSms({
    to: '+639171234567',
    message: 'Booking approved',
    environment: {
      TWILIO_ACCOUNT_SID: 'AC123',
      TWILIO_AUTH_TOKEN: 'private-token',
      TWILIO_FROM_NUMBER: '+15005550006',
    },
    fetchImpl: async (url, options) => {
      captured = { url, options };
      return { ok: true };
    },
  });

  test('Philippine mobile phone formats are converted to Twilio E.164', () => {
    assert.equal(normalizeTwilioPhone('0917 123 4567'), '+639171234567');
    assert.equal(normalizeTwilioPhone('639171234567'), '+639171234567');
    assert.equal(normalizeTwilioPhone('+639171234567'), '+639171234567');
    assert.throws(() => normalizeTwilioPhone('not-a-phone'), /international format/);
  });

  assert.match(captured.url, /Accounts\/AC123\/Messages\.json$/);
  assert.equal(
    captured.options.headers.Authorization,
    `Basic ${Buffer.from('AC123:private-token').toString('base64')}`,
  );
  assert.equal(
    new URLSearchParams(captured.options.body).get('To'),
    '+639171234567',
  );
});
