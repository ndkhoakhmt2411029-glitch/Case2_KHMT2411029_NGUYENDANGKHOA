const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

const STATUSES = ['todo', 'in_progress', 'completed'];
const PRIORITIES = ['low', 'medium', 'high'];
const PRIORITY_RANK = { low: 1, medium: 2, high: 3 };
const USER_FIELDS = 'fullName email avatarUrl';

// Lấy id người dùng đăng nhập, tương thích nhiều cách viết authMiddleware.
const currentUserId = (req) =>
  String(
    (req.user && (req.user._id || req.user.id)) || req.userId || ''
  );

const fail = (res, status, message) => res.status(status).json({ message });

const sameId = (a, b) => String(a && (a._id || a)) === String(b);

const parseDate = (v) => {
  if (v === undefined || v === null || v === '') return null;
  const d = new Date(v);
  return Number.isNaN(d.getTime()) ? undefined : d; // undefined = không hợp lệ
};

// ---------- Phân quyền ----------
// owner (người tạo) > editor (chia sẻ sửa) > assignee (được giao) > viewer
function roleOf(task, userId, shareMap) {
  if (sameId(task.createdBy, userId)) return 'owner';
  const share = shareMap.get(String(task._id));
  if (share === 'editor') return 'editor';
  if (task.assigneeIds.some((u) => sameId(u, userId))) return 'assignee';
  if (share === 'viewer') return 'viewer';
  return null;
}

function permissionsOf(role) {
  return {
    canEdit: role === 'owner' || role === 'editor',
    canDelete: role === 'owner', // editor không mặc nhiên được xóa
    canChangeStatus: ['owner', 'editor', 'assignee'].includes(role),
  };
}

function serialize(task, role) {
  const obj = task.toObject();
  obj.myRole = role;
  obj.permissions = permissionsOf(role);
  return obj;
}

async function shareMapFor(userId, taskIds) {
  const filter = { userId };
  if (taskIds) filter.taskId = { $in: taskIds };
  const shares = await TaskShare.find(filter).lean();
  return new Map(shares.map((s) => [String(s.taskId), s.permission]));
}

function populate(query) {
  return query
    .populate('createdBy', USER_FIELDS)
    .populate('assigneeIds', USER_FIELDS)
    .populate('primaryAssigneeId', USER_FIELDS);
}

// Tìm công việc và kiểm tra người gọi có quyền truy cập hay không.
async function loadAccessible(req, res) {
  const { id } = req.params;
  if (!mongoose.isValidObjectId(id)) {
    fail(res, 404, 'Không tìm thấy công việc');
    return null;
  }
  const userId = currentUserId(req);
  const task = await populate(Task.findById(id));
  if (!task) {
    fail(res, 404, 'Không tìm thấy công việc');
    return null;
  }
  const shareMap = await shareMapFor(userId, [task._id]);
  const role = roleOf(task, userId, shareMap);
  if (!role) {
    // Không tiết lộ công việc có tồn tại hay không
    fail(res, 404, 'Không tìm thấy công việc');
    return null;
  }
  return { task, role };
}

// Kiểm tra và chuẩn hóa dữ liệu đầu vào cho tạo / sửa.
function readBody(body, { partial = false } = {}) {
  const out = {};
  const errors = [];

  if (!partial || body.title !== undefined) {
    const title = typeof body.title === 'string' ? body.title.trim() : '';
    if (!title) errors.push('Tên công việc không được để trống');
    else if (title.length > 200) errors.push('Tên công việc tối đa 200 ký tự');
    else out.title = title;
  }
  if (body.description !== undefined) {
    out.description = String(body.description || '').trim();
  }
  if (body.priority !== undefined) {
    if (!PRIORITIES.includes(body.priority)) errors.push('Mức độ ưu tiên không hợp lệ');
    else out.priority = body.priority;
  }
  if (body.status !== undefined) {
    if (!STATUSES.includes(body.status)) errors.push('Trạng thái không hợp lệ');
    else out.status = body.status;
  }
  for (const key of ['startDate', 'dueDate']) {
    if (body[key] !== undefined) {
      const d = parseDate(body[key]);
      if (d === undefined) errors.push(`${key === 'startDate' ? 'Ngày bắt đầu' : 'Hạn hoàn thành'} không hợp lệ`);
      else out[key] = d;
    }
  }
  return { data: out, errors };
}

// ---------- GET /tasks ----------
exports.listTasks = async (req, res, next) => {
  try {
    const userId = currentUserId(req);
    const { scope, status, priority, q, assigneeId } = req.query;
    const sortBy = ['dueDate', 'priority', 'createdAt'].includes(req.query.sortBy)
      ? req.query.sortBy
      : 'createdAt';
    const order = req.query.order === 'asc' ? 1 : -1;

    const shareMap = await shareMapFor(userId);
    const sharedIds = [...shareMap.keys()].map((id) => new mongoose.Types.ObjectId(id));

    let access;
    if (scope === 'created') access = { createdBy: userId };
    else if (scope === 'assigned') access = { assigneeIds: userId };
    else if (scope === 'shared') access = { _id: { $in: sharedIds } };
    else access = { $or: [{ createdBy: userId }, { assigneeIds: userId }, { _id: { $in: sharedIds } }] };

    const filter = { $and: [access] };
    if (STATUSES.includes(status)) filter.$and.push({ status });
    if (PRIORITIES.includes(priority)) filter.$and.push({ priority });
    if (q && String(q).trim()) {
      const safe = String(q).trim().replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
      filter.$and.push({ title: { $regex: safe, $options: 'i' } });
    }
    if (assigneeId && mongoose.isValidObjectId(assigneeId)) {
      filter.$and.push({ $or: [{ primaryAssigneeId: assigneeId }, { assigneeIds: assigneeId }] });
    }

    const tasks = await populate(Task.find(filter));

    tasks.sort((a, b) => {
      let cmp;
      if (sortBy === 'priority') {
        cmp = PRIORITY_RANK[a.priority] - PRIORITY_RANK[b.priority];
      } else if (sortBy === 'dueDate') {
        // Công việc chưa có hạn luôn xếp cuối
        if (!a.dueDate && !b.dueDate) cmp = 0;
        else if (!a.dueDate) return 1;
        else if (!b.dueDate) return -1;
        else cmp = a.dueDate - b.dueDate;
      } else {
        cmp = a.createdAt - b.createdAt;
      }
      return cmp * order;
    });

    const result = tasks.map((t) => serialize(t, roleOf(t, userId, shareMap)));
    res.json({ tasks: result });
  } catch (err) {
    next(err);
  }
};

// ---------- GET /tasks/:id ----------
exports.getTask = async (req, res, next) => {
  try {
    const found = await loadAccessible(req, res);
    if (!found) return;
    res.json({ task: serialize(found.task, found.role) });
  } catch (err) {
    next(err);
  }
};

// ---------- POST /tasks ----------
exports.createTask = async (req, res, next) => {
  try {
    const { data, errors } = readBody(req.body || {});
    if (errors.length) return fail(res, 400, errors[0]);
    if (data.startDate && data.dueDate && data.dueDate < data.startDate) {
      return fail(res, 400, 'Hạn hoàn thành phải sau hoặc bằng ngày bắt đầu');
    }
    const created = await Task.create({ ...data, createdBy: currentUserId(req) });
    const task = await populate(Task.findById(created._id));
    res.status(201).json({ task: serialize(task, 'owner') });
  } catch (err) {
    next(err);
  }
};

// ---------- PUT /tasks/:id ----------
exports.updateTask = async (req, res, next) => {
  try {
    const found = await loadAccessible(req, res);
    if (!found) return;
    if (!permissionsOf(found.role).canEdit) {
      return fail(res, 403, 'Bạn không có quyền chỉnh sửa công việc này');
    }
    const { data, errors } = readBody(req.body || {});
    if (errors.length) return fail(res, 400, errors[0]);

    const start = 'startDate' in data ? data.startDate : found.task.startDate;
    const due = 'dueDate' in data ? data.dueDate : found.task.dueDate;
    if (start && due && due < start) {
      return fail(res, 400, 'Hạn hoàn thành phải sau hoặc bằng ngày bắt đầu');
    }

    Object.assign(found.task, data);
    await found.task.save();
    const task = await populate(Task.findById(found.task._id));
    res.json({ task: serialize(task, found.role) });
  } catch (err) {
    next(err);
  }
};

// ---------- PATCH /tasks/:id/status ----------
exports.updateStatus = async (req, res, next) => {
  try {
    const found = await loadAccessible(req, res);
    if (!found) return;
    if (!permissionsOf(found.role).canChangeStatus) {
      return fail(res, 403, 'Bạn không có quyền đổi trạng thái công việc này');
    }
    const status = req.body && req.body.status;
    if (!STATUSES.includes(status)) return fail(res, 400, 'Trạng thái không hợp lệ');

    found.task.status = status;
    await found.task.save();
    const task = await populate(Task.findById(found.task._id));
    res.json({ task: serialize(task, found.role) });
  } catch (err) {
    next(err);
  }
};

// ---------- DELETE /tasks/:id ----------
exports.deleteTask = async (req, res, next) => {
  try {
    const found = await loadAccessible(req, res);
    if (!found) return;
    if (!permissionsOf(found.role).canDelete) {
      return fail(res, 403, 'Chỉ người tạo mới được xóa công việc');
    }
    await TaskShare.deleteMany({ taskId: found.task._id });
    await found.task.deleteOne();
    res.json({ message: 'Đã xóa công việc' });
  } catch (err) {
    next(err);
  }
};
