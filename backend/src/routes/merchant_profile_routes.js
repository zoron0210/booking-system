function registerMerchantProfileRoutes({
  app,
  pool,
  requireAuth,
  requireRole,
  invalidateCustomerBusinesses,
  recordUserActivity,
  isValidBookingDeadlineMinutes,
  DEFAULT_BOOKING_DEADLINE_MINUTES,
  MAX_BOOKING_DEADLINE_MINUTES,
  isValidEmail,
}) {
app.get('/api/merchant/profile', requireAuth, requireRole('merchant'), async (req, res, next) => {
  try {
    const [rows] = await pool.execute(
      `SELECT u.id, u.email, u.first_name AS firstName, u.last_name AS lastName,
              u.phone, u.avatar_url AS avatarUrl, u.role, u.status,
              mp.business_name AS businessName, mp.business_type AS businessType,
              mp.registration_number AS registrationNumber,
              mp.categories_json AS categoriesJson, mp.facility_type AS facilityType,
              mp.address, mp.contact_email AS contactEmail,
              mp.owner_designation AS ownerDesignation,
              mp.business_image AS businessImage,
              CASE WHEN mp.user_id IS NULL THEN 0 ELSE 1 END AS profileExists
       FROM users u
       LEFT JOIN merchant_profiles mp ON mp.user_id = u.id
       WHERE u.id = ? AND u.role = 'merchant'
       LIMIT 1`,
      [req.auth.sub],
    );
    if (rows.length === 0) {
      return res.status(403).json({ error: 'Only merchant accounts can access this profile.' });
    }
    const profile = rows[0];
    let categories = [];
    if (profile.categoriesJson) {
      try {
        const parsedCategories = JSON.parse(profile.categoriesJson);
        if (Array.isArray(parsedCategories)) {
          categories = parsedCategories.filter(
            (category) => typeof category === 'string',
          );
        }
      } catch (error) {
        // Keep the saved merchant profile usable when older data contains
        // invalid category JSON. Categories can be edited and saved again.
        categories = [];
      }
    }
    delete profile.categoriesJson;
    return res.json({
      profile: {
        ...profile,
        categories,
        profileExists: Boolean(profile.profileExists),
      },
    });
  } catch (error) {
    return next(error);
  }
});

app.get(
  '/api/merchant/booking-deadlines',
  requireAuth,
  requireRole('merchant'),
  async (req, res, next) => {
    try {
      const [rows] = await pool.execute(
        `SELECT COALESCE(mp.approval_timeout_minutes, ?) AS approvalTimeoutMinutes,
                COALESCE(mp.payment_timeout_minutes, ?) AS paymentTimeoutMinutes
         FROM users u
         LEFT JOIN merchant_profiles mp ON mp.user_id = u.id
         WHERE u.id = ? AND u.role = 'merchant'
         LIMIT 1`,
        [
          DEFAULT_BOOKING_DEADLINE_MINUTES,
          DEFAULT_BOOKING_DEADLINE_MINUTES,
          req.auth.sub,
        ],
      );
      if (!rows.length) {
        return res.status(403).json({
          error: 'Only merchant accounts can manage booking deadlines.',
        });
      }
      return res.json({
        approvalTimeoutMinutes: Number(rows[0].approvalTimeoutMinutes),
        paymentTimeoutMinutes: Number(rows[0].paymentTimeoutMinutes),
      });
    } catch (error) {
      return next(error);
    }
  },
);

app.put(
  '/api/merchant/booking-deadlines',
  requireAuth,
  requireRole('merchant'),
  async (req, res, next) => {
    const approvalTimeoutMinutes = req.body?.approvalTimeoutMinutes;
    const paymentTimeoutMinutes = req.body?.paymentTimeoutMinutes;
    if (
      !isValidBookingDeadlineMinutes(approvalTimeoutMinutes) ||
      !isValidBookingDeadlineMinutes(paymentTimeoutMinutes)
    ) {
      return res.status(400).json({
        error: `Each booking deadline must be a whole number of minutes between 1 and ${MAX_BOOKING_DEADLINE_MINUTES}.`,
      });
    }

    try {
      const [users] = await pool.execute(
        'SELECT id FROM users WHERE id = ? AND role = \'merchant\' LIMIT 1',
        [req.auth.sub],
      );
      if (!users.length) {
        return res.status(403).json({
          error: 'Only merchant accounts can manage booking deadlines.',
        });
      }
      await pool.execute(
        `INSERT INTO merchant_profiles
         (user_id, approval_timeout_minutes, payment_timeout_minutes)
         VALUES (?, ?, ?)
         ON DUPLICATE KEY UPDATE
           approval_timeout_minutes = VALUES(approval_timeout_minutes),
           payment_timeout_minutes = VALUES(payment_timeout_minutes)`,
        [req.auth.sub, approvalTimeoutMinutes, paymentTimeoutMinutes],
      );
      return res.json({ approvalTimeoutMinutes, paymentTimeoutMinutes });
    } catch (error) {
      return next(error);
    }
  },
);

app.put('/api/merchant/profile', requireAuth, requireRole('merchant'), async (req, res, next) => {
  const text = (value, max = 255) =>
    typeof value === 'string' ? value.trim().slice(0, max) : '';
  const profileTextLimits = {
    businessName: 255,
    businessType: 255,
    registrationNumber: 255,
    facilityType: 255,
    address: 500,
    contactEmail: 254,
    ownerDesignation: 255,
    firstName: 100,
    lastName: 100,
    phone: 30,
    profileImage: 10 * 1024 * 1024,
    businessImage: 10 * 1024 * 1024,
  };
  const invalidProfileText = Object.entries(profileTextLimits).some(
    ([field, maxLength]) => req.body[field] != null &&
      (typeof req.body[field] !== 'string' ||
        req.body[field].length > maxLength),
  );
  const invalidCategories = req.body.categories !== undefined &&
    (!Array.isArray(req.body.categories) ||
      req.body.categories.length > 12 ||
      req.body.categories.some(
        (category) => typeof category !== 'string' || category.length > 100,
      ));
  if (
    invalidProfileText ||
    invalidCategories ||
    (typeof req.body.contactEmail === 'string' &&
      req.body.contactEmail.trim() !== '' &&
      !isValidEmail(req.body.contactEmail.trim()))
  ) {
    return res.status(400).json({ error: 'One or more merchant profile fields are invalid.' });
  }
  const businessName = text(req.body.businessName);
  const businessType = text(req.body.businessType);
  const registrationNumber = text(req.body.registrationNumber);
  const facilityType = text(req.body.facilityType);
  const address = text(req.body.address, 500);
  const contactEmail = text(req.body.contactEmail);
  const ownerDesignation = text(req.body.ownerDesignation);
  const firstName = text(req.body.firstName, 100);
  const lastName = text(req.body.lastName, 100);
  const phone = text(req.body.phone, 30);
  const profileImage = text(req.body.profileImage, 10 * 1024 * 1024);
  const businessImage = text(req.body.businessImage, 10 * 1024 * 1024);
  const categories = Array.isArray(req.body.categories)
    ? req.body.categories.filter((value) => typeof value === 'string').slice(0, 12)
    : [];

  try {
    const [users] = await pool.execute(
      'SELECT id FROM users WHERE id = ? AND role = \'merchant\' LIMIT 1',
      [req.auth.sub],
    );
    if (users.length === 0) {
      return res.status(403).json({ error: 'Only merchant accounts can save this profile.' });
    }
    await pool.execute(
      `UPDATE users SET first_name = ?, last_name = ?, phone = ?, avatar_url = ?
       WHERE id = ?`,
      [firstName || null, lastName || null, phone || null, profileImage || null, req.auth.sub],
    );
    invalidateCustomerBusinesses();
    await pool.execute(
      `INSERT INTO merchant_profiles
       (user_id, business_name, business_type, registration_number,
        categories_json, facility_type, address, contact_email, owner_designation,
        business_image)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON DUPLICATE KEY UPDATE business_name = VALUES(business_name),
         business_type = VALUES(business_type),
         registration_number = VALUES(registration_number),
         categories_json = VALUES(categories_json),
         facility_type = VALUES(facility_type),
         address = VALUES(address),
         contact_email = VALUES(contact_email),
         owner_designation = VALUES(owner_designation),
         business_image = VALUES(business_image)`,
      [
        req.auth.sub,
        businessName,
        businessType,
        registrationNumber || null,
        JSON.stringify(categories),
        facilityType,
        address,
        contactEmail,
        ownerDesignation || null,
        businessImage || null,
      ],
    );
    await recordUserActivity(
      pool,
      req.auth.sub,
      'merchant_profile_updated',
      'Merchant profile updated',
      'Your merchant profile details were changed.',
      {
        details: {
          businessName,
          businessType,
          categoriesCount: categories.length,
        },
      },
    );
    return res.json({ message: 'Merchant profile saved.' });
  } catch (error) {
    return next(error);
  }
});
}

module.exports = { registerMerchantProfileRoutes };
