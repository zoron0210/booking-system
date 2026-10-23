const crypto = require('node:crypto');

const notificationCopy = {
  requested: {
    title: 'Booking request received',
    message: (booking) =>
      `Booking #${booking.id} at ${booking.venueName} was requested for ${booking.bookingDate} at ${booking.startTime}.`,
  },
  approved: {
    title: 'Booking approved',
    message: (booking) =>
      `Booking #${booking.id} at ${booking.venueName} was approved.`,
  },
  declined: {
    title: 'Booking declined',
    message: (booking) =>
      `Booking #${booking.id} at ${booking.venueName} was declined. Reason: ${booking.reason}`,
  },
  cancelled: {
    title: 'Booking cancelled',
    message: (booking) =>
      `Booking #${booking.id} at ${booking.venueName} was cancelled.`,
  },
  payment_updated: {
    title: 'Booking payment updated',
    message: (booking) =>
      `Payment for booking #${booking.id} at ${booking.venueName} is now ${booking.paymentStatus}.`,
  },
  approval_expired: {
    title: 'Booking request expired',
    message: (booking) =>
      `Booking #${booking.id} at ${booking.venueName} expired before the merchant approved it.`,
  },
  payment_expired: {
    title: 'Booking payment window expired',
    message: (booking) =>
      `Booking #${booking.id} at ${booking.venueName} expired because the required payment was not completed in time.`,
  },
};

async function sendBookingEmail({ to, title, message }) {
  const { sendBookingNotificationEmail } = require('./mailer');
  await sendBookingNotificationEmail({ to, title, message });
}

async function sendTwilioSms({ to, message, environment = process.env, fetchImpl = fetch }) {
  const required = ['TWILIO_ACCOUNT_SID', 'TWILIO_AUTH_TOKEN', 'TWILIO_FROM_NUMBER'];
  const missing = required.filter((key) => !environment[key]);
  if (missing.length > 0) {
    throw new Error(`Missing Twilio configuration: ${missing.join(', ')}`);
  }

  const credentials = Buffer.from(
    `${environment.TWILIO_ACCOUNT_SID}:${environment.TWILIO_AUTH_TOKEN}`,
  ).toString('base64');
  const response = await fetchImpl(
    `https://api.twilio.com/2010-04-01/Accounts/${environment.TWILIO_ACCOUNT_SID}/Messages.json`,
    {
      method: 'POST',
      headers: {
        Authorization: `Basic ${credentials}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        To: to,
        From: environment.TWILIO_FROM_NUMBER,
        Body: message,
      }),
    },
  );
  if (!response.ok) {
    const details = (await response.text()).slice(0, 500);
    throw new Error(`Twilio SMS failed (${response.status}): ${details}`);
  }
}

let firebaseApp;

function getFirebaseMessaging() {
  if (!firebaseApp) {
    const {
      applicationDefault,
      cert,
      getApps,
      initializeApp,
    } = require('firebase-admin/app');
    const { getMessaging } = require('firebase-admin/messaging');
    const serviceAccountJson = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;
    const credential = serviceAccountJson
      ? cert(JSON.parse(serviceAccountJson))
      : applicationDefault();
    firebaseApp = getApps()[0] || initializeApp({ credential });
  }
  return require('firebase-admin/messaging').getMessaging(firebaseApp);
}

async function sendPush({ token, title, message, bookingId, event, sound }) {
  const tone = sound === 'tinker_bell' ? 'tinker_bell' : 'system';
  const channelId = `booking_alerts_${tone}`;
  await getFirebaseMessaging().send({
    token,
    notification: { title, body: message },
    data: {
      type: 'booking',
      bookingId: String(bookingId),
      event,
      sound: tone,
    },
    android: {
      priority: 'high',
      notification: {
        channelId,
        sound: tone === 'tinker_bell' ? 'tinker_bell' : 'default',
      },
    },
    apns: {
      payload: {
        aps: {
          sound: tone === 'tinker_bell' ? 'tinker_bell.wav' : 'default',
        },
      },
    },
  });
}

function createBookingNotificationService({
  pool,
  sendEmail = sendBookingEmail,
  sendSms = sendTwilioSms,
  sendPushNotification = sendPush,
  logger = console,
}) {
  return async function notifyBookingParticipants({
    userIds,
    event,
    booking,
  }) {
    const copy = notificationCopy[event];
    if (!copy || !Array.isArray(userIds) || userIds.length === 0) return;

    const recipients = [...new Set(userIds.map(Number).filter(Number.isSafeInteger))];
    if (recipients.length === 0) return;
    const placeholders = recipients.map(() => '?').join(', ');
    const [users] = await pool.execute(
      `SELECT id, email, phone
       FROM users
       WHERE id IN (${placeholders}) AND status = 'active'`,
      recipients,
    );
    const [devices] = await pool.execute(
      `SELECT user_id AS userId, fcm_token AS fcmToken, sound
       FROM booking_notification_devices
       WHERE user_id IN (${placeholders})`,
      recipients,
    );
    const title = copy.title;
    const message = copy.message(booking);
    const tasks = [];

    for (const user of users) {
      if (user.email) {
        tasks.push({
          channel: 'email',
          userId: user.id,
          promise: Promise.resolve().then(() =>
            sendEmail({ to: user.email, title, message }),
          ),
        });
      }
      if (user.phone) {
        tasks.push({
          channel: 'sms',
          userId: user.id,
          promise: Promise.resolve().then(() =>
            sendSms({
              to: normalizeTwilioPhone(user.phone),
              message: `${title}: ${message}`,
            }),
          ),
        });
      }
    }
    for (const device of devices) {
      tasks.push({
        channel: 'push',
        userId: device.userId,
        promise: sendPushNotification({
          token: device.fcmToken,
          title,
          message,
          bookingId: booking.id,
          event,
          sound: device.sound,
        }),
      });
    }

    const results = await Promise.allSettled(
      tasks.map(({ promise }) => promise),
    );
    results.forEach((result, index) => {
      if (result.status === 'rejected') {
        logger.error('Booking notification delivery failed.', {
          bookingId: booking.id,
          event,
          userId: tasks[index].userId,
          channel: tasks[index].channel,
          error: result.reason,
        });
      }
    });
  };
}

function normalizeTwilioPhone(value) {
  const input = String(value).trim();
  const compact = input.replace(/[\s().-]/g, '');
  if (/^\+[1-9]\d{7,14}$/.test(compact)) return compact;
  if (/^00[1-9]\d{7,14}$/.test(compact)) return `+${compact.slice(2)}`;

  const digits = compact.replace(/\D/g, '');
  if (/^09\d{9}$/.test(digits)) return `+63${digits.slice(1)}`;
  if (/^9\d{9}$/.test(digits)) return `+63${digits}`;
  if (/^639\d{9}$/.test(digits)) return `+${digits}`;
  throw new Error('The saved phone number is not in a valid international format.');
}

function notificationTokenHash(token) {
  return crypto.createHash('sha256').update(token).digest('hex');
}

module.exports = {
  createBookingNotificationService,
  normalizeTwilioPhone,
  notificationTokenHash,
  sendTwilioSms,
};
