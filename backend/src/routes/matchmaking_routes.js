const SKILL_LEVELS = new Set([
  'beginner',
  'intermediate',
  'advanced',
  'open',
]);

function registerMatchmakingRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  publishToUser = () => {},
  recordUserActivity = async () => {},
  notifyBookingParticipants = async () => {},
}) {
  const requireCustomer = requireRole('customer');
  const requireMerchant = requireRole('merchant');

  app.get(
    '/api/matchmaking/lobbies',
    requireAuth,
    requireCustomer,
    async (req, res, next) => {
      const { sport, venueId, date, skillLevel, cursor } = req.query;
      const limit = req.query.limit === undefined ? 20 : Number(req.query.limit);
      const parsedVenueId = venueId === undefined ? null : positiveId(venueId);
      const lobbyId = req.query.lobbyId === undefined
        ? null
        : positiveId(req.query.lobbyId);
      const parsedCursor = cursor === undefined ? null : positiveId(cursor);

      if (
        !Number.isInteger(limit) ||
        limit < 1 ||
        limit > 50 ||
        (req.query.lobbyId !== undefined && lobbyId === null) ||
        (venueId !== undefined && parsedVenueId === null) ||
        (cursor !== undefined && parsedCursor === null) ||
        (sport !== undefined &&
          (typeof sport !== 'string' || sport.trim().length === 0 || sport.length > 100)) ||
        (date !== undefined && !validDate(date)) ||
        (skillLevel !== undefined && !SKILL_LEVELS.has(skillLevel))
      ) {
        return res.status(400).json({ error: 'Invalid matchmaking filters.' });
      }

      const conditions = [
        "l.status = 'open'",
        'TIMESTAMP(l.match_date, l.start_time) > UTC_TIMESTAMP()',
        'b.enabled = 1',
        'b.allow_matchmaking = 1',
        'bk.payment_status = \'partial\'',
      ];
      const params = [Number(req.auth.sub)];
      if (sport !== undefined) {
        conditions.push('l.sport_type = ?');
        params.push(sport.trim());
      }
      if (parsedVenueId !== null) {
        conditions.push('l.venue_id = ?');
        params.push(parsedVenueId);
      }
      if (lobbyId !== null) {
        conditions.push('l.id = ?');
        params.push(lobbyId);
      }
      if (date !== undefined) {
        conditions.push('l.match_date = ?');
        params.push(date);
      }
      if (skillLevel !== undefined) {
        conditions.push('l.skill_level = ?');
        params.push(skillLevel);
      }
      if (parsedCursor !== null) {
        conditions.push('l.id < ?');
        params.push(parsedCursor);
      }
      params.push(limit + 1);

      try {
        const [rows] = await pool.execute(
          `SELECT l.id, l.host_user_id AS hostUserId, l.venue_id AS venueId,
                  l.booking_id AS bookingId, l.sport_type AS sportType,
                  l.slot_number AS slotNumber, l.total_price AS totalPrice,
                  l.host_share_amount AS hostShareAmount,
                  l.host_balance_amount AS hostBalanceAmount,
                  l.opponent_share_amount AS opponentShareAmount,
                  l.payment_policy AS paymentPolicy,
                  bk.payment_method AS paymentMethod,
                  l.opponent_criteria AS opponentCriteria,
                  DATE_FORMAT(l.match_date, '%Y-%m-%d') AS matchDate,
                  TIME_FORMAT(l.start_time, '%H:%i') AS startTime,
                  l.duration_hours AS durationHours,
                  l.skill_level AS skillLevel, l.cost_per_player AS costPerPlayer,
                  l.status, l.created_at AS createdAt,
                  b.name AS venueName, b.address AS venueAddress,
                  b.latitude AS venueLatitude, b.longitude AS venueLongitude,
                  b.business_logo_url AS venueLogoUrl,
                  b.image_url AS venueImageUrl, b.image_urls AS venueImageUrls,
                  COALESCE((SELECT AVG(r.rating) FROM venue_reviews r
                            WHERE r.business_id = b.id), 0) AS venueRating,
                  (SELECT COUNT(*) FROM venue_reviews r
                   WHERE r.business_id = b.id) AS venueReviewCount,
                  host.first_name AS hostFirstName,
                  host.avatar_url AS hostAvatarUrl,
                  mine.status AS requestStatus
           FROM matchmaking_lobbies l
           JOIN merchant_businesses b ON b.id = l.venue_id
           JOIN bookings bk ON bk.id = l.booking_id
           JOIN users host ON host.id = l.host_user_id
           LEFT JOIN matchmaking_requests mine
             ON mine.lobby_id = l.id AND mine.opponent_user_id = ?
           WHERE ${conditions.join(' AND ')}
           ORDER BY l.id DESC
           LIMIT ?`,
          params,
        );
        const hasMore = rows.length > limit;
        const lobbies = hasMore ? rows.slice(0, limit) : rows;
        return res.json({
          lobbies,
          nextCursor: hasMore ? String(lobbies.at(-1).id) : null,
          hasMore,
        });
      } catch (error) {
        return next(error);
      }
    },
  );

  app.get(
    '/api/matchmaking/host/lobbies',
    requireAuth,
    requireCustomer,
    async (req, res, next) => {
      try {
        const [rows] = await pool.execute(
          `SELECT l.id AS lobbyId, l.booking_id AS bookingId,
                  l.sport_type AS sportType, l.slot_number AS slotNumber,
                  DATE_FORMAT(l.match_date, '%Y-%m-%d') AS matchDate,
                  TIME_FORMAT(l.start_time, '%H:%i') AS startTime,
                  l.total_price AS totalPrice,
                  l.host_share_amount AS hostShareAmount,
                  l.host_balance_amount AS hostBalanceAmount,
                  l.opponent_share_amount AS opponentShareAmount,
                  l.payment_policy AS paymentPolicy,
                  l.host_balance_payment_status AS hostBalancePaymentStatus,
                  bk.payment_method AS paymentMethod,
                  l.status, bk.payment_status AS paymentStatus,
                  bk.payment_due_at AS paymentDueAt, b.name AS venueName
           FROM matchmaking_lobbies l
           JOIN bookings bk ON bk.id = l.booking_id
           JOIN merchant_businesses b ON b.id = l.venue_id
           WHERE l.host_user_id = ?
             AND l.status IN (
               'pending_merchant_approval', 'awaiting_host_downpayment',
               'open', 'matched'
             )
           ORDER BY l.created_at DESC
           LIMIT 20`,
          [Number(req.auth.sub)],
        );
        return res.json({ lobbies: rows });
      } catch (error) {
        return next(error);
      }
    },
  );

  app.post(
    '/api/matchmaking/lobbies',
    requireAuth,
    requireCustomer,
    async (req, res, next) => {
      const venueId = positiveId(req.body.venueId);
      const slotNumber = positiveId(req.body.slotNumber);
      const sportType =
        typeof req.body.sportType === 'string' ? req.body.sportType.trim() : '';
      const matchDate = req.body.matchDate;
      const startTime = req.body.startTime;
      const durationHours = Number(req.body.durationHours ?? 1);
      const skillLevel = req.body.skillLevel ?? 'open';
      const paymentMethod = req.body.paymentMethod ?? 'online';
      const paymentPolicy = req.body.paymentPolicy ?? 'split_remaining';
      const opponentCriteria = req.body.opponentCriteria ?? req.body.notes ?? null;

      if (
        venueId === null ||
        slotNumber === null ||
        sportType.length === 0 ||
        sportType.length > 100 ||
        !isFutureDateTime(matchDate, startTime) ||
        !Number.isFinite(durationHours) ||
        durationHours <= 0 ||
        durationHours > 24 ||
        !SKILL_LEVELS.has(skillLevel) ||
        !['online', 'cash_on_arrival'].includes(paymentMethod) ||
        !['split_remaining', 'host_covers_remaining'].includes(paymentPolicy) ||
        (opponentCriteria !== null &&
          (typeof opponentCriteria !== 'string' || opponentCriteria.length > 255))
      ) {
        return res.status(400).json({ error: 'A valid future match is required.' });
      }

      let connection;
      try {
        connection = await pool.getConnection();
        await connection.beginTransaction();
        const [venues] = await connection.execute(
          `SELECT b.id, b.merchant_id AS merchantId, b.name, b.category,
                  b.opening_hours AS openingHours, b.price_per_hour AS pricePerHour,
                  b.slot_count AS slotCount, b.sports_slots_json AS sportsSlots,
                  b.enabled, b.allow_matchmaking AS allowMatchmaking,
                  u.status AS merchantStatus
           FROM merchant_businesses b
           JOIN users u ON u.id = b.merchant_id
           WHERE b.id = ? AND b.business_type = 'Sports'
           FOR UPDATE`,
          [venueId],
        );
        const venue = venues[0];
        if (
          !venue ||
          Number(venue.enabled) !== 1 ||
          Number(venue.allowMatchmaking) !== 1 ||
          venue.merchantStatus !== 'active'
        ) {
          await connection.rollback();
          return res.status(400).json({
            error: 'This sports venue does not allow matchmaking.',
          });
        }
        const slotConfig = findSportConfiguration(venue, sportType);
        const venueHours = parseVenueHours(venue.openingHours);
        const startMinutes = timeToMinutes(startTime);
        const matchEndMinutes = startMinutes + durationHours * 60;
        if (
          !slotConfig ||
          slotNumber > (slotConfig.fullStudio ? 1 : slotConfig.slotCount) ||
          !venueHours ||
          startMinutes < venueHours.opening ||
          matchEndMinutes > venueHours.closing
        ) {
          await connection.rollback();
          return res.status(400).json({
            error: 'The sport, court, or match time is outside this venue availability.',
          });
        }

        const [conflicts] = await connection.execute(
          `SELECT id FROM bookings
           WHERE venue_id = ? AND booking_date = ?
             AND start_time < ADDTIME(?, SEC_TO_TIME(? * 3600))
             AND ADDTIME(start_time, SEC_TO_TIME(duration_hours * 3600)) > ?
             AND status IN (
               'pending', 'approved',
               'matchmaking_pending_merchant', 'matchmaking_open'
             )
             AND (
               ? = 1 OR occupies_full_studio = 1 OR slot_number = ?
               OR JSON_CONTAINS(slot_numbers_json, JSON_ARRAY(?))
             )
           FOR UPDATE`,
          [
            venueId,
            matchDate,
            startTime,
            durationHours,
            startTime,
            slotConfig.fullStudio ? 1 : 0,
            slotNumber,
            slotNumber,
          ],
        );
        if (conflicts.length > 0) {
          await connection.rollback();
          return res.status(409).json({
            error: 'This court slot is already booked for this date and time.',
          });
        }

        const totalPrice = Number(
          (Number(slotConfig.pricePerHour) * durationHours).toFixed(2),
        );
        const hostShareAmount = Number((totalPrice * 0.5).toFixed(2));
        const remainingBalance = Number((totalPrice - hostShareAmount).toFixed(2));
        const hostBalanceAmount = paymentPolicy === 'host_covers_remaining'
          ? remainingBalance
          : Number((remainingBalance * 0.5).toFixed(2));
        const opponentShareAmount = Number(
          (remainingBalance - hostBalanceAmount).toFixed(2),
        );
        const hostBalancePaymentStatus = paymentMethod === 'cash_on_arrival'
          ? 'cash_on_arrival'
          : 'unpaid';
        const [bookingResult] = await connection.execute(
          `INSERT INTO bookings
           (customer_id, venue_id, booking_type, booking_date, start_time, duration_hours,
            players, payment_method, price_per_hour, total_amount,
            downpayment_amount, payment_status, paid_amount, status,
            sport_type, slot_number, occupies_full_studio)
           VALUES (?, ?, 'matchmaking', ?, ?, ?, 2, ?, ?, ?, ?, 'unpaid', 0,
                   'matchmaking_pending_merchant', ?, ?, ?)`,
          [
            Number(req.auth.sub),
            venueId,
            matchDate,
            `${startTime}:00`,
            durationHours,
            paymentMethod,
            Number(slotConfig.pricePerHour),
            totalPrice,
            hostShareAmount,
            sportType,
            slotNumber,
            slotConfig.fullStudio ? 1 : 0,
          ],
        );
        const [bookingConversation] = await connection.execute(
          `INSERT INTO conversations (type, title, created_by)
           VALUES ('direct', ?, ?)`,
          [`Booking ${bookingResult.insertId}`, Number(req.auth.sub)],
        );
        await connection.execute(
          `INSERT INTO conversation_members (conversation_id, user_id)
           VALUES (?, ?), (?, ?)`,
          [
            bookingConversation.insertId,
            Number(req.auth.sub),
            bookingConversation.insertId,
            Number(venue.merchantId),
          ],
        );
        const [result] = await connection.execute(
          `INSERT INTO matchmaking_lobbies
           (host_user_id, venue_id, booking_id, sport_type, slot_number,
            match_date, start_time, duration_hours, total_price,
            host_share_amount, host_balance_amount, opponent_share_amount,
            payment_policy, host_balance_payment_status, skill_level,
            opponent_criteria, status)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
                   'pending_merchant_approval')`,
          [
            Number(req.auth.sub),
            venueId,
            bookingResult.insertId,
            sportType,
            slotNumber,
            matchDate,
            `${startTime}:00`,
            durationHours,
            totalPrice,
            hostShareAmount,
            hostBalanceAmount,
            opponentShareAmount,
            paymentPolicy,
            hostBalancePaymentStatus,
            skillLevel,
            typeof opponentCriteria === 'string'
              ? opponentCriteria.trim() || null
              : null,
          ],
        );
        const hostName = [req.auth.firstName, req.auth.lastName]
          .filter((name) => typeof name === 'string' && name.trim())
          .join(' ')
          .trim() || 'Customer';
        const ticket = {
          type: 'matchmaking_booking_request_ticket',
          lobbyId: Number(result.insertId),
          bookingId: Number(bookingResult.insertId),
          venueName: venue.name,
          hostName,
          sportType,
          slotNumber,
          matchDate,
          startTime,
          durationHours,
          totalPrice,
          hostShareAmount,
          paymentMethod,
          paymentPolicy,
          status: 'pending_merchant_approval',
        };
        await connection.execute(
          `INSERT INTO messages
           (conversation_id, sender_id, body, attachment_json)
           VALUES (?, ?, ?, ?)`,
          [
              bookingConversation.insertId,
              Number(req.auth.sub),
              `Match booking request for ${venue.name} awaits venue approval.`,
              JSON.stringify(ticket),
          ],
        );
        await connection.commit();
        for (const userId of [Number(venue.merchantId), Number(req.auth.sub)]) {
          publishToUser(userId, {
              type: 'message.created',
              conversationId: Number(bookingConversation.insertId),
          });
        }
        publishToUser(Number(venue.merchantId), {
          type: 'matchmaking.merchant-request.created',
          lobbyId: Number(result.insertId),
          bookingId: Number(bookingResult.insertId),
        });
        publishToUser(Number(req.auth.sub), {
          type: 'matchmaking.request.created',
          lobbyId: Number(result.insertId),
        });
        notifyBookingParticipants({
          userIds: [Number(venue.merchantId)],
          event: 'matchmaking_host_request',
          booking: {
            id: Number(bookingResult.insertId),
            venueName: venue.name,
            bookingDate: matchDate,
            startTime,
            hostName: req.auth.firstName || 'A player',
          },
        }).catch((error) => {
          console.error('Could not send matchmaking request notifications.', error);
        });
        return res.status(201).json({
          lobbyId: Number(result.insertId),
          bookingId: Number(bookingResult.insertId),
          totalPrice,
          hostShareAmount,
          hostBalanceAmount,
          opponentShareAmount,
          paymentMethod,
          paymentPolicy,
        });
      } catch (error) {
        if (connection) await connection.rollback();
        return next(error);
      } finally {
        connection?.release();
      }
    },
  );

  app.get(
    '/api/merchant/matchmaking/lobbies',
    requireAuth,
    requireMerchant,
    async (req, res, next) => {
      try {
        const [rows] = await pool.execute(
          `SELECT l.id AS lobbyId, l.booking_id AS bookingId,
                  l.sport_type AS sportType, l.slot_number AS slotNumber,
                  l.opponent_criteria AS opponentCriteria,
                  DATE_FORMAT(l.match_date, '%Y-%m-%d') AS matchDate,
                  TIME_FORMAT(l.start_time, '%H:%i') AS startTime,
                  l.duration_hours AS durationHours,
                  l.total_price AS totalPrice,
                  l.host_share_amount AS hostShareAmount,
                  l.status, b.name AS venueName,
                  CONCAT_WS(' ', u.first_name, u.last_name) AS hostName
           FROM matchmaking_lobbies l
           JOIN merchant_businesses b ON b.id = l.venue_id
           JOIN users u ON u.id = l.host_user_id
           WHERE b.merchant_id = ?
             AND l.status = 'pending_merchant_approval'
           ORDER BY l.created_at ASC`,
          [Number(req.auth.sub)],
        );
        return res.json({ lobbies: rows });
      } catch (error) {
        return next(error);
      }
    },
  );

  const decideMerchantRequest = (approve) => async (req, res, next) => {
    const lobbyId = positiveId(req.params.id);
    const reason = typeof req.body?.reason === 'string'
      ? req.body.reason.trim()
      : '';
    if (lobbyId === null) {
      return res.status(400).json({ error: 'The matchmaking lobby is invalid.' });
    }
    if (!approve && reason.length > 1000) {
      return res.status(400).json({ error: 'The decline reason is too long.' });
    }

    let connection;
    try {
      connection = await pool.getConnection();
      await connection.beginTransaction();
      const [rows] = await connection.execute(
        `SELECT l.id, l.host_user_id AS hostUserId, l.booking_id AS bookingId,
                l.venue_id AS venueId, l.status, b.name AS venueName,
                l.match_date AS matchDate, l.start_time AS startTime,
                l.host_share_amount AS hostShareAmount
         FROM matchmaking_lobbies l
         JOIN merchant_businesses b ON b.id = l.venue_id
         WHERE l.id = ? AND b.merchant_id = ?
         FOR UPDATE`,
        [lobbyId, Number(req.auth.sub)],
      );
      const lobby = rows[0];
      if (!lobby) {
        await connection.rollback();
        return res.status(404).json({ error: 'Matchmaking request not found.' });
      }
      if (lobby.status !== 'pending_merchant_approval') {
        await connection.rollback();
        return res.status(409).json({ error: 'This matchmaking request is no longer pending.' });
      }
      if (approve) {
        const [bookingUpdate] = await connection.execute(
          `UPDATE bookings
           SET status = 'matchmaking_open',
               payment_due_at = DATE_ADD(CURRENT_TIMESTAMP, INTERVAL 15 MINUTE),
               payment_timeout_minutes = 15
           WHERE id = ? AND status = 'matchmaking_pending_merchant'`,
          [lobby.bookingId],
        );
        if (!bookingUpdate.affectedRows) {
          await connection.rollback();
          return res.status(409).json({
            error: 'The linked court booking is no longer available.',
          });
        }
        await connection.execute(
          `UPDATE matchmaking_lobbies
           SET status = 'awaiting_host_downpayment'
           WHERE id = ?`,
          [lobbyId],
        );
      } else {
        const [bookingUpdate] = await connection.execute(
          `UPDATE bookings SET status = 'cancelled'
           WHERE id = ? AND status = 'matchmaking_pending_merchant'`,
          [lobby.bookingId],
        );
        if (!bookingUpdate.affectedRows) {
          await connection.rollback();
          return res.status(409).json({
            error: 'The linked court booking is no longer available.',
          });
        }
        await connection.execute(
          `UPDATE matchmaking_lobbies SET status = 'cancelled' WHERE id = ?`,
          [lobbyId],
        );
      }
      await connection.execute(
        `UPDATE messages m
         JOIN conversations c ON c.id = m.conversation_id
         SET m.attachment_json = JSON_SET(
           m.attachment_json, '$.status', ?,
           '$.declineReason', ?
         )
         WHERE c.type = 'direct' AND c.title = ?
           AND CASE WHEN JSON_VALID(m.attachment_json)
                    THEN JSON_UNQUOTE(JSON_EXTRACT(
                      m.attachment_json, '$.type'
                    )) END = 'matchmaking_booking_request_ticket'
           AND CASE WHEN JSON_VALID(m.attachment_json)
                    THEN JSON_UNQUOTE(JSON_EXTRACT(
                      m.attachment_json, '$.bookingId'
                    )) END = ?`,
        [
          approve ? 'approved' : 'declined',
          approve || reason.length === 0 ? null : reason,
          `Booking ${lobby.bookingId}`,
          String(lobby.bookingId),
        ],
      );
      await recordUserActivity(
        connection,
        Number(lobby.hostUserId),
        approve ? 'matchmaking_approved' : 'matchmaking_declined',
        approve ? 'Matchmaking request approved' : 'Matchmaking request declined',
        approve
          ? `Your matchmaking request at ${lobby.venueName} was approved. Pay the 50% downpayment within 15 minutes to publish it.`
          : 'Venue could not accommodate your matchmaking request.',
        {
          venueId: lobby.venueId,
          venueName: lobby.venueName,
          sportType: 'Matchmaking',
          details: { lobbyId, bookingId: lobby.bookingId },
        },
        { systemGenerated: true },
      );
      const [conversationRows] = await connection.execute(
        'SELECT id FROM conversations WHERE type = ? AND title = ? LIMIT 1',
        ['direct', `Booking ${lobby.bookingId}`],
      );
      await connection.commit();
      if (conversationRows[0]) {
        publishToUser(Number(lobby.hostUserId), {
          type: 'message.created',
          conversationId: Number(conversationRows[0].id),
        });
        publishToUser(Number(req.auth.sub), {
          type: 'message.created',
          conversationId: Number(conversationRows[0].id),
        });
      }
      publishToUser(Number(lobby.hostUserId), {
        type: approve
          ? 'matchmaking.merchant-request.approved'
          : 'matchmaking.merchant-request.declined',
        lobbyId,
        bookingId: Number(lobby.bookingId),
        paymentTimeoutMinutes: approve ? 15 : null,
        hostShareAmount: approve ? Number(lobby.hostShareAmount) : null,
      });
      publishToUser(Number(req.auth.sub), {
        type: 'dashboard.updated',
      });
      notifyBookingParticipants({
        userIds: [Number(lobby.hostUserId)],
        event: approve
          ? 'matchmaking_approved'
          : 'matchmaking_declined',
        booking: {
          id: Number(lobby.bookingId),
          venueName: lobby.venueName,
          reason: 'Venue could not accommodate your matchmaking request.',
        },
      }).catch((error) => {
        console.error('Could not send matchmaking decision notification.', error);
      });
      return res.json({
        message: approve
          ? 'Matchmaking request approved. The host has 15 minutes to pay.'
          : 'Matchmaking request declined and the court slot was released.',
      });
    } catch (error) {
      if (connection) await connection.rollback();
      return next(error);
    } finally {
      connection?.release();
    }
  };

  app.post(
    '/api/matchmaking/lobbies/:id/merchant-approve',
    requireAuth,
    requireMerchant,
    decideMerchantRequest(true),
  );
  app.post(
    '/api/matchmaking/lobbies/:id/merchant-decline',
    requireAuth,
    requireMerchant,
    decideMerchantRequest(false),
  );

  app.delete(
    '/api/matchmaking/lobbies/:id',
    requireAuth,
    requireCustomer,
    async (req, res, next) => {
      const lobbyId = positiveId(req.params.id);
      if (lobbyId === null) {
        return res.status(400).json({ error: 'The matchmaking lobby is invalid.' });
      }
      try {
        const [result] = await pool.execute(
          `UPDATE matchmaking_lobbies
           SET status = 'cancelled'
           WHERE id = ? AND host_user_id = ?
             AND status IN (
               'pending_merchant_approval', 'awaiting_host_downpayment', 'open'
             )`,
          [lobbyId, Number(req.auth.sub)],
        );
        if (result.affectedRows === 0) {
          const [owned] = await pool.execute(
            'SELECT id FROM matchmaking_lobbies WHERE id = ? AND host_user_id = ?',
            [lobbyId, Number(req.auth.sub)],
          );
          if (owned.length === 0) {
            return res.status(404).json({ error: 'Matchmaking lobby not found.' });
          }
          return res.status(409).json({ error: 'This lobby can no longer be cancelled.' });
        }
        return res.json({ message: 'Matchmaking lobby cancelled.' });
      } catch (error) {
        return next(error);
      }
    },
  );

  app.post(
    '/api/matchmaking/lobbies/:id/join',
    requireAuth,
    requireCustomer,
    async (req, res, next) => {
      const lobbyId = positiveId(req.params.id);
      const message =
        req.body.message == null
          ? null
          : typeof req.body.message === 'string'
            ? req.body.message.trim()
            : undefined;
      if (lobbyId === null || message === undefined || message?.length > 255) {
        return res.status(400).json({ error: 'The join request is invalid.' });
      }

      let connection;
      try {
        connection = await pool.getConnection();
        await connection.beginTransaction();
        const [lobbies] = await connection.execute(
          `SELECT l.id, l.host_user_id AS hostUserId, l.booking_id AS bookingId,
                  l.sport_type AS sportType,
                  DATE_FORMAT(l.match_date, '%Y-%m-%d') AS matchDate,
                  TIME_FORMAT(l.start_time, '%H:%i') AS startTime,
                  l.skill_level AS skillLevel,
                  l.opponent_share_amount AS opponentShareAmount,
                  l.host_balance_amount AS hostBalanceAmount,
                  l.payment_policy AS paymentPolicy,
                  bk.payment_method AS paymentMethod,
                  l.status, b.allow_matchmaking AS allowMatchmaking, b.enabled,
                  b.name AS venueName
           FROM matchmaking_lobbies l
           JOIN merchant_businesses b ON b.id = l.venue_id
           JOIN bookings bk ON bk.id = l.booking_id
           WHERE l.id = ?
           FOR UPDATE`,
          [lobbyId],
        );
        const lobby = lobbies[0];
        if (!lobby) {
          await connection.rollback();
          return res.status(404).json({ error: 'Matchmaking lobby not found.' });
        }
        if (
          Number(lobby.hostUserId) === Number(req.auth.sub) ||
          lobby.status !== 'open' ||
          Number(lobby.allowMatchmaking) !== 1 ||
          Number(lobby.enabled) !== 1
        ) {
          await connection.rollback();
          return res.status(409).json({ error: 'This lobby is not accepting requests.' });
        }

        const [existingRequests] = await connection.execute(
          `SELECT id, status, conversation_id AS conversationId
           FROM matchmaking_requests
           WHERE lobby_id = ? AND opponent_user_id = ? FOR UPDATE`,
          [lobbyId, Number(req.auth.sub)],
        );
        if (
          existingRequests[0]?.status === 'pending' ||
          existingRequests[0]?.status === 'accepted'
        ) {
          await connection.rollback();
          return res.status(409).json({ error: 'You already have an active request for this match.' });
        }
        const hostId = Number(lobby.hostUserId);
        const applicantId = Number(req.auth.sub);
        const [blocked] = await connection.execute(
          `SELECT 1 FROM user_blocks
           WHERE (blocker_id = ? AND blocked_user_id = ?)
              OR (blocker_id = ? AND blocked_user_id = ?)
           LIMIT 1`,
          [hostId, applicantId, applicantId, hostId],
        );
        if (blocked.length > 0) {
          await connection.rollback();
          return res.status(403).json({ error: 'This host cannot receive your request.' });
        }

        const [users] = await connection.execute(
          `SELECT id, first_name AS firstName, last_name AS lastName,
                  avatar_url AS avatarUrl
           FROM users WHERE id IN (?, ?) AND status = 'active'`,
          [hostId, applicantId],
        );
        if (users.length !== 2) {
          await connection.rollback();
          return res.status(404).json({ error: 'A match participant is unavailable.' });
        }
        const applicant = users.find((user) => Number(user.id) === applicantId);
        const applicantName = [applicant.firstName, applicant.lastName]
          .filter(Boolean)
          .join(' ')
          .trim() || 'Player';

        const conversationId = await findOrCreateDirectConversation(
          connection,
          applicantId,
          hostId,
        );
        let requestId;
        if (existingRequests.length > 0) {
          requestId = Number(existingRequests[0].id);
          await connection.execute(
            `UPDATE matchmaking_requests
             SET status = 'pending', message = ?, conversation_id = ?,
                 created_at = CURRENT_TIMESTAMP
             WHERE id = ?`,
            [message || null, conversationId, requestId],
          );
        } else {
          const [requestResult] = await connection.execute(
            `INSERT INTO matchmaking_requests
             (lobby_id, opponent_user_id, conversation_id, message)
             VALUES (?, ?, ?, ?)`,
            [lobbyId, applicantId, conversationId, message || null],
          );
          requestId = Number(requestResult.insertId);
        }
        const applicantAvatarUrl = applicant.avatarUrl ?? null;
        const ticket = {
          type: 'matchmaking_ticket',
          lobbyId,
          bookingId: Number(lobby.bookingId),
          requestId,
          applicantId,
          applicantName,
          applicantAvatarUrl,
          sportType: lobby.sportType,
          venueName: lobby.venueName,
          matchDate: lobby.matchDate,
          startTime: lobby.startTime,
          skillLevel: lobby.skillLevel,
          opponentShareAmount: Number(lobby.opponentShareAmount),
          hostBalanceAmount: Number(lobby.hostBalanceAmount),
          paymentMethod: lobby.paymentMethod,
          paymentPolicy: lobby.paymentPolicy,
          status: 'pending',
        };
        await connection.execute(
          `INSERT INTO messages
           (conversation_id, sender_id, body, attachment_json)
           VALUES (?, ?, ?, ?)`,
          [
            conversationId,
            applicantId,
            message || `I'd like to join your ${lobby.sportType} match.`,
            JSON.stringify(ticket),
          ],
        );
        await connection.execute(
          `UPDATE conversation_members
           SET archived_at = NULL, deleted_at = NULL
           WHERE conversation_id = ?`,
          [conversationId],
        );
        await connection.commit();
        publishToUser(hostId, {
          type: 'message.created',
          conversationId,
        });
        publishToUser(hostId, {
          type: 'matchmaking.request.created',
          lobbyId,
          requestId,
        });
        publishToUser(applicantId, {
          type: 'message.created',
          conversationId,
        });
        notifyBookingParticipants({
          userIds: [hostId],
          event: 'matchmaking_request',
          booking: {
            id: Number(lobby.bookingId),
            venueName: lobby.venueName,
            sportType: lobby.sportType,
            applicantName,
          },
        }).catch((error) => {
          console.error('Could not send opponent request notification.', error);
        });
        return res.status(201).json({ requestId, conversationId });
      } catch (error) {
        if (connection) await connection.rollback();
        return next(error);
      } finally {
        connection?.release();
      }
    },
  );

  app.post(
    '/api/matchmaking/lobbies/:id/opponent-payment',
    requireAuth,
    requireCustomer,
    (req, res) => {
      const lobbyId = positiveId(req.params.id);
      if (lobbyId === null) {
        return res.status(400).json({ error: 'The matchmaking lobby is invalid.' });
      }
      return res.status(409).json({
        error: 'Online payment is required for this match.',
      });
    },
  );

  app.post(
    '/api/matchmaking/lobbies/:id/requests/:requestId/accept',
    requireAuth,
    requireCustomer,
    async (req, res, next) => {
      const lobbyId = positiveId(req.params.id);
      const requestId = positiveId(req.params.requestId);
      if (lobbyId === null || requestId === null) {
        return res.status(400).json({ error: 'The matchmaking request is invalid.' });
      }

      let connection;
      try {
        connection = await pool.getConnection();
        await connection.beginTransaction();
        const [lobbies] = await connection.execute(
          `SELECT l.id, l.host_user_id AS hostUserId,
                  l.opponent_share_amount AS opponentShareAmount,
                  l.host_balance_amount AS hostBalanceAmount,
                  l.payment_policy AS paymentPolicy,
                  l.host_balance_payment_status AS hostBalancePaymentStatus,
                  l.status, bk.payment_method AS paymentMethod
           FROM matchmaking_lobbies l
           JOIN bookings bk ON bk.id = l.booking_id
           WHERE l.id = ? FOR UPDATE`,
          [lobbyId],
        );
        const lobby = lobbies[0];
        if (!lobby || Number(lobby.hostUserId) !== Number(req.auth.sub)) {
          await connection.rollback();
          return res.status(404).json({ error: 'Matchmaking lobby not found.' });
        }
        const [requests] = await connection.execute(
          `SELECT id, opponent_user_id AS opponentUserId,
                  conversation_id AS conversationId, status
           FROM matchmaking_requests
           WHERE id = ? AND lobby_id = ? FOR UPDATE`,
          [requestId, lobbyId],
        );
        const joinRequest = requests[0];
        if (!joinRequest) {
          await connection.rollback();
          return res.status(404).json({ error: 'Matchmaking request not found.' });
        }
        if (
          joinRequest.status !== 'pending' ||
          lobby.status !== 'open'
        ) {
          await connection.rollback();
          return res.status(409).json({ error: 'This request can no longer be accepted.' });
        }

        const opponentPaymentStatus =
          lobby.paymentPolicy === 'host_covers_remaining'
            ? 'not_required'
            : lobby.paymentMethod === 'cash_on_arrival'
              ? 'cash_on_arrival'
              : 'unpaid';
        await connection.execute(
          `UPDATE matchmaking_lobbies
           SET accepted_opponent_id = ?, status = 'matched',
               opponent_payment_status = ?
           WHERE id = ?`,
          [Number(joinRequest.opponentUserId), opponentPaymentStatus, lobbyId],
        );
        await connection.execute(
          `UPDATE matchmaking_requests SET status = 'accepted' WHERE id = ?`,
          [requestId],
        );
        if (joinRequest.conversationId) {
          await connection.execute(
            `UPDATE messages
             SET attachment_json = JSON_SET(
               JSON_SET(
                 JSON_SET(
                   JSON_SET(attachment_json, '$.status', 'matched'),
                   '$.opponentShareAmount', ?
                 ),
                 '$.opponentPaymentStatus', ?
               ),
               '$.hostBalanceAmount', ?
             )
             WHERE conversation_id = ?
               AND JSON_UNQUOTE(JSON_EXTRACT(attachment_json, '$.requestId')) = ?`,
            [
              Number(lobby.opponentShareAmount),
              opponentPaymentStatus,
              Number(lobby.hostBalanceAmount),
              joinRequest.conversationId,
              String(requestId),
            ],
          );
        }
        await connection.commit();
        publishMatchmakingUpdate(
          publishToUser,
          Number(joinRequest.opponentUserId),
          joinRequest.conversationId,
          lobbyId,
          requestId,
          'matched',
        );
        return res.json({
          message: lobby.paymentPolicy === 'host_covers_remaining'
            ? 'Player accepted. The host covers the remaining balance.'
            : lobby.paymentMethod === 'cash_on_arrival'
              ? 'Player accepted. The remaining shares are due at the venue.'
              : 'Player accepted. Each player can pay their share online.',
          opponentShareAmount: Number(lobby.opponentShareAmount),
          hostBalanceAmount: Number(lobby.hostBalanceAmount),
          opponentPaymentStatus,
          paymentMethod: lobby.paymentMethod,
        });
      } catch (error) {
        if (connection) await connection.rollback();
        return next(error);
      } finally {
        connection?.release();
      }
    },
  );

  app.post(
    '/api/matchmaking/lobbies/:id/requests/:requestId/decline',
    requireAuth,
    requireCustomer,
    async (req, res, next) => {
      const lobbyId = positiveId(req.params.id);
      const requestId = positiveId(req.params.requestId);
      if (lobbyId === null || requestId === null) {
        return res.status(400).json({ error: 'The matchmaking request is invalid.' });
      }

      let connection;
      try {
        connection = await pool.getConnection();
        await connection.beginTransaction();
        const [lobbies] = await connection.execute(
          `SELECT id, host_user_id AS hostUserId
           FROM matchmaking_lobbies WHERE id = ? FOR UPDATE`,
          [lobbyId],
        );
        if (!lobbies[0] || Number(lobbies[0].hostUserId) !== Number(req.auth.sub)) {
          await connection.rollback();
          return res.status(404).json({ error: 'Matchmaking lobby not found.' });
        }
        const [requests] = await connection.execute(
          `SELECT id, opponent_user_id AS opponentUserId,
                  conversation_id AS conversationId, status
           FROM matchmaking_requests
           WHERE id = ? AND lobby_id = ? FOR UPDATE`,
          [requestId, lobbyId],
        );
        const joinRequest = requests[0];
        if (!joinRequest) {
          await connection.rollback();
          return res.status(404).json({ error: 'Matchmaking request not found.' });
        }
        if (joinRequest.status !== 'pending') {
          await connection.rollback();
          return res.status(409).json({ error: 'This request is no longer pending.' });
        }
        await connection.execute(
          `UPDATE matchmaking_requests SET status = 'declined' WHERE id = ?`,
          [requestId],
        );
        if (joinRequest.conversationId) {
          await connection.execute(
            `UPDATE messages
             SET attachment_json = JSON_SET(attachment_json, '$.status', 'declined')
             WHERE conversation_id = ?
               AND JSON_UNQUOTE(JSON_EXTRACT(attachment_json, '$.requestId')) = ?`,
            [joinRequest.conversationId, String(requestId)],
          );
        }
        await connection.commit();
        publishMatchmakingUpdate(
          publishToUser,
          Number(joinRequest.opponentUserId),
          joinRequest.conversationId,
          lobbyId,
          requestId,
          'declined',
        );
        return res.json({ message: 'Player request declined.' });
      } catch (error) {
        if (connection) await connection.rollback();
        return next(error);
      } finally {
        connection?.release();
      }
    },
  );
}

async function findOrCreateDirectConversation(connection, firstUserId, secondUserId) {
  const participants = [firstUserId, secondUserId].sort((a, b) => a - b);
  await connection.execute(
    'SELECT id FROM users WHERE id IN (?, ?) ORDER BY id FOR UPDATE',
    participants,
  );
  const [existing] = await connection.execute(
    `SELECT c.id
     FROM conversations c
     JOIN conversation_members cm ON cm.conversation_id = c.id
     WHERE c.type = 'direct' AND cm.user_id IN (?, ?)
     GROUP BY c.id
     HAVING COUNT(DISTINCT cm.user_id) = 2 AND COUNT(*) = 2
     ORDER BY c.id DESC LIMIT 1`,
    participants,
  );
  if (existing[0]) return Number(existing[0].id);

  const [result] = await connection.execute(
    `INSERT INTO conversations (type, title, created_by)
     VALUES ('direct', NULL, ?)`,
    [firstUserId],
  );
  for (const userId of participants) {
    await connection.execute(
      'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?)',
      [result.insertId, userId],
    );
  }
  return Number(result.insertId);
}

function findSportConfiguration(venue, targetSport) {
  let configurations = venue.sportsSlots;
  if (typeof configurations === 'string') {
    try {
      configurations = JSON.parse(configurations);
    } catch {
      return null;
    }
  }
  if (Array.isArray(configurations) && configurations.length > 0) {
    const config = configurations.find(
      (item) =>
        item &&
        typeof item.sportType === 'string' &&
        item.sportType.trim().toLowerCase() === targetSport.toLowerCase(),
    );
    if (!config) return null;
    const pricePerHour = Number(config.pricePerHour);
    const slotCount = Number(config.slotCount);
    if (
      !Number.isFinite(pricePerHour) ||
      pricePerHour <= 0 ||
      !Number.isSafeInteger(slotCount) ||
      slotCount < 1
    ) {
      return null;
    }
    return {
      pricePerHour,
      slotCount,
      fullStudio: config.fullStudio === true,
    };
  }
  if (
    typeof venue.category !== 'string' ||
    venue.category.trim().toLowerCase() !== targetSport.toLowerCase()
  ) {
    return null;
  }
  const pricePerHour = Number(venue.pricePerHour);
  const slotCount = Number(venue.slotCount);
  if (
    !Number.isFinite(pricePerHour) ||
    pricePerHour <= 0 ||
    !Number.isSafeInteger(slotCount) ||
    slotCount < 1
  ) {
    return null;
  }
  return { pricePerHour, slotCount, fullStudio: true };
}

function parseVenueHours(value) {
  const match = String(value ?? '').match(
    /^\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\s*[-–]\s*(\d{1,2})(?::(\d{2}))?\s*(AM|PM)\s*$/i,
  );
  if (!match) return null;
  const minutes = (hourText, minuteText, period) => {
    const hour = Number(hourText);
    const minute = Number(minuteText ?? 0);
    if (hour < 1 || hour > 12 || minute < 0 || minute > 59) return null;
    return (hour % 12 + (period.toUpperCase() === 'PM' ? 12 : 0)) * 60 +
      minute;
  };
  const opening = minutes(match[1], match[2], match[3]);
  let closing = minutes(match[4], match[5], match[6]);
  if (
    Number(match[4]) === 12 &&
    Number(match[5] ?? 0) === 0 &&
    match[6].toUpperCase() === 'AM'
  ) {
    closing = 24 * 60;
  }
  return opening === null || closing === null || closing <= opening
    ? null
    : { opening, closing };
}

function timeToMinutes(value) {
  if (typeof value !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(value)) {
    return -1;
  }
  const [hours, minutes] = value.split(':').map(Number);
  return hours * 60 + minutes;
}

function publishMatchmakingUpdate(
  publishToUser,
  userId,
  conversationId,
  lobbyId,
  requestId,
  status,
) {
  if (conversationId !== undefined) {
    publishToUser(userId, { type: 'message.created', conversationId });
  }
  publishToUser(userId, {
    type: 'matchmaking.request.updated',
    lobbyId,
    requestId,
    status,
  });
}

function positiveId(value) {
  if (
    (typeof value !== 'string' && typeof value !== 'number') ||
    (typeof value === 'string' && !/^[1-9]\d*$/.test(value))
  ) {
    return null;
  }
  const parsed = Number(value);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function validDate(value) {
  if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(value)) {
    return false;
  }
  const date = new Date(`${value}T00:00:00.000Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().slice(0, 10) === value;
}

function isFutureDateTime(date, time) {
  if (!validDate(date) || typeof time !== 'string' || !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) {
    return false;
  }
  return Date.parse(`${date}T${time}:00.000Z`) > Date.now();
}

module.exports = { registerMatchmakingRoutes };
