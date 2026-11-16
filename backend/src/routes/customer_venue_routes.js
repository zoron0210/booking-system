function registerCustomerVenueRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  positiveIntegerId,
  normalizeBusinessType,
  normalizeText,
  isNumericInput,
  invalidateCustomerBusinesses,
  recordUserActivity,
  newsPostResponse,
  jwt,
}) {
async function customerNewsFeed(req, res, next) {
  const businessType = req.query.businessType === undefined
    ? null
    : normalizeBusinessType(req.query.businessType);
  if (req.query.businessType !== undefined && !businessType) {
    return res.status(400).json({ error: 'Invalid business type filter.' });
  }
  const businessTypeValues = businessType
    ? {
        sports: ['sports', 'sport'],
        event: ['event', 'events'],
        'fitness & wellness': [
          'fitness & wellness',
          'fitness',
          'wellness',
          'fitness wellness',
          'fitness_wellness',
        ],
      }[businessType]
    : [];
  const businessTypeFilter = businessType
    ? ` AND LOWER(TRIM(b.business_type)) IN (${businessTypeValues.map(() => '?').join(', ')})`
    : '';
  const params = [req.auth.sub, ...businessTypeValues];
  try {
    const [rows] = await pool.execute(
      `SELECT n.*, b.name AS business_name, b.business_type,
              b.category AS business_category, b.address AS business_address,
              b.latitude, b.longitude,
              b.facility_type, b.opening_hours, b.availability,
              b.price_per_hour, b.event_fee, b.rate_periods,
              b.slot_count, b.sports_slots_json,
              b.amenities_json, b.details AS business_details,
              b.image_url AS business_image_url, b.image_urls, b.enabled,
              b.business_logo_url AS business_logo_url,
              b.visit_url, e.event_types_json,
              u.first_name AS merchant_first_name, u.last_name AS merchant_last_name,
              u.email AS merchant_email, u.phone AS merchant_phone,
              u.avatar_url AS merchant_avatar_url,
              COALESCE((SELECT AVG(r.rating) FROM venue_reviews r WHERE r.business_id = b.id), 0) AS average_rating,
              (SELECT COUNT(*) FROM venue_reviews r WHERE r.business_id = b.id) AS review_count,
              (SELECT COUNT(DISTINCT r.customer_id) FROM venue_reviews r WHERE r.business_id = b.id) AS rating_user_count,
              (SELECT COUNT(*) FROM venue_hearts h WHERE h.business_id = b.id) AS heart_count,
              (SELECT COUNT(*) FROM bookings bk
               WHERE bk.venue_id = b.id
                 AND bk.status IN ('finished', 'completed', 'done')) AS visit_count,
              EXISTS(SELECT 1 FROM venue_hearts h
                     WHERE h.business_id = b.id AND h.user_id = ?) AS hearted_by_me
       FROM merchant_news n
       INNER JOIN merchant_businesses b ON b.id = n.business_id
       INNER JOIN users u ON u.id = b.merchant_id
       LEFT JOIN event_business_details e ON e.business_id = b.id
       WHERE n.status = 'published'
         AND n.id = (
           SELECT MAX(latest.id)
           FROM merchant_news latest
           WHERE latest.business_id = n.business_id
             AND latest.status = 'published'
         )
         AND b.enabled = 1
         AND u.status = 'active'
         AND NULLIF(TRIM(n.title), '') IS NOT NULL
         AND NULLIF(TRIM(n.body), '') IS NOT NULL
         AND COALESCE(NULLIF(TRIM(n.image_url), ''),
                      NULLIF(TRIM(b.image_url), '')) IS NOT NULL${businessTypeFilter}
       ORDER BY n.created_at DESC`,
      params,
    );
    return res.json({ posts: rows.map(newsPostResponse) });
  } catch (error) { return next(error); }
}

async function setVenueHeart(req, res, next, hearted) {
  const businessId = positiveIntegerId(req.params.businessId);
  if (businessId === null) {
    return res.status(400).json({ error: 'A valid venue is required.' });
  }
  try {
    const [venues] = await pool.execute(
      `SELECT id, name, category FROM merchant_businesses
       WHERE id = ? AND enabled = 1 LIMIT 1`,
      [businessId],
    );
    if (venues.length === 0) {
      return res.status(404).json({ error: 'Venue not found.' });
    }
    let changed = false;
    if (hearted) {
      const [result] = await pool.execute(
        `INSERT IGNORE INTO venue_hearts (business_id, user_id)
         VALUES (?, ?)`,
        [businessId, req.auth.sub],
      );
      changed = result.affectedRows > 0;
    } else {
      const [result] = await pool.execute(
        'DELETE FROM venue_hearts WHERE business_id = ? AND user_id = ?',
        [businessId, req.auth.sub],
      );
      changed = result.affectedRows > 0;
    }
    if (changed) invalidateCustomerBusinesses();
    if (changed) {
      await recordUserActivity(
        pool,
        req.auth.sub,
        hearted ? 'venue_hearted' : 'venue_unhearted',
        hearted ? 'Venue hearted' : 'Venue unhearted',
        hearted
          ? 'You hearted a venue.'
          : 'You removed your heart from a venue.',
        {
          venueId: venues[0].id,
          venueName: venues[0].name,
          sportType: venues[0].category,
        },
      );
    }
    const [counts] = await pool.execute(
      'SELECT COUNT(*) AS heartCount FROM venue_hearts WHERE business_id = ?',
      [businessId],
    );
    return res.json({
      heartCount: Number(counts[0]?.heartCount || 0),
      heartedByMe: hearted,
    });
  } catch (error) {
    return next(error);
  }
}

app.get(
  '/api/customer/venue-hearts',
  requireAuth,
  requireRole('customer'),
  async (req, res, next) => {
    try {
      const [rows] = await pool.execute(
        `SELECT business_id AS businessId
         FROM venue_hearts WHERE user_id = ?`,
        [req.auth.sub],
      );
      return res.json({ businesses: rows });
    } catch (error) {
      return next(error);
    }
  },
);

app.put(
  '/api/businesses/:businessId/heart',
  requireAuth,
  requireRole('customer'),
  (req, res, next) => setVenueHeart(req, res, next, true),
);
app.delete(
  '/api/businesses/:businessId/heart',
  requireAuth,
  requireRole('customer'),
  (req, res, next) => setVenueHeart(req, res, next, false),
);

app.get('/api/news/feed', requireAuth, requireRole('customer'), customerNewsFeed);
app.get('/api/customer/news', requireAuth, requireRole('customer'), customerNewsFeed);
app.get('/api/news-feed', requireAuth, requireRole('customer'), customerNewsFeed);

async function submitCustomerReview(req, res, next) {
  const bookingId = positiveIntegerId(req.body.bookingId);
  const rating = Number(req.body.rating);
  const comment = normalizeText(req.body.comment, 2000) || null;
  const imageData = req.body.imageData ?? null;
  let imageBytes = null;
  if (imageData != null) {
    const match = typeof imageData === 'string'
      ? /^data:image\/(jpeg|png|webp);base64,([A-Za-z0-9+/]+={0,2})$/.exec(imageData)
      : null;
    if (match) {
      imageBytes = Buffer.from(match[2], 'base64');
    }
    if (
      !match ||
      imageBytes.length > 5 * 1024 * 1024 ||
      imageBytes.toString('base64') !== match[2]
    ) {
      return res.status(400).json({
        error: 'The review photo must be a valid JPEG, PNG, or WebP image up to 5 MB.',
      });
    }
  }
  if (bookingId === null ||
      !isNumericInput(req.body.rating) ||
      !Number.isInteger(rating) || rating < 1 || rating > 5 ||
      (req.body.comment != null &&
        (typeof req.body.comment !== 'string' ||
          req.body.comment.length > 2000))) {
    return res.status(400).json({ error: 'A valid bookingId and rating from 1 to 5 are required.' });
  }
  try {
    const [bookings] = await pool.execute(
      `SELECT b.id, b.venue_id AS venueId, v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType,
              b.booking_date AS bookingDate,
              b.start_time AS startTime
       FROM bookings b
       JOIN merchant_businesses v ON v.id = b.venue_id
       WHERE b.id = ? AND b.customer_id = ? AND b.status = 'finished' LIMIT 1`,
      [bookingId, req.auth.sub],
    );
    if (!bookings[0]) return res.status(403).json({ error: 'Reviews are only allowed for your completed bookings.' });
    const [existing] = await pool.execute(
      'SELECT id FROM venue_reviews WHERE booking_id = ? AND customer_id = ? LIMIT 1',
      [bookingId, req.auth.sub],
    );
    if (existing[0]) return res.status(409).json({ error: 'You have already reviewed this booking.' });
    const [result] = await pool.execute(
      `INSERT INTO venue_reviews
         (business_id, booking_id, customer_id, rating, comment, image_data)
       VALUES (?, ?, ?, ?, ?, ?)`,
      [bookings[0].venueId, bookingId, req.auth.sub, rating, comment, imageData],
    );
    invalidateCustomerBusinesses();
    return res.status(201).json({ id: result.insertId, message: 'Review submitted.' });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'You have already reviewed this booking.' });
    return next(error);
  }
}

async function listBusinessReviews(req, res, next) {
  const businessId = positiveIntegerId(req.params.businessId);
  if (businessId === null) {
    return res.status(400).json({ error: 'Invalid business id.' });
  }
  const authorization = req.get('authorization') || '';
  const [scheme, token] = authorization.split(' ');
  let viewerId = null;
  if (scheme === 'Bearer' && token) {
    try {
      viewerId = positiveIntegerId(jwt.verify(token, process.env.JWT_SECRET).sub);
    } catch {
      viewerId = null;
    }
  }
  try {
    const [rows] = await pool.execute(
      `SELECT r.id, r.business_id AS businessId, r.customer_id AS customerId,
              r.rating, r.comment,
              r.image_data AS imageData, r.created_at AS createdAt,
              u.first_name AS firstName, u.last_name AS lastName,
              u.avatar_url AS avatarUrl,
              (SELECT COUNT(*) FROM venue_review_reactions rr
               WHERE rr.review_id = r.id) AS reactionCount,
              EXISTS (SELECT 1 FROM venue_review_reactions rr
                      WHERE rr.review_id = r.id AND rr.user_id = ?) AS reactedByMe
       FROM venue_reviews r INNER JOIN users u ON u.id = r.customer_id
       WHERE r.business_id = ? ORDER BY r.created_at DESC`,
      [viewerId, businessId],
    );
    const [replyRows] = await pool.execute(
      `SELECT rp.id, rp.review_id AS reviewId, rp.reply_text AS text,
              rp.created_at AS createdAt, u.id AS userId,
              u.first_name AS firstName, u.last_name AS lastName,
              u.avatar_url AS avatarUrl
       FROM venue_review_replies rp
       INNER JOIN venue_reviews r ON r.id = rp.review_id
       INNER JOIN users u ON u.id = rp.user_id AND u.status = 'active'
       WHERE r.business_id = ?
       ORDER BY rp.created_at, rp.id
       LIMIT 500`,
      [businessId],
    );
    const repliesByReview = new Map();
    for (const reply of replyRows) {
      const reviewId = Number(reply.reviewId);
      const replies = repliesByReview.get(reviewId) ?? [];
      replies.push({
        ...reply,
        createdAt: reply.createdAt == null
          ? null
          : new Date(reply.createdAt).toISOString(),
      });
      repliesByReview.set(reviewId, replies);
    }
    return res.json({
      reviews: rows.map((row) => ({
        ...row,
        createdAt: row.createdAt == null
          ? null
          : new Date(row.createdAt).toISOString(),
        reactionCount: Number(row.reactionCount) || 0,
        reactedByMe: Boolean(row.reactedByMe),
        replies: repliesByReview.get(Number(row.id)) ?? [],
      })),
    });
  } catch (error) { return next(error); }
}

async function setVenueReviewReaction(req, res, next) {
  const reviewId = positiveIntegerId(req.params.reviewId);
  if (reviewId === null) return res.status(400).json({ error: 'Invalid review.' });
  try {
    const [reviews] = await pool.execute(
      'SELECT id FROM venue_reviews WHERE id = ? LIMIT 1',
      [reviewId],
    );
    if (!reviews[0]) return res.status(404).json({ error: 'Review not found.' });
    if (req.method === 'POST') {
      await pool.execute(
        'INSERT IGNORE INTO venue_review_reactions (review_id, user_id) VALUES (?, ?)',
        [reviewId, req.auth.sub],
      );
    } else {
      await pool.execute(
        'DELETE FROM venue_review_reactions WHERE review_id = ? AND user_id = ?',
        [reviewId, req.auth.sub],
      );
    }
    return res.json({ reactedByMe: req.method === 'POST' });
  } catch (error) {
    return next(error);
  }
}

async function replyToVenueReview(req, res, next) {
  const reviewId = positiveIntegerId(req.params.reviewId);
  const text = typeof req.body.text === 'string'
    ? req.body.text.replace(/[\u0000-\u001f\u007f]/g, ' ').trim()
    : '';
  if (reviewId === null || !text || text.length > 2000) {
    return res.status(400).json({
      error: 'Enter a reply of no more than 2,000 characters.',
    });
  }
  try {
    const [reviews] = await pool.execute(
      'SELECT id FROM venue_reviews WHERE id = ? LIMIT 1',
      [reviewId],
    );
    if (!reviews[0]) return res.status(404).json({ error: 'Review not found.' });
    const [result] = await pool.execute(
      `INSERT INTO venue_review_replies (review_id, user_id, reply_text)
       VALUES (?, ?, ?)`,
      [reviewId, req.auth.sub, text],
    );
    return res.status(201).json({
      id: Number(result.insertId),
      reviewId,
      userId: Number(req.auth.sub),
      text,
    });
  } catch (error) {
    return next(error);
  }
}

async function submitBusinessReview(req, res, next) {
  const businessId = positiveIntegerId(req.params.businessId);
  const rating = Number(req.body.rating);
  const comment = normalizeText(req.body.comment, 2000) || null;
  if (businessId === null ||
      !isNumericInput(req.body.rating) ||
      !Number.isInteger(rating) || rating < 1 || rating > 5 ||
      (req.body.comment != null &&
        (typeof req.body.comment !== 'string' ||
          req.body.comment.length > 2000))) {
    return res.status(400).json({ error: 'A valid business id and rating from 1 to 5 are required.' });
  }
  try {
    const [bookings] = await pool.execute(
      `SELECT b.id, b.venue_id AS venueId, v.name AS venueName,
              COALESCE(b.sport_type, v.category) AS sportType,
              b.booking_date AS bookingDate, b.start_time AS startTime
       FROM bookings b
       INNER JOIN merchant_businesses v ON v.id = b.venue_id
       LEFT JOIN venue_reviews r ON r.booking_id = b.id AND r.customer_id = b.customer_id
       WHERE b.venue_id = ? AND b.customer_id = ? AND b.status = 'finished'
         AND r.id IS NULL ORDER BY b.booking_date DESC, b.id DESC LIMIT 1`,
      [businessId, req.auth.sub],
    );
    if (!bookings[0]) {
      return res.status(403).json({ error: 'A completed, not-yet-reviewed booking is required.' });
    }
    const [result] = await pool.execute(
      `INSERT INTO venue_reviews (business_id, booking_id, customer_id, rating, comment)
       VALUES (?, ?, ?, ?, ?)`,
      [businessId, bookings[0].id, req.auth.sub, rating, comment],
    );
    invalidateCustomerBusinesses();
    const [reviews] = await pool.execute(
      `SELECT id, business_id AS businessId, booking_id AS bookingId, customer_id AS customerId,
              rating, comment, created_at AS createdAt
       FROM venue_reviews WHERE id = ?`,
      [result.insertId],
    );
    await recordUserActivity(
      pool,
      req.auth.sub,
      'review_submitted',
      'Review submitted',
      `You reviewed a venue with ${rating} star${rating === 1 ? '' : 's'}.`,
      {
        venueId: bookings[0].venueId,
        venueName: bookings[0].venueName,
        sportType: bookings[0].sportType,
        details: {
          bookingId: bookings[0].id,
          bookingDate: bookings[0].bookingDate,
          startTime: bookings[0].startTime,
          rating,
        },
      },
    );
    return res.status(201).json({ review: reviews[0] });
  } catch (error) {
    if (error.code === 'ER_DUP_ENTRY') return res.status(409).json({ error: 'You have already reviewed this booking.' });
    return next(error);
  }
}

app.get('/api/news-feed/:businessId/reviews', listBusinessReviews);
app.post('/api/news-feed/:businessId/reviews', requireAuth, requireRole('customer'), submitBusinessReview);
app.post(
  '/api/venue-reviews/:reviewId/reactions',
  requireAuth,
  setVenueReviewReaction,
);
app.delete(
  '/api/venue-reviews/:reviewId/reactions',
  requireAuth,
  setVenueReviewReaction,
);
app.post(
  '/api/venue-reviews/:reviewId/replies',
  requireAuth,
  replyToVenueReview,
);
app.post('/api/reviews', requireAuth, requireRole('customer'), submitCustomerReview);
app.post('/api/customer/reviews', requireAuth, requireRole('customer'), submitCustomerReview);
}

module.exports = { registerCustomerVenueRoutes };
