const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const { resolveRole, getRole, serialize, permissionsFor } = require('../services/taskService');
const { validateTask, validateStatus } = require('../validators/taskValidator');

const USER_FIELDS = 'fullName email avatarUrl';
const PRIORITY_RANK = { low: 1, medium: 2, high: 3 };

const populate = (q) =>
  q
    .populate('createdBy', USER_FIELDS)
    .populate('assigneeIds', USER_FIELDS)
    .populate('primaryAssigneeId', USER_FIELDS);

const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const validId = (id) => mongoose.isValidObjectId(id);

// Lấy task + vai trò; trả null và tự gửi lỗi nếu không tồn tại / không có quyền
async function loadTask(req, res) {
  if (!validId(req.params.id)) {
    res.status(404).json({ message: 'Không tìm thấy công việc' });
    return null;
  }
  const task = await populate(Task.findById(req.params.id));
  if (!task) {
    res.status(404).json({ message: 'Không tìm thấy công việc' });
    return null;
  }
  const role = await getRole(task, req.user._id);
  if (!role) {
    res.status(403).json({ message: 'Bạn không có quyền truy cập công việc này' });
    return null;
  }
  return { task, role };
}

// GET /tasks?scope=all|created|assigned|shared&status&priority&q&assigneeId&sortBy&order
exports.list = async (req, res, next) => {
  try {
    const me = req.user._id;
    const { scope = 'all', status, priority, q, assigneeId } = req.query;
    const sortBy = ['dueDate', 'priority', 'createdAt'].includes(req.query.sortBy)
      ? req.query.sortBy
      : 'createdAt';
    const order = req.query.order === 'asc' ? 1 : -1;

    const shares = await TaskShare.find({ userId: me });
    const shareByTask = new Map(shares.map((s) => [String(s.taskId), s]));
    const sharedIds = shares.map((s) => s.taskId);

    const scopes = {
      created: { createdBy: me },
      assigned: { assigneeIds: me },
      shared: { _id: { $in: sharedIds } },
    };
    const conditions = [
      scopes[scope] || {
        $or: [{ createdBy: me }, { assigneeIds: me }, { _id: { $in: sharedIds } }],
      },
    ];

    if (['todo', 'in_progress', 'completed'].includes(status)) conditions.push({ status });
    if (['low', 'medium', 'high'].includes(priority)) conditions.push({ priority });
    if (typeof q === 'string' && q.trim())
      conditions.push({ title: { $regex: escapeRegex(q.trim()), $options: 'i' } });
    if (assigneeId) {
      if (!validId(assigneeId)) return res.json({ tasks: [] });
      conditions.push({ $or: [{ assigneeIds: assigneeId }, { primaryAssigneeId: assigneeId }] });
    }

    const tasks = await populate(Task.find({ $and: conditions }));

    const dir = order;
    tasks.sort((a, b) => {
      let x;
      let y;
      if (sortBy === 'priority') {
        x = PRIORITY_RANK[a.priority];
        y = PRIORITY_RANK[b.priority];
      } else {
        x = a[sortBy] ? a[sortBy].getTime() : null;
        y = b[sortBy] ? b[sortBy].getTime() : null;
        // Công việc không có hạn luôn xếp cuối
        if (x === null && y === null) return 0;
        if (x === null) return 1;
        if (y === null) return -1;
      }
      return (x - y) * dir;
    });

    res.json({
      tasks: tasks.map((t) => serialize(t, resolveRole(t, me, shareByTask.get(String(t._id))))),
    });
  } catch (err) {
    next(err);
  }
};

// POST /tasks
exports.create = async (req, res, next) => {
  try {
    const error = validateTask(req.body);
    if (error) return res.status(400).json({ message: error });

    const b = req.body;
    const task = await Task.create({
      title: b.title.trim(),
      description: (b.description || '').trim(),
      createdBy: req.user._id,
      startDate: b.startDate || null,
      dueDate: b.dueDate || null,
      priority: b.priority || 'medium',
      status: b.status || 'todo',
    });
    const full = await populate(Task.findById(task._id));
    res.status(201).json({ task: serialize(full, 'owner') });
  } catch (err) {
    next(err);
  }
};

// GET /tasks/:id
exports.getOne = async (req, res, next) => {
  try {
    const found = await loadTask(req, res);
    if (!found) return;
    res.json({ task: serialize(found.task, found.role) });
  } catch (err) {
    next(err);
  }
};

// PUT /tasks/:id
exports.update = async (req, res, next) => {
  try {
    const found = await loadTask(req, res);
    if (!found) return;
    if (!permissionsFor(found.role).canEdit)
      return res.status(403).json({ message: 'Bạn không có quyền chỉnh sửa công việc này' });

    const merged = {
      startDate: found.task.startDate,
      dueDate: found.task.dueDate,
      ...req.body,
    };
    const error = validateTask(merged, { partial: true });
    if (error) return res.status(400).json({ message: error });

    const b = req.body;
    const { task } = found;
    if (b.title !== undefined) task.title = b.title.trim();
    if (b.description !== undefined) task.description = b.description.trim();
    if (b.startDate !== undefined) task.startDate = b.startDate || null;
    if (b.dueDate !== undefined) task.dueDate = b.dueDate || null;
    if (b.priority !== undefined) task.priority = b.priority;
    if (b.status !== undefined) task.status = b.status;
    await task.save();

    res.json({ task: serialize(task, found.role) });
  } catch (err) {
    next(err);
  }
};

// PATCH /tasks/:id/status
exports.updateStatus = async (req, res, next) => {
  try {
    const found = await loadTask(req, res);
    if (!found) return;
    if (!permissionsFor(found.role).canChangeStatus)
      return res.status(403).json({ message: 'Bạn không có quyền đổi trạng thái công việc này' });

    const error = validateStatus(req.body);
    if (error) return res.status(400).json({ message: error });

    found.task.status = req.body.status;
    await found.task.save();
    res.json({ task: serialize(found.task, found.role) });
  } catch (err) {
    next(err);
  }
};

// DELETE /tasks/:id  (chỉ người tạo)
exports.remove = async (req, res, next) => {
  try {
    const found = await loadTask(req, res);
    if (!found) return;
    if (!permissionsFor(found.role).canDelete)
      return res.status(403).json({ message: 'Chỉ người tạo mới được xóa công việc' });

    await TaskShare.deleteMany({ taskId: found.task._id });
    await found.task.deleteOne();
    res.json({ message: 'Đã xóa công việc' });
  } catch (err) {
    next(err);
  }
};
