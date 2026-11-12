const mongoose = require('mongoose');
const Task = require('../models/Task');
const User = require('../models/User');
const notifier = require('../services/notificationService');

const FIELDS = 'fullName email avatarUrl';
const MAX_PEOPLE = 50;

const fail = (res, status, message) => res.status(status).json({ message });

// Tìm người dùng theo danh sách email và/hoặc userId.
async function resolveUsers(body) {
  const emails = [
    ...new Set(
      (Array.isArray(body.emails) ? body.emails : [])
        .map((e) => String(e).trim().toLowerCase())
        .filter(Boolean)
    ),
  ];
  const ids = [
    ...new Set((Array.isArray(body.userIds) ? body.userIds : []).map(String)),
  ];
  if (emails.length + ids.length === 0) return { error: 'Vui lòng chọn ít nhất một người' };
  if (emails.length + ids.length > MAX_PEOPLE) {
    return { error: `Mỗi lần chỉ giao tối đa ${MAX_PEOPLE} người` };
  }
  if (ids.some((i) => !mongoose.isValidObjectId(i))) {
    return { error: 'Mã người dùng không hợp lệ' };
  }

  const users = await User.find({
    $or: [{ email: { $in: emails } }, { _id: { $in: ids } }],
  }).select(FIELDS);

  const foundEmails = new Set(users.map((u) => String(u.email).toLowerCase()));
  const foundIds = new Set(users.map((u) => String(u._id)));
  const missing = [
    ...emails.filter((e) => !foundEmails.has(e)),
    ...ids.filter((i) => !foundIds.has(i)),
  ];
  if (missing.length) return { error: `Không tìm thấy người dùng: ${missing.join(', ')}` };
  return { users };
}

async function respond(res, taskId, status = 200) {
  const task = await Task.findById(taskId).populate('assigneeIds', FIELDS);
  const primary = task.primaryAssigneeId ? String(task.primaryAssigneeId) : null;
  res.status(status).json({
    primaryAssigneeId: primary,
    assignees: task.assigneeIds.map((u) => ({
      ...u.toObject(),
      isPrimary: String(u._id) === primary,
    })),
  });
}

const hasAssignee = (task, userId) =>
  task.assigneeIds.some((u) => String(u) === String(userId));

// GET /tasks/:id/assignees
exports.listAssignees = async (req, res, next) => {
  try {
    await respond(res, req.task._id);
  } catch (err) {
    next(err);
  }
};

// POST /tasks/:id/assignees   { userIds?, emails?, primaryAssigneeId?, primaryEmail? }
exports.addAssignees = async (req, res, next) => {
  try {
    const body = req.body || {};
    const r = await resolveUsers(body);
    if (r.error) return fail(res, 400, r.error);

    const task = req.task;
    const added = []; // người mới được giao (để gửi thông báo + email)
    for (const u of r.users) {
      if (!hasAssignee(task, u._id)) {
        task.assigneeIds.push(u._id);
        added.push(u);
      }
    }

    let primary = body.primaryAssigneeId ? String(body.primaryAssigneeId) : null;
    if (!primary && body.primaryEmail) {
      const email = String(body.primaryEmail).trim().toLowerCase();
      const found = r.users.find((u) => String(u.email).toLowerCase() === email);
      if (found) primary = String(found._id);
    }
    if (primary) {
      if (!mongoose.isValidObjectId(primary) || !hasAssignee(task, primary)) {
        return fail(res, 400, 'Người phụ trách chính phải nằm trong danh sách được giao');
      }
      task.primaryAssigneeId = primary;
    } else if (!task.primaryAssigneeId && task.assigneeIds.length) {
      task.primaryAssigneeId = task.assigneeIds[0]; // mặc định: người đầu tiên
    }

    await task.save();
    if (added.length) notifier.notifyAssigned(task, added, req.currentUserId); // chạy nền
    await respond(res, task._id, 201);
  } catch (err) {
    next(err);
  }
};

// PATCH /tasks/:id/assignees/:userId  → đặt làm người phụ trách chính
exports.setPrimary = async (req, res, next) => {
  try {
    const { userId } = req.params;
    if (!mongoose.isValidObjectId(userId) || !hasAssignee(req.task, userId)) {
      return fail(res, 404, 'Người này chưa được giao công việc');
    }
    req.task.primaryAssigneeId = userId;
    await req.task.save();
    await respond(res, req.task._id);
  } catch (err) {
    next(err);
  }
};

// DELETE /tasks/:id/assignees/:userId  → hủy giao việc cho một người
exports.removeAssignee = async (req, res, next) => {
  try {
    const { userId } = req.params;
    if (!mongoose.isValidObjectId(userId) || !hasAssignee(req.task, userId)) {
      return fail(res, 404, 'Người này chưa được giao công việc');
    }
    const task = req.task;
    task.assigneeIds = task.assigneeIds.filter((u) => String(u) !== String(userId));
    if (task.primaryAssigneeId && String(task.primaryAssigneeId) === String(userId)) {
      task.primaryAssigneeId = task.assigneeIds.length ? task.assigneeIds[0] : null;
    }
    await task.save();
    await respond(res, task._id);
  } catch (err) {
    next(err);
  }
};
