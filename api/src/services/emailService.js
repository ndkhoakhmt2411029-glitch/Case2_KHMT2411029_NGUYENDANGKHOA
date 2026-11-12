// Gửi email từ backend qua SMTP (nodemailer). Thông tin SMTP đọc từ biến môi trường (.env),
// không viết cứng trong code:
//   SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, MAIL_FROM, (tùy chọn) SMTP_SECURE=true
// Mỗi email được ghi vào email_logs: pending -> sent | failed (kèm số lần thử và lỗi).
// Chỉ thử gửi tối đa MAX_ATTEMPTS lần cho mỗi email để tránh gửi trùng.
const EmailLog = require('../models/EmailLog');

const MAX_ATTEMPTS = 2;
const RETRY_DELAY_MS = 1500;

let transporter; // khởi tạo lười, chỉ khi thật sự cần gửi
function getTransporter() {
  if (transporter !== undefined) return transporter;
  const { SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_SECURE } = process.env;
  if (!SMTP_HOST) {
    transporter = null;
    return null;
  }
  const nodemailer = require('nodemailer'); // npm install nodemailer
  transporter = nodemailer.createTransport({
    host: SMTP_HOST,
    port: Number(SMTP_PORT) || 587,
    secure: String(SMTP_SECURE).toLowerCase() === 'true',
    auth: SMTP_USER ? { user: SMTP_USER, pass: SMTP_PASS } : undefined,
  });
  return transporter;
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const escapeHtml = (s) =>
  String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

// Không ném lỗi ra ngoài: lỗi gửi email không được làm hỏng API chính.
async function sendEmail({ to, subject, text, taskId = null, eventType }) {
  let log;
  try {
    log = await EmailLog.create({ taskId, recipientEmail: to, eventType, subject, status: 'pending' });
    const tx = getTransporter();
    if (!tx) {
      log.status = 'failed';
      log.errorMessage = 'SMTP chưa được cấu hình (thiếu SMTP_HOST trong .env)';
      await log.save();
      return log;
    }
    const from = process.env.MAIL_FROM || process.env.SMTP_USER;
    for (let i = 1; i <= MAX_ATTEMPTS; i += 1) {
      log.attempts = i;
      try {
        await tx.sendMail({
          from,
          to,
          subject,
          text,
          html: `<div style="font-family:Arial,sans-serif">${escapeHtml(text).replace(/\n/g, '<br>')}</div>`,
        });
        log.status = 'sent';
        log.sentAt = new Date();
        log.errorMessage = '';
        break;
      } catch (err) {
        log.status = 'failed';
        log.errorMessage = String(err.message || err).slice(0, 500);
        if (i < MAX_ATTEMPTS) await sleep(RETRY_DELAY_MS);
      }
    }
    await log.save();
    return log;
  } catch (err) {
    console.error('Lỗi ghi/gửi email:', err.message);
    return log;
  }
}

module.exports = { sendEmail };
