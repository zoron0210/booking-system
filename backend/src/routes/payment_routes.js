function registerPaymentRoutes({
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
}) {
app.post('/api/payments/paymongo/checkout', requireAuth, requireRole('customer'), async (req, res, next) => {
  const bookingId = Number(req.body.bookingId);
  const paymentMethod = typeof req.body.paymentMethod === 'string'
    ? req.body.paymentMethod.trim() : '';
  const paymentType = typeof req.body.paymentType === 'string'
    ? req.body.paymentType.trim() : 'full';
  if (!isNumericInput(req.body.bookingId) ||
      !Number.isSafeInteger(bookingId) || bookingId <= 0 ||
      !['gcash', 'paymaya'].includes(paymentMethod) ||
      ![
        'full',
        'matchmaking_downpayment',
        'matchmaking_opponent_share',
        'matchmaking_host_balance',
      ].includes(paymentType)) {
    return res.status(400).json({
      error: 'Choose a valid GCash or PayMaya payment before starting checkout.',
    });
  }
  if (!paymongoIsConfigured()) {
    return res.status(503).json({
      error: 'Online payment is not fully configured. Ask the app administrator to configure PayMongo checkout and its payment webhook.',
    });
  }
  let connection;
  let transactionActive = false;
  const rollbackResponse = async (status, body) => {
    await connection.rollback();
    transactionActive = false;
    return res.status(status).json(body);
  };
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    transactionActive = true;
    const [rows] = await connection.execute(
      `SELECT b.id, b.customer_id AS customerId,
              b.total_amount AS totalAmount,
              b.downpayment_amount AS downpaymentAmount,
              b.payment_method AS paymentMethod,
              b.payment_status AS paymentStatus, b.paid_amount AS paidAmount,
              b.payment_checkout_session_id AS paymentCheckoutSessionId,
              b.payment_checkout_url AS paymentCheckoutUrl,
              b.payment_checkout_method AS paymentCheckoutMethod,
              b.status, b.payment_due_at AS paymentDueAt,
              b.payment_due_at > CURRENT_TIMESTAMP AS paymentDeadlineActive,
              l.id AS matchmakingLobbyId, l.status AS matchmakingStatus,
              l.opponent_share_amount AS opponentShareAmount,
              l.host_balance_amount AS hostBalanceAmount,
              l.host_balance_payment_status AS hostBalancePaymentStatus,
              l.payment_policy AS paymentPolicy,
              l.opponent_payment_status AS opponentPaymentStatus,
              l.accepted_opponent_id AS acceptedOpponentId,
              l.opponent_checkout_session_id AS opponentCheckoutSessionId,
              l.opponent_checkout_url AS opponentCheckoutUrl,
              l.opponent_checkout_method AS opponentCheckoutMethod,
              l.host_balance_checkout_session_id AS hostBalanceCheckoutSessionId,
              l.host_balance_checkout_url AS hostBalanceCheckoutUrl,
              l.host_balance_checkout_method AS hostBalanceCheckoutMethod
         FROM bookings b
         LEFT JOIN matchmaking_lobbies l ON l.booking_id = b.id
        WHERE b.id = ?
          AND (b.customer_id = ? OR l.accepted_opponent_id = ?)
        LIMIT 1
        FOR UPDATE`,
      [bookingId, req.auth.sub, req.auth.sub],
    );
    const booking = rows[0];
    if (!booking) {
      return await rollbackResponse(404, { error: 'Booking not found.' });
    }
    const matchmakingDownpayment = paymentType === 'matchmaking_downpayment';
    const matchmakingOpponentShare =
      paymentType === 'matchmaking_opponent_share';
    const matchmakingHostBalance =
      paymentType === 'matchmaking_host_balance';
    const eligibleStatus = matchmakingOpponentShare
      ? Number(booking.acceptedOpponentId) === Number(req.auth.sub) &&
        booking.matchmakingStatus === 'matched' &&
        booking.opponentPaymentStatus === 'unpaid'
      : matchmakingHostBalance
      ? Number(booking.customerId) === Number(req.auth.sub) &&
        booking.matchmakingStatus === 'matched' &&
        booking.hostBalancePaymentStatus === 'unpaid' &&
        booking.paymentStatus === 'partial'
      : matchmakingDownpayment
      ? booking.status === 'matchmaking_open' &&
        booking.matchmakingStatus === 'awaiting_host_downpayment'
      : booking.status === 'approved';
    if (
      !eligibleStatus ||
      (!matchmakingOpponentShare && booking.paymentMethod !== 'online')
    ) {
      return await rollbackResponse(409, {
        error: 'Online payment is not available for this booking.',
      });
    }
    if (
      !matchmakingOpponentShare &&
      !matchmakingHostBalance &&
      (!booking.paymentDueAt || !booking.paymentDeadlineActive)
    ) {
      return await rollbackResponse(410, {
        error: 'The 15-minute online payment deadline has expired.',
      });
    }
    if (
      booking.paymentStatus === 'paid' ||
      (matchmakingDownpayment && booking.paymentStatus !== 'unpaid') ||
      (matchmakingOpponentShare && booking.opponentPaymentStatus !== 'unpaid') ||
      (matchmakingHostBalance &&
        (booking.hostBalancePaymentStatus !== 'unpaid' ||
          Number(booking.hostBalanceAmount) <= 0))
    ) {
      return await rollbackResponse(409, {
        error: 'This booking amount has already been paid.',
      });
    }
    const checkoutTarget = matchmakingOpponentShare
      ? {
          sessionId: booking.opponentCheckoutSessionId,
          url: booking.opponentCheckoutUrl,
          method: booking.opponentCheckoutMethod,
          table: 'matchmaking_lobbies',
          sessionColumn: 'opponent_checkout_session_id',
          urlColumn: 'opponent_checkout_url',
          methodColumn: 'opponent_checkout_method',
          idColumn: 'id',
          id: booking.matchmakingLobbyId,
          scope: 'accepted_opponent_id = ? AND status = \'matched\' AND opponent_payment_status = \'unpaid\'',
          ownerId: req.auth.sub,
        }
      : matchmakingHostBalance
      ? {
          sessionId: booking.hostBalanceCheckoutSessionId,
          url: booking.hostBalanceCheckoutUrl,
          method: booking.hostBalanceCheckoutMethod,
          table: 'matchmaking_lobbies',
          sessionColumn: 'host_balance_checkout_session_id',
          urlColumn: 'host_balance_checkout_url',
          methodColumn: 'host_balance_checkout_method',
          idColumn: 'id',
          id: booking.matchmakingLobbyId,
          scope: 'host_user_id = ? AND status = \'matched\' AND host_balance_payment_status = \'unpaid\'',
          ownerId: req.auth.sub,
        }
      : {
          sessionId: booking.paymentCheckoutSessionId,
          url: booking.paymentCheckoutUrl,
          method: booking.paymentCheckoutMethod,
          table: 'bookings',
          sessionColumn: 'payment_checkout_session_id',
          urlColumn: 'payment_checkout_url',
          methodColumn: 'payment_checkout_method',
          idColumn: 'id',
          id: booking.id,
          scope: 'customer_id = ? AND status = ? AND payment_method = \'online\' AND payment_status <> \'paid\' AND payment_due_at > CURRENT_TIMESTAMP',
          ownerId: req.auth.sub,
          bookingStatus: matchmakingDownpayment ? 'matchmaking_open' : 'approved',
        };
    const isSafeCheckoutUrl = (value) => {
      if (typeof value !== 'string' || value.trim().length === 0) return false;
      try {
        const parsed = new URL(value);
        return parsed.protocol === 'https:' &&
          parsed.origin === 'https://checkout.paymongo.com' &&
          parsed.username === '' &&
          parsed.password === '';
      } catch {
        return false;
      }
    };
    const persistCheckout = async (
      sessionId,
      checkoutUrl,
      method,
      expectedSessionId = null,
    ) => {
      const ownerParams = checkoutTarget.table === 'bookings'
        ? [checkoutTarget.ownerId, checkoutTarget.bookingStatus]
        : [checkoutTarget.ownerId];
      const sessionPredicate = expectedSessionId
        ? `${checkoutTarget.sessionColumn} = ?`
        : `${checkoutTarget.sessionColumn} IS NULL`;
      const [update] = await connection.execute(
        `UPDATE ${checkoutTarget.table}
            SET ${checkoutTarget.sessionColumn} = ?,
                ${checkoutTarget.urlColumn} = ?,
                ${checkoutTarget.methodColumn} = ?
          WHERE ${checkoutTarget.idColumn} = ?
            AND ${sessionPredicate}
            AND ${checkoutTarget.scope}`,
        [
          sessionId,
          checkoutUrl,
          method,
          checkoutTarget.id,
          ...(expectedSessionId ? [expectedSessionId] : []),
          ...ownerParams,
        ],
      );
      return update.affectedRows > 0;
    };
    const existingSessionId =
      typeof checkoutTarget.sessionId === 'string'
        ? checkoutTarget.sessionId.trim()
        : '';
    if (existingSessionId) {
      let existingUrl = checkoutTarget.url;
      let existingMethod = checkoutTarget.method;
      if (!isSafeCheckoutUrl(existingUrl)) {
        const existingResponse = await fetch(
          `https://api.paymongo.com/v1/checkout_sessions/${encodeURIComponent(existingSessionId)}`,
          {
            method: 'GET',
            headers: {
              Authorization: `Basic ${Buffer.from(`${process.env.PAYMONGO_SECRET_KEY}:`).toString('base64')}`,
              Accept: 'application/json',
            },
            signal: AbortSignal.timeout(15000),
          },
        );
        const existingPayload = await existingResponse.json();
        if (!existingResponse.ok) {
          return await rollbackResponse(502, {
            error: existingPayload?.errors?.[0]?.detail ||
              'PayMongo could not retrieve the existing checkout.',
          });
        }
        existingUrl = existingPayload?.data?.attributes?.checkout_url;
        const existingMethods =
          existingPayload?.data?.attributes?.payment_method_types;
        if (
          !existingMethod &&
          Array.isArray(existingMethods) &&
          existingMethods.length === 1 &&
          typeof existingMethods[0] === 'string'
        ) {
          existingMethod = existingMethods[0];
        }
        if (!isSafeCheckoutUrl(existingUrl)) {
          return await rollbackResponse(502, {
            error: 'PayMongo returned no valid URL for the existing checkout.',
          });
        }
        if (!await persistCheckout(
          existingSessionId,
          existingUrl,
          existingMethod,
          existingSessionId,
        )) {
          return await rollbackResponse(409, {
            error: 'The existing checkout is no longer available for this booking.',
          });
        }
      }
      if (existingMethod && existingMethod !== paymentMethod) {
        return await rollbackResponse(409, {
          error: `A checkout is already open for ${existingMethod}. Choose that payment method to continue.`,
        });
      }
      await connection.commit();
      transactionActive = false;
      return res.json({ checkoutUrl: existingUrl });
    }
    const checkoutAmount = matchmakingOpponentShare
      ? Number(booking.opponentShareAmount)
      : matchmakingHostBalance
      ? Number(booking.hostBalanceAmount)
      : matchmakingDownpayment
      ? Number(booking.downpaymentAmount)
      : Number(booking.totalAmount);
    const response = await fetch('https://api.paymongo.com/v1/checkout_sessions', {
      method: 'POST',
      headers: {
        Authorization: `Basic ${Buffer.from(`${process.env.PAYMONGO_SECRET_KEY}:`).toString('base64')}`,
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        data: {
          attributes: {
            line_items: [{
              currency: 'PHP',
              amount: Math.round(checkoutAmount * 100),
              name: matchmakingDownpayment
                ? `SpotGo matchmaking downpayment #${booking.id}`
                : matchmakingOpponentShare
                ? `SpotGo matchmaking opponent share #${booking.id}`
                : matchmakingHostBalance
                ? `SpotGo matchmaking host balance #${booking.id}`
                : `SpotGo booking #${booking.id}`,
              quantity: 1,
            }],
            payment_method_types: [paymentMethod],
            success_url: process.env.PAYMONGO_SUCCESS_URL,
            cancel_url: process.env.PAYMONGO_CANCEL_URL,
            description: matchmakingDownpayment
              ? `SpotGo matchmaking downpayment #${booking.id}`
              : matchmakingOpponentShare
              ? `SpotGo matchmaking opponent share #${booking.id}`
              : matchmakingHostBalance
              ? `SpotGo matchmaking host balance #${booking.id}`
              : `SpotGo booking #${booking.id}`,
            reference_number: bookingTransactionId(booking.id),
            metadata: {
              booking_id: String(booking.id),
              transaction_id: bookingTransactionId(booking.id),
              payment_type: paymentType,
              ...(matchmakingOpponentShare || matchmakingHostBalance
                ? { lobby_id: String(booking.matchmakingLobbyId) }
                : {}),
            },
          },
        },
      }),
      signal: AbortSignal.timeout(15000),
    });
    const payload = await response.json();
    if (!response.ok) {
      return await rollbackResponse(502, {
        error: payload?.errors?.[0]?.detail || 'PayMongo could not create checkout.',
      });
    }
    const checkoutSessionId = payload?.data?.id;
    const checkoutUrl = payload?.data?.attributes?.checkout_url;
    if (
      typeof checkoutSessionId !== 'string' ||
      checkoutSessionId.trim().length === 0 ||
      !isSafeCheckoutUrl(checkoutUrl)
    ) {
      return await rollbackResponse(502, {
        error: 'PayMongo returned no valid checkout URL.',
      });
    }
    const checkoutPersisted = await persistCheckout(
      checkoutSessionId,
      checkoutUrl,
      paymentMethod,
    );
    if (!checkoutPersisted) {
      return await rollbackResponse(410, {
        error: matchmakingHostBalance
          ? 'The host balance is no longer payable.'
          : 'The booking payment deadline expired before checkout could start.',
      });
    }
    await connection.commit();
    transactionActive = false;
    return res.json({ checkoutUrl });
  } catch (error) {
    if (transactionActive) {
      try {
        await connection.rollback();
        transactionActive = false;
      } catch (rollbackError) {
        return next(rollbackError);
      }
    }
    return next(error);
  } finally {
    if (connection) connection.release();
  }
});

app.post(
  '/api/bookings/:id/prototype-payment',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    if (process.env.NODE_ENV === 'production') {
      return res.status(503).json({
        error: 'Prototype payments are disabled in production.',
      });
    }
    const bookingId = Number(req.params.id);
    const prototypeProviders = ['gcash', 'maya', 'atome', 'card'];
    if (
      !isNumericInput(req.params.id) ||
      !Number.isSafeInteger(bookingId) ||
      bookingId <= 0 ||
      req.body.paymentMethod !== 'prototype_card' ||
      !prototypeProviders.includes(req.body.provider)
    ) {
      return res.status(400).json({
        error: 'A valid booking and prototype payment method are required.',
      });
    }
    let connection;
    try {
      connection = await pool.getConnection();
      await connection.beginTransaction();
      const [rows] = await connection.execute(
        `SELECT b.id, b.customer_id AS customerId,
                b.venue_id AS venueId, b.total_amount AS totalAmount,
                b.downpayment_amount AS downpaymentAmount,
                b.payment_method AS paymentMethod,
                b.payment_status AS paymentStatus, b.status,
                b.payment_due_at AS paymentDueAt,
                b.payment_due_at > CURRENT_TIMESTAMP AS paymentDeadlineActive,
                v.merchant_id AS merchantId, v.name AS venueName,
                v.business_type AS businessType
         FROM bookings b
         JOIN merchant_businesses v ON v.id = b.venue_id
         WHERE b.id = ? AND b.customer_id = ?
         LIMIT 1 FOR UPDATE`,
        [bookingId, req.auth.sub],
      );
      const booking = rows[0];
      if (!booking) {
        await connection.rollback();
        return res.status(404).json({ error: 'Booking not found.' });
      }
      if (
        booking.status !== 'approved' ||
        !['online', 'cash_on_arrival'].includes(booking.paymentMethod)
      ) {
        await connection.rollback();
        return res.status(409).json({
          error: 'Prototype payment is available only for approved payable bookings.',
        });
      }
      if (booking.paymentStatus === 'paid') {
        await connection.rollback();
        return res.status(409).json({
          error: 'This booking has already been paid.',
        });
      }
      if (!booking.paymentDueAt || Number(booking.paymentDeadlineActive) !== 1) {
        await connection.rollback();
        return res.status(410).json({
          error: 'The 15-minute payment window has expired.',
        });
      }

      const isCashOnArrival = booking.paymentMethod === 'cash_on_arrival';
      const paymentProvider = req.body.provider;
      const amount = isCashOnArrival
        ? Number(booking.downpaymentAmount)
        : Number(booking.totalAmount);
      if (!Number.isFinite(amount) || amount <= 0) {
        await connection.rollback();
        return res.status(409).json({
          error: 'This booking has no valid payment amount due.',
        });
      }
      const paymentReference = `PROTOTYPE-${booking.id}-${Date.now()}`;
      const [paymentUpdate] = await connection.execute(
        `UPDATE bookings
         SET payment_status = ?, paid_amount = ?,
             payment_reference = ?, paid_at = CURRENT_TIMESTAMP
         WHERE id = ? AND customer_id = ? AND status = 'approved'
           AND payment_method IN ('online', 'cash_on_arrival')
           AND payment_status = 'unpaid'
           AND payment_due_at > CURRENT_TIMESTAMP`,
        [
          isCashOnArrival ? 'partial' : 'paid',
          amount,
          paymentReference,
          booking.id,
          req.auth.sub,
        ],
      );
      if (!paymentUpdate.affectedRows) {
        await connection.rollback();
        return res.status(409).json({
          error: 'This booking is no longer eligible for prototype payment.',
        });
      }

      await connection.execute(
        `UPDATE messages m
         JOIN conversations c ON c.id = m.conversation_id
         SET m.attachment_json = JSON_SET(
           m.attachment_json, '$.paymentStatus', ?,
           '$.paidAmount', ?, '$.paymentReference', ?,
           '$.paymentProvider', ?
         )
         WHERE c.title = ? AND c.type = 'direct'
           AND CASE WHEN JSON_VALID(m.attachment_json)
                    THEN JSON_UNQUOTE(JSON_EXTRACT(
                      m.attachment_json, '$.type'
                    )) END = 'booking_ticket'
           AND CASE WHEN JSON_VALID(m.attachment_json)
                    THEN JSON_UNQUOTE(JSON_EXTRACT(
                      m.attachment_json, '$.bookingId'
                    )) END = ?`,
        [
          isCashOnArrival ? 'partial' : 'paid',
          amount,
          paymentReference,
          paymentProvider,
          `Booking ${booking.id}`,
          String(booking.id),
        ],
      );

      const [conversations] = await connection.execute(
        'SELECT id FROM conversations WHERE type = ? AND title = ? LIMIT 1',
        ['direct', `Booking ${booking.id}`],
      );
      let conversationId = conversations[0]?.id;
      if (!conversationId) {
        const [conversation] = await connection.execute(
          'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
          ['direct', `Booking ${booking.id}`, booking.customerId],
        );
        conversationId = conversation.insertId;
        await connection.execute(
          'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?), (?, ?)',
          [
            conversationId,
            booking.customerId,
            conversationId,
            booking.merchantId,
          ],
        );
      }
      const transactionId = bookingTransactionId(booking.id);
      const bookingReference = `BK-${booking.id}`;
      const message =
        `Prototype ${isCashOnArrival ? 'downpayment' : 'payment'} of ₱${amount.toFixed(2)} was recorded for booking #${booking.id} at ${booking.venueName}. ` +
        `This is a test transaction; no real payment was processed. ` +
        `Transaction ID: ${transactionId}. Booking reference: ${bookingReference}.`;
      if (!isCashOnArrival) {
        await connection.execute(
          `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
           VALUES (?, ?, ?, ?)`,
          [
            conversationId,
            booking.customerId,
            message,
            JSON.stringify({
              type: 'booking_payment_ticket',
              bookingId: booking.id,
              transactionId,
              bookingReference,
              venueName: booking.venueName,
              businessType: booking.businessType,
              amount,
              totalAmount: Number(booking.totalAmount),
              payableAmount: amount,
              paymentMethod: booking.paymentMethod,
              paymentStatus: 'paid',
              paymentReference,
              paymentProvider,
              status: 'paid',
            }),
          ],
        );
      }
      for (const userId of [booking.customerId, booking.merchantId]) {
        await recordUserActivity(
          connection,
          userId,
          'booking_payment_received',
          'Prototype payment recorded',
          message,
          {
            venueId: booking.venueId,
            venueName: booking.venueName,
            details: {
              bookingId: booking.id,
              transactionId,
              bookingReference,
              amount,
              paymentReference,
              prototype: true,
            },
          },
          { systemGenerated: true },
        );
      }
      await connection.commit();
      queueBookingNotifications({
        userIds: [booking.customerId, req.auth.sub],
        event: 'payment_updated',
        booking: {
          id: booking.id,
          venueName: booking.venueName,
          paymentStatus: 'paid',
        },
      });
      return res.json({
        received: true,
        prototype: true,
        bookingId: booking.id,
        transactionId,
        bookingReference,
        amount,
        paymentReference,
      });
    } catch (error) {
      if (connection) await connection.rollback();
      return next(error);
    } finally {
      connection?.release();
    }
  },
);

app.post('/api/payments/paymongo/webhook', async (req, res, next) => {
  const webhookSecret = process.env.PAYMONGO_WEBHOOK_SECRET;
  if (!webhookSecret) {
    return res.status(503).json({ error: 'Payment webhook is not configured.' });
  }
  if (
    !hasValidPaymongoSignature(
      req.rawBody,
      req.get('paymongo-signature'),
      req.body?.data?.livemode === true,
      webhookSecret,
    )
  ) {
    return res.status(401).json({ error: 'Invalid payment webhook signature.' });
  }

  const event = req.body?.data;
  if (event?.type !== 'checkout_session.payment.paid') {
    return res.json({ received: true, ignored: true });
  }
  const checkoutSession = event.data;
  const checkoutSessionId = checkoutSession?.id;
  const attributes = checkoutSession?.attributes;
  const payments = Array.isArray(attributes?.payments)
    ? attributes.payments
    : [];
  const paidPayment = payments.find(
    (payment) => payment?.attributes?.status === 'paid',
  );
  if (
    typeof checkoutSessionId !== 'string' ||
    !paidPayment ||
    !Number.isSafeInteger(Number(paidPayment.attributes.amount)) ||
    String(paidPayment.attributes.currency).toUpperCase() !== 'PHP'
  ) {
    return res.status(400).json({ error: 'Paid checkout details are invalid.' });
  }

  if (attributes?.metadata?.payment_type === 'matchmaking_opponent_share') {
    let opponentConnection;
    try {
      opponentConnection = await pool.getConnection();
      await opponentConnection.beginTransaction();
      const [lobbies] = await opponentConnection.execute(
        `SELECT l.id AS lobbyId, l.status,
                l.accepted_opponent_id AS opponentUserId,
                l.opponent_share_amount AS opponentShareAmount,
                l.opponent_payment_status AS opponentPaymentStatus,
                l.host_balance_payment_status AS hostBalancePaymentStatus,
                l.opponent_checkout_session_id AS checkoutSessionId,
                l.booking_id AS bookingId, l.host_user_id AS hostUserId,
                v.merchant_id AS merchantId, v.name AS venueName
         FROM matchmaking_lobbies l
         JOIN merchant_businesses v ON v.id = l.venue_id
         WHERE l.opponent_checkout_session_id = ?
         LIMIT 1 FOR UPDATE`,
        [checkoutSessionId],
      );
      const lobby = lobbies[0];
      if (!lobby) {
        await opponentConnection.rollback();
        return res.status(404).json({
          error: 'Opponent checkout session is not linked to a match.',
        });
      }
      if (
        String(attributes?.metadata?.lobby_id) !== String(lobby.lobbyId) ||
        Number(paidPayment.attributes.amount) !==
          Math.round(Number(lobby.opponentShareAmount) * 100) ||
        String(paidPayment.attributes.currency).toUpperCase() !== 'PHP'
      ) {
        await opponentConnection.rollback();
        return res.status(409).json({
          error: 'Paid checkout does not match the opponent share.',
        });
      }
      if (lobby.opponentPaymentStatus === 'paid') {
        await opponentConnection.commit();
        return res.json({
          received: true,
          duplicate: true,
          lobbyId: Number(lobby.lobbyId),
        });
      }
      if (
        lobby.status !== 'matched' ||
        !['unpaid', 'cash_on_arrival'].includes(
          lobby.opponentPaymentStatus,
        )
      ) {
        await opponentConnection.rollback();
        return res.status(409).json({
          error: 'The opponent share is no longer payable online.',
        });
      }
      const paymentReference =
        paidPayment.id ?? attributes?.payment_intent?.id ?? checkoutSessionId;
      await opponentConnection.execute(
        `UPDATE matchmaking_lobbies
         SET opponent_payment_status = 'paid',
             opponent_payment_reference = ?
         WHERE id = ?
           AND opponent_payment_status IN ('unpaid', 'cash_on_arrival')`,
        [paymentReference, lobby.lobbyId],
      );
      if (lobby.hostBalancePaymentStatus === 'paid') {
        await opponentConnection.execute(
          `UPDATE bookings
           SET payment_status = 'paid', paid_amount = total_amount,
               paid_at = CURRENT_TIMESTAMP
           WHERE id = ? AND payment_status = 'partial'`,
          [lobby.bookingId],
        );
      }
      const [requests] = await opponentConnection.execute(
        `SELECT conversation_id AS conversationId
         FROM matchmaking_requests
         WHERE lobby_id = ? AND opponent_user_id = ?`,
        [lobby.lobbyId, lobby.opponentUserId],
      );
      if (requests[0]?.conversationId) {
        await opponentConnection.execute(
          `UPDATE messages
           SET attachment_json = JSON_SET(
             attachment_json, '$.opponentPaymentStatus', 'paid'
           )
           WHERE conversation_id = ?
             AND JSON_UNQUOTE(JSON_EXTRACT(attachment_json, '$.lobbyId')) = ?
             AND JSON_UNQUOTE(JSON_EXTRACT(attachment_json, '$.applicantId')) = ?`,
          [
            requests[0].conversationId,
            String(lobby.lobbyId),
            String(lobby.opponentUserId),
          ],
        );
      }
      await opponentConnection.commit();
      for (const userId of [
        Number(lobby.opponentUserId),
        Number(lobby.hostUserId),
        Number(lobby.merchantId),
      ]) {
        liveUpdates.publishToUser(userId, {
          type: 'matchmaking.opponent-payment.updated',
          lobbyId: Number(lobby.lobbyId),
          status: 'paid',
        });
        if (requests[0]?.conversationId) {
          liveUpdates.publishToUser(userId, {
            type: 'message.created',
            conversationId: Number(requests[0].conversationId),
          });
        }
      }
      notifyBookingParticipants({
        userIds: [
          Number(lobby.hostUserId),
          Number(lobby.merchantId),
        ],
        event: 'matchmaking_opponent_paid',
        booking: {
          id: Number(lobby.bookingId),
          venueName: lobby.venueName,
          amount: Number(lobby.opponentShareAmount),
        },
      }).catch((error) => {
        console.error('Could not send opponent payment notification.', error);
      });
      return res.json({
        received: true,
        lobbyId: Number(lobby.lobbyId),
        opponentPaymentStatus: 'paid',
      });
    } catch (error) {
      if (opponentConnection) await opponentConnection.rollback();
      return next(error);
    } finally {
      opponentConnection?.release();
    }
  }

  if (attributes?.metadata?.payment_type === 'matchmaking_host_balance') {
    let hostBalanceConnection;
    try {
      hostBalanceConnection = await pool.getConnection();
      await hostBalanceConnection.beginTransaction();
      const [lobbies] = await hostBalanceConnection.execute(
        `SELECT l.id AS lobbyId, l.host_user_id AS hostUserId,
                l.booking_id AS bookingId, l.status,
                l.host_balance_amount AS hostBalanceAmount,
                l.host_balance_payment_status AS hostBalancePaymentStatus,
                l.opponent_payment_status AS opponentPaymentStatus,
                l.host_balance_checkout_session_id AS checkoutSessionId,
                b.total_amount AS totalAmount, b.payment_method AS paymentMethod,
                v.merchant_id AS merchantId, v.name AS venueName
         FROM matchmaking_lobbies l
         JOIN bookings b ON b.id = l.booking_id
         JOIN merchant_businesses v ON v.id = l.venue_id
         WHERE l.host_balance_checkout_session_id = ?
         LIMIT 1 FOR UPDATE`,
        [checkoutSessionId],
      );
      const lobby = lobbies[0];
      if (!lobby) {
        await hostBalanceConnection.rollback();
        return res.status(404).json({
          error: 'Host balance checkout is not linked to a match.',
        });
      }
      if (
        String(attributes?.metadata?.lobby_id) !== String(lobby.lobbyId) ||
        String(attributes?.metadata?.booking_id) !== String(lobby.bookingId) ||
        Number(paidPayment.attributes.amount) !==
          Math.round(Number(lobby.hostBalanceAmount) * 100) ||
        String(paidPayment.attributes.currency).toUpperCase() !== 'PHP'
      ) {
        await hostBalanceConnection.rollback();
        return res.status(409).json({
          error: 'Paid checkout does not match the host balance.',
        });
      }
      if (lobby.hostBalancePaymentStatus === 'paid') {
        await hostBalanceConnection.commit();
        return res.json({
          received: true,
          duplicate: true,
          lobbyId: Number(lobby.lobbyId),
        });
      }
      if (
        lobby.status !== 'matched' ||
        lobby.paymentMethod !== 'online' ||
        lobby.hostBalancePaymentStatus !== 'unpaid'
      ) {
        await hostBalanceConnection.rollback();
        return res.status(409).json({
          error: 'The host balance is no longer payable online.',
        });
      }
      const paymentReference =
        paidPayment.id ?? attributes?.payment_intent?.id ?? checkoutSessionId;
      await hostBalanceConnection.execute(
        `UPDATE matchmaking_lobbies
         SET host_balance_payment_status = 'paid',
             host_balance_payment_reference = ?
         WHERE id = ? AND host_balance_payment_status = 'unpaid'`,
        [paymentReference, lobby.lobbyId],
      );
      const allSharesPaid =
        lobby.opponentPaymentStatus === 'paid' ||
        lobby.opponentPaymentStatus === 'not_required';
      if (allSharesPaid) {
        await hostBalanceConnection.execute(
          `UPDATE bookings
           SET payment_status = 'paid', paid_amount = total_amount,
               paid_at = CURRENT_TIMESTAMP
           WHERE id = ? AND payment_status = 'partial'`,
          [lobby.bookingId],
        );
      }
      await hostBalanceConnection.commit();
      for (const userId of [
        Number(lobby.hostUserId),
        Number(lobby.merchantId),
      ]) {
        liveUpdates.publishToUser(userId, {
          type: 'matchmaking.host-balance-payment.updated',
          lobbyId: Number(lobby.lobbyId),
          status: 'paid',
        });
      }
      return res.json({
        received: true,
        lobbyId: Number(lobby.lobbyId),
        hostBalancePaymentStatus: 'paid',
      });
    } catch (error) {
      if (hostBalanceConnection) await hostBalanceConnection.rollback();
      return next(error);
    } finally {
      hostBalanceConnection?.release();
    }
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [rows] = await connection.execute(
      `SELECT b.id, b.customer_id AS customerId, b.venue_id AS venueId,
              b.booking_date AS bookingDate, b.start_time AS startTime,
              b.duration_hours AS durationHours, b.players,
              b.sport_type AS sportType, b.slot_number AS slotNumber,
              b.slot_numbers_json AS slotNumbers,
              b.event_type AS eventType,
              b.fitness_plan_type AS fitnessPlanType,
              b.fitness_plan_duration_days AS fitnessPlanDurationDays,
              b.fitness_category AS fitnessCategory,
              b.fitness_coach_name AS fitnessCoachName,
              b.fitness_coach_duration_months AS fitnessCoachDurationMonths,
              b.fitness_plan_price AS fitnessPlanPrice,
              b.fitness_coach_price AS fitnessCoachPrice,
              b.occupies_full_studio AS occupiesFullStudio,
              b.total_amount AS totalAmount, b.payment_method AS paymentMethod,
              b.downpayment_amount AS downpaymentAmount,
              b.paid_amount AS paidAmount,
              b.payment_status AS paymentStatus,
              b.payment_refund_status AS paymentRefundStatus,
              b.payment_refund_id AS paymentRefundId, b.status,
              b.payment_due_at AS paymentDueAt,
              b.payment_timeout_minutes AS paymentTimeoutMinutes,
              b.payment_expired_at AS paymentExpiredAt,
              CASE WHEN b.status = 'approved'
                        AND b.payment_due_at <= CURRENT_TIMESTAMP
                       OR b.status = 'matchmaking_open'
                        AND b.payment_due_at <= CURRENT_TIMESTAMP
                   THEN 1 ELSE 0 END AS paymentDeadlineExpired,
              l.status AS matchmakingStatus,
              l.id AS matchmakingLobbyId,
              l.host_user_id AS hostUserId,
              l.host_share_amount AS matchmakingHostShareAmount,
              v.business_type AS businessType,
              v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType,
              v.merchant_id AS merchantId
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       LEFT JOIN matchmaking_lobbies l ON l.booking_id = b.id
       WHERE b.payment_checkout_session_id = ? LIMIT 1 FOR UPDATE`,
      [checkoutSessionId],
    );
    const booking = rows[0];
    if (!booking) {
      await connection.rollback();
      return res.status(404).json({ error: 'Checkout session is not linked to a booking.' });
    }
    booking.slotNumbers = bookingSlotNumbers(
      booking.slotNumbers,
      booking.slotNumber,
    );
    const expectedBookingId = String(booking.id);
    const transactionId = bookingTransactionId(booking.id);
    const metadataBookingId = attributes?.metadata?.booking_id;
    const referenceNumber = attributes?.reference_number;
    const metadataTransactionId = attributes?.metadata?.transaction_id;
    if (
      (metadataBookingId != null &&
        String(metadataBookingId) !== expectedBookingId) ||
      (metadataTransactionId != null &&
        String(metadataTransactionId) !== transactionId) ||
      (referenceNumber != null &&
        referenceNumber !== transactionId &&
        referenceNumber !== `BOOKING-${expectedBookingId}`)
    ) {
      await connection.rollback();
      return res.status(400).json({ error: 'Checkout does not match its booking.' });
    }
    const matchmakingDownpayment =
      attributes?.metadata?.payment_type === 'matchmaking_downpayment';
    const expectedPaymentAmount = matchmakingDownpayment
      ? Number(booking.downpaymentAmount)
      : Number(booking.totalAmount);
    const paymentStatusEligible = matchmakingDownpayment
      ? ['matchmaking_open', 'cancelled'].includes(booking.status) &&
        ['awaiting_host_downpayment', 'expired'].includes(
          booking.matchmakingStatus,
        )
      : ['pending', 'approved', 'cancelled'].includes(booking.status) &&
        attributes?.metadata?.payment_type === 'full';
    if (
      booking.paymentMethod !== 'online' ||
      !paymentStatusEligible ||
      Number(paidPayment.attributes.amount) !== Math.round(expectedPaymentAmount * 100)
    ) {
      await connection.rollback();
      return res.status(409).json({ error: 'Paid checkout does not match the booking.' });
    }
    if (
      booking.paymentStatus === 'paid' ||
      (matchmakingDownpayment && booking.paymentStatus === 'partial')
    ) {
      await connection.commit();
      const paymentRefundStatus =
        booking.status === 'cancelled' &&
        booking.paymentRefundStatus === 'pending' &&
        !booking.paymentRefundId
          ? await requestPaymongoBookingRefund(booking)
          : booking.paymentRefundStatus;
      return res.json({
        received: true,
        duplicate: true,
        bookingId: booking.id,
        transactionId,
        paymentRefundStatus,
      });
    }

    const nextPaymentStatus = matchmakingDownpayment ? 'partial' : 'paid';
    const paymentDeadlineExpired =
      Number(booking.paymentDeadlineExpired) === 1 ||
      Boolean(booking.paymentExpiredAt);
    const bookingWasCancelled =
      booking.status === 'cancelled' || paymentDeadlineExpired;
    const paymentReference = paidPayment.id ?? attributes?.payment_intent?.id ?? checkoutSessionId;
    await connection.execute(
      `UPDATE bookings
       SET payment_status = ?, paid_amount = ?, payment_reference = ?,
           paid_at = CURRENT_TIMESTAMP,
           status = CASE WHEN ? = 1 THEN 'cancelled' ELSE status END,
           payment_expired_at = CASE
             WHEN ? = 1 THEN CURRENT_TIMESTAMP
             ELSE payment_expired_at
           END,
           payment_refund_status = CASE
             WHEN ? = 1 THEN 'pending'
             ELSE payment_refund_status
           END
       WHERE id = ? AND payment_status <> 'paid'`,
      [
        nextPaymentStatus,
        expectedPaymentAmount,
        paymentReference,
        paymentDeadlineExpired ? 1 : 0,
        paymentDeadlineExpired ? 1 : 0,
        paymentDeadlineExpired ? 1 : 0,
        booking.id,
      ],
    );
    let matchmakingPublished = false;
    if (matchmakingDownpayment) {
      const [lobbyUpdate] = await connection.execute(
        `UPDATE matchmaking_lobbies
         SET status = CASE WHEN ? = 1 THEN 'expired' ELSE 'open' END
         WHERE booking_id = ?
           AND status IN ('awaiting_host_downpayment', 'expired')`,
        [paymentDeadlineExpired ? 1 : 0, booking.id],
      );
      matchmakingPublished =
        !paymentDeadlineExpired && Number(lobbyUpdate.affectedRows) > 0;
    }
    const [conversations] = await connection.execute(
      'SELECT id FROM conversations WHERE type = ? AND title = ? LIMIT 1',
      ['direct', `Booking ${booking.id}`],
    );
    let conversationId = conversations[0]?.id;
    if (!conversationId) {
      const [conversation] = await connection.execute(
        'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
        ['direct', `Booking ${booking.id}`, booking.customerId],
      );
      conversationId = conversation.insertId;
      await connection.execute(
        'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?), (?, ?)',
        [
          conversationId,
          booking.customerId,
          conversationId,
          booking.merchantId,
        ],
      );
    }
    if (paymentDeadlineExpired) {
      const expiredMessage =
        `The reservation at ${booking.venueName} expired because payment was not received within ${formatBookingDeadlineDuration(Number(booking.paymentTimeoutMinutes))} after approval. ` +
        `A late payment arrived, so its refund is being processed. ` +
        `Transaction ID: ${transactionId}. Booking reference: BK-${booking.id}.`;
      await connection.execute(
        `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
         VALUES (?, ?, ?, ?)`,
        [
          conversationId,
          booking.merchantId,
          expiredMessage,
          JSON.stringify({
            type: 'booking_ticket',
            bookingId: booking.id,
            transactionId,
            bookingReference: `BK-${booking.id}`,
            venueName: booking.venueName,
            amount: expectedPaymentAmount,
            payableAmount: expectedPaymentAmount,
            paymentDueAt: booking.paymentDueAt,
            paymentExpiredAt: new Date().toISOString(),
            status: 'payment_expired',
            approvalStatus: 'payment_expired',
            paymentMethod: 'online',
            paymentStatus: 'unpaid',
          }),
        ],
      );
      await recordUserActivity(
        connection,
        booking.customerId,
        'booking_payment_expired',
        'Booking payment expired',
        expiredMessage,
        {
          venueId: booking.venueId,
          venueName: booking.venueName,
          details: {
            bookingId: booking.id,
            transactionId,
            bookingReference: `BK-${booking.id}`,
          },
        },
        { systemGenerated: true },
      );
      await recordUserActivity(
        connection,
        booking.merchantId,
        'booking_payment_expired',
        'Booking payment expired',
        expiredMessage,
        {
          venueId: booking.venueId,
          venueName: booking.venueName,
          details: {
            bookingId: booking.id,
            transactionId,
            bookingReference: `BK-${booking.id}`,
          },
        },
        { systemGenerated: true },
      );
    }
    const ticketDetails = {
      type: 'booking_payment_ticket',
      bookingId: booking.id,
      transactionId,
      businessType: booking.businessType,
      eventType: booking.eventType,
      status: 'payment_received',
      approvalStatus: bookingWasCancelled ? 'cancelled' : 'approved',
      venueName: booking.venueName,
      sportType: booking.sportType,
      fitnessPlanType: booking.fitnessPlanType,
      fitnessCategory: booking.fitnessCategory,
      fitnessCoachName: booking.fitnessCoachName,
      fitnessCoachDurationMonths: booking.fitnessCoachDurationMonths,
      fitnessPlanPrice: booking.fitnessPlanPrice,
      fitnessCoachPrice: booking.fitnessCoachPrice,
      slotNumber: booking.slotNumber,
      slotNumbers: booking.slotNumbers,
      fullStudio: Number(booking.occupiesFullStudio) === 1,
      bookingDate: booking.bookingDate,
      startTime: booking.startTime,
      durationHours: booking.durationHours,
      players: booking.players,
      amount: expectedPaymentAmount,
      payableAmount: expectedPaymentAmount,
      paymentDueAt: booking.paymentDueAt,
      totalAmount: Number(booking.totalAmount),
      downpaymentAmount: Number(booking.downpaymentAmount),
      paidAmount: expectedPaymentAmount,
      paymentStatus: nextPaymentStatus,
      remainingBalance: Math.max(0, Number(booking.totalAmount) - expectedPaymentAmount),
      paymentReference,
      checkoutSessionId,
    };
    await connection.execute(
      `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
       VALUES (?, ?, ?, ?)`,
      [
        conversationId,
        booking.merchantId,
        bookingWasCancelled
          ? `Payment received for cancelled booking #${booking.id}. The applicable cancellation refund is being processed separately.`
          : `Payment received for booking #${booking.id}. The booking is approved.`,
        JSON.stringify(ticketDetails),
      ],
    );
    await recordUserActivity(
      connection,
      booking.customerId,
      'booking_paid',
      'Payment received',
      bookingWasCancelled
        ? `Payment received for cancelled booking #${booking.id} at ${booking.venueName}. The applicable cancellation refund is being processed separately.`
        : `Payment received for booking #${booking.id} at ${booking.venueName}.`,
      {
        venueId: booking.venueId,
        venueName: booking.venueName,
        sportType: booking.sportType,
        details: {
          bookingId: booking.id,
          transactionId,
          bookingDate: booking.bookingDate,
          startTime: booking.startTime,
          durationHours: booking.durationHours,
          players: booking.players,
          amount: expectedPaymentAmount,
          paymentReference,
        },
      },
    );
    await connection.commit();
    if (matchmakingDownpayment && !paymentDeadlineExpired) {
      liveUpdates.publishToUser(Number(booking.customerId), {
        type: 'matchmaking.lobby.published',
        lobbyId: Number(booking.matchmakingLobbyId),
      });
      notifyBookingParticipants({
        userIds: [booking.customerId],
        event: 'matchmaking_published',
        booking: {
          id: booking.id,
          venueName: booking.venueName,
        },
      }).catch((error) => {
        console.error('Could not send match publication notification.', error);
      });
    }
    if (matchmakingPublished) {
      notifyMatchDiscovery({
        lobbyId: booking.matchmakingLobbyId,
        hostUserId: booking.hostUserId,
        bookingId: booking.id,
        venueName: booking.venueName,
        sportType: booking.sportType,
        matchDate: booking.bookingDate,
        startTime: booking.startTime,
      }).catch((error) => {
        console.error('Could not send public match discovery alerts.', error);
      });
    }
    queueBookingNotifications({
      userIds: [booking.customerId, booking.merchantId],
      event: 'payment_updated',
      booking: {
        id: booking.id,
        venueName: booking.venueName,
        paymentStatus: nextPaymentStatus,
      },
    });
    const paymentRefundStatus =
      bookingWasCancelled &&
      (booking.paymentRefundStatus === 'pending' ||
        paymentDeadlineExpired) &&
      !booking.paymentRefundId
        ? await requestPaymongoBookingRefund({
            ...booking,
            paymentReference,
            paidAmount: expectedPaymentAmount,
          })
        : booking.paymentRefundStatus;
    return res.json({
      received: true,
      bookingId: booking.id,
      transactionId,
      paymentRefundStatus,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});
}

module.exports = { registerPaymentRoutes };
