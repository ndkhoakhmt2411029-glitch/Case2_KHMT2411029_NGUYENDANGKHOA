function notFound(req, res) {
  res.status(404).json({ message: 'Không tìm thấy đường dẫn' });
}

// eslint-disable-next-line no-unused-vars
function errorHandler(err, req, res, next) {
  if (err.type === 'entity.parse.failed') {
    return res.status(400).json({ message: 'Dữ liệu gửi lên không hợp lệ' });
  }
  if (err.code === 11000) {
    return res.status(409).json({ message: 'Email đã được sử dụng' });
  }
  console.error(err);
  res.status(500).json({ message: 'Lỗi máy chủ, vui lòng thử lại sau' });
}

module.exports = { notFound, errorHandler };
