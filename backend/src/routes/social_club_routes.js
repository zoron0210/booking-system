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

function normalizeText(value, maxLength) {
  return typeof value === 'string'
    ? value.replace(/[\u0000-\u001f\u007f]/g, ' ').replace(/\s+/g, ' ').trim().slice(0, maxLength)
    : '';
}

function serializeDate(value) {
  if (value instanceof Date) return value.toISOString();
  return value == null ? null : new Date(value).toISOString();
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

async function signClubLogo(mediaStorage, logoImage) {
  if (!logoImage || !mediaStorage) return logoImage ?? null;
  return (await mediaStorage.signImages([logoImage]))[0] ?? null;
}

function registerSocialClubRoutes({ app, pool, requireAuth, mediaStorage = null }) {
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

  app.get('/api/social/clubs', optionalAuth, async (req, res, next) => {
    const query = normalizeText(req.query.q, 80);
    const viewerId = req.auth?.sub ?? null;
    try {
      const [rows] = await pool.execute(
        `SELECT c.id, c.name, c.description, c.logo_image AS logoImage,
                c.owner_user_id AS ownerUserId,
                CONCAT_WS(' ', owner.first_name, owner.last_name) AS ownerName,
                c.created_at AS createdAt,
                (SELECT COUNT(*) FROM social_club_members m
                 WHERE m.club_id = c.id
                   AND m.membership_status = 'approved') AS memberCount,
                EXISTS (
                  SELECT 1 FROM social_club_members m
                  WHERE m.club_id = c.id AND m.user_id = ? AND m.role = 'owner'
                ) AS isOwner,
                EXISTS (
                  SELECT 1 FROM social_club_members m
                  WHERE m.club_id = c.id AND m.user_id = ?
                    AND m.membership_status = 'approved'
                ) AS isMember,
                EXISTS (
                  SELECT 1 FROM social_club_members m
                  WHERE m.club_id = c.id AND m.user_id = ?
                    AND m.membership_status = 'pending'
                ) AS isPending,
                c.requires_join_approval AS requiresJoinApproval
         FROM social_clubs c
         JOIN users owner ON owner.id = c.owner_user_id AND owner.status = 'active'
         WHERE (? = '' OR LOCATE(LOWER(?), LOWER(CONCAT_WS(' ', c.name, c.description))) > 0)
         ORDER BY memberCount DESC, c.created_at DESC, c.id DESC
         LIMIT 50`,
        [viewerId, viewerId, viewerId, query, query],
      );
      const clubs = await Promise.all(rows.map(async (row) => {
        const { logoImage, ...club } = row;
        return {
          ...club,
          id: Number(row.id),
          logoUrl: await signClubLogo(mediaStorage, logoImage),
          ownerUserId: Number(row.ownerUserId),
          memberCount: Number(row.memberCount),
          isOwner: Boolean(row.isOwner),
          isMember: Boolean(row.isMember),
          isPending: Boolean(row.isPending),
          requiresJoinApproval: Boolean(row.requiresJoinApproval),
          createdAt: serializeDate(row.createdAt),
        };
      }));
      return res.json({ clubs });
    } catch (error) {
      return next(error);
    }
  });

  app.get('/api/social/clubs/:clubId', optionalAuth, async (req, res, next) => {
    const clubId = positiveId(req.params.clubId);
    if (clubId === null) return res.status(400).json({ error: 'The club is invalid.' });
    try {
      const [rows] = await pool.execute(
        `SELECT c.id, c.name, c.description, c.logo_image AS logoImage,
                c.owner_user_id AS ownerUserId,
                CONCAT_WS(' ', owner.first_name, owner.last_name) AS ownerName,
                c.created_at AS createdAt,
                (SELECT COUNT(*) FROM social_club_members m
                 WHERE m.club_id = c.id
                   AND m.membership_status = 'approved') AS memberCount,
                EXISTS (
                  SELECT 1 FROM social_club_members m
                  WHERE m.club_id = c.id AND m.user_id = ? AND m.role = 'owner'
                ) AS isOwner,
                EXISTS (
                  SELECT 1 FROM social_club_members m
                  WHERE m.club_id = c.id AND m.user_id = ?
                    AND m.membership_status = 'approved'
                ) AS isMember,
                EXISTS (
                  SELECT 1 FROM social_club_members m
                  WHERE m.club_id = c.id AND m.user_id = ?
                    AND m.membership_status = 'pending'
                ) AS isPending,
                c.requires_join_approval AS requiresJoinApproval
         FROM social_clubs c
         JOIN users owner ON owner.id = c.owner_user_id AND owner.status = 'active'
         WHERE c.id = ?
         LIMIT 1`,
        [req.auth?.sub ?? null, req.auth?.sub ?? null, req.auth?.sub ?? null, clubId],
      );
      if (!rows.length) return res.status(404).json({ error: 'Club not found.' });
      const club = rows[0];
      const { logoImage, ...clubDetails } = club;
      return res.json({
        club: {
          ...clubDetails,
          id: Number(club.id),
          logoUrl: await signClubLogo(mediaStorage, logoImage),
          ownerUserId: Number(club.ownerUserId),
          memberCount: Number(club.memberCount),
          isOwner: Boolean(club.isOwner),
          isMember: Boolean(club.isMember),
          isPending: Boolean(club.isPending),
          requiresJoinApproval: Boolean(club.requiresJoinApproval),
          createdAt: serializeDate(club.createdAt),
        },
      });
    } catch (error) {
      return next(error);
    }
  });

  app.get('/api/social/clubs/:clubId/posts', optionalAuth, async (req, res, next) => {
    const clubId = positiveId(req.params.clubId);
    const rawLimit = req.query.limit;
    const limit = rawLimit === undefined ? 20 : positiveId(rawLimit);
    const rawCursor = req.query.before_id;
    const beforeId = rawCursor === undefined ? null : positiveId(rawCursor);
    if (clubId === null || limit === null || (rawCursor !== undefined && beforeId === null)) {
      return res.status(400).json({ error: 'The club post page is invalid.' });
    }
    const viewerId = req.auth?.sub ?? null;
    try {
      const [rows] = await pool.execute(
        `SELECT p.id, p.user_id AS userId, p.caption, p.images_json AS imagesJson,
                p.created_at AS createdAt, u.first_name AS firstName,
                u.last_name AS lastName, u.avatar_url AS avatarUrl, u.role,
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
         WHERE p.club_id = ?
           AND (? IS NULL OR NOT EXISTS (
             SELECT 1 FROM user_blocks b
             WHERE (b.blocker_id = ? AND b.blocked_user_id = p.user_id)
                OR (b.blocker_id = p.user_id AND b.blocked_user_id = ?)
           ))
           AND (? IS NULL OR p.id < ?)
         ORDER BY p.created_at DESC, p.id DESC
         LIMIT ?`,
        [
          viewerId, viewerId, clubId, viewerId, viewerId, viewerId,
          beforeId, beforeId, Math.min(limit, 50) + 1,
        ],
      );
      const pageSize = Math.min(limit, 50);
      const hasMore = rows.length > pageSize;
      const pageRows = rows.slice(0, pageSize);
      const posts = await Promise.all(pageRows.map(async (row) => ({
        ...row,
        id: Number(row.id),
        userId: Number(row.userId),
        displayName: `${row.firstName || ''} ${row.lastName || ''}`.trim() ||
          'SpotGo user',
        images: mediaStorage
          ? await mediaStorage.signImages(parseImages(row.imagesJson))
          : parseImages(row.imagesJson),
        createdAt: serializeDate(row.createdAt),
      })));
      return res.json({
        posts,
        hasMore,
        nextCursor: hasMore ? pageRows[pageRows.length - 1].id : null,
      });
    } catch (error) {
      return next(error);
    }
  });

  app.post('/api/social/clubs', requireAuth, async (req, res, next) => {
    const name = normalizeText(req.body.name, 1000);
    const description = normalizeText(req.body.description, 1000);
    const stagedLogo = req.body.logoImage;
    if (
      typeof req.body.name !== 'string' ||
      name.length < 3 ||
      name.length > 60 ||
      description.length > 500 ||
      (req.body.description !== undefined &&
        typeof req.body.description !== 'string') ||
      typeof stagedLogo !== 'string' ||
      !/^gcs:\/\/social-media-staging\/[1-9]\d*\/[0-9a-f-]{36}-[1-9]\d*$/i.test(stagedLogo)
    ) {
      return res.status(400).json({
        error: 'Add a club name between 3 and 60 characters, a description up to 500 characters, and a club logo.',
      });
    }
    if (!mediaStorage) {
      return res.status(503).json({
        error: 'Club logo storage is not configured on this server.',
      });
    }
    let connection;
    let transactionStarted = false;
    let promotedLogo = null;
    let clubCreated = false;
    try {
      promotedLogo = await mediaStorage.promoteUpload(stagedLogo, req.auth.sub);
      if (!promotedLogo) {
        return res.status(400).json({
          error: 'The club logo upload is missing, expired, or invalid.',
        });
      }
      connection = await pool.getConnection();
      await connection.beginTransaction();
      transactionStarted = true;
      const [users] = await connection.execute(
        `SELECT id FROM users WHERE id = ? AND status = 'active' FOR UPDATE`,
        [req.auth.sub],
      );
      if (!users.length) {
        await connection.rollback();
        transactionStarted = false;
        return res.status(403).json({ error: 'An active account is required to create a club.' });
      }
      const [result] = await connection.execute(
        `INSERT INTO social_clubs (owner_user_id, name, description, logo_image)
         VALUES (?, ?, ?, ?)`,
        [req.auth.sub, name, description || null, promotedLogo],
      );
      await connection.execute(
        `INSERT INTO social_club_members (club_id, user_id, role)
         VALUES (?, ?, 'owner')`,
        [result.insertId, req.auth.sub],
      );
      const logoUrl = await signClubLogo(mediaStorage, promotedLogo);
      await connection.commit();
      transactionStarted = false;
      clubCreated = true;
      return res.status(201).json({
        club: {
          id: Number(result.insertId),
          name,
          description: description || null,
          logoUrl,
          ownerUserId: Number(req.auth.sub),
          memberCount: 1,
          isOwner: true,
          isMember: true,
        },
        message: 'Your club is ready to join.',
      });
    } catch (error) {
      if (transactionStarted) await connection.rollback();
      return next(error);
    } finally {
      connection?.release();
      if (!clubCreated && promotedLogo) {
        try {
          await mediaStorage.deleteImages([promotedLogo]);
        } catch (error) {
          console.error('Could not clean up an unclaimed club logo.', {
            userId: req.auth.sub,
            error,
          });
        }
      }
    }
  });

  app.get('/api/social/clubs/:clubId/join-requests', requireAuth, async (req, res, next) => {
    const clubId = positiveId(req.params.clubId);
    if (clubId === null) return res.status(400).json({ error: 'The club is invalid.' });
    try {
      const [owners] = await pool.execute(
        'SELECT id FROM social_clubs WHERE id = ? AND owner_user_id = ? LIMIT 1',
        [clubId, req.auth.sub],
      );
      if (!owners.length) {
        return res.status(403).json({ error: 'Only this club owner can review join requests.' });
      }
      const [rows] = await pool.execute(
        `SELECT m.user_id AS userId, u.first_name AS firstName,
                u.last_name AS lastName, u.avatar_url AS avatarUrl,
                m.joined_at AS requestedAt
         FROM social_club_members m
         JOIN users u ON u.id = m.user_id AND u.status = 'active'
         WHERE m.club_id = ? AND m.role = 'member'
           AND m.membership_status = 'pending'
         ORDER BY m.joined_at ASC, m.user_id ASC`,
        [clubId],
      );
      return res.json({
        requests: rows.map((row) => ({
          userId: Number(row.userId),
          displayName: `${row.firstName || ''} ${row.lastName || ''}`.trim() ||
            'SpotGo user',
          avatarUrl: row.avatarUrl ?? null,
          requestedAt: serializeDate(row.requestedAt),
        })),
      });
    } catch (error) {
      return next(error);
    }
  });

  app.patch('/api/social/clubs/:clubId/join-requests/:userId', requireAuth, async (req, res, next) => {
    const clubId = positiveId(req.params.clubId);
    const userId = positiveId(req.params.userId);
    const action = req.body.action;
    if (
      clubId === null ||
      userId === null ||
      (action !== 'approve' && action !== 'reject')
    ) {
      return res.status(400).json({ error: 'The join request action is invalid.' });
    }
    try {
      const [owners] = await pool.execute(
        'SELECT id FROM social_clubs WHERE id = ? AND owner_user_id = ? LIMIT 1',
        [clubId, req.auth.sub],
      );
      if (!owners.length) {
        return res.status(403).json({ error: 'Only this club owner can review join requests.' });
      }
      if (action === 'approve') {
        const [result] = await pool.execute(
          `UPDATE social_club_members
           SET membership_status = 'approved'
           WHERE club_id = ? AND user_id = ? AND role = 'member'
             AND membership_status = 'pending'`,
          [clubId, userId],
        );
        if (result.affectedRows === 0) {
          return res.status(404).json({ error: 'Pending join request not found.' });
        }
        return res.json({ approved: true });
      }
      const [result] = await pool.execute(
        `DELETE FROM social_club_members
         WHERE club_id = ? AND user_id = ? AND role = 'member'
           AND membership_status = 'pending'`,
        [clubId, userId],
      );
      if (result.affectedRows === 0) {
        return res.status(404).json({ error: 'Pending join request not found.' });
      }
      return res.json({ rejected: true });
    } catch (error) {
      return next(error);
    }
  });

  app.patch('/api/social/clubs/:clubId/settings', requireAuth, async (req, res, next) => {
    const clubId = positiveId(req.params.clubId);
    if (
      clubId === null ||
      typeof req.body.requiresJoinApproval !== 'boolean'
    ) {
      return res.status(400).json({ error: 'The club settings are invalid.' });
    }
    try {
      const [result] = await pool.execute(
        `UPDATE social_clubs
         SET requires_join_approval = ?
         WHERE id = ? AND owner_user_id = ?`,
        [req.body.requiresJoinApproval ? 1 : 0, clubId, req.auth.sub],
      );
      if (result.affectedRows === 0) {
        const [owners] = await pool.execute(
          'SELECT id FROM social_clubs WHERE id = ? AND owner_user_id = ? LIMIT 1',
          [clubId, req.auth.sub],
        );
        if (!owners.length) {
          return res.status(403).json({ error: 'Only this club owner can change settings.' });
        }
      }
      return res.json({ requiresJoinApproval: req.body.requiresJoinApproval });
    } catch (error) {
      return next(error);
    }
  });

  app.patch('/api/social/clubs/:clubId', requireAuth, async (req, res, next) => {
    const clubId = positiveId(req.params.clubId);
    const name = normalizeText(req.body.name, 1000);
    const description = normalizeText(req.body.description, 1000);
    const stagedLogo = req.body.logoImage;
    if (
      clubId === null ||
      typeof req.body.name !== 'string' ||
      name.length < 3 ||
      name.length > 60 ||
      (req.body.description !== undefined &&
        typeof req.body.description !== 'string') ||
      description.length > 500 ||
      (stagedLogo !== undefined &&
        (typeof stagedLogo !== 'string' ||
          !/^gcs:\/\/social-media-staging\/[1-9]\d*\/[0-9a-f-]{36}-[1-9]\d*$/i.test(stagedLogo)))
    ) {
      return res.status(400).json({ error: 'Enter a club name between 3 and 60 characters and a description up to 500 characters.' });
    }
    let connection;
    let transactionStarted = false;
    let promotedLogo = null;
    let updated = false;
    try {
      if (stagedLogo !== undefined) {
        if (!mediaStorage) {
          return res.status(503).json({ error: 'Club logo storage is not configured on this server.' });
        }
        promotedLogo = await mediaStorage.promoteUpload(stagedLogo, req.auth.sub);
        if (!promotedLogo) {
          return res.status(400).json({ error: 'The club logo upload is missing, expired, or invalid.' });
        }
      }
      connection = await pool.getConnection();
      await connection.beginTransaction();
      transactionStarted = true;
      const [clubs] = await connection.execute(
        `SELECT logo_image AS logoImage FROM social_clubs
         WHERE id = ? AND owner_user_id = ? FOR UPDATE`,
        [clubId, req.auth.sub],
      );
      if (!clubs.length) {
        await connection.rollback();
        transactionStarted = false;
        return res.status(403).json({ error: 'Only this club owner can edit the club.' });
      }
      await connection.execute(
        `UPDATE social_clubs
         SET name = ?, description = ?, logo_image = ?
         WHERE id = ? AND owner_user_id = ?`,
        [
          name,
          description || null,
          promotedLogo ?? clubs[0].logoImage,
          clubId,
          req.auth.sub,
        ],
      );
      await connection.commit();
      transactionStarted = false;
      updated = true;
      if (promotedLogo && clubs[0].logoImage) {
        try {
          await mediaStorage.deleteImages([clubs[0].logoImage]);
        } catch (error) {
          console.error('Could not clean up the replaced club logo.', {
            clubId,
            error,
          });
        }
      }
      return res.json({
        club: {
          id: clubId,
          name,
          description: description || null,
          logoUrl: await signClubLogo(
            mediaStorage,
            promotedLogo ?? clubs[0].logoImage,
          ),
        },
      });
    } catch (error) {
      if (transactionStarted) await connection.rollback();
      return next(error);
    } finally {
      connection?.release();
      if (!updated && promotedLogo) {
        try {
          await mediaStorage.deleteImages([promotedLogo]);
        } catch (error) {
          console.error('Could not clean up an unclaimed club logo.', {
            clubId,
            userId: req.auth.sub,
            error,
          });
        }
      }
    }
  });

  app.delete('/api/social/clubs/:clubId', requireAuth, async (req, res, next) => {
    const clubId = positiveId(req.params.clubId);
    if (clubId === null) return res.status(400).json({ error: 'The club is invalid.' });
    let connection;
    let transactionStarted = false;
    let images = [];
    try {
      connection = await pool.getConnection();
      await connection.beginTransaction();
      transactionStarted = true;
      const [clubs] = await connection.execute(
        `SELECT logo_image AS logoImage FROM social_clubs
         WHERE id = ? AND owner_user_id = ? FOR UPDATE`,
        [clubId, req.auth.sub],
      );
      if (!clubs.length) {
        await connection.rollback();
        transactionStarted = false;
        return res.status(403).json({ error: 'Only this club owner can delete the club.' });
      }
      const [posts] = await connection.execute(
        'SELECT images_json AS imagesJson FROM social_posts WHERE club_id = ?',
        [clubId],
      );
      images = [
        clubs[0].logoImage,
        ...posts.flatMap((post) => parseImages(post.imagesJson)),
      ].filter((image) => typeof image === 'string' && image.startsWith('gcs://'));
      await connection.execute(
        'DELETE FROM social_clubs WHERE id = ? AND owner_user_id = ?',
        [clubId, req.auth.sub],
      );
      await connection.commit();
      transactionStarted = false;
      if (mediaStorage && images.length > 0) {
        try {
          await mediaStorage.deleteImages(images);
        } catch (error) {
          console.error('Could not clean up media for a deleted social club.', {
            clubId,
            error,
          });
        }
      }
      return res.json({ deleted: true });
    } catch (error) {
      if (transactionStarted) await connection.rollback();
      return next(error);
    } finally {
      connection?.release();
    }
  });

  app.post('/api/social/clubs/:clubId/join', requireAuth, async (req, res, next) => {
    const clubId = positiveId(req.params.clubId);
    if (clubId === null) return res.status(400).json({ error: 'The club is invalid.' });
    try {
      const [clubs] = await pool.execute(
        `SELECT requires_join_approval AS requiresJoinApproval
         FROM social_clubs WHERE id = ? LIMIT 1`,
        [clubId],
      );
      if (!clubs.length) return res.status(404).json({ error: 'Club not found.' });
      await pool.execute(
        `INSERT IGNORE INTO social_club_members
           (club_id, user_id, role, membership_status)
         SELECT ?, u.id, 'member', ?
         FROM users u WHERE u.id = ? AND u.status = 'active'`,
        [
          clubId,
          clubs[0].requiresJoinApproval ? 'pending' : 'approved',
          req.auth.sub,
        ],
      );
      const [memberships] = await pool.execute(
        `SELECT membership_status AS membershipStatus
         FROM social_club_members WHERE club_id = ? AND user_id = ? LIMIT 1`,
        [clubId, req.auth.sub],
      );
      return res.status(200).json({
        isMember: memberships[0]?.membershipStatus === 'approved',
        isPending: memberships[0]?.membershipStatus === 'pending',
      });
    } catch (error) {
      return next(error);
    }
  });

  app.delete('/api/social/clubs/:clubId/membership', requireAuth, async (req, res, next) => {
    const clubId = positiveId(req.params.clubId);
    if (clubId === null) return res.status(400).json({ error: 'The club is invalid.' });
    try {
      const [clubs] = await pool.execute(
        `SELECT owner_user_id AS ownerUserId FROM social_clubs WHERE id = ? LIMIT 1`,
        [clubId],
      );
      if (!clubs.length) return res.status(404).json({ error: 'Club not found.' });
      if (Number(clubs[0].ownerUserId) === Number(req.auth.sub)) {
        return res.status(409).json({
          error: 'Club owners cannot leave their own club.',
        });
      }
      await pool.execute(
        `DELETE FROM social_club_members
         WHERE club_id = ? AND user_id = ? AND role = 'member'`,
        [clubId, req.auth.sub],
      );
      return res.json({ isMember: false });
    } catch (error) {
      return next(error);
    }
  });
}

module.exports = { registerSocialClubRoutes };
