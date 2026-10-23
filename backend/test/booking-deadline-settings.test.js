const assert = require('node:assert/strict');
const { test } = require('node:test');
const {
  DEFAULT_BOOKING_DEADLINE_MINUTES,
  MAX_BOOKING_DEADLINE_MINUTES,
  formatBookingDeadlineDuration,
  isValidBookingDeadlineMinutes,
} = require('../src/booking_deadline_settings');

test('validates deadline values as whole minutes up to seven days', () => {
  assert.equal(DEFAULT_BOOKING_DEADLINE_MINUTES, 15);
  assert.equal(isValidBookingDeadlineMinutes(1), true);
  assert.equal(isValidBookingDeadlineMinutes(MAX_BOOKING_DEADLINE_MINUTES), true);
  assert.equal(isValidBookingDeadlineMinutes(0), false);
  assert.equal(isValidBookingDeadlineMinutes(1.5), false);
  assert.equal(isValidBookingDeadlineMinutes('60'), false);
  assert.equal(
    isValidBookingDeadlineMinutes(MAX_BOOKING_DEADLINE_MINUTES + 1),
    false,
  );
});

test('formats customer-facing deadline durations', () => {
  assert.equal(formatBookingDeadlineDuration(1), '1 minute');
  assert.equal(formatBookingDeadlineDuration(15), '15 minutes');
  assert.equal(formatBookingDeadlineDuration(60), '1 hour');
  assert.equal(formatBookingDeadlineDuration(120), '2 hours');
  assert.equal(formatBookingDeadlineDuration(125), '2 hours 5 minutes');
  assert.equal(formatBookingDeadlineDuration(null), '15 minutes');
});
