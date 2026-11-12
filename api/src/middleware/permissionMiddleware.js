const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');

const currentUserId = (req) =>
  String((req.user && (req.user._id || req.user.id)) || req.userId || '');

const sameId = (a, b) => String(a && (a._id || a)) === String(b);

// Nạp công việc từ :id và xác định vai trò của người đang đăng nhập:
// owner (người tạo) > editor (chia sẻ sửa) > assignee (được giao) > viewer (chia sẻ xem)
async function loadTask(req, res, next) {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) {
      return res.status(404).json({ message: 'Không tìm thấy công việc' });
    }
    const task = await Task.findById(id);
    if (!task) return res.status(404).json({ message: 'Không tìm thấy công việc' });

    const userId = currentUserId(req);
    let role = null;
    if (sameId(task.createdBy, userId)) {
      role = 'owner';
    } else {
      const share = await TaskShare.findOne({ taskId: task._id, userId }).lean();
      if (share && share.permission === 'editor') role = 'editor';
      else if (task.assigneeIds.some((u) => sameId(u, userId))) role = 'assignee';
      else if (share) role = 'viewer';
    }
    // Không tiết lộ công việc có tồn tại hay không
    if (!role) return res.status(404).json({ message: 'Không tìm thấy công việc' });

    req.task = task;
    req.taskRole = role;
    req.currentUserId = userId;
    next();
  } catch (err) {
    next(err);
  }
}

const requireRole = (...roles) => (req, res, next) =>
  roles.includes(req.taskRole)
    ? next()
    : res.status(403).json({ message: 'Bạn không có quyền thực hiện thao tác này' });

module.exports = { loadTask, requireRole, currentUserId };
