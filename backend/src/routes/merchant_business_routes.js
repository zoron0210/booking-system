function registerMerchantBusinessRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  parseJsonArray,
  readCache,
  customerBusinessesCacheKey,
  customerBusinessesCacheTtlMs,
}) {
app.get('/api/merchant/businesses', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const [merchants] = await pool.execute(
      'SELECT id FROM users WHERE id = ? AND role = \'merchant\' LIMIT 1',
      [req.auth.sub],
    );
    if (merchants.length === 0) {
      return res.status(403).json({ error: 'Only merchant accounts can access businesses.' });
    }
    const [businesses] = await pool.execute(
      `SELECT b.id, b.business_type AS businessType, b.name, b.category, b.address,
              b.latitude AS latitude, b.longitude AS longitude,
              u.first_name AS ownerFirstName, u.last_name AS ownerLastName,
              CONCAT_WS(' ', u.first_name, u.last_name) AS ownerName,
              b.facility_type AS facilityType, b.price_per_hour AS pricePerHour,
              b.event_fee AS eventFee,
              b.included_players AS includedPlayers,
              b.additional_player_fee AS additionalPlayerFee,
              b.slot_count AS slotCount,
              b.sports_slots_json AS sportsSlots,
              b.visit_url AS visitUrl,
              b.opening_hours AS hours, b.availability,
              b.enabled,
              b.rate_periods AS ratePeriods,
              e.event_types_json AS eventTypes, e.attendance_min AS attendanceMin,
              e.attendance_max AS attendanceMax,
              e.accessibility_needs AS accessibilityNeeds,
              e.parking_needs AS parkingNeeds, e.security_needs AS securityNeeds,
              f.fitness_categories_json AS fitnessCategories,
              f.fitness_coaches_json AS fitnessCoaches,
              COALESCE((SELECT AVG(r.rating) FROM venue_reviews r
                        WHERE r.business_id = b.id), 0) AS averageRating,
              (SELECT COUNT(*) FROM venue_reviews r
               WHERE r.business_id = b.id) AS reviewCount,
              (SELECT COUNT(DISTINCT r.customer_id) FROM venue_reviews r
               WHERE r.business_id = b.id) AS ratingUserCount,
              (SELECT COUNT(*) FROM bookings bk
               WHERE bk.venue_id = b.id
                 AND bk.status IN ('finished', 'completed', 'done')) AS visitCount,
              EXISTS (
                SELECT 1 FROM merchant_news n
                WHERE n.business_id = b.id
                  AND n.status = 'published'
                  AND NULLIF(TRIM(n.title), '') IS NOT NULL
                  AND NULLIF(TRIM(n.body), '') IS NOT NULL
                  AND COALESCE(NULLIF(TRIM(n.image_url), ''),
                               NULLIF(TRIM(b.image_url), '')) IS NOT NULL
              ) AS hasPublishedNewsCard,
              b.amenities_json AS tags, b.details,
              b.business_logo_url AS businessLogoUrl,
              b.image_url AS imageUrl,
              b.image_urls AS imageUrls,
              b.allow_matchmaking AS allowMatchmaking,
              b.created_at AS createdAt
       FROM merchant_businesses b
       JOIN users u ON u.id = b.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = b.id
       LEFT JOIN fitness_business_details f ON f.business_id = b.id
       WHERE b.merchant_id = ? AND u.role = 'merchant'
       ORDER BY b.created_at DESC`,
      [req.auth.sub],
    );
    for (const business of businesses) {
      for (const field of [
        'eventTypes',
        'accessibilityNeeds',
        'parkingNeeds',
        'securityNeeds',
        'fitnessCategories',
        'fitnessCoaches',
      ]) {
        business[field] = parseJsonArray(business[field], field);
      }
      business.sportsSlots = parseJsonArray(business.sportsSlots, 'sportsSlots');
      business.imageUrls = parseJsonArray(business.imageUrls, 'imageUrls');
      if (business.imageUrls.length === 0 && business.imageUrl) {
        try {
          const legacyImages = JSON.parse(business.imageUrl);
          if (Array.isArray(legacyImages)) {
            business.imageUrls = legacyImages.filter(
              (image) => typeof image === 'string' && image.length > 0,
            );
          }
        } catch {}
      }
      if (business.imageUrls.length === 0 && business.imageUrl) {
        business.imageUrls = [business.imageUrl];
      }
      if (business.imageUrls.length > 0) business.imageUrl = business.imageUrls[0];
    }
    return res.json({ businesses });
  } catch (error) {
    return next(error);
  }
});

app.get('/api/businesses', async (req, res, next) => {
  try {
    const businesses = await readCache.getOrLoad(
      customerBusinessesCacheKey,
      customerBusinessesCacheTtlMs,
      async () => {
        const [businesses] = await pool.execute(
          `SELECT b.id, b.business_type AS businessType, b.name, b.category, b.address,
              b.latitude AS latitude, b.longitude AS longitude,
              CONCAT_WS(' ', u.first_name, u.last_name) AS ownerName,
              u.first_name AS ownerFirstName, u.last_name AS ownerLastName,
              u.email AS ownerEmail, u.phone AS ownerPhone,
              u.avatar_url AS ownerAvatarUrl,
              b.facility_type AS facilityType, b.price_per_hour AS pricePerHour,
              b.event_fee AS eventFee,
              b.included_players AS includedPlayers,
              b.additional_player_fee AS additionalPlayerFee,
              b.slot_count AS slotCount,
              b.sports_slots_json AS sportsSlots,
              b.visit_url AS visitUrl,
              b.opening_hours AS hours, b.availability, b.enabled,
              b.rate_periods AS ratePeriods,
              e.event_types_json AS eventTypes, e.attendance_min AS attendanceMin,
              e.attendance_max AS attendanceMax,
              e.accessibility_needs AS accessibilityNeeds,
              e.parking_needs AS parkingNeeds, e.security_needs AS securityNeeds,
              f.fitness_categories_json AS fitnessCategories,
              f.fitness_coaches_json AS fitnessCoaches,
              COALESCE((SELECT AVG(r.rating) FROM venue_reviews r
                        WHERE r.business_id = b.id), 0) AS averageRating,
              (SELECT COUNT(*) FROM venue_reviews r
               WHERE r.business_id = b.id) AS reviewCount,
              (SELECT COUNT(DISTINCT r.customer_id) FROM venue_reviews r
               WHERE r.business_id = b.id) AS ratingUserCount,
              (SELECT COUNT(*) FROM venue_hearts h
               WHERE h.business_id = b.id) AS heartCount,
              (SELECT COUNT(*) FROM bookings bk
               WHERE bk.venue_id = b.id
                 AND bk.status IN ('finished', 'completed', 'done')) AS visitCount,
              b.amenities_json AS tags, b.details,
              b.business_logo_url AS businessLogoUrl,
              b.image_url AS imageUrl,
              b.image_urls AS imageUrls,
              b.created_at AS createdAt
       FROM merchant_businesses b
       JOIN users u ON u.id = b.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = b.id
       LEFT JOIN fitness_business_details f ON f.business_id = b.id
       WHERE (b.enabled = 1 OR b.business_type = 'Event')
         AND u.status = 'active'
         AND (
           b.business_type = 'Event'
           OR EXISTS (
           SELECT 1 FROM merchant_news n
           WHERE n.business_id = b.id
             AND n.status = 'published'
             AND NULLIF(TRIM(n.title), '') IS NOT NULL
             AND NULLIF(TRIM(n.body), '') IS NOT NULL
             AND COALESCE(NULLIF(TRIM(n.image_url), ''),
                          NULLIF(TRIM(b.image_url), '')) IS NOT NULL
           )
         )
       ORDER BY b.created_at DESC`,
        );
        for (const business of businesses) {
          for (const field of [
            'eventTypes',
            'accessibilityNeeds',
            'parkingNeeds',
            'securityNeeds',
            'fitnessCategories',
            'fitnessCoaches',
          ]) {
            business[field] = parseJsonArray(business[field], field);
          }
          for (const field of ['ratePeriods', 'tags']) {
            business[field] = parseJsonArray(business[field], field);
          }
          business.sportsSlots = parseJsonArray(
            business.sportsSlots,
            'sportsSlots',
          );
          business.imageUrls = parseJsonArray(business.imageUrls, 'imageUrls');
          if (business.imageUrls.length === 0 && business.imageUrl) {
            try {
              const legacyImages = JSON.parse(business.imageUrl);
              if (Array.isArray(legacyImages)) {
                business.imageUrls = legacyImages.filter(
                  (image) => typeof image === 'string' && image.length > 0,
                );
              }
            } catch {}
          }
          if (business.imageUrls.length === 0 && business.imageUrl) {
            business.imageUrls = [business.imageUrl];
          }
          if (business.imageUrls.length > 0) {
            business.imageUrl = business.imageUrls[0];
          }
        }
        return businesses;
      },
    );
    return res.json({ businesses });
  } catch (error) {
    return next(error);
  }
});


}

module.exports = { registerMerchantBusinessRoutes };
