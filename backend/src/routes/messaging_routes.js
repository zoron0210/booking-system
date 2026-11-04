const { publicMessageUser } = require('../normalizers');

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

function registerMessagingRoutes({
  app,
  pool,
  requireAuth,
  positiveIntegerId,
  normalizeBusinessType,
  recordUserActivity,
  publishToUser = () => {},
}) {
  async function isConversationForBusinessType(conversationId, userId, businessType) {
    const [rows] = await pool.execute(
      `SELECT 1
       FROM conversation_members cm
       JOIN conversations c ON c.id = cm.conversation_id
       JOIN bookings b ON c.title = CONCAT('Booking ', b.id)
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE cm.conversation_id = ? AND cm.user_id = ?
         AND cm.deleted_at IS NULL AND LOWER(v.business_type) = ?
       LIMIT 1`,
      [conversationId, userId, businessType],
    );
    return rows.length > 0;
  }

  app.patch('/api/messages/conversations/:id/state', requireAuth, async (req, res, next) => {
    const conversationId = positiveIntegerId(req.params.id);
    if (conversationId === null) {
      return res.status(400).json({ error: 'The conversation is invalid.' });
    }
    const hasArchived = typeof req.body.archived === 'boolean';
    const hasUnread = typeof req.body.unread === 'boolean';
    if (!hasArchived && !hasUnread) {
      return res.status(400).json({ error: 'A valid conversation state is required.' });
    }
    try {
      const [members] = await pool.execute(
        `SELECT conversation_id FROM conversation_members
         WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
        [conversationId, req.auth.sub],
      );
      if (members.length === 0) {
        return res.status(404).json({ error: 'Conversation not found.' });
      }
      const updates = [];
      const values = [];
      if (hasArchived) {
        updates.push('archived_at = ?');
        values.push(req.body.archived ? new Date() : null);
      }
      if (hasUnread) {
        updates.push('manually_unread_at = ?');
        values.push(req.body.unread ? new Date() : null);
      }
      values.push(conversationId, req.auth.sub);
      await pool.execute(
        `UPDATE conversation_members SET ${updates.join(', ')}
         WHERE conversation_id = ? AND user_id = ?`,
        values,
      );
      if (req.body.unread === false) {
        await pool.execute(
          `INSERT IGNORE INTO message_reads (message_id, user_id)
           SELECT id, ? FROM messages
           WHERE conversation_id = ? AND sender_id <> ?`,
          [req.auth.sub, conversationId, req.auth.sub],
        );
      }
      return res.json({ message: 'Conversation updated.' });
    } catch (error) {
      return next(error);
    }
  });
  
  app.delete('/api/messages/conversations/:id', requireAuth, async (req, res, next) => {
    const conversationId = positiveIntegerId(req.params.id);
    if (conversationId === null) {
      return res.status(400).json({ error: 'The conversation is invalid.' });
    }
    try {
      const [result] = await pool.execute(
        `UPDATE conversation_members SET deleted_at = CURRENT_TIMESTAMP
         WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
        [conversationId, req.auth.sub],
      );
      if (result.affectedRows === 0) {
        return res.status(404).json({ error: 'Conversation not found.' });
      }
      return res.json({ message: 'Conversation deleted for you.' });
    } catch (error) {
      return next(error);
    }
  });
  
  app.post('/api/messages/blocks/:userId', requireAuth, async (req, res, next) => {
    const blockedUserId = positiveIntegerId(req.params.userId);
    if (blockedUserId === null ||
        blockedUserId === Number(req.auth.sub)) {
      return res.status(400).json({ error: 'The user to block is invalid.' });
    }
    try {
      const [users] = await pool.execute(
        `SELECT id FROM users WHERE id = ? AND status = 'active' LIMIT 1`,
        [blockedUserId],
      );
      if (users.length === 0) {
        return res.status(404).json({ error: 'User not found.' });
      }
      await pool.execute(
        `INSERT IGNORE INTO user_blocks (blocker_id, blocked_user_id)
         VALUES (?, ?)`,
        [req.auth.sub, blockedUserId],
      );
      return res.json({ message: 'User blocked.' });
    } catch (error) {
      return next(error);
    }
  });
  
  app.delete('/api/messages/blocks/:userId', requireAuth, async (req, res, next) => {
    const blockedUserId = positiveIntegerId(req.params.userId);
    if (blockedUserId === null) {
      return res.status(400).json({ error: 'The user to unblock is invalid.' });
    }
    try {
      await pool.execute(
        `DELETE FROM user_blocks WHERE blocker_id = ? AND blocked_user_id = ?`,
        [req.auth.sub, blockedUserId],
      );
      return res.json({ message: 'User unblocked.' });
    } catch (error) {
      return next(error);
    }
  });


  app.get('/api/messages/owner', requireAuth, async (req, res, next) => {
    const key = typeof req.query.businessKey === 'string'
      ? req.query.businessKey.trim()
      : '';
    if (!key || key.length > 255) {
      return res.status(400).json({ error: 'A valid business key is required.' });
    }
    try {
      const [rows] = await pool.execute(
        `SELECT u.id, u.email, u.first_name, u.last_name, u.avatar_url, u.role
         FROM merchant_businesses b
         JOIN users u ON u.id = b.merchant_id
         WHERE (CAST(b.id AS CHAR) = ? OR b.name = ?) AND u.status = 'active'
         LIMIT 1`,
        [key, key],
      );
      if (rows.length === 0) {
        return res.status(404).json({ error: 'The venue owner is no longer available.' });
      }
      return res.json({ owner: publicMessageUser(rows[0]) });
    } catch (error) {
      return next(error);
    }
  });
  
  app.get('/api/messages/contacts', requireAuth, async (req, res, next) => {
    try {
      const [rows] = await pool.execute(
        `SELECT id, email, first_name, last_name, avatar_url, role
         FROM users
         WHERE id <> ? AND status = 'active'
         ORDER BY first_name, last_name, email`,
        [req.auth.sub],
      );
      return res.json({ contacts: rows.map(publicMessageUser) });
    } catch (error) {
      return next(error);
    }
  });
  
  app.get('/api/messages/conversations', requireAuth, async (req, res, next) => {
    try {
      const params = [
        req.auth.sub,
        req.auth.sub,
        req.auth.sub,
        req.auth.sub,
        req.auth.sub,
      ];
      let bookingTypeFilter = '';
      if (req.query.businessType !== undefined) {
        const businessType = normalizeBusinessType(req.query.businessType);
        if (!businessType) {
          return res.status(400).json({ error: 'Invalid business type filter.' });
        }
        bookingTypeFilter = `AND EXISTS (
          SELECT 1
          FROM bookings b
          JOIN merchant_businesses v ON v.id = b.venue_id
          WHERE c.title = CONCAT('Booking ', b.id)
            AND LOWER(v.business_type) = ?
        )`;
        params.push(businessType);
      }
      const [rows] = await pool.execute(
        `SELECT c.id, c.type, c.title, c.created_at AS createdAt,
                CASE WHEN m.removed_at IS NOT NULL
                     THEN CONCAT_WS(
                       ' ', removed_by_user.first_name,
                       removed_by_user.last_name, 'removed this message'
                     )
                     ELSE m.body
                END AS lastMessage,
                m.created_at AS lastMessageAt,
                cm.archived_at IS NOT NULL AS archived,
                cm.manually_unread_at IS NOT NULL AS manuallyUnread,
                (cm.manually_unread_at IS NOT NULL OR
                 (SELECT COUNT(*) FROM messages unread
                  WHERE unread.conversation_id = c.id
                    AND unread.sender_id <> ?
                    AND unread.removed_at IS NULL
                    AND NOT EXISTS (
                      SELECT 1 FROM message_user_deletions mud
                      WHERE mud.message_id = unread.id AND mud.user_id = cm.user_id
                    )
                    AND NOT EXISTS (
                      SELECT 1 FROM message_reads mr
                      WHERE mr.message_id = unread.id AND mr.user_id = ?
                    )) > 0)
                  AS unreadCount,
                EXISTS (
                  SELECT 1
                  FROM conversation_members other
                  JOIN user_blocks ub
                    ON ub.blocker_id = ? AND ub.blocked_user_id = other.user_id
                  WHERE other.conversation_id = c.id
                    AND other.user_id <> ?
                ) AS blockedByMe
         FROM conversations c
         JOIN conversation_members cm ON cm.conversation_id = c.id AND cm.user_id = ?
         LEFT JOIN messages m ON m.id = (
           SELECT MAX(latest.id) FROM messages latest
           WHERE latest.conversation_id = c.id
             AND NOT EXISTS (
               SELECT 1 FROM message_user_deletions mud
               WHERE mud.message_id = latest.id AND mud.user_id = cm.user_id
             )
         )
         LEFT JOIN users removed_by_user ON removed_by_user.id = m.removed_by
         WHERE cm.deleted_at IS NULL
           ${bookingTypeFilter}
         ORDER BY COALESCE(m.created_at, c.created_at) DESC`,
        params,
      );
      for (const conversation of rows) {
        const [members] = await pool.execute(
          `SELECT u.id, u.email, u.first_name, u.last_name, u.avatar_url, u.role
           FROM conversation_members cm JOIN users u ON u.id = cm.user_id
           WHERE cm.conversation_id = ?`,
          [conversation.id],
        );
        conversation.members = members.map(publicMessageUser);
      }
      return res.json({ conversations: rows });
    } catch (error) {
      return next(error);
    }
  });
  
  app.post('/api/messages/conversations', requireAuth, async (req, res, next) => {
    const rawParticipantIds = req.body.participantIds;
    const participantIdsValid = rawParticipantIds === undefined ||
      (Array.isArray(rawParticipantIds) &&
        rawParticipantIds.length <= 20 &&
        rawParticipantIds.every((id) => positiveIntegerId(id) !== null));
    const requestedIds = Array.isArray(rawParticipantIds)
      ? rawParticipantIds.map(positiveIntegerId)
      : [];
    const recipientId = req.body.recipientId === undefined
      ? null
      : positiveIntegerId(req.body.recipientId);
    if (recipientId !== null) requestedIds.push(recipientId);
    const participantIds = [...new Set(requestedIds)].filter(
      (id) => id !== Number(req.auth.sub),
    );
    const requestedType = req.body.type;
    const isGroup = req.body.type === 'group' || participantIds.length > 1;
    const title = typeof req.body.title === 'string'
      ? req.body.title.trim().slice(0, 120)
      : null;
    if (
      !participantIdsValid ||
      (req.body.recipientId !== undefined && recipientId === null) ||
      (requestedType !== undefined &&
        !['direct', 'group'].includes(requestedType)) ||
      (req.body.title !== undefined &&
        (typeof req.body.title !== 'string' || req.body.title.length > 120)) ||
      (requestedType === 'direct' && participantIds.length > 1) ||
      participantIds.length === 0
    ) {
      return res.status(400).json({ error: 'A valid recipient is required.' });
    }
    try {
      if (!isGroup) {
        const [blocks] = await pool.execute(
          `SELECT 1 FROM user_blocks
           WHERE (blocker_id = ? AND blocked_user_id = ?)
              OR (blocker_id = ? AND blocked_user_id = ?)
           LIMIT 1`,
          [req.auth.sub, participantIds[0], participantIds[0], req.auth.sub],
        );
        if (blocks.length > 0) {
          return res.status(403).json({ error: 'This conversation is blocked.' });
        }
      }
      const placeholders = participantIds.map(() => '?').join(', ');
      const [users] = await pool.execute(
        `SELECT id FROM users
         WHERE id IN (${placeholders}) AND status = 'active'`,
        participantIds,
      );
      if (users.length !== participantIds.length) {
        return res.status(404).json({ error: 'One or more user accounts are unavailable.' });
      }
      const connection = await pool.getConnection();
      try {
        await connection.beginTransaction();
        if (!isGroup) {
          const directParticipants = [Number(req.auth.sub), participantIds[0]];
          await connection.execute(
            `SELECT id FROM users
             WHERE id IN (?, ?) ORDER BY id FOR UPDATE`,
            directParticipants,
          );
          const [existing] = await connection.execute(
            `SELECT c.id FROM conversations c
             JOIN conversation_members cm ON cm.conversation_id = c.id
             WHERE c.type = 'direct' AND cm.user_id IN (?, ?)
             GROUP BY c.id
             HAVING COUNT(DISTINCT cm.user_id) = 2 AND COUNT(*) = 2
             ORDER BY COALESCE(
               (SELECT MAX(m.created_at) FROM messages m
                WHERE m.conversation_id = c.id),
               c.created_at
             ) DESC, c.id DESC
             LIMIT 1`,
            directParticipants,
          );
          if (existing.length > 0) {
            await connection.execute(
              `UPDATE conversation_members
               SET archived_at = NULL, deleted_at = NULL, manually_unread_at = NULL
               WHERE conversation_id = ? AND user_id = ?`,
              [existing[0].id, req.auth.sub],
            );
            await connection.commit();
            return res.json({ conversationId: existing[0].id });
          }
        }
        const [result] = await connection.execute(
          'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
          [isGroup ? 'group' : 'direct', title, req.auth.sub],
        );
        const allParticipants = [Number(req.auth.sub), ...participantIds];
        for (const userId of allParticipants) {
          await connection.execute(
            'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?)',
            [result.insertId, userId],
          );
        }
        await connection.commit();
        return res.status(201).json({ conversationId: result.insertId });
      } catch (error) {
        await connection.rollback();
        throw error;
      } finally {
        connection.release();
      }
    } catch (error) {
      return next(error);
    }
  });

  app.get('/api/messages/conversations/:id', requireAuth, async (req, res, next) => {
    try {
      const conversationId = positiveIntegerId(req.params.id);
      if (conversationId === null) {
        return res.status(400).json({ error: 'The conversation is invalid.' });
      }
      const businessType = req.query.businessType === undefined
        ? null
        : normalizeBusinessType(req.query.businessType);
      if (req.query.businessType !== undefined && !businessType) {
        return res.status(400).json({ error: 'Invalid business type filter.' });
      }
      const [members] = await pool.execute(
        `SELECT 1 FROM conversation_members
         WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
        [conversationId, req.auth.sub],
      );
      if (members.length === 0) {
        return res.status(403).json({ error: 'You are not a member of this conversation.' });
      }
      if (
        businessType &&
        !(await isConversationForBusinessType(
          conversationId,
          req.auth.sub,
          businessType,
        ))
      ) {
        return res.status(404).json({ error: 'Conversation not found.' });
      }
      const [readScopeRows] = await pool.execute(
        `SELECT c.type, cm.archived_at AS archivedAt,
                (SELECT peer.user_id FROM conversation_members peer
                 WHERE peer.conversation_id = c.id
                   AND peer.user_id <> cm.user_id
                   AND peer.deleted_at IS NULL
                 LIMIT 1) AS peerId
         FROM conversations c
         JOIN conversation_members cm ON cm.conversation_id = c.id
         WHERE c.id = ? AND cm.user_id = ? AND cm.deleted_at IS NULL`,
        [conversationId, req.auth.sub],
      );
      const readScope = readScopeRows[0];
      let readConversationIds = [conversationId];
      const peerId = positiveIntegerId(readScope?.peerId);
      if (readScope?.type === 'direct' && peerId !== null) {
        const businessTypeFilter = businessType
          ? `AND EXISTS (
               SELECT 1 FROM bookings b
               JOIN merchant_businesses v ON v.id = b.venue_id
               WHERE c.title = CONCAT('Booking ', b.id)
                 AND LOWER(v.business_type) = ?
             )`
          : '';
        const duplicateParams = [
          req.auth.sub,
          peerId,
          readScope.archivedAt,
          req.auth.sub,
          peerId,
        ];
        if (businessType) duplicateParams.push(businessType);
        const [duplicateConversations] = await pool.execute(
          `SELECT c.id
           FROM conversations c
           JOIN conversation_members viewer
             ON viewer.conversation_id = c.id
            AND viewer.user_id = ? AND viewer.deleted_at IS NULL
           JOIN conversation_members peer
             ON peer.conversation_id = c.id
            AND peer.user_id = ? AND peer.deleted_at IS NULL
           WHERE c.type = 'direct'
             AND viewer.archived_at <=> ?
             AND NOT EXISTS (
               SELECT 1 FROM conversation_members extra
               WHERE extra.conversation_id = c.id
                 AND extra.deleted_at IS NULL
                 AND extra.user_id NOT IN (?, ?)
             )
             ${businessTypeFilter}`,
          duplicateParams,
        );
        readConversationIds = [
          ...new Set([
            conversationId,
            ...duplicateConversations.map((row) => Number(row.id)),
          ]),
        ];
      }
      const readConversationPlaceholders = readConversationIds
        .map(() => '?')
        .join(', ');
      await pool.execute(
        `UPDATE conversation_members SET manually_unread_at = NULL
         WHERE conversation_id IN (${readConversationPlaceholders})
           AND user_id = ?`,
        [...readConversationIds, req.auth.sub],
      );
      await pool.execute(
        `INSERT IGNORE INTO message_reads (message_id, user_id)
         SELECT id, ? FROM messages
         WHERE conversation_id IN (${readConversationPlaceholders})
           AND sender_id <> ?`,
        [req.auth.sub, ...readConversationIds, req.auth.sub],
      );
      const [rows] = await pool.execute(
        `SELECT m.id, m.conversation_id AS conversationId,
                m.sender_id AS senderId, m.body, m.created_at AS createdAt,
                m.removed_at AS removedAt,
                CASE WHEN m.removed_at IS NULL THEN NULL
                     ELSE CONCAT_WS(' ', remover.first_name, remover.last_name)
                END AS removedByName,
                m.attachment_json AS attachmentJson,
                EXISTS (
                  SELECT 1 FROM message_reads mr
                  WHERE mr.message_id = m.id AND mr.user_id <> ?
                ) AS isSeen,
                u.first_name AS senderFirstName,
                u.last_name AS senderLastName
         FROM messages m
         JOIN users u ON u.id = m.sender_id
         LEFT JOIN users remover ON remover.id = m.removed_by
         WHERE m.conversation_id IN (${readConversationPlaceholders})
           AND NOT EXISTS (
             SELECT 1 FROM message_user_deletions mud
             WHERE mud.message_id = m.id AND mud.user_id = ?
           )
         ORDER BY m.created_at ASC, m.id ASC`,
        [req.auth.sub, ...readConversationIds, req.auth.sub],
      );
      for (const message of rows) {
        if (typeof message.attachmentJson === 'string') {
          try {
            message.attachment = JSON.parse(message.attachmentJson);
          } catch {
            message.attachment = null;
          }
        } else {
          message.attachment = message.attachmentJson || null;
        }
        delete message.attachmentJson;
      }
      const bookingIdsWithApprovalTickets = new Set(
        rows
          .filter(({ attachment }) => {
            if (attachment?.type !== 'booking_ticket') return false;
            return ['approved', 'confirmed'].includes(
              String(attachment.status ?? '').toLowerCase(),
            ) || ['approved', 'confirmed'].includes(
              String(attachment.approvalStatus ?? '').toLowerCase(),
            );
          })
          .map(({ attachment }) => positiveIntegerId(attachment.bookingId))
          .filter((id) => id !== null)
          .map(String),
      );
      const visibleRows = rows.filter(({ attachment }) => {
        if (
          attachment?.type !== 'booking_payment_ticket' ||
          attachment.paymentMethod !== 'cash_on_arrival'
        ) {
          return true;
        }
        const bookingId = positiveIntegerId(attachment.bookingId);
        return (
          bookingId === null ||
          !bookingIdsWithApprovalTickets.has(String(bookingId))
        );
      });
      const bookingTicketIds = [
        ...new Set(
          visibleRows
            .map((message) => message.attachment)
            .filter(
              (attachment) =>
                attachment &&
                ['booking', 'booking_ticket', 'booking_payment_ticket'].includes(
                  attachment.type,
                ),
            )
            .map((attachment) => positiveIntegerId(attachment.bookingId))
            .filter((id) => id !== null),
        ),
      ];
      if (bookingTicketIds.length > 0) {
        const placeholders = bookingTicketIds.map(() => '?').join(', ');
        const [ticketVenues] = await pool.execute(
          `SELECT b.id AS bookingId, v.name AS venueName
           FROM bookings b
           JOIN merchant_businesses v ON v.id = b.venue_id
           WHERE b.id IN (${placeholders})`,
          bookingTicketIds,
        );
        const venueNames = new Map(
          ticketVenues.map((booking) => [
            String(booking.bookingId),
            booking.venueName,
          ]),
        );
        for (const message of visibleRows) {
          const attachment = message.attachment;
          if (
            !attachment ||
            !['booking', 'booking_ticket', 'booking_payment_ticket'].includes(
              attachment.type,
            )
          ) {
            continue;
          }
          const bookingId = positiveIntegerId(attachment.bookingId);
          const venueName =
            bookingId === null ? null : venueNames.get(String(bookingId));
          if (venueName) attachment.venueName = venueName;
        }
      }
      return res.json({ messages: visibleRows });
    } catch (error) {
      return next(error);
    }
  });
  
  app.delete('/api/messages/conversations/:conversationId/messages/:messageId', requireAuth, async (req, res, next) => {
    const conversationId = positiveIntegerId(req.params.conversationId);
    const messageId = positiveIntegerId(req.params.messageId);
    const scope = req.body.scope;
    if (conversationId === null || messageId === null) {
      return res.status(400).json({ error: 'The conversation and message are invalid.' });
    }
    if (scope !== 'me' && scope !== 'everyone') {
      return res.status(400).json({ error: 'Choose a valid message deletion scope.' });
    }
    try {
      const [messages] = await pool.execute(
        `SELECT m.sender_id AS senderId
         FROM messages m
         JOIN conversation_members cm
           ON cm.conversation_id = m.conversation_id
          AND cm.user_id = ? AND cm.deleted_at IS NULL
         WHERE m.id = ? AND m.conversation_id = ?
         LIMIT 1`,
        [req.auth.sub, messageId, conversationId],
      );
      if (messages.length === 0) {
        return res.status(404).json({ error: 'Message not found or cannot be deleted.' });
      }
      if (scope === 'everyone') {
        if (String(messages[0].senderId) !== String(req.auth.sub)) {
          return res.status(403).json({
            error: 'You can only delete your own message for everyone.',
          });
        }
        await pool.execute(
          `UPDATE messages
           SET body = NULL, attachment_json = NULL,
               removed_at = COALESCE(removed_at, CURRENT_TIMESTAMP),
               removed_by = COALESCE(removed_by, ?)
           WHERE id = ? AND conversation_id = ?`,
          [req.auth.sub, messageId, conversationId],
        );
        return res.json({ message: 'Message deleted for everyone.' });
      }
      await pool.execute(
        `INSERT IGNORE INTO message_user_deletions (message_id, user_id)
         VALUES (?, ?)`,
        [messageId, req.auth.sub],
      );
      return res.json({ message: 'Message deleted for you.' });
    } catch (error) {
      return next(error);
    }
  });
  
  app.post('/api/messages/conversations/:id', requireAuth, async (req, res, next) => {
    const body = typeof req.body.body === 'string' ? req.body.body.trim() : '';
    const attachment = req.body.attachment;
    const businessType = req.body.businessType === undefined
      ? null
      : normalizeBusinessType(req.body.businessType);
    if (req.body.businessType !== undefined && !businessType) {
      return res.status(400).json({ error: 'Invalid business type filter.' });
    }
    const hasImage = attachment &&
      typeof attachment === 'object' &&
      attachment.type === 'image' &&
      typeof attachment.data === 'string' &&
      /^data:image\/(jpeg|jpg|png|webp|gif);base64,[A-Za-z0-9+/=]+$/.test(attachment.data) &&
      attachment.data.length <= 7 * 1024 * 1024;
    const hasGif = attachment &&
      typeof attachment === 'object' &&
      attachment.type === 'gif' &&
      validTenorGifUrl(attachment.url);
    if ((!body && !hasImage && !hasGif) || body.length > 4000) {
      return res.status(400).json({
        error: 'Add a message or a valid image attachment. Images must be smaller than 5 MB.',
      });
    }
    if (attachment != null && !hasImage && !hasGif) {
      return res.status(400).json({ error: 'The image or GIF attachment is invalid or too large.' });
    }
    try {
      const conversationId = positiveIntegerId(req.params.id);
      if (conversationId === null) {
        return res.status(400).json({ error: 'The conversation is invalid.' });
      }
      const [members] = await pool.execute(
        `SELECT 1 FROM conversation_members
         WHERE conversation_id = ? AND user_id = ? AND deleted_at IS NULL`,
        [conversationId, req.auth.sub],
      );
      if (members.length === 0) {
        return res.status(403).json({ error: 'You are not a member of this conversation.' });
      }
      if (
        businessType &&
        !(await isConversationForBusinessType(
          conversationId,
          req.auth.sub,
          businessType,
        ))
      ) {
        return res.status(404).json({ error: 'Conversation not found.' });
      }
      const [blocked] = await pool.execute(
        `SELECT 1
         FROM conversation_members sender
         JOIN conversations c
           ON c.id = sender.conversation_id AND c.type = 'direct'
         JOIN conversation_members recipient
           ON recipient.conversation_id = sender.conversation_id
          AND recipient.user_id <> sender.user_id
         JOIN user_blocks ub
           ON (ub.blocker_id = sender.user_id AND ub.blocked_user_id = recipient.user_id)
           OR (ub.blocker_id = recipient.user_id AND ub.blocked_user_id = sender.user_id)
         WHERE sender.conversation_id = ? AND sender.user_id = ?
         LIMIT 1`,
        [conversationId, req.auth.sub],
      );
      if (blocked.length > 0) {
        return res.status(403).json({ error: 'Messages cannot be sent in this blocked conversation.' });
      }
      const [recipients] = await pool.execute(
        `SELECT user_id FROM conversation_members
         WHERE conversation_id = ? AND deleted_at IS NULL`,
        [conversationId],
      );
      await pool.execute(
        `UPDATE conversation_members
         SET archived_at = NULL, deleted_at = NULL
         WHERE conversation_id = ?`,
        [conversationId],
      );
      await pool.execute(
        'INSERT INTO messages (conversation_id, sender_id, body, attachment_json) VALUES (?, ?, ?, ?)',
        [
          conversationId,
          req.auth.sub,
          body || null,
          hasImage
            ? JSON.stringify({
                type: 'image',
                name: typeof attachment.name === 'string'
                  ? attachment.name.slice(0, 255)
                  : 'image',
                data: attachment.data,
              })
            : hasGif
            ? JSON.stringify({ type: 'gif', url: attachment.url })
            : null,
        ],
      );
      await recordUserActivity(
        pool,
        req.auth.sub,
        'message_sent',
        'Message sent',
        'You sent a message in a conversation.',
      );
      for (const member of recipients) {
        publishToUser(member.user_id, {
          type: 'message.created',
          conversationId,
        });
      }
      return res.status(201).json({ message: 'Message sent.' });
    } catch (error) {
      return next(error);
    }
  });
}

module.exports = { registerMessagingRoutes };
