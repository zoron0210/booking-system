const DEFAULT_BOOKING_DEADLINE_MINUTES = 15;
const MAX_BOOKING_DEADLINE_MINUTES = 10080;

function isValidBookingDeadlineMinutes(value) {
  return Number.isSafeInteger(value) &&
    value >= 1 &&
    value <= MAX_BOOKING_DEADLINE_MINUTES;
}

function formatBookingDeadlineDuration(value) {
  const minutes = isValidBookingDeadlineMinutes(value)
    ? value
    : DEFAULT_BOOKING_DEADLINE_MINUTES;
  if (minutes < 60) return `${minutes} minute${minutes === 1 ? '' : 's'}`;

  const hours = Math.floor(minutes / 60);
  const remainingMinutes = minutes % 60;
  const hourLabel = `${hours} hour${hours === 1 ? '' : 's'}`;
  if (remainingMinutes === 0) return hourLabel;
  return `${hourLabel} ${remainingMinutes} minute${remainingMinutes === 1 ? '' : 's'}`;
}

module.exports = {
  DEFAULT_BOOKING_DEADLINE_MINUTES,
  MAX_BOOKING_DEADLINE_MINUTES,
  formatBookingDeadlineDuration,
  isValidBookingDeadlineMinutes,
};
