const mongoose = require('mongoose');
const TaskShare = require('../models/TaskShare');
const User = require('../models/User');

const FIELDS = 'fullName email avatarUrl';
const PERMISSIONS = ['viewer', 'editor'];
const MAX_PEOPLE = 50;

const fail = (res, status, message) => res.status(status).json({ message });

async function listFor(taskId) {
  const shares = await TaskShare.find({ taskId })
    .populate('userId', FIELDS)
    .populate('sharedBy', FIELDS)
    .sort({ createdAt: 1 });
  return shares.map((s) => ({
    _id: s._id,
    permission: s.permission,
    user: s.userId,
    sharedBy: s.sharedBy,
    createdAt: s.createdAt,
  }));
}

// GET /tasks/:id/shares
exports.listShares = async (req, res, next) => {
  try {
    res.json({ shares: await listFor(req.task._id) });
  } catch (err) {
    next(err);
  }
};

// POST /tasks/:id/shares
//   { items: [{ email | userId, permission }] }
//   hoặc { emails?: [], userIds?: [], permission }
exports.addShares = async (req, res, next) => {
  try {
    const body = req.body || {};
    let items = [];
    if (Array.isArray(body.items)) {
      items = body.items.map((i) => ({
        email: i && i.email,
        userId: i && i.userId,
        permission: (i && i.permission) || 'viewer',
      }));
    } else {
      const permission = body.permission || 'viewer';
      (Array.isArray(body.emails) ? body.emails : []).forEach((email) =>
        items.push({ email, permission })
      );
      (Array.isArray(body.userIds) ? body.userIds : []).forEach((userId) =>
        items.push({ userId, permission })
      );
    }
    if (!items.length) return fail(res, 400, 'Vui lòng chọn ít nhất một người');
    if (items.length > MAX_PEOPLE) {
      return fail(res, 400, `Mỗi lần chỉ chia sẻ tối đa ${MAX_PEOPLE} người`);
    }
    if (items.some((i) => !PERMISSIONS.includes(i.permission))) {
      return fail(res, 400, 'Quyền chia sẻ phải là viewer hoặc editor');
    }

    const emails = items
      .filter((i) => i.email)
      .map((i) => String(i.email).trim().toLowerCase());
    const ids = items.filter((i) => i.userId).map((i) => String(i.userId));
    if (ids.some((i) => !mongoose.isValidObjectId(i))) {
      return fail(res, 400, 'Mã người dùng không hợp lệ');
    }

    const users = await User.find({
      $or: [{ email: { $in: emails } }, { _id: { $in: ids } }],
    }).select(FIELDS);
    const byEmail = new Map(users.map((u) => [String(u.email).toLowerCase(), u]));
    const byId = new Map(users.map((u) => [String(u._id), u]));

    const targets = [];
    const missing = [];
    for (const item of items) {
      const user = item.userId
        ? byId.get(String(item.userId))
        : byEmail.get(String(item.email || '').trim().toLowerCase());
      if (!user) missing.push(item.email || item.userId);
      else targets.push({ user, permission: item.permission });
    }
    if (missing.length) {
      return fail(res, 400, `Không tìm thấy người dùng: ${missing.join(', ')}`);
    }
    if (targets.some((t) => String(t.user._id) === String(req.task.createdBy))) {
      return fail(res, 400, 'Không thể chia sẻ cho người tạo công việc');
    }

    for (const t of targets) {
      // Đã chia sẻ trước đó thì cập nhật quyền, không tạo bản ghi trùng
      await TaskShare.findOneAndUpdate(
        { taskId: req.task._id, userId: t.user._id },
        { $set: { permission: t.permission, sharedBy: req.currentUserId } },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      );
    }
    res.status(201).json({ shares: await listFor(req.task._id) });
  } catch (err) {
    next(err);
  }
};

// PATCH /tasks/:id/shares/:shareId   { permission }
exports.updateShare = async (req, res, next) => {
  try {
    const { shareId } = req.params;
    const permission = req.body && req.body.permission;
    if (!PERMISSIONS.includes(permission)) {
      return fail(res, 400, 'Quyền chia sẻ phải là viewer hoặc editor');
    }
    if (!mongoose.isValidObjectId(shareId)) return fail(res, 404, 'Không tìm thấy bản ghi chia sẻ');
    const share = await TaskShare.findOne({ _id: shareId, taskId: req.task._id });
    if (!share) return fail(res, 404, 'Không tìm thấy bản ghi chia sẻ');
    share.permission = permission;
    await share.save();
    res.json({ shares: await listFor(req.task._id) });
  } catch (err) {
    next(err);
  }
};

// DELETE /tasks/:id/shares/:shareId   → thu hồi quyền
exports.revokeShare = async (req, res, next) => {
  try {
    const { shareId } = req.params;
    if (!mongoose.isValidObjectId(shareId)) return fail(res, 404, 'Không tìm thấy bản ghi chia sẻ');
    const share = await TaskShare.findOneAndDelete({ _id: shareId, taskId: req.task._id });
    if (!share) return fail(res, 404, 'Không tìm thấy bản ghi chia sẻ');
    res.json({ shares: await listFor(req.task._id) });
  } catch (err) {
    next(err);
  }
};
