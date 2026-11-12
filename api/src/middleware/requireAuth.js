// Lấy hàm xác thực từ authMiddleware.js dù được export theo kiểu nào.
const m = require('./authMiddleware');

const auth =
  typeof m === 'function'
    ? m
    : m.authMiddleware || m.protect || m.authenticate || m.auth || m.verifyToken;

if (typeof auth !== 'function') {
  throw new Error('Không tìm thấy hàm xác thực trong middleware/authMiddleware.js');
}

module.exports = auth;
