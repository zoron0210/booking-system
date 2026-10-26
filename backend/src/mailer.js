const nodemailer = require('nodemailer');

function createMailer() {
  const required = ['SMTP_USER', 'SMTP_APP_PASSWORD'];
  const missing = required.filter((key) => !process.env[key]);
  if (missing.length > 0) {
    throw new Error(`Missing SMTP configuration: ${missing.join(', ')}`);
  }

  return nodemailer.createTransport({
    host: 'smtp.gmail.com',
    port: 465,
    secure: true,
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_APP_PASSWORD.replace(/\s+/g, ''),
    },
  });
}

async function sendVerificationCode(email, code) {
  const transporter = createMailer();
  await transporter.sendMail({
    from: `"SpotGo Sports" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'Your SpotGo Sports verification code',
    text: `Your SpotGo Sports verification code is ${code}. It expires in 10 minutes.`,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#192B50">
        <h2>Verify your SpotGo Sports account</h2>
        <p>Use this one-time code to finish creating your account:</p>
        <p style="font-size:32px;font-weight:700;letter-spacing:8px;color:#FF8200">${code}</p>
        <p>This code expires in 10 minutes. If you did not create an account, you can ignore this email.</p>
      </div>
    `,
  });
}

async function sendPasswordResetCode(email, code) {
  const transporter = createMailer();
  await transporter.sendMail({
    from: `"SpotGo Password Support" <${process.env.SMTP_USER}>`,
    to: email,
    subject: 'SpotGo PASSWORD RESET CODE',
    text: `Your SpotGo PASSWORD RESET CODE is ${code}. This is not a registration code. It expires in 10 minutes.`,
    html: `
      <div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#192B50">
        <h2>SpotGo password reset</h2>
        <p>Use this <strong>password reset code</strong> to choose a new password:</p>
        <p style="font-size:32px;font-weight:700;letter-spacing:8px;color:#FF8200">${code}</p>
        <p><strong>This is not a registration verification code.</strong></p>
        <p>This password reset code expires in 10 minutes. If you did not request a password reset, you can ignore this email.</p>
      </div>
    `,
  });
}

async function sendBookingNotificationEmail({ to, title, message }) {
  const transporter = createMailer();
  const escapeHtml = (value) => String(value).replace(/[&<>"']/g, (character) => ({
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  })[character]);
  await transporter.sendMail({
    from: `"SpotGo Sports" <${process.env.SMTP_USER}>`,
    to,
    subject: title,
    text: message,
    html: `<div style="font-family:Arial,sans-serif;max-width:560px;margin:auto;color:#192B50"><h2>${escapeHtml(title)}</h2><p>${escapeHtml(message)}</p></div>`,
  });
}

module.exports = {
  sendBookingNotificationEmail,
  sendPasswordResetCode,
  sendVerificationCode,
};
