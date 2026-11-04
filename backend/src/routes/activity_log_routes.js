function registerActivityLogRoutes({ app, pool, requireAuth }) {
  app.get('/api/activity-logs', requireAuth, async (req, res, next) => {
    try {
      const [activities] = await pool.execute(
        `SELECT id, activity_type AS activityType, title, description,
                venue_id AS venueId, venue_name AS venueName,
                sport_type AS sportType, details_json AS details,
                actor_role AS actorRole, request_id AS requestId,
                created_at AS createdAt
         FROM user_activity_logs
         WHERE user_id = ?
         ORDER BY created_at DESC, id DESC`,
        [req.auth.sub],
      );
      return res.json({ activities });
    } catch (error) {
      return next(error);
    }
  });
}

module.exports = { registerActivityLogRoutes };
