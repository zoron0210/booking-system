const { createRateLimiter } = require('../rate_limit');

const MAX_POSTS_PER_24_HOURS = 5;
const MAX_CAPTION_LENGTH = 2000;
const MAX_IMAGES_PER_POST = 5;
const MAX_IMAGE_BYTES = 10 * 1024 * 1024;
const MAX_COMMENT_LENGTH = 2000;
const SOCIAL_POST_REPORT_REASONS = new Set([
  'spam',
  'harassment',
  'inappropriate',
  'other',
]);

function validTenorGifUrl(value) {
  if (typeof value !== 'string' || value.length > 2048) return false;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' &&
      url.hostname === 'media.tenor.com' &&
      url.port === '' &&
      !url.username &&
      !url.password &&
      /\.(gif|webp)$/i.test(url.pathname);
  } catch {
    return false;
  }
}

function positiveId(value) {
  if (
    (typeof value !== 'string' && typeof value !== 'number') ||
    (typeof value === 'string' && !/^[1-9]\d*$/.test(value))
  ) {
    return null;
  }
  const id = Number(value);
  return Number.isSafeInteger(id) && id > 0 ? id : null;
}

function normalizeCaption(value) {
  return typeof value === 'string'
    ? value.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim()
    : '';
}

async function visiblePost(pool, postId, viewerId) {
  const [rows] = await pool.execute(
    `SELECT p.id, p.user_id AS ownerId
     FROM social_posts p
     JOIN users u ON u.id = p.user_id AND u.status = 'active'
     WHERE p.id = ?
       AND (? IS NULL OR NOT EXISTS (
         SELECT 1 FROM user_blocks b
         WHERE (b.blocker_id = ? AND b.blocked_user_id = p.user_id)
            OR (b.blocker_id = p.user_id AND b.blocked_user_id = ?)
       ))
     LIMIT 1`,
    [postId, viewerId, viewerId, viewerId],
  );
  return rows[0] ?? null;
}

async function createSocialNotification(
  pool,
  { recipientUserId, actorUserId, type, postId = null, sourceId },
) {
  if (String(recipientUserId) === String(actorUserId)) return;
  await pool.execute(
    `INSERT IGNORE INTO social_notifications
       (recipient_user_id, actor_user_id, type, post_id, source_id)
     VALUES (?, ?, ?, ?, ?)`,
    [recipientUserId, actorUserId, type, postId, sourceId],
  );
}

function validateImages(value) {
  if (value == null) return { valid: true, images: [] };
  if (!Array.isArray(value) || value.length > MAX_IMAGES_PER_POST) {
    return { valid: false };
  }
  const images = [];
  for (const image of value) {
    if (validTenorGifUrl(image)) {
      images.push(image);
      continue;
    }
    const match = typeof image === 'string'
      ? /^data:image\/(jpeg|png|webp);base64,([A-Za-z0-9+/]+={0,2})$/i.exec(image)
      : null;
    if (!match) return { valid: false };
    const bytes = Buffer.from(match[2], 'base64');
    if (
      bytes.length === 0 ||
      bytes.length > MAX_IMAGE_BYTES ||
      bytes.toString('base64') !== match[2] ||
      !matchesImageType(bytes, match[1].toLowerCase())
    ) {
      return { valid: false };
    }
    images.push(image);
  }
  return { valid: true, images };
}

function matchesImageType(bytes, type) {
  if (type === 'png') {
    return bytes.subarray(0, 8).equals(
      Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    );
  }
  if (type === 'jpeg' || type === 'jpg') {
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

function registerSocialRoutes({
  app,
  pool,
  requireAuth,
  tenorApiKey = process.env.TENOR_API_KEY,
  fetchImpl = globalThis.fetch,
}) {
  const optionalAuth = (req, res, next) => {
    const authorization = typeof req.get === 'function'
      ? req.get('authorization')
      : req.headers?.authorization;
    if (!authorization) {
      req.auth = null;
      return next();
    }
    return requireAuth(req, res, next);
  };
  const tenorSearchRateLimit = createRateLimiter({
    windowMs: 60_000,
    maxRequests: 30,
    keyGenerator: (req) => req.ip ?? req.socket?.remoteAddress ?? 'unknown',
    message: 'Too many GIF searches. Try again in a minute.',
  });

  app.get('/api/social/feed', optionalAuth, async (req, res, next) => {
    const viewerId = req.auth?.sub ?? null;
    const feedScope = ['public', 'following'].includes(req.query.scope)
      ? req.query.scope
      : 'default';
    if (feedScope === 'following' && viewerId == null) {
      return res.status(401).json({
        error: 'Sign in to view posts from people you follow.',
      });
    }
    try {
      const [rows] = await pool.execute(
        `SELECT p.id, p.user_id AS userId, p.caption,
                p.images_json AS imagesJson, p.created_at AS createdAt,
                u.first_name AS firstName, u.last_name AS lastName,
                u.avatar_url AS avatarUrl, u.role,
                (SELECT COUNT(*) FROM social_post_likes l
                 WHERE l.post_id = p.id) AS likeCount,
                (SELECT COUNT(*) FROM social_post_comments c
                 WHERE c.post_id = p.id) AS commentCount,
                EXISTS (
                  SELECT 1 FROM social_post_likes l
                  WHERE l.post_id = p.id AND l.user_id = ?
                ) AS isLiked,
                EXISTS (
                  SELECT 1 FROM social_saved_posts s
                  WHERE s.post_id = p.id AND s.user_id = ?
                ) AS isSaved
         FROM social_posts p
         JOIN users u ON u.id = p.user_id AND u.status = 'active'
         WHERE (
           ? = 'public'
           OR (
             ? = 'following'
             AND ? IS NOT NULL
             AND p.user_id <> ?
             AND EXISTS (
               SELECT 1 FROM user_follows f
               WHERE f.follower_id = ? AND f.followed_id = p.user_id
             )
           )
           OR (
             ? = 'default'
             AND (
               ? IS NULL
               OR p.user_id = ?
               OR EXISTS (
                 SELECT 1 FROM user_follows f
                 WHERE f.follower_id = ? AND f.followed_id = p.user_id
               )
             )
           )
         )
         AND (? IS NULL OR NOT EXISTS (
           SELECT 1 FROM user_blocks b
           WHERE (b.blocker_id = ? AND b.blocked_user_id = p.user_id)
              OR (b.blocker_id = p.user_id AND b.blocked_user_id = ?)
         ))
         ORDER BY p.created_at DESC, p.id DESC
         LIMIT 50`,
        [
          viewerId,
          viewerId,
          feedScope,
          feedScope,
          viewerId,
          viewerId,
          viewerId,
          feedScope,
          viewerId,
          viewerId,
          viewerId,
          viewerId,
          viewerId,
          viewerId,
        ],
      );
      return res.json({
        posts: rows.map((row) => ({
          ...row,
          displayName: `${row.firstName || ''} ${row.lastName || ''}`.trim() ||
            'SpotGo user',
          images: parseImages(row.imagesJson),
          createdAt: serializeDate(row.createdAt),
        })),
      });
    } catch (error) {
      return next(error);
    }
  });

  app.get('/api/social/notifications', requireAuth, async (req, res, next) => {
    try {
      const [countRows] = await pool.execute(
        `SELECT COUNT(*) AS unreadCount
         FROM social_notifications n
         JOIN users actor ON actor.id = n.actor_user_id
           AND actor.status = 'active'
         LEFT JOIN social_posts p ON p.id = n.post_id
         LEFT JOIN users post_owner ON post_owner.id = p.user_id
           AND post_owner.status = 'active'
         WHERE n.recipient_user_id = ? AND n.read_at IS NULL
           AND (n.post_id IS NULL OR post_owner.id IS NOT NULL)
           AND NOT EXISTS (
             SELECT 1 FROM user_blocks b
             WHERE (b.blocker_id = n.recipient_user_id
                    AND b.blocked_user_id = n.actor_user_id)
                OR (b.blocker_id = n.actor_user_id
                    AND b.blocked_user_id = n.recipient_user_id)
           )`,
        [req.auth.sub],
      );
      const [rows] = await pool.execute(
        `SELECT n.id, n.type, n.post_id AS postId,
                n.created_at AS createdAt, n.read_at AS readAt,
                actor.id AS actorUserId,
                actor.first_name AS actorFirstName,
                actor.last_name AS actorLastName,
                actor.avatar_url AS actorAvatarUrl,
                p.user_id AS postOwnerId, p.caption AS postCaption,
                c.comment_text AS commentText
         FROM social_notifications n
         JOIN users actor ON actor.id = n.actor_user_id
           AND actor.status = 'active'
         LEFT JOIN social_posts p ON p.id = n.post_id
         LEFT JOIN users post_owner ON post_owner.id = p.user_id
           AND post_owner.status = 'active'
         LEFT JOIN social_post_comments c
           ON n.type = 'comment' AND c.id = n.source_id
         WHERE n.recipient_user_id = ?
           AND (n.post_id IS NULL OR post_owner.id IS NOT NULL)
           AND NOT EXISTS (
             SELECT 1 FROM user_blocks b
             WHERE (b.blocker_id = n.recipient_user_id
                    AND b.blocked_user_id = n.actor_user_id)
                OR (b.blocker_id = n.actor_user_id
                    AND b.blocked_user_id = n.recipient_user_id)
           )
         ORDER BY n.created_at DESC, n.id DESC
         LIMIT 50`,
        [req.auth.sub],
      );
      return res.json({
        unreadCount: Number(countRows[0]?.unreadCount ?? 0),
        notifications: rows.map((row) => ({
          ...row,
          id: Number(row.id),
          postId: row.postId == null ? null : Number(row.postId),
          postOwnerId: row.postOwnerId == null ? null : Number(row.postOwnerId),
          actorUserId: Number(row.actorUserId),
          createdAt: serializeDate(row.createdAt),
          readAt: serializeDate(row.readAt),
        })),
      });
    } catch (error) {
      return next(error);
    }
  });

  app.patch(
    '/api/social/notifications/:notificationId/read',
    requireAuth,
    async (req, res, next) => {
      const notificationId = positiveId(req.params.notificationId);
      if (notificationId === null) {
        return res.status(400).json({ error: 'Invalid notification.' });
      }
      try {
        await pool.execute(
          `UPDATE social_notifications
           SET read_at = COALESCE(read_at, CURRENT_TIMESTAMP)
           WHERE id = ? AND recipient_user_id = ?`,
          [notificationId, req.auth.sub],
        );
        return res.json({ read: true });
      } catch (error) {
        return next(error);
      }
    },
  );

  app.post(
    '/api/social/notifications/read-all',
    requireAuth,
    async (req, res, next) => {
      try {
        await pool.execute(
          `UPDATE social_notifications
           SET read_at = CURRENT_TIMESTAMP
           WHERE recipient_user_id = ? AND read_at IS NULL`,
          [req.auth.sub],
        );
        return res.json({ read: true });
      } catch (error) {
        return next(error);
      }
    },
  );

  app.get('/api/social/gifs', tenorSearchRateLimit, async (req, res, next) => {
    const query =
      typeof req.query.q === 'string' ? req.query.q.trim().slice(0, 80) : '';
    if (!query) return res.status(400).json({ error: 'Enter a GIF search term.' });
    if (!tenorApiKey) {
      return res.status(503).json({ error: 'GIF search is not configured.' });
    }
    try {
      const url = new URL('https://tenor.googleapis.com/v2/search');
      url.searchParams.set('q', query);
      url.searchParams.set('key', tenorApiKey);
      url.searchParams.set('client_key', 'tinkerpro');
      url.searchParams.set('limit', '20');
      url.searchParams.set('media_filter', 'tinygif');
      const response = await fetchImpl(url, { signal: AbortSignal.timeout(8000) });
      if (!response.ok) {
        return res.status(502).json({ error: 'GIF search is temporarily unavailable.' });
      }
      const payload = await response.json();
      const gifs = (Array.isArray(payload.results) ? payload.results : [])
        .map((result) => {
          const formats = result.media_formats ?? {};
          const media = formats.tinygif ?? formats.gif;
          const gifUrl = media?.url;
          if (!validTenorGifUrl(gifUrl)) return null;
          return {
            url: gifUrl,
            title: typeof result.content_description === 'string'
              ? result.content_description.slice(0, 120)
              : 'GIF',
          };
        })
        .filter(Boolean);
      return res.json({ gifs });
    } catch (error) {
      return next(error);
    }
  });

  app.get(
    '/api/social/posts/:postId/comments',
    optionalAuth,
    async (req, res, next) => {
      const postId = positiveId(req.params.postId);
      if (postId === null) return res.status(400).json({ error: 'Invalid post.' });
      const viewerId = req.auth?.sub ?? null;
      try {
        const visible = await visiblePost(pool, postId, viewerId);
        if (!visible) return res.status(404).json({ error: 'Post not found.' });
        const [rows] = await pool.execute(
          `SELECT c.id, c.comment_text AS text, c.gif_url AS gifUrl,
                  c.created_at AS createdAt, u.id AS userId,
                  u.first_name AS firstName, u.last_name AS lastName,
                  u.avatar_url AS avatarUrl
           FROM social_post_comments c
           JOIN users u ON u.id = c.user_id AND u.status = 'active'
           WHERE c.post_id = ?
             AND (? IS NULL OR NOT EXISTS (
               SELECT 1 FROM user_blocks b
               WHERE (b.blocker_id = ? AND b.blocked_user_id = c.user_id)
                  OR (b.blocker_id = c.user_id AND b.blocked_user_id = ?)
             ))
           ORDER BY c.created_at, c.id
           LIMIT 100`,
          [postId, viewerId, viewerId, viewerId],
        );
        return res.json({
          comments: rows.map((row) => ({
            ...row,
            displayName: `${row.firstName || ''} ${row.lastName || ''}`.trim() ||
              'SpotGo user',
            createdAt: serializeDate(row.createdAt),
          })),
        });
      } catch (error) {
        return next(error);
      }
    },
  );

  app.post(
    '/api/social/posts/:postId/comments',
    requireAuth,
    async (req, res, next) => {
      const postId = positiveId(req.params.postId);
      const text = typeof req.body.text === 'string'
        ? req.body.text.replace(/[\u0000-\u001f\u007f]/g, ' ').trim()
        : '';
      const gifUrl = req.body.gifUrl == null ? null : req.body.gifUrl;
      if (
        postId === null ||
        text.length > MAX_COMMENT_LENGTH ||
        (!text && !gifUrl) ||
        (gifUrl != null && !validTenorGifUrl(gifUrl))
      ) {
        return res.status(400).json({
          error: 'Enter a comment or choose a valid GIF.',
        });
      }
      try {
        const post = await visiblePost(pool, postId, req.auth.sub);
        if (!post) return res.status(404).json({ error: 'Post not found.' });
        const [result] = await pool.execute(
          `INSERT INTO social_post_comments (post_id, user_id, comment_text, gif_url)
           VALUES (?, ?, ?, ?)`,
          [postId, req.auth.sub, text, gifUrl],
        );
        await createSocialNotification(pool, {
          recipientUserId: post.ownerId,
          actorUserId: req.auth.sub,
          type: 'comment',
          postId,
          sourceId: result.insertId,
        });
        return res.status(201).json({
          id: Number(result.insertId),
          postId,
          userId: Number(req.auth.sub),
          text,
          gifUrl,
        });
      } catch (error) {
        return next(error);
      }
    },
  );

  for (const [action, table, column, status] of [
    ['likes', 'social_post_likes', 'isLiked', true],
    ['saves', 'social_saved_posts', 'isSaved', true],
  ]) {
    app.post(
      `/api/social/posts/:postId/${action}`,
      requireAuth,
      async (req, res, next) => {
        const postId = positiveId(req.params.postId);
        if (postId === null) {
          return res.status(400).json({ error: 'Invalid post.' });
        }
        try {
          const post = await visiblePost(pool, postId, req.auth.sub);
          if (!post) return res.status(404).json({ error: 'Post not found.' });
          const [result] = await pool.execute(
            `INSERT IGNORE INTO ${table} (post_id, user_id) VALUES (?, ?)`,
            [postId, req.auth.sub],
          );
          if (action === 'likes' && result.affectedRows > 0) {
            await createSocialNotification(pool, {
              recipientUserId: post.ownerId,
              actorUserId: req.auth.sub,
              type: 'like',
              postId,
              sourceId: postId,
            });
          }
          return res.json({ [column]: status });
        } catch (error) {
          return next(error);
        }
      },
    );
    app.delete(
      `/api/social/posts/:postId/${action}`,
      requireAuth,
      async (req, res, next) => {
        const postId = positiveId(req.params.postId);
        if (postId === null) {
          return res.status(400).json({ error: 'Invalid post.' });
        }
        try {
          await pool.execute(
            `DELETE FROM ${table} WHERE post_id = ? AND user_id = ?`,
            [postId, req.auth.sub],
          );
          return res.json({ [column]: !status });
        } catch (error) {
          return next(error);
        }
      },
    );
  }

  app.post(
    '/api/social/posts/:postId/reports',
    requireAuth,
    async (req, res, next) => {
      const postId = positiveId(req.params.postId);
      const reason = typeof req.body.reason === 'string'
        ? req.body.reason.trim()
        : '';
      if (postId === null || !SOCIAL_POST_REPORT_REASONS.has(reason)) {
        return res.status(400).json({ error: 'Choose a valid report reason.' });
      }
      try {
        const visible = await visiblePost(pool, postId, req.auth.sub);
        if (!visible) return res.status(404).json({ error: 'Post not found.' });
        await pool.execute(
          `INSERT IGNORE INTO social_post_reports (post_id, user_id, reason)
           VALUES (?, ?, ?)`,
          [postId, req.auth.sub, reason],
        );
        return res.status(201).json({ reported: true });
      } catch (error) {
        return next(error);
      }
    },
  );

  app.get('/api/social/users', optionalAuth, async (req, res, next) => {
    const viewerId = req.auth?.sub ?? null;
    const query = typeof req.query.q === 'string'
      ? req.query.q.trim().slice(0, 80)
      : '';
    try {
      const [rows] = await pool.execute(
        `SELECT u.id, u.first_name AS firstName, u.last_name AS lastName,
                u.avatar_url AS avatarUrl, u.role,
                (SELECT COUNT(*) FROM user_follows f
                 WHERE f.followed_id = u.id) AS followersCount,
                EXISTS (
                  SELECT 1 FROM user_follows f
                  WHERE f.follower_id = ? AND f.followed_id = u.id
                ) AS isFollowing
         FROM users u
         WHERE (? IS NULL OR u.id <> ?) AND u.status = 'active'
           AND (? = '' OR CONCAT_WS(' ', u.first_name, u.last_name) LIKE ?)
           AND (? IS NULL OR NOT EXISTS (
             SELECT 1 FROM user_blocks b
             WHERE (b.blocker_id = ? AND b.blocked_user_id = u.id)
                OR (b.blocker_id = u.id AND b.blocked_user_id = ?)
           ))
         ORDER BY u.first_name, u.last_name, u.id
         LIMIT 50`,
        [
          viewerId,
          viewerId,
          viewerId,
          query,
          `%${query}%`,
          viewerId,
          viewerId,
          viewerId,
        ],
      );
      return res.json({
        users: rows.map((row) => ({
          id: Number(row.id),
          displayName: `${row.firstName || ''} ${row.lastName || ''}`.trim() ||
            'SpotGo user',
          avatarUrl: row.avatarUrl,
          role: row.role,
          followersCount: Number(row.followersCount),
          isFollowing: Boolean(row.isFollowing),
        })),
      });
    } catch (error) {
      return next(error);
    }
  });

  app.get('/api/social/users/:userId', optionalAuth, async (req, res, next) => {
    const viewerId = req.auth?.sub ?? null;
    const userId = positiveId(req.params.userId);
    if (userId === null) {
      return res.status(400).json({ error: 'The profile is invalid.' });
    }
    try {
      const [users] = await pool.execute(
        `SELECT u.id, u.first_name AS firstName, u.last_name AS lastName,
                u.avatar_url AS avatarUrl, u.hobby, u.role,
                (SELECT COUNT(*) FROM user_follows f
                 WHERE f.followed_id = u.id) AS followersCount,
                (SELECT COUNT(*) FROM user_follows f
                 WHERE f.follower_id = u.id) AS followingCount,
                (SELECT COUNT(*) FROM social_posts p
                 WHERE p.user_id = u.id) AS postsCount,
                EXISTS (
                  SELECT 1 FROM user_follows f
                  WHERE f.follower_id = ? AND f.followed_id = u.id
                ) AS isFollowing
         FROM users u
         WHERE u.id = ? AND u.status = 'active'
           AND (? IS NULL OR NOT EXISTS (
             SELECT 1 FROM user_blocks b
             WHERE (b.blocker_id = ? AND b.blocked_user_id = u.id)
                OR (b.blocker_id = u.id AND b.blocked_user_id = ?)
           ))
         LIMIT 1`,
        [viewerId, userId, viewerId, viewerId, viewerId],
      );
      if (!users[0]) {
        return res.status(404).json({ error: 'Profile not found.' });
      }
      const [posts] = await pool.execute(
        `SELECT id, user_id AS userId, caption,
                images_json AS imagesJson, created_at AS createdAt,
                (SELECT COUNT(*) FROM social_post_likes l
                 WHERE l.post_id = social_posts.id) AS likeCount,
                (SELECT COUNT(*) FROM social_post_comments c
                 WHERE c.post_id = social_posts.id) AS commentCount,
                EXISTS (
                  SELECT 1 FROM social_post_likes l
                  WHERE l.post_id = social_posts.id AND l.user_id = ?
                ) AS isLiked,
                EXISTS (
                  SELECT 1 FROM social_saved_posts s
                  WHERE s.post_id = social_posts.id AND s.user_id = ?
                ) AS isSaved
         FROM social_posts
         WHERE user_id = ?
         ORDER BY created_at DESC, id DESC
         LIMIT 50`,
        [viewerId, viewerId, userId],
      );
      const [businesses] = await pool.execute(
        `SELECT b.id AS businessId, b.name AS businessName,
                b.business_type AS businessType, b.enabled,
                n.title, n.body, b.image_urls AS imageUrls,
                COALESCE(NULLIF(TRIM(n.image_url), ''),
                         NULLIF(TRIM(b.image_url), '')) AS imageUrl
         FROM merchant_businesses b
         JOIN users u ON u.id = b.merchant_id AND u.status = 'active'
         JOIN merchant_news n ON n.business_id = b.id
           AND n.status = 'published'
           AND n.id = (
             SELECT MAX(latest.id)
             FROM merchant_news latest
             WHERE latest.business_id = b.id
               AND latest.status = 'published'
           )
         WHERE b.merchant_id = ?
           AND b.enabled = 1
           AND NULLIF(TRIM(n.title), '') IS NOT NULL
           AND NULLIF(TRIM(n.body), '') IS NOT NULL
           AND (
             COALESCE(NULLIF(TRIM(n.image_url), ''),
                      NULLIF(TRIM(b.image_url), '')) IS NOT NULL
               OR COALESCE(JSON_LENGTH(b.image_urls), 0) > 0
           )
         ORDER BY n.created_at DESC, b.id DESC`,
        [userId],
      );
      const user = users[0];
      return res.json({
        profile: {
          id: Number(user.id),
          displayName: `${user.firstName || ''} ${user.lastName || ''}`.trim() ||
            'SpotGo user',
          avatarUrl: user.avatarUrl,
          hobby: user.hobby || '',
          role: user.role,
          followersCount: Number(user.followersCount),
          followingCount: Number(user.followingCount),
          postsCount: Number(user.postsCount),
          isFollowing: Boolean(user.isFollowing),
        },
        posts: posts.map((post) => ({
          ...post,
          images: parseImages(post.imagesJson),
          createdAt: serializeDate(post.createdAt),
        })),
        businesses: businesses.map((business) => ({
          ...business,
          businessId: Number(business.businessId),
          enabled: business.enabled === true || Number(business.enabled) === 1,
          imageUrl: firstImage(business.imageUrl) ||
            parseImages(business.imageUrls)[0] || '',
          imageUrls: parseImages(business.imageUrls),
        })),
      });
    } catch (error) {
      return next(error);
    }
  });

  for (const type of ['followers', 'following']) {
    app.get(`/api/social/users/:userId/${type}`, optionalAuth, async (req, res, next) => {
      const viewerId = req.auth?.sub ?? null;
      const userId = positiveId(req.params.userId);
      if (userId === null) {
        return res.status(400).json({ error: 'The profile is invalid.' });
      }
      const relation = type === 'followers'
        ? 'f.followed_id = ? AND f.follower_id = u.id'
        : 'f.follower_id = ? AND f.followed_id = u.id';
      try {
        const [profiles] = await pool.execute(
          `SELECT u.id, u.first_name AS firstName, u.last_name AS lastName,
                  u.avatar_url AS avatarUrl, u.role,
                  (SELECT COUNT(*) FROM user_follows count_follows
                   WHERE count_follows.followed_id = u.id) AS followersCount,
                  EXISTS (
                    SELECT 1 FROM user_follows current_follow
                    WHERE current_follow.follower_id = ? AND
                          current_follow.followed_id = u.id
                  ) AS isFollowing
           FROM user_follows f
           JOIN users u ON u.id = ${type === 'followers' ? 'f.follower_id' : 'f.followed_id'}
           WHERE ${relation} AND u.status = 'active'
             AND (? IS NULL OR NOT EXISTS (
               SELECT 1 FROM user_blocks b
               WHERE (b.blocker_id = ? AND b.blocked_user_id = u.id)
                  OR (b.blocker_id = u.id AND b.blocked_user_id = ?)
             ))
           ORDER BY u.first_name, u.last_name, u.id`,
          [viewerId, userId, viewerId, viewerId, viewerId],
        );
        return res.json({
          users: profiles.map((profile) => ({
            id: Number(profile.id),
            displayName: `${profile.firstName || ''} ${profile.lastName || ''}`.trim() ||
              'SpotGo user',
            avatarUrl: profile.avatarUrl,
            role: profile.role,
            followersCount: Number(profile.followersCount),
            isFollowing: Boolean(profile.isFollowing),
          })),
        });
      } catch (error) {
        return next(error);
      }
    });
  }

  app.post('/api/social/posts', requireAuth, async (req, res, next) => {
    const caption = normalizeCaption(req.body.caption);
    const imageResult = validateImages(req.body.images);
    if (
      (req.body.caption !== undefined &&
        (typeof req.body.caption !== 'string' ||
          req.body.caption.length > MAX_CAPTION_LENGTH)) ||
      caption.length > MAX_CAPTION_LENGTH ||
      !imageResult.valid ||
      (!caption && imageResult.images.length === 0)
    ) {
      return res.status(400).json({
        error: 'Add a caption or up to five JPEG, PNG, or WebP photos (10 MB each).',
      });
    }

    let connection;
    let transactionStarted = false;
    try {
      connection = await pool.getConnection();
      await connection.beginTransaction();
      transactionStarted = true;
      const [users] = await connection.execute(
        `SELECT id FROM users
         WHERE id = ? AND status = 'active'
         FOR UPDATE`,
        [req.auth.sub],
      );
      if (!users.length) {
        await connection.rollback();
        return res.status(403).json({ error: 'An active account is required to post.' });
      }
      const [recentPosts] = await connection.execute(
        `SELECT COUNT(*) AS postCount, MIN(created_at) AS oldestPostAt
         FROM social_posts
         WHERE user_id = ?
           AND created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)`,
        [req.auth.sub],
      );
      if (Number(recentPosts[0]?.postCount ?? 0) >= MAX_POSTS_PER_24_HOURS) {
        await connection.rollback();
        const availableAt = recentPosts[0]?.oldestPostAt
          ? new Date(
              new Date(recentPosts[0].oldestPostAt).getTime() + 24 * 60 * 60 * 1000,
            ).toISOString()
          : null;
        return res.status(429).json({
          error: 'You have reached the limit of five posts in 24 hours.',
          limit: MAX_POSTS_PER_24_HOURS,
          availableAt,
        });
      }
      const [result] = await connection.execute(
        `INSERT INTO social_posts (user_id, caption, images_json)
         VALUES (?, ?, ?)`,
        [
          req.auth.sub,
          caption || null,
          JSON.stringify(imageResult.images),
        ],
      );
      await connection.execute(
        `INSERT IGNORE INTO social_notifications
           (recipient_user_id, actor_user_id, type, post_id, source_id)
         SELECT f.follower_id, ?, 'post', ?, ?
         FROM user_follows f
         JOIN users recipient ON recipient.id = f.follower_id
           AND recipient.status = 'active'
         WHERE f.followed_id = ?
           AND NOT EXISTS (
             SELECT 1 FROM user_blocks b
             WHERE (b.blocker_id = f.follower_id AND b.blocked_user_id = ?)
                OR (b.blocker_id = ? AND b.blocked_user_id = f.follower_id)
           )`,
        [
          req.auth.sub,
          result.insertId,
          result.insertId,
          req.auth.sub,
          req.auth.sub,
          req.auth.sub,
        ],
      );
      await connection.commit();
      transactionStarted = false;
      return res.status(201).json({
        id: Number(result.insertId),
        userId: Number(req.auth.sub),
        caption,
        images: imageResult.images,
        message: 'Experience shared.',
      });
    } catch (error) {
      if (transactionStarted) await connection.rollback();
      return next(error);
    } finally {
      connection?.release();
    }
  });

  app.post('/api/social/follows/:userId', requireAuth, async (req, res, next) => {
    const userId = positiveId(req.params.userId);
    if (userId === null || userId === Number(req.auth.sub)) {
      return res.status(400).json({ error: 'Choose another valid profile to follow.' });
    }
    try {
      const [targets] = await pool.execute(
        `SELECT id FROM users u
         WHERE u.id = ? AND u.status = 'active'
           AND NOT EXISTS (
             SELECT 1 FROM user_blocks b
             WHERE (b.blocker_id = ? AND b.blocked_user_id = u.id)
                OR (b.blocker_id = u.id AND b.blocked_user_id = ?)
           )
         LIMIT 1`,
        [userId, req.auth.sub, req.auth.sub],
      );
      if (!targets.length) {
        return res.status(404).json({ error: 'Profile not found.' });
      }
      const [result] = await pool.execute(
        `INSERT IGNORE INTO user_follows (follower_id, followed_id)
         VALUES (?, ?)`,
        [req.auth.sub, userId],
      );
      if (result.affectedRows > 0) {
        await createSocialNotification(pool, {
          recipientUserId: userId,
          actorUserId: req.auth.sub,
          type: 'follow',
          sourceId: userId,
        });
      }
      return res.json({ isFollowing: true });
    } catch (error) {
      return next(error);
    }
  });

  app.delete('/api/social/follows/:userId', requireAuth, async (req, res, next) => {
    const userId = positiveId(req.params.userId);
    if (userId === null || userId === Number(req.auth.sub)) {
      return res.status(400).json({ error: 'Choose another valid profile to unfollow.' });
    }
    try {
      await pool.execute(
        'DELETE FROM user_follows WHERE follower_id = ? AND followed_id = ?',
        [req.auth.sub, userId],
      );
      return res.json({ isFollowing: false });
    } catch (error) {
      return next(error);
    }
  });
}

function parseImages(value) {
  if (Array.isArray(value)) return value.filter((image) => typeof image === 'string');
  if (typeof value !== 'string') return [];
  try {
    const images = JSON.parse(value);
    return Array.isArray(images)
      ? images.filter((image) => typeof image === 'string')
      : [];
  } catch {
    return [];
  }
}

function firstImage(value) {
  if (typeof value !== 'string') return '';
  const image = value.trim();
  if (!image) return '';
  const images = parseImages(image);
  return images[0] || image;
}

function serializeDate(value) {
  if (value instanceof Date) return value.toISOString();
  return value == null ? null : new Date(value).toISOString();
}

module.exports = {
  MAX_CAPTION_LENGTH,
  MAX_IMAGES_PER_POST,
  MAX_IMAGE_BYTES,
  MAX_POSTS_PER_24_HOURS,
  registerSocialRoutes,
  matchesImageType,
  validateImages,
};
