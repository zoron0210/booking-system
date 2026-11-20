function registerBookingRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  positiveIntegerId,
  bookingCheckInWindowIncludesNow,
  bookingSlotNumbers,
  bookingStartsAtLeastSixHoursAway,
  bookingTransactionId,
  configuredSportsSlots,
  createBookingToken,
  dateOnly,
  fitnessAvailabilityIncludesDate,
  fitnessPlanDurationDays,
  fitnessPlanEndDate,
  formatBookingDeadlineDuration,
  hashBookingToken,
  isNumericInput,
  manilaDateTime,
  normalizeBusinessType,
  parseJsonArray,
  processBookingApprovalDeadlines,
  processBookingPaymentDeadlines,
  DEFAULT_BOOKING_DEADLINE_MINUTES,
  queueBookingNotifications,
  recordUserActivity,
  requestPaymongoBookingRefund,
  validCalendarDate,
  validDate,
  validTime,
  venueCheckInCode,
  venueHours,
  verifyVenueCheckInCode,
  liveUpdates,
  notifyBookingParticipants,
  notifyMatchDiscovery,
  crypto,
}) {
app.post('/api/bookings', requireAuth, requireRole('customer'), async (req, res, next) => {
  const venueId = Number(req.body.venueId ?? req.body.businessId);
  const bookingDate = req.body.date;
  let startTime = req.body.startTime;
  let durationHours = Number(req.body.durationHours ?? req.body.duration);
  const players = Number(req.body.players);
  const paymentMethod = typeof req.body.paymentMethod === 'string'
    ? req.body.paymentMethod.trim().slice(0, 50) : '';
  const sportType = typeof req.body.sportType === 'string'
    ? req.body.sportType.trim().slice(0, 100) : '';
  const fitnessPlanType = typeof req.body.fitnessPlanType === 'string'
    ? req.body.fitnessPlanType.trim().toLowerCase() : '';
  const fitnessCoachName = typeof req.body.fitnessCoachName === 'string'
    ? req.body.fitnessCoachName.trim().slice(0, 100) : '';
  const fitnessCoachDurationMonths =
    req.body.fitnessCoachDurationMonths === undefined
      ? fitnessCoachName
        ? fitnessPlanType === 'yearly' ? 12 : 1
        : 0
      : Number(req.body.fitnessCoachDurationMonths);
  const requestedEventType = typeof req.body.eventType === 'string'
    ? req.body.eventType.trim().slice(0, 100) : '';
  const requestedSlot = Number(req.body.slotNumber);
  const hasRequestedSlots = req.body.slotNumbers !== undefined;
  const requestedSlots = hasRequestedSlots && Array.isArray(req.body.slotNumbers)
    ? req.body.slotNumbers.map(Number)
    : [requestedSlot];
  const invalidRequestedSlots = hasRequestedSlots &&
    (!Array.isArray(req.body.slotNumbers) ||
      req.body.slotNumbers.length < 1 ||
      req.body.slotNumbers.length > 100 ||
      req.body.slotNumbers.some((slot) =>
        !isNumericInput(slot) ||
        !Number.isSafeInteger(Number(slot)) ||
        Number(slot) < 1,
      ) ||
      new Set(requestedSlots).size !== requestedSlots.length);
  const allowedPaymentMethods = new Set(['online', 'cash_on_arrival']);
  const optionalTextFields = [
    ['sportType', 100],
    ['fitnessPlanType', 50],
    ['fitnessCoachName', 100],
    ['eventType', 100],
  ];
  const invalidOptionalText = optionalTextFields.some(([field, maxLength]) =>
    req.body[field] !== undefined &&
    (typeof req.body[field] !== 'string' ||
      req.body[field].length > maxLength),
  );
  if (!isNumericInput(req.body.venueId ?? req.body.businessId) ||
      !isNumericInput(req.body.durationHours ?? req.body.duration) ||
      !isNumericInput(req.body.players) ||
      (req.body.slotNumber !== undefined &&
        !isNumericInput(req.body.slotNumber)) ||
      invalidRequestedSlots ||
        (req.body.fitnessCoachDurationMonths !== undefined &&
          (!isNumericInput(req.body.fitnessCoachDurationMonths) ||
            !Number.isSafeInteger(fitnessCoachDurationMonths) ||
            fitnessCoachDurationMonths < 0 ||
            fitnessCoachDurationMonths > 4294967295)) ||
        !Number.isSafeInteger(venueId) || venueId <= 0 || !validDate(bookingDate) ||
      !validTime(startTime) || !Number.isFinite(durationHours) ||
      durationHours <= 0 || durationHours > 24 || !Number.isSafeInteger(players) ||
      players <= 0 || players > 1000 || !allowedPaymentMethods.has(paymentMethod) ||
      typeof req.body.paymentMethod !== 'string' ||
      req.body.paymentMethod.length > 50 || invalidOptionalText) {
    return res.status(400).json({
      error: 'Choose Online payment or Cash on Arrival (COA).',
    });
  }
  const idempotencyKey = req.get('Idempotency-Key')?.trim() ?? '';
  if (!/^[A-Za-z0-9._:-]{16,100}$/.test(idempotencyKey)) {
    return res.status(400).json({
      error: 'A valid Idempotency-Key header is required for booking requests.',
    });
  }
  const idempotencyRequestHash = crypto.createHash('sha256')
    .update(JSON.stringify({
      venueId,
      bookingDate,
      startTime,
      durationHours,
      players,
      paymentMethod,
      sportType,
      ...(hasRequestedSlots
        ? { slotNumbers: [...requestedSlots].sort((a, b) => a - b) }
        : {
            slotNumber: Number.isFinite(requestedSlot) ? requestedSlot : null,
          }),
      fitnessPlanType,
      fitnessCoachName,
      fitnessCoachDurationMonths,
      eventType: requestedEventType,
    }))
    .digest('hex');

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [priorRequests] = await connection.execute(
      `SELECT idempotency_request_hash AS requestHash,
              idempotency_response_json AS responseJson,
              idempotency_response_status AS responseStatus
       FROM bookings
       WHERE customer_id = ? AND idempotency_key = ?
       LIMIT 1 FOR UPDATE`,
      [req.auth.sub, idempotencyKey],
    );
    if (priorRequests.length > 0) {
      await connection.rollback();
      return sendBookingIdempotencyReplay(
        res,
        priorRequests[0],
        idempotencyRequestHash,
      );
    }
    const [venues] = await connection.execute(
      `SELECT b.id, b.merchant_id, b.name, b.category, b.business_type AS businessType,
              b.opening_hours AS hours,
              b.price_per_hour, b.event_fee AS eventFee,
              b.slot_count AS slotCount, b.sports_slots_json AS sportsSlots,
              b.included_players, b.additional_player_fee, b.enabled,
              u.status AS merchant_status
       FROM merchant_businesses b JOIN users u ON u.id = b.merchant_id
       WHERE b.id = ? FOR UPDATE`,
      [venueId],
    );
    const venue = venues[0];
    if (!venue || !venue.enabled || venue.merchant_status !== 'active') {
      await connection.rollback();
      return res.status(404).json({ error: 'The venue is unavailable.' });
    }
    const [deadlineSettings] = await connection.execute(
      `SELECT COALESCE(approval_timeout_minutes, ?) AS approvalTimeoutMinutes,
              COALESCE(payment_timeout_minutes, ?) AS paymentTimeoutMinutes
       FROM merchant_profiles
       WHERE user_id = ?
       LIMIT 1`,
      [
        DEFAULT_BOOKING_DEADLINE_MINUTES,
        DEFAULT_BOOKING_DEADLINE_MINUTES,
        venue.merchant_id,
      ],
    );
    const approvalTimeoutMinutes = Number(
      deadlineSettings[0]?.approvalTimeoutMinutes ??
        DEFAULT_BOOKING_DEADLINE_MINUTES,
    );
    const paymentTimeoutMinutes = Number(
      deadlineSettings[0]?.paymentTimeoutMinutes ??
        DEFAULT_BOOKING_DEADLINE_MINUTES,
    );
    const businessType = normalizeBusinessType(String(venue.businessType));
    if (!businessType) {
      await connection.rollback();
      return res.status(400).json({
        error: 'This venue has an unsupported booking category.',
      });
    }
    const isFitness = businessType === 'fitness & wellness';
    const isEvent = businessType === 'event';
    let selectedEventType = null;
    let sportConfig = null;
    let fitnessCategory = null;
    let fitnessCoach = null;
    let fitnessPlanPrice = 0;
    let fitnessCoachPrice = 0;
    let fitnessDurationDays = null;
    let selectedSportType = sportType || venue.category || '';
    let fullStudio = true;
    let slotNumber = null;
    let slotNumbers = [];
    if (isFitness) {
      if (players !== 1) {
        await connection.rollback();
        return res.status(400).json({
          error: 'Fitness first visits must be for one attendee.',
        });
      }
      if (!['session', 'monthly', 'yearly'].includes(fitnessPlanType)) {
        await connection.rollback();
        return res.status(400).json({ error: 'Choose a valid Fitness plan.' });
      }
      if (fitnessPlanType === 'session') {
        const hours = venueHours(venue.hours);
        const startMatch = startTime.match(/^([01]\d|2[0-3]):([0-5]\d)/);
        const startMinutes = startMatch
          ? Number(startMatch[1]) * 60 + Number(startMatch[2])
          : null;
        const fullSessionDuration = hours
          ? (hours.closing - hours.opening) / 60
          : null;
        if (hours === null || fullSessionDuration === null) {
          await connection.rollback();
          return res.status(400).json({
            error: 'This venue must provide valid same-day opening and closing hours before a full-day session can be booked.',
          });
        }
        if (
          startMinutes !== hours.opening ||
          Math.abs(durationHours - fullSessionDuration) > 0.001
        ) {
          await connection.rollback();
          return res.status(400).json({
            error: 'A session plan must reserve the full venue schedule from opening through closing.',
          });
        }
      } else if (durationHours !== 1) {
        await connection.rollback();
        return res.status(400).json({
          error: 'Monthly and yearly Fitness plans reserve a one-hour first visit.',
        });
      }
      const [fitnessRows] = await connection.execute(
        `SELECT fitness_categories_json AS fitnessCategories,
                fitness_coaches_json AS fitnessCoaches
         FROM fitness_business_details WHERE business_id = ?`,
        [venueId],
      );
      const fitnessDetails = fitnessRows[0] || {};
      const fitnessCategories = parseJsonArray(
        fitnessDetails.fitnessCategories,
        'fitnessCategories',
      );
      const fitnessCoaches = parseJsonArray(
        fitnessDetails.fitnessCoaches,
        'fitnessCoaches',
      );
      fitnessCategory = fitnessCategories.find(
        (item) =>
          typeof item.category === 'string' &&
          item.category.toLowerCase() === sportType.toLowerCase(),
      );
      if (!fitnessCategory) {
        await connection.rollback();
        return res.status(400).json({ error: 'Choose a Fitness category offered by this venue.' });
      }
      const priceKey = `${fitnessPlanType}Price`;
      fitnessPlanPrice = Number(fitnessCategory[priceKey]);
      if (!Number.isFinite(fitnessPlanPrice) || fitnessPlanPrice <= 0) {
        await connection.rollback();
        return res.status(400).json({ error: 'The selected Fitness plan is not available.' });
      }
      if (fitnessPlanType === 'yearly') {
        if (fitnessCategory.yearlyDiscountType === 'freeMonths') {
          fitnessPlanPrice = Math.max(
            0,
            fitnessPlanPrice -
              Number(fitnessCategory.monthlyPrice) *
                Number(fitnessCategory.yearlyDiscountValue),
          );
        } else if (fitnessCategory.yearlyDiscountType === 'percentage') {
          fitnessPlanPrice *=
            1 - Number(fitnessCategory.yearlyDiscountValue) / 100;
        }
      }
      fitnessDurationDays = fitnessPlanDurationDays(
        fitnessPlanType,
        fitnessCategory,
      );
      if (fitnessCoachName) {
        if (fitnessCoachDurationMonths < 1) {
          await connection.rollback();
          return res.status(400).json({
            error: 'Coach duration must be at least one month.',
          });
        }
        fitnessCoach = fitnessCoaches.find(
          (item) =>
            typeof item.name === 'string' &&
            item.name.toLowerCase() === fitnessCoachName.toLowerCase(),
        );
        if (!fitnessCoach) {
          await connection.rollback();
          return res.status(400).json({ error: 'Choose a coach offered by this venue.' });
        }
        fitnessCoachPrice =
          Number(fitnessCoach.monthlyPrice) * fitnessCoachDurationMonths;
        if (
          !Number.isFinite(fitnessCoachPrice) ||
          fitnessCoachPrice <= 0 ||
          fitnessCoachPrice > 99999999.99
        ) {
          await connection.rollback();
          return res.status(400).json({
            error: 'The selected coach duration price is unavailable.',
          });
        }
      }
      fitnessPlanPrice = Number(fitnessPlanPrice.toFixed(2));
      fitnessCoachPrice = Number(fitnessCoachPrice.toFixed(2));
      selectedSportType = fitnessCategory.category;
    } else if (isEvent) {
      const [eventRows] = await connection.execute(
        `SELECT event_types_json AS eventTypes,
                attendance_min AS attendanceMin,
                attendance_max AS attendanceMax
         FROM event_business_details WHERE business_id = ?`,
        [venueId],
      );
      const eventDetails = eventRows[0] || {};
      const eventTypes = parseJsonArray(eventDetails.eventTypes, 'eventTypes');
      const configuredEventType = eventTypes.find(
        (item) =>
          typeof item === 'string' &&
          item.toLowerCase() === requestedEventType.toLowerCase(),
      );
      if (!configuredEventType) {
        await connection.rollback();
        return res.status(400).json({
          error: 'Choose an event type offered by this venue.',
        });
      }
      const attendanceMin = Number(eventDetails.attendanceMin ?? 0);
      const attendanceMax = Number(eventDetails.attendanceMax ?? 0);
      if (
        (attendanceMin > 0 && players < attendanceMin) ||
        (attendanceMax > 0 && players > attendanceMax)
      ) {
        await connection.rollback();
        return res.status(400).json({
          error: 'Guest count is outside this venue’s event capacity.',
        });
      }
      const hours = venueHours(venue.hours, { allowMidnightClosing: true });
      if (hours === null) {
        await connection.rollback();
        return res.status(400).json({
          error: 'This venue must provide valid same-day opening and closing hours before an event can be booked.',
        });
      }
      startTime = `${String(Math.floor(hours.opening / 60)).padStart(2, '0')}:` +
        `${String(hours.opening % 60).padStart(2, '0')}:00`;
      durationHours = (hours.closing - hours.opening) / 60;
      selectedEventType = configuredEventType;
      selectedSportType = venue.category || 'Event';
      fullStudio = true;
    } else {
      const sportsSlots = configuredSportsSlots(venue);
      sportConfig = sportsSlots.find(
        (sport) =>
          sport.sportType.toLowerCase() === selectedSportType.toLowerCase(),
      );
      fullStudio = sportConfig?.fullStudio === true;
      slotNumbers = fullStudio ? [] : requestedSlots;
      slotNumber = fullStudio ? null : slotNumbers[0] ?? requestedSlot;
      if (!sportConfig || (!fullStudio &&
          (slotNumbers.length === 0 ||
           slotNumbers.some((slot) =>
             !Number.isSafeInteger(slot) ||
             slot < 1 ||
             slot > Number(sportConfig.slotCount),
           ))) ||
          (fullStudio && requestedSlots.length > 1)) {
        await connection.rollback();
        return res.status(400).json({ error: 'Choose a valid sport and available slot.' });
      }
    }
    const occupancyStatuses = isFitness || isEvent
      ? "status IN ('pending', 'approved')"
      : `status IN (
          'approved', 'matchmaking_pending_merchant', 'matchmaking_open'
        )`;
    const [overlaps] = await connection.execute(
      `SELECT slot_number AS slotNumber,
              slot_numbers_json AS slotNumbers,
              occupies_full_studio AS occupiesFullStudio
       FROM bookings
       WHERE venue_id = ? AND booking_date = ?
         AND ${occupancyStatuses}
         AND start_time < ADDTIME(?, SEC_TO_TIME(? * 3600))
         AND ADDTIME(start_time, SEC_TO_TIME(duration_hours * 3600)) > ?
       FOR UPDATE`,
      [venueId, bookingDate, startTime, durationHours, startTime],
    );
    const hasConflict = overlaps.some((booking) =>
      isEvent ||
      fullStudio ||
      Number(booking.occupiesFullStudio) === 1 ||
      bookingSlotNumbers(booking.slotNumbers, booking.slotNumber)
        .some((slot) => slotNumbers.includes(slot)),
    );
    if (hasConflict) {
      await connection.rollback();
      return res.status(409).json({
        error: isFitness
          ? 'That Fitness session time is already booked.'
          : isEvent
          ? 'That event time is already booked at this venue.'
          : 'That sport slot is already booked for the selected time.',
      });
    }
    const pricePerHour = isFitness
      ? fitnessPlanPrice
      : isEvent
      ? Number(venue.eventFee)
      : Number(sportConfig.pricePerHour);
    if (isEvent && (!Number.isFinite(pricePerHour) || pricePerHour <= 0)) {
      await connection.rollback();
      return res.status(400).json({ error: 'The venue event fee is unavailable.' });
    }
    const includedPlayers = isFitness
      ? 0
      : isEvent
      ? players
      : Number(sportConfig.includedPlayers ?? venue.included_players) *
        (fullStudio ? 1 : slotNumbers.length);
    const additionalPlayerFee = isFitness
      ? 0
      : isEvent
      ? 0
      : Number(sportConfig.additionalPlayerFee ?? venue.additional_player_fee);
    const extraPlayers = Math.max(0, players - includedPlayers);
    const extraPlayerCharge = Number(
      (extraPlayers * additionalPlayerFee).toFixed(2),
    );
    const total = Number(
      (isFitness
        ? fitnessPlanPrice + fitnessCoachPrice
        : isEvent
        ? pricePerHour
        : pricePerHour *
              durationHours *
              (fullStudio ? 1 : slotNumbers.length) +
            extraPlayerCharge
      ).toFixed(2),
    );
    const downpayment = Number(
      (paymentMethod === 'cash_on_arrival' ? total * 0.50 : total).toFixed(2),
    );
    const bookingToken = createBookingToken();
    const [result] = await connection.execute(
      `INSERT INTO bookings
       (customer_id, venue_id, booking_date, start_time, duration_hours, players,
        payment_method, sport_type, slot_number, occupies_full_studio,
        price_per_hour, total_amount, downpayment_amount,
        extra_player_charge, event_type, fitness_plan_type, fitness_category,
        fitness_coach_name, fitness_plan_price, fitness_coach_price,
        fitness_coach_duration_months, fitness_plan_duration_days,
        booking_token_hash, payment_status, idempotency_key,
        idempotency_request_hash, status, slot_numbers_json,
        approval_due_at, approval_timeout_minutes, payment_timeout_minutes)
       VALUES (
         ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
         ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?,
         ?, ?,
         'pending', ?, DATE_ADD(CURRENT_TIMESTAMP, INTERVAL ? MINUTE), ?, ?
       )`,
      [req.auth.sub, venueId, bookingDate, startTime, durationHours, players,
       paymentMethod, selectedSportType, slotNumber, fullStudio ? 1 : 0,
       pricePerHour, total, downpayment, extraPlayerCharge,
       selectedEventType,
       isFitness ? fitnessPlanType : null,
       isFitness ? selectedSportType : null,
       isFitness ? fitnessCoach?.name ?? null : null,
       isFitness ? fitnessPlanPrice : null,
       isFitness ? fitnessCoachPrice : null,
       isFitness && fitnessCoach ? fitnessCoachDurationMonths : null,
       fitnessDurationDays,
       hashBookingToken(bookingToken),
       'unpaid',
       idempotencyKey, idempotencyRequestHash,
       slotNumbers.length > 0 ? JSON.stringify(slotNumbers) : null,
       approvalTimeoutMinutes, approvalTimeoutMinutes, paymentTimeoutMinutes],
    );
    const [conversation] = await connection.execute(
      'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
      ['direct', `Booking ${result.insertId}`, req.auth.sub],
    );
    const conversationId = conversation.insertId;
    await connection.execute(
      'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?), (?, ?)',
      [conversationId, req.auth.sub, conversationId, venue.merchant_id],
    );
    await connection.execute(
      `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
       VALUES (?, ?, ?, ?)`,
      [
        conversationId,
        req.auth.sub,
        `New booking request #${result.insertId} submitted. ` +
          `The request expires if not approved within ${formatBookingDeadlineDuration(approvalTimeoutMinutes)}. ` +
          (paymentMethod === 'online'
            ? `No payment is due while the merchant reviews your request. If approved, pay the full amount of ₱${total.toFixed(2)} online within ${formatBookingDeadlineDuration(paymentTimeoutMinutes)}. `
            : `No payment is due while the merchant reviews your request. If approved, the ₱${downpayment.toFixed(2)} cash downpayment is due within ${formatBookingDeadlineDuration(paymentTimeoutMinutes)}; the remaining ₱${(total - downpayment).toFixed(2)} is due on arrival. `) +
          `Booking token: ${bookingToken}`,
        JSON.stringify({
          type: 'booking',
          bookingId: result.insertId,
          venueName: venue.name,
          transactionId: bookingTransactionId(result.insertId),
          bookingReference: `BK-${result.insertId}`,
          businessType: venue.businessType,
          status: 'pending',
          approvalTimeoutMinutes,
          paymentTimeoutMinutes,
          extraPlayerCharge,
          sportType: selectedSportType,
          eventType: selectedEventType,
          bookingDate,
          startTime,
          durationHours,
          players,
          total,
          downpayment,
          payableAmount: downpayment,
          paymentMethod,
          slotNumber,
          slotNumbers,
          fullStudio,
          includedPlayers,
          additionalPlayerFee,
          ...(isFitness
            ? {
                fitnessPlanType,
                fitnessPlanPrice,
                fitnessCoachName: fitnessCoach?.name ?? null,
                fitnessCoachPrice,
                fitnessCoachDurationMonths: fitnessCoach
                  ? fitnessCoachDurationMonths
                  : null,
              }
            : {}),
          bookingToken,
        }),
      ],
    );
    await recordUserActivity(
      connection,
      req.auth.sub,
      'booking_requested',
      'Booking requested',
      `Booking #${result.insertId} was requested for ${bookingDate}.`,
      {
        venueId,
        venueName: venue.name,
        sportType: selectedSportType,
        details: {
          bookingId: result.insertId,
          transactionId: bookingTransactionId(result.insertId),
          bookingReference: `BK-${result.insertId}`,
          bookingDate,
          startTime,
          durationHours,
          players,
          businessType: venue.businessType,
          eventType: selectedEventType,
          paymentMethod,
          total,
          downpayment,
          payableAmount: downpayment,
          ...(slotNumbers.length > 0 ? { slotNumbers } : {}),
          ...(isFitness
            ? {
                fitnessPlanType,
                fitnessPlanPrice,
                fitnessCoachName: fitnessCoach?.name ?? null,
                fitnessCoachPrice,
                fitnessCoachDurationMonths: fitnessCoach
                  ? fitnessCoachDurationMonths
                  : null,
              }
            : {}),
        },
      },
    );
    const responseBody = {
      booking: { id: result.insertId, transactionId: bookingTransactionId(result.insertId),
        businessType: venue.businessType, venueId, date: bookingDate, startTime,
        durationHours, players, sportType: selectedSportType,
        eventType: selectedEventType,
        slotNumber, slotNumbers, fullStudio, paymentMethod, pricePerHour, total,
        downpayment, payableAmount: downpayment,
        extraPlayers, extraPlayerCharge, includedPlayers,
        additionalPlayerFee, fitnessPlanType: isFitness ? fitnessPlanType : null,
        fitnessCategory: isFitness ? selectedSportType : null,
        fitnessCoachName: isFitness ? fitnessCoach?.name ?? null : null,
        fitnessCoachDurationMonths: isFitness && fitnessCoach
          ? fitnessCoachDurationMonths
          : null,
        fitnessPlanPrice: isFitness ? fitnessPlanPrice : null,
        fitnessCoachPrice: isFitness ? fitnessCoachPrice : null,
        status: 'pending', bookingToken },
    };
    const [idempotencyUpdate] = await connection.execute(
      `UPDATE bookings
       SET idempotency_response_json = ?, idempotency_response_status = 201
       WHERE id = ? AND customer_id = ?`,
      [JSON.stringify(responseBody), result.insertId, req.auth.sub],
    );
    if (idempotencyUpdate.affectedRows !== 1) {
      throw new Error('Could not persist the booking idempotency response.');
    }
    await connection.commit();
    queueBookingNotifications({
      userIds: [req.auth.sub, venue.merchant_id],
      event: 'requested',
      booking: {
        id: result.insertId,
        venueName: venue.name,
        bookingDate,
        startTime,
      },
    });
    return res.status(201).json(responseBody);
  } catch (error) {
    if (connection) await connection.rollback();
    if (
      error.code === 'ER_DUP_ENTRY' &&
      String(error.message ?? '').includes('uq_bookings_customer_idempotency')
    ) {
      const [priorRequests] = await pool.execute(
        `SELECT idempotency_request_hash AS requestHash,
                idempotency_response_json AS responseJson,
                idempotency_response_status AS responseStatus
         FROM bookings
         WHERE customer_id = ? AND idempotency_key = ?
         LIMIT 1`,
        [req.auth.sub, idempotencyKey],
      );
      if (priorRequests.length > 0) {
        return sendBookingIdempotencyReplay(
          res,
          priorRequests[0],
          idempotencyRequestHash,
        );
      }
    }
    return next(error);
  } finally {
    connection?.release();
  }
});

function sendBookingIdempotencyReplay(res, priorRequest, requestHash) {
  if (priorRequest.requestHash !== requestHash) {
    return res.status(409).json({
      error: 'This Idempotency-Key was already used for a different booking request.',
    });
  }
  let responseBody = priorRequest.responseJson;
  if (typeof responseBody === 'string') responseBody = JSON.parse(responseBody);
  if (!responseBody || typeof responseBody !== 'object') {
    throw new Error('Stored booking idempotency response is unavailable.');
  }
  return res.status(Number(priorRequest.responseStatus) || 201).json(responseBody);
}

app.get('/api/bookings', requireAuth, requireRole('customer'), async (req, res, next) => {
  try {
    await pool.execute(
      `UPDATE bookings b
       JOIN (
         SELECT CASE WHEN JSON_VALID(m.attachment_json)
                     THEN CAST(JSON_UNQUOTE(JSON_EXTRACT(
                       m.attachment_json, '$.bookingId'
                     )) AS UNSIGNED) END AS bookingId,
                MAX(m.created_at) AS approvedAt
         FROM messages m
         WHERE CASE WHEN JSON_VALID(m.attachment_json)
                    THEN JSON_UNQUOTE(JSON_EXTRACT(
                      m.attachment_json, '$.type'
                    )) END = 'booking_ticket'
           AND CASE WHEN JSON_VALID(m.attachment_json)
                    THEN JSON_UNQUOTE(JSON_EXTRACT(
                      m.attachment_json, '$.status'
                    )) END IN ('approved', 'confirmed')
         GROUP BY bookingId
       ) approval_ticket ON approval_ticket.bookingId = b.id
       SET b.payment_due_at = DATE_ADD(
         approval_ticket.approvedAt,
         INTERVAL COALESCE(b.payment_timeout_minutes, ?) MINUTE
       )
       WHERE b.customer_id = ? AND b.status = 'approved'
         AND b.payment_method IN ('online', 'cash_on_arrival')
         AND b.payment_status = 'unpaid' AND b.payment_due_at IS NULL`,
      [DEFAULT_BOOKING_DEADLINE_MINUTES, req.auth.sub],
    );
    await processBookingPaymentDeadlines();
    const businessType = req.query.businessType;
    let businessTypeFilter = '';
    const params = [req.auth.sub];
    if (businessType !== undefined) {
      if (typeof businessType !== 'string') {
        return res.status(400).json({ error: 'Invalid business type filter.' });
      }
      const businessTypeValue = normalizeBusinessType(businessType);
      if (!businessTypeValue) {
        return res.status(400).json({ error: 'Invalid business type filter.' });
      }
      const aliases = {
        sports: ['sports', 'sport'],
        event: ['event', 'events'],
        'fitness & wellness': [
          'fitness & wellness',
          'fitness',
          'wellness',
          'fitness wellness',
          'fitness_wellness',
        ],
      }[businessTypeValue];
      businessTypeFilter =
        ` AND LOWER(TRIM(v.business_type)) IN (${aliases.map(() => '?').join(', ')})`;
      params.push(...aliases);
    }
    const [bookings] = await pool.execute(
      `SELECT b.id, b.booking_type AS bookingType,
              ml.id AS matchmakingLobbyId, ml.status AS matchmakingStatus,
              b.venue_id AS venueId, v.name AS venueName, v.address,
              CONCAT_WS(' ', u.first_name, u.last_name) AS ownerName,
              v.business_type AS businessType, v.category, v.facility_type AS facilityType,
              v.opening_hours AS hours, v.availability, v.rate_periods AS ratePeriods,
              e.event_types_json AS eventTypes, e.attendance_min AS attendanceMin,
              e.attendance_max AS attendanceMax,
              e.accessibility_needs AS accessibilityNeeds,
              e.parking_needs AS parkingNeeds, e.security_needs AS securityNeeds,
              f.class_capacity AS classCapacity,
              f.session_duration_minutes AS sessionDurationMinutes,
              f.instructor_name AS instructorName,
              f.class_schedule AS classSchedule,
              v.details, v.visit_url AS visitUrl,
              v.price_per_hour AS venuePricePerHour, v.event_fee AS eventFee,
              v.amenities_json AS amenities,
              v.business_logo_url AS businessLogoUrl,
              v.image_url AS imageUrl, v.image_urls AS imageUrls,
              b.booking_date AS date, b.start_time AS startTime,
              b.duration_hours AS durationHours, b.players, b.payment_method AS paymentMethod,
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
              b.price_per_hour AS pricePerHour, b.total_amount AS total,
              b.extra_player_charge AS extraPlayerCharge,
              b.downpayment_amount AS downpayment,
              b.payment_status AS paymentStatus,
              b.paid_amount AS paidAmount,
              b.payment_refund_status AS paymentRefundStatus,
              b.payment_refund_id AS paymentRefundId,
              b.payment_reference AS paymentReference,
              b.payment_due_at AS paymentDueAt,
              b.payment_timeout_minutes AS paymentTimeoutMinutes,
              b.approval_timeout_minutes AS approvalTimeoutMinutes,
              b.approval_due_at AS approvalExpiresAt,
              b.payment_expired_at AS paymentExpiredAt,
              ci.checked_in_at AS checkedInAt,
              b.status, b.created_at AS createdAt,
              r.id AS reviewId, r.rating AS reviewRating
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       JOIN users u ON u.id = v.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = v.id
       LEFT JOIN fitness_business_details f ON f.business_id = v.id
       LEFT JOIN booking_check_ins ci ON ci.booking_id = b.id
       LEFT JOIN matchmaking_lobbies ml ON ml.booking_id = b.id
       LEFT JOIN venue_reviews r ON r.booking_id = b.id AND r.customer_id = b.customer_id
       WHERE b.customer_id = ?${businessTypeFilter}
       ORDER BY b.booking_date DESC, b.start_time DESC`,
      params,
    );
    for (const booking of bookings) {
      booking.slotNumbers = bookingSlotNumbers(
        booking.slotNumbers,
        booking.slotNumber,
      );
      booking.transactionId = bookingTransactionId(booking.id);
      for (const field of [
        'eventTypes',
        'accessibilityNeeds',
        'parkingNeeds',
        'securityNeeds',
      ]) {
        booking[field] = parseJsonArray(booking[field], field);
      }
      for (const field of ['ratePeriods', 'amenities']) {
        booking[field] = parseJsonArray(booking[field], field);
      }
      booking.imageUrls = parseJsonArray(booking.imageUrls, 'imageUrls');
      if (booking.imageUrls.length === 0 && booking.imageUrl) {
        try {
          const legacyImages = JSON.parse(booking.imageUrl);
          if (Array.isArray(legacyImages)) {
            booking.imageUrls = legacyImages.filter(
              (image) => typeof image === 'string' && image.length > 0,
            );
          }
        } catch {}
      }
      if (booking.imageUrls.length === 0 && booking.imageUrl) {
        booking.imageUrls = [booking.imageUrl];
      }
      if (booking.imageUrls.length > 0) {
        booking.imageUrl = booking.imageUrls[0];
      }
    }
    return res.json({ bookings });
  } catch (error) { return next(error); }
});

app.patch('/api/bookings/:bookingId/cancel', requireAuth, requireRole('customer'), async (req, res, next) => {
  let connection;
  try {
    const bookingId = positiveIntegerId(req.params.bookingId);
    if (bookingId === null) {
      return res.status(400).json({ error: 'Invalid booking ID.' });
    }
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [bookings] = await connection.execute(
      `SELECT b.id, b.booking_type AS bookingType, b.status,
              b.booking_date AS bookingDate, b.start_time AS startTime,
              payment_method AS paymentMethod, payment_status AS paymentStatus,
              paid_amount AS paidAmount, payment_reference AS paymentReference,
              payment_checkout_session_id AS checkoutSessionId,
              v.merchant_id AS merchantId, v.name AS venueName
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND b.customer_id = ?
         AND b.status IN (
           'pending', 'approved',
           'matchmaking_pending_merchant', 'matchmaking_open'
         )
       LIMIT 1 FOR UPDATE`,
      [bookingId, req.auth.sub],
    );
    const booking = bookings[0];
    if (
      !booking ||
      (booking.bookingType === 'matchmaking'
        ? !['matchmaking_pending_merchant', 'matchmaking_open'].includes(booking.status)
        : !['pending', 'approved'].includes(booking.status))
    ) {
      await connection.rollback();
      return res.status(404).json({
        error: 'Booking not found or can no longer be cancelled.',
      });
    }
    const refundEligible = bookingStartsAtLeastSixHoursAway(booking);
    const isOnline = booking.paymentMethod === 'online';
    const hasPayment = Number(booking.paidAmount) > 0;
    let paymentRefundStatus = 'not_requested';
    if (isOnline && refundEligible && (hasPayment || booking.checkoutSessionId)) {
      paymentRefundStatus = 'pending';
    } else if (isOnline && hasPayment) {
      paymentRefundStatus = 'not_eligible';
    } else if (!isOnline && hasPayment) {
      paymentRefundStatus = 'manual_cash_return';
    }
    const [result] = await connection.execute(
      `UPDATE bookings
       SET status = 'cancelled', payment_refund_status = ?
       WHERE id = ? AND customer_id = ? AND status = ?`,
      [paymentRefundStatus, bookingId, req.auth.sub, booking.status],
    );
    if (!result.affectedRows) {
      await connection.rollback();
      return res.status(404).json({
        error: 'Booking not found or can no longer be cancelled.',
      });
    }
    if (booking.bookingType === 'matchmaking') {
      await connection.execute(
        `UPDATE matchmaking_lobbies
         SET status = 'cancelled'
         WHERE booking_id = ?
           AND status IN (
             'pending_merchant_approval', 'awaiting_host_downpayment',
             'open', 'matched'
           )`,
        [bookingId],
      );
      await connection.execute(
        `UPDATE messages
         SET attachment_json = JSON_SET(
           attachment_json, '$.status', 'cancelled'
         )
         WHERE JSON_VALID(attachment_json)
           AND JSON_UNQUOTE(JSON_EXTRACT(
             attachment_json, '$.type'
           )) = 'matchmaking_booking_request_ticket'
           AND JSON_UNQUOTE(JSON_EXTRACT(
             attachment_json, '$.bookingId'
           )) = ?`,
        [String(bookingId)],
      );
    }
    await connection.commit();
    queueBookingNotifications({
      userIds: [req.auth.sub, booking.merchantId],
      event: 'cancelled',
      booking: { id: booking.id, venueName: booking.venueName },
    });

    if (paymentRefundStatus === 'pending' && hasPayment) {
      paymentRefundStatus = await requestPaymongoBookingRefund(booking);
    }
    const message = paymentRefundStatus === 'succeeded'
      ? 'Booking cancelled. The online payment refund was completed.'
      : paymentRefundStatus === 'pending'
      ? 'Booking cancelled. The online payment refund is being processed.'
      : paymentRefundStatus === 'failed'
      ? 'Booking cancelled, but the online payment refund could not be confirmed. Please contact support.'
      : paymentRefundStatus === 'not_eligible'
      ? 'Booking cancelled. It is within 6 hours of the start time or has started, so the online payment was not refunded.'
      : paymentRefundStatus === 'manual_cash_return'
      ? 'Booking cancelled. Cash already collected must be returned manually; it cannot be voided by the app.'
      : 'Booking cancelled.';
    return res.json({ message, status: 'cancelled', paymentRefundStatus });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});

app.delete('/api/bookings/:bookingId', requireAuth, requireRole('customer'), async (req, res, next) => {
  try {
    const [result] = await pool.execute(
      `DELETE FROM bookings
       WHERE id = ? AND customer_id = ?
         AND (
           status = 'finished'
           OR (
             status = 'cancelled'
             AND paid_amount = 0
             AND payment_refund_status <> 'pending'
           )
         )`,
      [req.params.bookingId, req.auth.sub],
    );
    if (!result.affectedRows) {
      return res.status(404).json({
        error: 'Completed or unpaid cancelled booking not found.',
      });
    }
    return res.json({ message: 'Booking permanently deleted.' });
  } catch (error) { return next(error); }
});

async function customerFitnessBookingForAttendance(bookingId, customerId) {
  const [bookings] = await pool.execute(
    `SELECT b.id, b.booking_date AS bookingDate, v.availability,
            b.fitness_plan_type AS fitnessPlanType,
            b.fitness_plan_duration_days AS fitnessPlanDurationDays,
            v.business_type AS businessType
     FROM bookings b
     JOIN merchant_businesses v ON v.id = b.venue_id
     WHERE b.id = ? AND b.customer_id = ?
       AND b.status IN ('approved', 'finished')
     LIMIT 1`,
    [bookingId, customerId],
  );
  const booking = bookings[0];
  if (!booking || String(booking.businessType).trim().toLowerCase() !== 'fitness & wellness') {
    return null;
  }
  return {
    ...booking,
    startDate: dateOnly(booking.bookingDate),
    endDate: fitnessPlanEndDate(
      booking.bookingDate,
      booking.fitnessPlanType,
      booking.fitnessPlanDurationDays,
    ),
  };
}

function validAttendanceDate(booking, date) {
  return validCalendarDate(date) &&
    date >= booking.startDate &&
    date <= booking.endDate;
}

app.get(
  '/api/bookings/:bookingId/attendance',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    try {
      const bookingId = positiveIntegerId(req.params.bookingId);
      if (bookingId === null) {
        return res.status(400).json({ error: 'Invalid booking ID.' });
      }
      const booking = await customerFitnessBookingForAttendance(
        bookingId,
        req.auth.sub,
      );
      if (!booking) return res.status(404).json({ error: 'Fitness booking not found.' });
      const [attendance] = await pool.execute(
        `SELECT DATE_FORMAT(attendance_date, '%Y-%m-%d') AS date, status
         FROM fitness_booking_attendance
         WHERE booking_id = ? AND customer_id = ?
         ORDER BY attendance_date`,
        [bookingId, req.auth.sub],
      );
      return res.json({ attendance });
    } catch (error) { return next(error); }
  },
);

app.put(
  '/api/bookings/:bookingId/attendance/:date',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    try {
      const bookingId = positiveIntegerId(req.params.bookingId);
      const { date, status } = req.params;
      if (bookingId === null) {
        return res.status(400).json({ error: 'Invalid booking ID.' });
      }
      if (!['present', 'absent'].includes(req.body?.status)) {
        return res.status(400).json({ error: 'Attendance status must be present or absent.' });
      }
      const booking = await customerFitnessBookingForAttendance(
        bookingId,
        req.auth.sub,
      );
      if (!booking) return res.status(404).json({ error: 'Fitness booking not found.' });
      if (!validAttendanceDate(booking, date)) {
        return res.status(400).json({ error: 'Attendance date must be within the booking period.' });
      }
      if (!fitnessAvailabilityIncludesDate(booking.availability, date)) {
        return res.status(400).json({ error: 'The fitness venue is closed on this day.' });
      }
      const today = new Date().toISOString().slice(0, 10);
      if (req.body.status === 'present' && date > today) {
        return res.status(400).json({ error: 'Future dates cannot be marked present.' });
      }
      await pool.execute(
        `INSERT INTO fitness_booking_attendance
           (booking_id, customer_id, attendance_date, status)
         VALUES (?, ?, ?, ?)
         ON DUPLICATE KEY UPDATE status = VALUES(status)`,
        [bookingId, req.auth.sub, date, req.body.status],
      );
      return res.json({ attendance: { date, status: req.body.status } });
    } catch (error) { return next(error); }
  },
);

app.delete(
  '/api/bookings/:bookingId/attendance/:date',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    try {
      const bookingId = positiveIntegerId(req.params.bookingId);
      const { date } = req.params;
      if (bookingId === null) {
        return res.status(400).json({ error: 'Invalid booking ID.' });
      }
      const booking = await customerFitnessBookingForAttendance(
        bookingId,
        req.auth.sub,
      );
      if (!booking) return res.status(404).json({ error: 'Fitness booking not found.' });
      if (!validAttendanceDate(booking, date)) {
        return res.status(400).json({ error: 'Attendance date must be within the booking period.' });
      }
      await pool.execute(
        `DELETE FROM fitness_booking_attendance
         WHERE booking_id = ? AND customer_id = ? AND attendance_date = ?`,
        [bookingId, req.auth.sub, date],
      );
      return res.json({ message: 'Attendance cleared.' });
    } catch (error) { return next(error); }
  },
);

app.get(
  '/api/merchant/businesses/:venueId/check-in-code',
  requireAuth,
  requireRole('merchant'),
  async (req, res, next) => {
    try {
      const venueId = positiveIntegerId(req.params.venueId);
      if (venueId === null) {
        return res.status(400).json({ error: 'Invalid venue ID.' });
      }
      const [venues] = await pool.execute(
        `SELECT id, name
         FROM merchant_businesses
         WHERE id = ? AND merchant_id = ?
         LIMIT 1`,
        [venueId, req.auth.sub],
      );
      if (venues.length === 0) {
        return res.status(404).json({ error: 'Venue not found.' });
      }
      const code = venueCheckInCode(venueId);
      return res.json({
        qrCode: JSON.stringify(code),
        expiresAt: code.issuedAt + 120_000,
        venueName: venues[0].name,
      });
    } catch (error) {
      return next(error);
    }
  },
);

app.post(
  '/api/bookings/check-in',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    const code = verifyVenueCheckInCode(req.body?.qrCode);
    if (!code) {
      return res.status(400).json({ error: 'This venue check-in QR code is invalid or expired.' });
    }
    const current = manilaDateTime();
    let connection;
    try {
      connection = await pool.getConnection();
      await connection.beginTransaction();
      const [bookings] = await connection.execute(
        `SELECT b.id AS bookingId, b.booking_date AS date,
                b.start_time AS startTime, b.duration_hours AS durationHours,
                v.name AS venueName
         FROM bookings b
         JOIN merchant_businesses v ON v.id = b.venue_id
         WHERE b.customer_id = ? AND b.venue_id = ?
           AND b.booking_date = ? AND b.status = 'approved'
         ORDER BY b.start_time
         FOR UPDATE`,
        [req.auth.sub, code.venueId, current.date],
      );
      const booking = bookings.find((candidate) =>
        bookingCheckInWindowIncludesNow(candidate, current.minutes),
      );
      if (!booking) {
        await connection.rollback();
        return res.status(409).json({
          error: 'No approved booking at this venue is scheduled for check-in right now.',
        });
      }

      const [existing] = await connection.execute(
        `SELECT DATE_FORMAT(checked_in_at, '%Y-%m-%dT%H:%i:%s') AS checkedInAt
         FROM booking_check_ins
         WHERE booking_id = ? AND customer_id = ?
         LIMIT 1
         FOR UPDATE`,
        [booking.bookingId, req.auth.sub],
      );
      if (existing.length > 0) {
        await connection.commit();
        return res.json({
          checkIn: {
            ...booking,
            checkedInAt: existing[0].checkedInAt,
          },
          alreadyCheckedIn: true,
        });
      }

      await connection.execute(
        `INSERT INTO booking_check_ins (booking_id, customer_id, qr_issued_at)
         VALUES (?, ?, FROM_UNIXTIME(? / 1000))`,
        [booking.bookingId, req.auth.sub, code.issuedAt],
      );
      const [checkIns] = await connection.execute(
        `SELECT DATE_FORMAT(checked_in_at, '%Y-%m-%dT%H:%i:%s') AS checkedInAt
         FROM booking_check_ins
         WHERE booking_id = ? AND customer_id = ?
         LIMIT 1`,
        [booking.bookingId, req.auth.sub],
      );
      await connection.commit();
      return res.status(201).json({
        checkIn: {
          ...booking,
          checkedInAt: checkIns[0]?.checkedInAt ?? null,
        },
        alreadyCheckedIn: false,
      });
    } catch (error) {
      if (connection) await connection.rollback();
      return next(error);
    } finally {
      connection?.release();
    }
  },
);

app.get('/api/merchant/bookings', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    await processBookingApprovalDeadlines();
    await processBookingPaymentDeadlines();
    await completeDueBookings();
    const [bookings] = await pool.execute(
      `SELECT b.id, b.booking_type AS bookingType,
              ml.id AS matchmakingLobbyId, ml.status AS matchmakingStatus,
              b.customer_id AS customerId,
              CONCAT_WS(' ', u.first_name, u.last_name) AS customerName,
              u.avatar_url AS customerAvatarUrl, u.email AS customerEmail,
              b.venue_id AS venueId, v.name AS venueName,
              v.address, v.facility_type AS facilityType, v.details,
              v.business_type AS businessType, b.booking_date AS date,
              b.start_time AS startTime, b.duration_hours AS durationHours, b.players,
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
              b.payment_method AS paymentMethod, b.price_per_hour AS pricePerHour,
              b.extra_player_charge AS extraPlayerCharge,
              b.total_amount AS total, b.downpayment_amount AS downpayment,
              b.payment_status AS paymentStatus,
              b.paid_amount AS paidAmount,
              b.paid_at AS paidAt,
              b.payment_due_at AS paymentDueAt,
              b.payment_timeout_minutes AS paymentTimeoutMinutes,
              b.approval_timeout_minutes AS approvalTimeoutMinutes,
              b.approval_due_at AS approvalExpiresAt,
              b.payment_expired_at AS paymentExpiredAt,
              b.payment_refund_status AS paymentRefundStatus,
              b.payment_refund_id AS paymentRefundId,
              b.payment_reference AS paymentReference,
              ci.checked_in_at AS checkedInAt,
              b.status, b.created_at AS createdAt
       FROM bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       JOIN users u ON u.id = b.customer_id
       LEFT JOIN booking_check_ins ci ON ci.booking_id = b.id
       LEFT JOIN matchmaking_lobbies ml ON ml.booking_id = b.id
       WHERE v.merchant_id = ? ORDER BY b.booking_date, b.start_time`,
      [req.auth.sub],
    );
    for (const booking of bookings) {
      booking.slotNumbers = bookingSlotNumbers(
        booking.slotNumbers,
        booking.slotNumber,
      );
    }
    return res.json({ bookings });
  } catch (error) { return next(error); }
});

app.patch('/api/merchant/bookings/:id/decline', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const reason = typeof req.body?.reason === 'string'
    ? req.body.reason.trim()
    : '';
  if (!reason || reason.length > 1000) {
    return res.status(400).json({
      error: 'Provide a reason of no more than 1000 characters to decline this booking.',
    });
  }

  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const [bookings] = await connection.execute(
      `SELECT b.id, b.customer_id AS customerId, b.venue_id AS venueId,
              b.paid_amount AS paidAmount, v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
       LIMIT 1 FOR UPDATE`,
      [req.params.id, req.auth.sub],
    );
    if (bookings.length === 0) {
      await connection.rollback();
      return res.status(404).json({ error: 'Pending booking not found.' });
    }
    const booking = bookings[0];
    if (Number(booking.paidAmount) > 0) {
      await connection.rollback();
      return res.status(409).json({
        error: 'Return the received payment before declining this booking.',
      });
    }

    const [result] = await connection.execute(
      `UPDATE bookings
       SET status = 'cancelled'
       WHERE id = ? AND status = 'pending' AND paid_amount = 0`,
      [booking.id],
    );
    if (!result.affectedRows) {
      await connection.rollback();
      return res.status(404).json({ error: 'Pending booking not found.' });
    }

    const [conversations] = await connection.execute(
      'SELECT id FROM conversations WHERE type = ? AND title = ? LIMIT 1',
      ['direct', `Booking ${booking.id}`],
    );
    let conversationId = conversations[0]?.id;
    if (!conversationId) {
      const [conversation] = await connection.execute(
        'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
        ['direct', `Booking ${booking.id}`, req.auth.sub],
      );
      conversationId = conversation.insertId;
      await connection.execute(
        'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?), (?, ?)',
        [conversationId, req.auth.sub, conversationId, booking.customerId],
      );
    }
    await connection.execute(
      `UPDATE conversation_members
       SET archived_at = NULL, deleted_at = NULL
       WHERE conversation_id = ?`,
      [conversationId],
    );
    const message = `Your booking request #${booking.id} for ${booking.venueName} was declined.\nReason: ${reason}`;
    await connection.execute(
      `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
       VALUES (?, ?, ?, NULL)`,
      [conversationId, req.auth.sub, message],
    );

    const activityDetails = {
      venueId: booking.venueId,
      venueName: booking.venueName,
      sportType: booking.sportType,
      details: { bookingId: booking.id, reason },
    };
    await recordUserActivity(
      connection,
      req.auth.sub,
      'booking_declined',
      'Booking declined',
      `Booking #${booking.id} for ${booking.venueName} was declined. Reason: ${reason}`,
      activityDetails,
    );
    await recordUserActivity(
      connection,
      booking.customerId,
      'booking_declined',
      'Booking declined',
      message,
      activityDetails,
    );

    await connection.commit();
    queueBookingNotifications({
      userIds: [booking.customerId, req.auth.sub],
      event: 'declined',
      booking: {
        id: booking.id,
        venueName: booking.venueName,
        reason,
      },
    });
    return res.json({ message: 'Booking declined and customer notified.', status: 'cancelled' });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});

app.delete('/api/merchant/bookings/:id', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const [result] = await pool.execute(
      `DELETE b FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'finished'`,
      [req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) {
      return res.status(404).json({ error: 'Completed booking not found.' });
    }
    return res.json({ message: 'Completed booking permanently deleted.' });
  } catch (error) { return next(error); }
});

app.patch('/api/merchant/bookings/:id/payment', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const paymentStatus = req.body?.paymentStatus;
    if (!['partial', 'paid'].includes(paymentStatus)) {
      return res.status(400).json({
        error: 'Record the cash downpayment first, then the remaining balance.',
      });
    }
    const [result] = await pool.execute(
      paymentStatus === 'partial'
        ? `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
           SET b.payment_status = 'partial',
               b.paid_amount = b.downpayment_amount,
               b.paid_at = CURRENT_TIMESTAMP
           WHERE b.id = ? AND v.merchant_id = ?
             AND b.payment_method = 'cash_on_arrival'
             AND b.status IN ('approved', 'finished', 'matchmaking_open')
             AND b.payment_status = 'unpaid'
             AND b.downpayment_amount > 0`
        : `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
           SET b.payment_status = 'paid', b.paid_amount = b.total_amount,
               b.paid_at = CURRENT_TIMESTAMP
           WHERE b.id = ? AND v.merchant_id = ?
             AND b.payment_method = 'cash_on_arrival'
             AND b.status IN ('approved', 'finished', 'matchmaking_open')
             AND b.payment_status = 'partial'`,
      [req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) {
      return res.status(404).json({
        error: 'Cash-on-arrival booking not found.',
      });
    }
    if (paymentStatus === 'partial') {
      const [lobbyUpdate] = await pool.execute(
        `UPDATE matchmaking_lobbies
         SET status = 'open'
         WHERE booking_id = ? AND status = 'awaiting_host_downpayment'`,
        [req.params.id],
      );
      if (Number(lobbyUpdate.affectedRows) > 0) {
        const [publishedLobbies] = await pool.execute(
          `SELECT l.id AS lobbyId, l.host_user_id AS hostUserId,
                  b.id AS bookingId, v.name AS venueName,
                  COALESCE(b.sport_type, v.category) AS sportType,
                  DATE_FORMAT(b.booking_date, '%Y-%m-%d') AS matchDate,
                  TIME_FORMAT(b.start_time, '%H:%i') AS startTime
           FROM matchmaking_lobbies l
           JOIN bookings b ON b.id = l.booking_id
           JOIN merchant_businesses v ON v.id = b.venue_id
           WHERE l.booking_id = ? AND l.status = 'open'
           LIMIT 1`,
          [req.params.id],
        );
        if (publishedLobbies[0]) {
          notifyMatchDiscovery(publishedLobbies[0]).catch((error) => {
            console.error('Could not send public match discovery alerts.', error);
          });
        }
      }
    } else {
      await pool.execute(
        `UPDATE matchmaking_lobbies
         SET host_balance_payment_status = 'paid',
             opponent_payment_status = CASE
               WHEN opponent_payment_status = 'cash_on_arrival'
               THEN 'paid'
               ELSE opponent_payment_status
             END
         WHERE booking_id = ? AND status = 'matched'`,
        [req.params.id],
      );
      await pool.execute(
        `UPDATE messages
         SET attachment_json = JSON_SET(
           attachment_json, '$.opponentPaymentStatus', 'paid'
         )
         WHERE JSON_VALID(attachment_json)
           AND JSON_UNQUOTE(JSON_EXTRACT(
             attachment_json, '$.type'
           )) = 'matchmaking_ticket'
           AND JSON_UNQUOTE(JSON_EXTRACT(
             attachment_json, '$.bookingId'
           )) = ?`,
        [String(req.params.id)],
      );
    }
    const [bookings] = await pool.execute(
      `SELECT b.id, b.customer_id AS customerId, v.merchant_id AS merchantId,
              v.name AS venueName, b.payment_status AS paymentStatus
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND v.merchant_id = ? LIMIT 1`,
      [req.params.id, req.auth.sub],
    );
    const booking = bookings[0];
    if (booking) {
      queueBookingNotifications({
        userIds: [booking.customerId, booking.merchantId],
        event: 'payment_updated',
        booking,
      });
    }
    return res.json({ message: 'Payment status updated.', paymentStatus });
  } catch (error) { return next(error); }
});

app.patch('/api/merchant/bookings/:id/approve', requireAuth, requireRole('merchant'), async (req, res, next) => {
  let connection;
  try {
    connection = await pool.getConnection();
    await connection.beginTransaction();
    const ticketCode = createBookingToken();
    const [pendingRows] = await connection.execute(
      `SELECT b.id, b.customer_id AS customerId, b.venue_id AS venueId,
              b.booking_date AS bookingDate, b.start_time AS startTime,
              b.duration_hours AS durationHours, b.slot_number AS slotNumber,
              b.slot_numbers_json AS slotNumbers,
              b.occupies_full_studio AS occupiesFullStudio,
              b.total_amount AS totalAmount,
              b.downpayment_amount AS downpaymentAmount,
              b.payment_reference AS paymentReference,
              b.payment_method AS paymentMethod,
              b.payment_status AS paymentStatus,
              b.payment_due_at AS paymentDueAt,
              b.payment_timeout_minutes AS paymentTimeoutMinutes,
              v.business_type AS businessType,
              v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType,
              b.event_type AS eventType,
              b.fitness_plan_type AS fitnessPlanType,
              b.fitness_category AS fitnessCategory,
              b.fitness_coach_name AS fitnessCoachName,
              b.fitness_coach_duration_months AS fitnessCoachDurationMonths,
              b.fitness_plan_price AS fitnessPlanPrice,
              b.fitness_coach_price AS fitnessCoachPrice
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
       LIMIT 1 FOR UPDATE`,
      [req.params.id, req.auth.sub],
    );
    if (pendingRows.length === 0) {
      const [expired] = await connection.execute(
        `SELECT b.id, b.customer_id AS customerId, b.venue_id AS venueId,
                v.name AS venueName,
                COALESCE(b.sport_type, v.category) AS sportType,
                b.approval_timeout_minutes AS approvalTimeoutMinutes
         FROM bookings b
         JOIN merchant_businesses v ON v.id = b.venue_id
         WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
           AND COALESCE(b.approval_due_at, DATE_ADD(
             b.created_at,
             INTERVAL COALESCE(b.approval_timeout_minutes, 15) MINUTE
           )) <= CURRENT_TIMESTAMP
         LIMIT 1`,
        [req.params.id, req.auth.sub],
      );
      if (expired.length > 0) {
        const expiredBooking = expired[0];
        const [cancelled] = await connection.execute(
          `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
           SET b.status = 'cancelled'
           WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
           AND COALESCE(b.approval_due_at, DATE_ADD(
             b.created_at,
             INTERVAL COALESCE(b.approval_timeout_minutes, 15) MINUTE
           )) <= CURRENT_TIMESTAMP`,
          [req.params.id, req.auth.sub],
        );
        if (cancelled.affectedRows) {
          await connection.execute(
            `UPDATE messages m
             JOIN conversations c ON c.id = m.conversation_id
             SET m.attachment_json = JSON_SET(
               m.attachment_json, '$.status', 'expired',
               '$.approvalStatus', 'expired'
             )
             WHERE c.title = ? AND c.type = 'direct'
               AND CASE WHEN JSON_VALID(m.attachment_json)
                        THEN JSON_UNQUOTE(JSON_EXTRACT(
                          m.attachment_json, '$.type'
                        )) END = 'booking'
               AND CASE WHEN JSON_VALID(m.attachment_json)
                        THEN JSON_UNQUOTE(JSON_EXTRACT(
                          m.attachment_json, '$.bookingId'
                        )) END = ?`,
            [`Booking ${expiredBooking.id}`, String(expiredBooking.id)],
          );
          const details = {
            venueId: expiredBooking.venueId,
            venueName: expiredBooking.venueName,
            sportType: expiredBooking.sportType,
            details: { bookingId: expiredBooking.id },
          };
          const description =
            `Booking request #${expiredBooking.id} for ${expiredBooking.venueName} expired after ${formatBookingDeadlineDuration(Number(expiredBooking.approvalTimeoutMinutes))} without merchant approval.`;
          for (const userId of [
            expiredBooking.customerId,
            req.auth.sub,
          ]) {
            await recordUserActivity(
              connection,
              userId,
              'booking_auto_cancelled',
              'Booking request expired',
              description,
              details,
              { systemGenerated: true },
            );
          }
          await connection.commit();
          queueBookingNotifications({
            userIds: [expiredBooking.customerId, req.auth.sub],
            event: 'approval_expired',
            booking: {
              id: expiredBooking.id,
              venueName: expiredBooking.venueName,
            },
          });
        } else {
          await connection.rollback();
          return res.status(404).json({
            error: 'Pending booking not found.',
          });
        }
        return res.status(410).json({
          error: 'Booking request expired and can no longer be approved.',
        });
      }
      const [unpaid] = await connection.execute(
        `SELECT b.id FROM bookings b
         JOIN merchant_businesses v ON v.id = b.venue_id
         WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
           AND b.payment_method = 'online' AND b.payment_status <> 'paid'
         LIMIT 1`,
        [req.params.id, req.auth.sub],
      );
      await connection.rollback();
      if (unpaid.length > 0) {
        return res.status(409).json({
          error: 'The booking payment method is not supported.',
        });
      }
      return res.status(404).json({ error: 'Pending booking not found.' });
    }
    const booking = pendingRows[0];
    if (String(booking.businessType) === 'Sports') {
      const requestedSlots = bookingSlotNumbers(
        booking.slotNumbers,
        booking.slotNumber,
      );
      const [conflicts] = await connection.execute(
        `SELECT slot_number AS slotNumber,
                slot_numbers_json AS slotNumbers,
                occupies_full_studio AS occupiesFullStudio
         FROM bookings
         WHERE venue_id = ? AND booking_date = ?
           AND id <> ?
           AND status IN (
             'approved', 'matchmaking_pending_merchant', 'matchmaking_open'
           )
           AND start_time < ADDTIME(?, SEC_TO_TIME(? * 3600))
           AND ADDTIME(start_time, SEC_TO_TIME(duration_hours * 3600)) > ?
         FOR UPDATE`,
        [
          booking.venueId,
          booking.bookingDate,
          booking.id,
          booking.startTime,
          Number(booking.durationHours),
          booking.startTime,
        ],
      );
      const hasConflict = conflicts.some((other) =>
        Number(booking.occupiesFullStudio) === 1 ||
        Number(other.occupiesFullStudio) === 1 ||
        bookingSlotNumbers(other.slotNumbers, other.slotNumber)
          .some((slot) => requestedSlots.includes(slot)),
      );
      if (hasConflict) {
        await connection.rollback();
        return res.status(409).json({
          error: 'That sport slot is already booked for the selected time.',
        });
      }
    }
    const [result] = await connection.execute(
      `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       SET b.status = 'approved',
           b.ticket_token_hash = ?,
           b.payment_due_at = CASE
             WHEN b.payment_status = 'unpaid'
             THEN DATE_ADD(
               CURRENT_TIMESTAMP,
               INTERVAL COALESCE(b.payment_timeout_minutes, 15) MINUTE
             )
             ELSE NULL
           END
       WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'pending'
         AND NOT (
           COALESCE(b.approval_due_at, DATE_ADD(
             b.created_at,
             INTERVAL COALESCE(b.approval_timeout_minutes, 15) MINUTE
           )) <= CURRENT_TIMESTAMP
         )
         AND (
           b.payment_method = 'online'
           OR b.payment_method = 'cash_on_arrival'
         )`,
      [hashBookingToken(ticketCode), booking.id, req.auth.sub],
    );
    if (!result.affectedRows) {
      await connection.rollback();
      return res.status(404).json({ error: 'Pending booking not found.' });
    }
    const payableAmount = booking.paymentMethod === 'online'
      ? Number(booking.totalAmount)
      : Number(booking.downpaymentAmount);
    const requiresPaymentAfterApproval =
      booking.paymentStatus === 'unpaid' && Boolean(booking.paymentDueAt);
    const paymentTimeoutLabel = formatBookingDeadlineDuration(
      Number(booking.paymentTimeoutMinutes),
    );
    const transactionId = bookingTransactionId(booking.id);
    const bookingReference = `BK-${booking.id}`;
    const approvalMessage = requiresPaymentAfterApproval
      ? `Booking #${booking.id} for ${booking.venueName} is approved. Pay ₱${payableAmount.toFixed(2)} ${booking.paymentMethod === 'online' ? 'online' : 'as the cash-on-arrival downpayment'} within ${paymentTimeoutLabel} to keep the reservation active. Transaction ID: ${transactionId}. Booking reference: ${bookingReference}.`
      : booking.paymentMethod === 'cash_on_arrival' &&
          booking.paymentStatus !== 'paid'
      ? `Booking #${booking.id} for ${booking.venueName} is approved. Pay the ₱${payableAmount.toFixed(2)} cash-on-arrival downpayment within ${paymentTimeoutLabel} to keep the reservation active. The remaining ₱${(Number(booking.totalAmount) - payableAmount).toFixed(2)} is due at the venue. Transaction ID: ${transactionId}. Booking reference: ${bookingReference}.`
      : `Booking #${booking.id} for ${booking.venueName} is approved. Transaction ID: ${transactionId}. Booking reference: ${bookingReference}.`;
    booking.slotNumbers = bookingSlotNumbers(
      booking.slotNumbers,
      booking.slotNumber,
    );
    const [existingConversation] = await connection.execute(
      'SELECT id FROM conversations WHERE type = ? AND title = ? LIMIT 1',
      ['direct', `Booking ${booking.id}`],
    );
    let conversationId = existingConversation[0]?.id;
    if (!conversationId) {
      const [conversation] = await connection.execute(
        'INSERT INTO conversations (type, title, created_by) VALUES (?, ?, ?)',
        ['direct', `Booking ${booking.id}`, req.auth.sub],
      );
      conversationId = conversation.insertId;
      await connection.execute(
        'INSERT INTO conversation_members (conversation_id, user_id) VALUES (?, ?), (?, ?)',
        [conversationId, req.auth.sub, conversationId, booking.customerId],
      );
    }
    await connection.execute(
      `INSERT INTO messages (conversation_id, sender_id, body, attachment_json)
       VALUES (?, ?, ?, ?)`,
      [
        conversationId,
        req.auth.sub,
        approvalMessage,
        JSON.stringify({
          type: 'booking_ticket',
          bookingId: booking.id,
          transactionId,
          bookingReference,
          businessType: booking.businessType,
          eventType: booking.eventType,
          status: 'approved',
          ticketCode,
          venueName: booking.venueName,
          sportType: booking.sportType,
          fitnessPlanType: booking.fitnessPlanType,
          fitnessCategory: booking.fitnessCategory,
          fitnessCoachName: booking.fitnessCoachName,
          fitnessPlanPrice: booking.fitnessPlanPrice,
          fitnessCoachPrice: booking.fitnessCoachPrice,
          slotNumber: booking.slotNumber,
          slotNumbers: booking.slotNumbers,
          fullStudio: Number(booking.occupiesFullStudio) === 1,
          bookingDate: booking.bookingDate,
          startTime: booking.startTime,
          durationHours: booking.durationHours,
          players: booking.players,
          amount: booking.totalAmount,
          payableAmount,
          paymentDueAt: booking.paymentDueAt,
          paymentTimeoutMinutes: booking.paymentTimeoutMinutes,
          paymentMethod: booking.paymentMethod,
          paymentStatus: booking.paymentStatus,
          paymentReference: booking.paymentReference,
        }),
      ],
    );
    await recordUserActivity(
      connection,
      req.auth.sub,
      'booking_approved',
      'Booking approved',
      approvalMessage,
      {
        venueId: booking.venueId,
        venueName: booking.venueName,
        sportType: booking.sportType,
        details: {
          bookingId: booking.id,
          transactionId,
          bookingReference,
          paymentMethod: booking.paymentMethod,
          payableAmount,
          paymentDueAt: booking.paymentDueAt,
          bookingDate: booking.bookingDate,
          startTime: booking.startTime,
          durationHours: booking.durationHours,
          players: booking.players,
        },
      },
    );
    await recordUserActivity(
      connection,
      booking.customerId,
      'booking_approved',
      'Booking approved',
      approvalMessage,
      {
        venueId: booking.venueId,
        venueName: booking.venueName,
        sportType: booking.sportType,
        details: {
          bookingId: booking.id,
          bookingDate: booking.bookingDate,
          startTime: booking.startTime,
          durationHours: booking.durationHours,
          players: booking.players,
        },
      },
    );
    await connection.commit();
    queueBookingNotifications({
      userIds: [booking.customerId, req.auth.sub],
      event: 'approved',
      booking: { id: booking.id, venueName: booking.venueName },
    });
    return res.json({
      message: 'Booking approved and ticket issued.',
      status: 'approved',
      transactionId,
      bookingReference,
      payableAmount,
      paymentDueAt: booking.paymentDueAt,
      ticketCode,
    });
  } catch (error) {
    if (connection) await connection.rollback();
    return next(error);
  } finally {
    connection?.release();
  }
});

const dueBookingPredicate = `(
  (
    LOWER(v.business_type) = 'fitness & wellness'
    AND b.fitness_plan_type = 'monthly'
    AND CURRENT_DATE >= DATE_ADD(b.booking_date, INTERVAL 1 MONTH)
  )
  OR (
    LOWER(v.business_type) = 'fitness & wellness'
    AND b.fitness_plan_type = 'yearly'
    AND CURRENT_DATE >= DATE_ADD(b.booking_date, INTERVAL 1 YEAR)
  )
  OR (
    (
      LOWER(v.business_type) = 'fitness & wellness'
      AND b.fitness_plan_type = 'session'
    )
    AND TIMESTAMP(b.booking_date, b.start_time)
        + INTERVAL COALESCE(
            f.session_duration_minutes,
            ROUND(b.duration_hours * 60)
          ) MINUTE <= CURRENT_TIMESTAMP
  )
  OR (
    (
      LOWER(v.business_type) <> 'fitness & wellness'
      OR b.fitness_plan_type IS NULL
    )
    AND TIMESTAMP(b.booking_date, b.start_time)
        + INTERVAL ROUND(b.duration_hours * 60) MINUTE <= CURRENT_TIMESTAMP
  )
)`;

let dueBookingCompletionRunning = false;

async function completeDueBookings() {
  if (dueBookingCompletionRunning) return;
  dueBookingCompletionRunning = true;
  try {
    const [dueBookings] = await pool.execute(
      `SELECT b.id, b.booking_type AS bookingType,
              b.customer_id AS customerId, v.merchant_id AS merchantId,
              b.venue_id AS venueId, v.name AS venueName,
              b.booking_date AS bookingDate, b.start_time AS startTime,
              b.duration_hours AS durationHours,
              COALESCE(b.sport_type, v.category) AS sportType
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       LEFT JOIN fitness_business_details f ON f.business_id = v.id
       WHERE b.status IN ('approved', 'matchmaking_open')
         AND ${dueBookingPredicate}
       ORDER BY b.id`,
    );

    for (const booking of dueBookings) {
      const connection = await pool.getConnection();
      try {
        await connection.beginTransaction();
        const [result] = await connection.execute(
          `UPDATE bookings b
           JOIN merchant_businesses v ON v.id = b.venue_id
           LEFT JOIN fitness_business_details f ON f.business_id = v.id
           SET b.status = 'finished'
           WHERE b.id = ? AND b.status IN ('approved', 'matchmaking_open')
             AND ${dueBookingPredicate}`,
          [booking.id],
        );
        if (!result.affectedRows) {
          await connection.rollback();
          continue;
        }
        if (booking.bookingType === 'matchmaking') {
          await connection.execute(
            `UPDATE matchmaking_lobbies
             SET status = 'completed'
             WHERE booking_id = ?
               AND status IN ('open', 'matched')`,
            [booking.id],
          );
        }
        const description =
          `Booking #${booking.id} for ${booking.venueName} was completed automatically at its scheduled end.`;
        const activityDetails = {
          venueId: booking.venueId,
          venueName: booking.venueName,
          sportType: booking.sportType,
          details: {
            bookingId: booking.id,
            bookingDate: booking.bookingDate,
            startTime: booking.startTime,
            durationHours: booking.durationHours,
          },
        };
        await recordUserActivity(
          connection,
          booking.merchantId,
          'booking_finished',
          'Booking completed automatically',
          description,
          activityDetails,
        );
        await recordUserActivity(
          connection,
          booking.customerId,
          'booking_finished',
          'Booking completed',
          description,
          activityDetails,
        );
        await connection.commit();
      } catch (error) {
        await connection.rollback();
        throw error;
      } finally {
        connection.release();
      }
    }
  } finally {
    dueBookingCompletionRunning = false;
  }
}

app.patch('/api/merchant/bookings/:id/finish', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const [result] = await pool.execute(
      `UPDATE bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       SET b.status = 'finished' WHERE b.id = ? AND v.merchant_id = ? AND b.status = 'approved'`,
      [req.params.id, req.auth.sub],
    );
    if (!result.affectedRows) return res.status(404).json({ error: 'Approved booking not found.' });
    const [bookings] = await pool.execute(
      `SELECT b.customer_id AS customerId, b.venue_id AS venueId,
              b.booking_date AS bookingDate, b.start_time AS startTime,
              b.duration_hours AS durationHours, b.players,
              v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType
       FROM bookings b JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND v.merchant_id = ? LIMIT 1`,
      [req.params.id, req.auth.sub],
    );
    const booking = bookings[0];
    if (booking) {
      await recordUserActivity(
        pool,
        req.auth.sub,
        'booking_finished',
        'Booking marked finished',
        `Booking #${req.params.id} for ${booking.venueName} was marked finished.`,
        {
          venueId: booking.venueId,
          venueName: booking.venueName,
          sportType: booking.sportType,
          details: {
            bookingId: req.params.id,
            bookingDate: booking.bookingDate,
            startTime: booking.startTime,
            durationHours: booking.durationHours,
            players: booking.players,
          },
        },
      );
      await recordUserActivity(
        pool,
        booking.customerId,
        'booking_finished',
        'Booking completed',
        `Booking #${req.params.id} for ${booking.venueName} was marked finished.`,
        {
          venueId: booking.venueId,
          venueName: booking.venueName,
          sportType: booking.sportType,
          details: {
            bookingId: req.params.id,
            bookingDate: booking.bookingDate,
            startTime: booking.startTime,
            durationHours: booking.durationHours,
            players: booking.players,
          },
        },
      );
    }
    return res.json({ message: 'Booking marked finished.', status: 'finished' });
  } catch (error) { return next(error); }
});
  return completeDueBookings;
}

module.exports = { registerBookingRoutes };
