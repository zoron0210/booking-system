function registerSystemRoutes({
  app,
  pool,
  requireAuth,
  notificationTokenHash,
}) {
  app.get('/health', async (req, res, next) => {
    try {
      await pool.query('SELECT 1');
      return res.json({ status: 'ok', database: 'connected' });
    } catch (error) {
      return next(error);
    }
  });

  app.put('/api/notifications/device', requireAuth, async (req, res, next) => {
    const token = req.body?.fcmToken;
    const sound = req.body?.sound;
    if (
      typeof token !== 'string' ||
      token.trim().length < 20 ||
      token.length > 4096 ||
      !['system', 'tinker_bell'].includes(sound)
    ) {
      return res.status(400).json({
        error: 'A valid device token and notification sound are required.',
      });
    }
    try {
      const cleanToken = token.trim();
      await pool.execute(
        `INSERT INTO booking_notification_devices
         (token_hash, user_id, fcm_token, sound)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE user_id = VALUES(user_id),
           fcm_token = VALUES(fcm_token), sound = VALUES(sound),
           updated_at = CURRENT_TIMESTAMP`,
        [
          notificationTokenHash(cleanToken),
          req.auth.sub,
          cleanToken,
          sound,
        ],
      );
      return res.json({ message: 'Booking push notifications are enabled.' });
    } catch (error) {
      return next(error);
    }
  });

  app.delete(
    '/api/notifications/device',
    requireAuth,
    async (req, res, next) => {
      const token = req.body?.fcmToken;
      if (
        typeof token !== 'string' ||
        token.trim().length < 20 ||
        token.length > 4096
      ) {
        return res.status(400).json({ error: 'A valid device token is required.' });
      }
      try {
        await pool.execute(
          `DELETE FROM booking_notification_devices
           WHERE token_hash = ? AND user_id = ?`,
          [notificationTokenHash(token.trim()), req.auth.sub],
        );
        return res.json({
          message: 'Booking push notifications are disabled.',
        });
      } catch (error) {
        return next(error);
      }
    },
  );
}

module.exports = { registerSystemRoutes };
