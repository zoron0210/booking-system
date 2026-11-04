function registerSavedItemsRoutes({ app, pool, requireAuth, recordUserActivity }) {
  app.get('/api/saved-items', requireAuth, async (req, res, next) => {
    try {
      const [items] = await pool.execute(
        `SELECT id, item_type AS itemType, item_key AS itemKey,
                title, subtitle, image_url AS imageUrl,
                owner_email AS ownerEmail, owner_phone AS ownerPhone,
                created_at AS createdAt
         FROM saved_items
         WHERE user_id = ?
         ORDER BY created_at DESC`,
        [req.auth.sub],
      );
      return res.json({ items });
    } catch (error) {
      return next(error);
    }
  });

  app.get('/api/saved-item-counts', requireAuth, async (req, res, next) => {
    const itemType = req.query.itemType;
    if (!['sports', 'event', 'fitness'].includes(itemType)) {
      return res.status(400).json({ error: 'Invalid saved item type.' });
    }
    try {
      const [rows] = await pool.execute(
        `SELECT item_key AS itemKey, COUNT(*) AS saveCount
         FROM saved_items
         WHERE item_type = ?
         GROUP BY item_key`,
        [itemType],
      );
      return res.json({
        counts: Object.fromEntries(
          rows.map((row) => [row.itemKey, Number(row.saveCount)]),
        ),
      });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/saved-items', requireAuth, async (req, res, next) => {
    const itemType = req.body.itemType;
    const itemKey =
      typeof req.body.itemKey === 'string' ? req.body.itemKey.trim() : '';
    const title = typeof req.body.title === 'string' ? req.body.title.trim() : '';
    const subtitle =
      typeof req.body.subtitle === 'string' ? req.body.subtitle.trim() : '';
    const imageUrl =
      typeof req.body.imageUrl === 'string' ? req.body.imageUrl.trim() : null;

    if (
      !['sports', 'event', 'fitness'].includes(itemType) ||
      !itemKey ||
      !title ||
      itemKey.length > 255 ||
      title.length > 255 ||
      (req.body.subtitle != null &&
        (typeof req.body.subtitle !== 'string' ||
          req.body.subtitle.length > 500)) ||
      (req.body.imageUrl != null &&
        (typeof req.body.imageUrl !== 'string' ||
          req.body.imageUrl.length > 10 * 1024 * 1024))
    ) {
      return res.status(400).json({ error: 'A valid saved item is required.' });
    }

    try {
      const [owners] = await pool.execute(
        `SELECT u.email, u.phone, mp.contact_email AS contactEmail
         FROM merchant_businesses b
         JOIN users u ON u.id = b.merchant_id
         LEFT JOIN merchant_profiles mp ON mp.user_id = u.id
         WHERE b.id = ? OR b.name = ?
         LIMIT 1`,
        [itemKey, itemKey],
      );
      const owner = owners[0];
      const ownerEmail = owner?.contactEmail || owner?.email || null;
      const ownerPhone = owner?.phone || null;
      await pool.execute(
        `INSERT INTO saved_items
         (user_id, item_type, item_key, title, subtitle, image_url,
          owner_email, owner_phone)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE title = VALUES(title), subtitle = VALUES(subtitle),
                                 image_url = VALUES(image_url),
                                 owner_email = COALESCE(VALUES(owner_email), owner_email),
                                 owner_phone = COALESCE(VALUES(owner_phone), owner_phone)`,
        [
          req.auth.sub,
          itemType,
          itemKey,
          title,
          subtitle || null,
          imageUrl,
          ownerEmail,
          ownerPhone,
        ],
      );
      await recordUserActivity(
        pool,
        req.auth.sub,
        'item_saved',
        'Saved an item',
        `Saved ${itemType} item: ${title.slice(0, 200)}.`,
      );
      return res.status(201).json({ message: 'Item saved.' });
    } catch (error) {
      return next(error);
    }
  });

  app.delete(
    '/api/saved-items/:itemType/:itemKey',
    requireAuth,
    async (req, res, next) => {
      if (
        !['sports', 'event', 'fitness'].includes(req.params.itemType) ||
        !req.params.itemKey ||
        req.params.itemKey.length > 255
      ) {
        return res.status(400).json({ error: 'Invalid saved item type.' });
      }
      try {
        const [result] = await pool.execute(
          'DELETE FROM saved_items WHERE user_id = ? AND item_type = ? AND item_key = ?',
          [req.auth.sub, req.params.itemType, req.params.itemKey],
        );
        if (result.affectedRows > 0) {
          await recordUserActivity(
            pool,
            req.auth.sub,
            'item_removed',
            'Removed a saved item',
            `Removed a saved ${req.params.itemType} item.`,
          );
        }
        return res.json({ message: 'Item removed.' });
      } catch (error) {
        return next(error);
      }
    },
  );
}

module.exports = { registerSavedItemsRoutes };
