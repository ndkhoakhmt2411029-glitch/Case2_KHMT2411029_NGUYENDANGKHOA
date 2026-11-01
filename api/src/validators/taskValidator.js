const PRIORITIES = ['low', 'medium', 'high'];
const STATUSES = ['todo', 'in_progress', 'completed'];

const isValidDate = (v) => v === null || !Number.isNaN(new Date(v).getTime());

// Trả về chuỗi lỗi hoặc null. partial=true dùng cho cập nhật (không bắt buộc title).
function validateTask(body = {}, { partial = false } = {}) {
  if (!partial || body.title !== undefined) {
    if (typeof body.title !== 'string' || !body.title.trim())
      return 'Vui lòng nhập tên công việc';
    if (body.title.trim().length > 200)
      return 'Tên công việc tối đa 200 ký tự';
  }
  if (body.description !== undefined && typeof body.description !== 'string')
    return 'Mô tả không hợp lệ';
  if (body.priority !== undefined && !PRIORITIES.includes(body.priority))
    return 'Mức độ ưu tiên không hợp lệ';
  if (body.status !== undefined && !STATUSES.includes(body.status))
    return 'Trạng thái không hợp lệ';
  for (const key of ['startDate', 'dueDate']) {
    if (body[key] !== undefined && !isValidDate(body[key]))
      return key === 'startDate' ? 'Ngày bắt đầu không hợp lệ' : 'Hạn hoàn thành không hợp lệ';
  }
  if (body.startDate && body.dueDate && new Date(body.dueDate) < new Date(body.startDate))
    return 'Hạn hoàn thành phải sau hoặc bằng ngày bắt đầu';
  return null;
}

function validateStatus(body = {}) {
  if (!STATUSES.includes(body.status)) return 'Trạng thái không hợp lệ';
  return null;
}

module.exports = { validateTask, validateStatus, PRIORITIES, STATUSES };
