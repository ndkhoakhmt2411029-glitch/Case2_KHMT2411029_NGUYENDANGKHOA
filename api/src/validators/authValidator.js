const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const MIN_PASSWORD = 6;

const str = (v) => (typeof v === 'string' ? v : '');

// Mỗi hàm trả về chuỗi lỗi (tiếng Việt) hoặc null nếu hợp lệ
function validateRegister(body = {}) {
  if (!str(body.fullName).trim()) return 'Vui lòng nhập họ và tên';
  if (!EMAIL_RE.test(str(body.email).trim())) return 'Email không hợp lệ';
  if (str(body.password).length < MIN_PASSWORD)
    return `Mật khẩu phải có ít nhất ${MIN_PASSWORD} ký tự`;
  return null;
}

function validateLogin(body = {}) {
  if (!EMAIL_RE.test(str(body.email).trim())) return 'Email không hợp lệ';
  if (!str(body.password)) return 'Vui lòng nhập mật khẩu';
  return null;
}

function validateUpdateProfile(body = {}) {
  if (!str(body.fullName).trim()) return 'Vui lòng nhập họ và tên';
  if (body.avatarUrl != null && typeof body.avatarUrl !== 'string')
    return 'Đường dẫn ảnh đại diện không hợp lệ';
  return null;
}

function validateChangePassword(body = {}) {
  if (!str(body.currentPassword)) return 'Vui lòng nhập mật khẩu hiện tại';
  if (str(body.newPassword).length < MIN_PASSWORD)
    return `Mật khẩu mới phải có ít nhất ${MIN_PASSWORD} ký tự`;
  if (body.newPassword === body.currentPassword)
    return 'Mật khẩu mới phải khác mật khẩu hiện tại';
  return null;
}

module.exports = {
  validateRegister,
  validateLogin,
  validateUpdateProfile,
  validateChangePassword,
};
