function registerMerchantBusinessWriteRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  positiveIntegerId,
  validateBusinessPayload,
  invalidateCustomerBusinesses,
  recordUserActivity,
  parseBusinessCoordinates,
  normalizeSportsSlots,
  fitnessDetailsFromBody,
  saveEventDetails,
  saveFitnessDetails,
}) {
app.delete('/api/merchant/businesses/:id', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const id = positiveIntegerId(req.params.id);
  if (id === null) {
    return res.status(400).json({ error: 'Invalid business id.' });
  }
  try {
    const [result] = await pool.execute(
      'DELETE FROM merchant_businesses WHERE id = ? AND merchant_id = ?',
      [id, req.auth.sub],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Business not found.' });
    }
    invalidateCustomerBusinesses();
    await recordUserActivity(
      pool,
      req.auth.sub,
      'business_deleted',
      'Business deleted',
      `Business #${id} was deleted.`,
      { details: { businessId: id } },
    );
    return res.json({ message: 'Business deleted.' });
  } catch (error) {
    return next(error);
  }
});

app.put('/api/merchant/businesses/:id/status', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const id = positiveIntegerId(req.params.id);
  if (id === null || typeof req.body.enabled !== 'boolean') {
    return res.status(400).json({ error: 'Invalid business status.' });
  }
  try {
    const [result] = await pool.execute(
      'UPDATE merchant_businesses SET enabled = ? WHERE id = ? AND merchant_id = ?',
      [req.body.enabled ? 1 : 0, id, req.auth.sub],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Business not found.' });
    }
    invalidateCustomerBusinesses();
    await recordUserActivity(
      pool,
      req.auth.sub,
      req.body.enabled ? 'business_enabled' : 'business_disabled',
      req.body.enabled ? 'Business enabled' : 'Business disabled',
      `Business #${id} was ${req.body.enabled ? 'enabled' : 'disabled'}.`,
      { details: { businessId: id, enabled: req.body.enabled } },
    );
    return res.json({ message: req.body.enabled ? 'Business enabled.' : 'Business disabled.' });
  } catch (error) {
    return next(error);
  }
});

app.put(
  '/api/merchant/businesses/:id/matchmaking',
  requireAuth,
  requireRole('merchant'),
  async (req, res, next) => {
    const id = positiveIntegerId(req.params.id);
    if (id === null || typeof req.body.allowMatchmaking !== 'boolean') {
      return res.status(400).json({ error: 'Invalid matchmaking setting.' });
    }
    try {
      const [businesses] = await pool.execute(
        `SELECT business_type AS businessType
         FROM merchant_businesses
         WHERE id = ? AND merchant_id = ?
         LIMIT 1`,
        [id, req.auth.sub],
      );
      if (businesses.length === 0) {
        return res.status(404).json({ error: 'Business not found.' });
      }
      if (businesses[0].businessType !== 'Sports') {
        return res.status(400).json({
          error: 'Matchmaking is only available for sports venues.',
        });
      }
      await pool.execute(
        `UPDATE merchant_businesses
         SET allow_matchmaking = ?
         WHERE id = ? AND merchant_id = ?`,
        [req.body.allowMatchmaking ? 1 : 0, id, req.auth.sub],
      );
      invalidateCustomerBusinesses();
      await recordUserActivity(
        pool,
        req.auth.sub,
        'business_matchmaking_updated',
        'Venue matchmaking updated',
        `Matchmaking was ${req.body.allowMatchmaking ? 'enabled' : 'disabled'} for business #${id}.`,
        { details: { businessId: id, allowMatchmaking: req.body.allowMatchmaking } },
      );
      return res.json({
        message: 'Matchmaking setting updated.',
        allowMatchmaking: req.body.allowMatchmaking,
      });
    } catch (error) {
      return next(error);
    }
  },
);

app.put('/api/merchant/businesses/:id/images', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const id = positiveIntegerId(req.params.id);
  const imageUrls = req.body.imageUrls;
  if (
    id === null ||
    !Array.isArray(imageUrls) ||
    imageUrls.length === 0 ||
    imageUrls.length > 20 ||
    imageUrls.some((image) =>
      typeof image !== 'string' ||
      image.trim().length === 0 ||
      image.length > 10 * 1024 * 1024
    )
  ) {
    return res.status(400).json({ error: 'A valid business id and venue images are required.' });
  }
  const normalizedImages = imageUrls.map((image) => image.trim());
  try {
    const [result] = await pool.execute(
      `UPDATE merchant_businesses
       SET image_url = ?, image_urls = ?
       WHERE id = ? AND merchant_id = ?`,
      [
        normalizedImages[0],
        JSON.stringify(normalizedImages),
        id,
        req.auth.sub,
      ],
    );
    if (!result.affectedRows) {
      return res.status(404).json({ error: 'Business not found.' });
    }
    invalidateCustomerBusinesses();
    await recordUserActivity(
      pool,
      req.auth.sub,
      'business_image_updated',
      'Business image updated',
      `Images for business #${id} were updated.`,
      { details: { businessId: id } },
    );
    return res.json({ message: 'Business images updated.' });
  } catch (error) {
    return next(error);
  }
});

app.put('/api/merchant/businesses/:id', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const id = positiveIntegerId(req.params.id);
  if (id === null) {
    return res.status(400).json({ error: 'Invalid business id.' });
  }
  const payloadErrors = validateBusinessPayload(req.body);
  if (payloadErrors.length > 0) {
    return res.status(400).json({
      error: `Please correct the business fields: ${payloadErrors.join(', ')}.`,
      validationErrors: payloadErrors,
    });
  }
  const text = (value, max = 255) =>
    typeof value === 'string' ? value.trim().slice(0, max) : '';
  const businessType = text(req.body.businessType, 50);
  const name = text(req.body.name);
  const category = text(req.body.category, 100);
  const address = text(req.body.address, 500);
  const facilityType = text(req.body.facilityType, 50);
  const hours = text(req.body.hours, 100);
  const visitUrl = text(req.body.visitUrl, 1000);
  const coordinates = parseBusinessCoordinates(req.body);
  const availability = text(req.body.availability, 255) || 'Any';
  const hasBusinessLogo = Object.hasOwn(req.body, 'businessLogoUrl');
  const businessLogoUrl = text(req.body.businessLogoUrl, 10 * 1024 * 1024) || null;
  const hasMatchmakingSetting = typeof req.body.allowMatchmaking === 'boolean';
  const allowMatchmaking =
    businessType === 'Sports' && req.body.allowMatchmaking === false ? 0 : 1;
  const pricePerHour = Number(req.body.pricePerHour);
  const eventFee = Number(req.body.eventFee);
  const includedPlayers = Number(req.body.includedPlayers ?? 0);
  const additionalPlayerFee = Number(req.body.additionalPlayerFee ?? 0);
  const slotCount = Number(req.body.slotCount ?? 1);
  const sportsSlots = req.body.sportsSlots === undefined
    ? null : normalizeSportsSlots(req.body.sportsSlots, slotCount);
  const ratePeriods = Array.isArray(req.body.ratePeriods)
    ? req.body.ratePeriods.slice(0, 20)
    : [];
  const fitnessDetails = fitnessDetailsFromBody(req.body);
  const tags = Array.isArray(req.body.tags)
    ? req.body.tags.filter((item) => typeof item === 'string').slice(0, 20)
    : [];
  const imageUrls = Array.isArray(req.body.imageUrls)
    ? req.body.imageUrls
        .filter((item) => typeof item === 'string')
        .map((item) => item.trim())
        .filter(Boolean)
        .slice(0, 20)
    : [];
  const imageUrl = text(req.body.imageUrl, 10 * 1024 * 1024) || imageUrls[0] || '';
  const hasVenueImage = Boolean(imageUrl.trim()) ||
    imageUrls.some((item) => item.trim().length > 0);
  const valid =
    coordinates.valid &&
    ['Sports', 'Event', 'Fitness & Wellness'].includes(businessType) &&
    name && category && address && facilityType && hours &&
    (businessType === 'Event'
      ? Number.isFinite(eventFee) && eventFee > 0
      : Number.isFinite(pricePerHour) &&
        (pricePerHour > 0 || ratePeriods.length > 0)) &&
    Number.isInteger(includedPlayers) &&
    includedPlayers >= 0 &&
    includedPlayers <= 30 &&
    Number.isFinite(additionalPlayerFee) &&
    additionalPlayerFee >= 0 &&
    additionalPlayerFee <= 99999999.99 &&
    (additionalPlayerFee === 0 ||
      (businessType === 'Sports' && includedPlayers > 0)) &&
    (businessType !== 'Sports' || req.body.sportsSlots === undefined ||
      sportsSlots !== null) &&
    (req.body.allowMatchmaking === undefined ||
      typeof req.body.allowMatchmaking === 'boolean') &&
    hasVenueImage &&
    fitnessDetails.valid;
  if (!valid) {
    return res.status(400).json({ error: 'Please check the business details.' });
  }
  try {
    const [result] = await pool.execute(
      `UPDATE merchant_businesses
       SET business_type = ?, name = ?, category = ?, address = ?, facility_type = ?,
           price_per_hour = ?, event_fee = ?, opening_hours = ?, availability = ?,
           rate_periods = ?, amenities_json = ?, details = ?,
           business_logo_url = IF(?, ?, business_logo_url), image_url = ?,
           image_urls = ?, visit_url = ?, included_players = ?,
           additional_player_fee = ?, slot_count = ?, sports_slots_json = ?,
           allow_matchmaking = IF(?, ?, allow_matchmaking),
           latitude = IF(?, ?, latitude), longitude = IF(?, ?, longitude)
       WHERE id = ? AND merchant_id = ?`,
      [
        businessType, name, category, address, facilityType,
        businessType === 'Event' ? eventFee : pricePerHour,
        businessType === 'Event' ? eventFee : 0,
        hours, availability, JSON.stringify(ratePeriods), JSON.stringify(tags),
        text(req.body.details, 1000) || null,
        hasBusinessLogo, businessLogoUrl, imageUrl || null,
        JSON.stringify(imageUrls), visitUrl || null,
        businessType === 'Sports' ? includedPlayers : 0,
        businessType === 'Sports' ? additionalPlayerFee : 0,
        businessType === 'Sports' ? slotCount : 1,
        businessType === 'Sports' && sportsSlots
          ? JSON.stringify(sportsSlots) : null,
        hasMatchmakingSetting, allowMatchmaking,
        coordinates.provided, coordinates.latitude,
        coordinates.provided, coordinates.longitude,
        id, req.auth.sub,
      ],
    );
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Business not found.' });
    }
    invalidateCustomerBusinesses();
    await saveEventDetails(pool, id, req.body);
    await saveFitnessDetails(pool, id, req.body, fitnessDetails);
    await recordUserActivity(
      pool,
      req.auth.sub,
      'business_updated',
      'Business updated',
      `${businessType} business "${name}" was updated.`,
      {
        venueId: id,
        venueName: name,
        sportType: category,
        details: { businessId: id, businessType },
      },
    );
    return res.json({ message: 'Business updated.' });
  } catch (error) {
    return next(error);
  }
});

app.post('/api/merchant/businesses', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const payloadErrors = validateBusinessPayload(req.body);
  if (payloadErrors.length > 0) {
    return res.status(400).json({
      error: `Please correct the business fields: ${payloadErrors.join(', ')}.`,
      validationErrors: payloadErrors,
    });
  }
  const text = (value, max = 255) =>
    typeof value === 'string' ? value.trim().slice(0, max) : '';
  const businessType = text(req.body.businessType, 50);
  const name = text(req.body.name);
  const category = text(req.body.category, 100);
  const address = text(req.body.address, 500);
  const visitUrl = text(req.body.visitUrl, 1000);
  const coordinates = parseBusinessCoordinates(req.body);
  const facilityType = text(req.body.facilityType, 50);
  const pricePerHour = Number(req.body.pricePerHour);
  const eventFee = Number(req.body.eventFee);
  const includedPlayers = Number(req.body.includedPlayers ?? 0);
  const additionalPlayerFee = Number(req.body.additionalPlayerFee ?? 0);
  const slotCount = Number(req.body.slotCount ?? 1);
  const sportsSlots = req.body.sportsSlots === undefined
    ? null : normalizeSportsSlots(req.body.sportsSlots, slotCount);
  const hours = text(req.body.hours, 100);
  const availability = text(req.body.availability, 255);
  const allowMatchmaking =
    businessType === 'Sports' && req.body.allowMatchmaking === false ? 0 : 1;
  const ratePeriods = Array.isArray(req.body.ratePeriods)
    ? req.body.ratePeriods
        .filter(
          (item) =>
            item &&
            typeof item === 'object' &&
            typeof item.start === 'string' &&
            typeof item.end === 'string' &&
            Number.isFinite(Number(item.pricePerHour)) &&
            Number(item.pricePerHour) > 0,
        )
        .slice(0, 20)
        .map((item) => ({
          start: text(item.start, 20),
          end: text(item.end, 20),
          pricePerHour: Number(item.pricePerHour),
        }))
    : [];
  const fitnessDetails = fitnessDetailsFromBody(req.body);
  const amenities = Array.isArray(req.body.tags)
    ? req.body.tags.filter((item) => typeof item === 'string').slice(0, 20)
    : [];
  const details = text(req.body.details, 1000);
  const businessLogoUrl = text(req.body.businessLogoUrl, 10 * 1024 * 1024);
  const imageUrl = text(req.body.imageUrl, 10 * 1024 * 1024);
  const imageUrls = Array.isArray(req.body.imageUrls)
    ? req.body.imageUrls
        .filter((item) => typeof item === 'string')
        .map((item) => item.trim())
        .filter(Boolean)
        .slice(0, 20)
    : imageUrl ? [imageUrl] : [];
  const primaryImageUrl = imageUrl || imageUrls[0] || '';
  const allowedBusinessTypes = new Set([
    'Sports',
    'Event',
    'Fitness & Wellness',
  ]);
  const validationErrors = [];
  if (!coordinates.valid) validationErrors.push('map location');
  if (!allowedBusinessTypes.has(businessType)) {
    validationErrors.push('booking type');
  }
  if (!name) validationErrors.push('business name');
  if (!category) validationErrors.push('category');
  if (!address) validationErrors.push('address');
  if (!facilityType) validationErrors.push('facility type');
  if (!primaryImageUrl.trim()) validationErrors.push('venue image');
  if (!hours) validationErrors.push('opening and closing hours');
  if (visitUrl && !/^https?:\/\/\S+$/i.test(visitUrl)) validationErrors.push('visit link');
  const amountIsValid = businessType === 'Event'
    ? Number.isFinite(eventFee) && eventFee > 0
    : Number.isFinite(pricePerHour) &&
      (pricePerHour > 0 || ratePeriods.length > 0);
  if (!amountIsValid) {
    validationErrors.push(
      businessType === 'Event'
        ? 'event fee'
        : ratePeriods.length > 0 ? 'rate periods' : 'price per hour',
    );
  }
  if (
    !Number.isInteger(includedPlayers) ||
    includedPlayers < 0 ||
    includedPlayers > 30 ||
    !Number.isFinite(additionalPlayerFee) ||
    additionalPlayerFee < 0 ||
    additionalPlayerFee > 99999999.99 ||
    (additionalPlayerFee > 0 &&
      (businessType !== 'Sports' || includedPlayers < 1))
  ) {
    validationErrors.push('extra-player fee settings');
  }
  if (businessType === 'Sports' && req.body.sportsSlots !== undefined &&
      sportsSlots === null) {
    validationErrors.push('sport slot and pricing settings');
  }
  if (
    req.body.allowMatchmaking !== undefined &&
    typeof req.body.allowMatchmaking !== 'boolean'
  ) {
    validationErrors.push('matchmaking setting');
  }
  if (!fitnessDetails.valid) {
    validationErrors.push('fitness category pricing and coach settings');
  }
  if (validationErrors.length > 0) {
    return res.status(400).json({
      error: `Please check: ${validationErrors.join(', ')}.`,
      validationErrors,
    });

  }
  try {
    const [merchants] = await pool.execute(
      'SELECT id FROM users WHERE id = ? AND role = \'merchant\' LIMIT 1',
      [req.auth.sub],
    );
    if (merchants.length === 0) {
      return res.status(403).json({ error: 'Only merchant accounts can add businesses.' });
    }
    const [result] = await pool.execute(
      `INSERT INTO merchant_businesses
       (merchant_id, business_type, name, category, address, facility_type,
        price_per_hour, event_fee, opening_hours, availability, rate_periods,
        amenities_json, details, business_logo_url, image_url, image_urls, visit_url,
        included_players, additional_player_fee, slot_count, sports_slots_json,
        latitude, longitude, allow_matchmaking)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)` ,
      [
        req.auth.sub,
        businessType,
        name,
        category,
        address,
        facilityType,
        businessType === 'Event' ? eventFee : pricePerHour,
        businessType === 'Event' ? eventFee : 0,
        hours,
        availability || 'Any',
        ratePeriods.length > 0 ? JSON.stringify(ratePeriods) : null,
        JSON.stringify(amenities),
        details || null,
        businessLogoUrl || null,
        primaryImageUrl || null,
        JSON.stringify(imageUrls),
        visitUrl || null,
        businessType === 'Sports' ? includedPlayers : 0,
        businessType === 'Sports' ? additionalPlayerFee : 0,
        businessType === 'Sports' ? slotCount : 1,
        businessType === 'Sports' && sportsSlots
          ? JSON.stringify(sportsSlots) : null,
        coordinates.latitude,
        coordinates.longitude,
        allowMatchmaking,
      ],
    );
    invalidateCustomerBusinesses();
    await saveEventDetails(pool, result.insertId, req.body);
    await saveFitnessDetails(pool, result.insertId, req.body, fitnessDetails);
    await recordUserActivity(
      pool,
      req.auth.sub,
      'business_created',
      'Business created',
      `${businessType} business "${name}" was created.`,
      {
        venueId: result.insertId,
        venueName: name,
        sportType: category,
        details: { businessId: result.insertId, businessType },
      },
    );
    return res.status(201).json({ message: 'Business added.' });
  } catch (error) {
    return next(error);
  }
});
}

module.exports = { registerMerchantBusinessWriteRoutes };
