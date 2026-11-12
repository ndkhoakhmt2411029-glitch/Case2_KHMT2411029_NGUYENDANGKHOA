const mongoose = require('mongoose');
const Notification = require('../models/Notification');
const EmailLog = require('../models/EmailLog');
const User = require('../models/User');
const { currentUserId } = require('../middleware/permissionMiddleware');

const fail = (res, status, message) => res.status(status).json({ message });

// GET /notifications?unread=true&limit=50
exports.list = async (req, res, next) => {
  try {
    const userId = currentUserId(req);
    const filter = { userId };
    if (req.query.unread === 'true') filter.isRead = false;
    const limit = Math.min(Math.max(parseInt(req.query.limit, 10) || 50, 1), 100);
    const [notifications, unreadCount] = await Promise.all([
      Notification.find(filter).sort({ createdAt: -1 }).limit(limit),
      Notification.countDocuments({ userId, isRead: false }),
    ]);
    res.json({ notifications, unreadCount });
  } catch (err) {
    next(err);
  }
};

// GET /notifications/unread-count
exports.unreadCount = async (req, res, next) => {
  try {
    const unreadCount = await Notification.countDocuments({
      userId: currentUserId(req),
      isRead: false,
    });
    res.json({ unreadCount });
  } catch (err) {
    next(err);
  }
};

// PATCH /notifications/read-all
exports.markAllRead = async (req, res, next) => {
  try {
    await Notification.updateMany({ userId: currentUserId(req), isRead: false }, { isRead: true });
    res.json({ unreadCount: 0 });
  } catch (err) {
    next(err);
  }
};

// PATCH /notifications/:id/read
exports.markRead = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) return fail(res, 404, 'Không tìm thấy thông báo');
    const n = await Notification.findOneAndUpdate(
      { _id: id, userId: currentUserId(req) },
      { isRead: true },
      { new: true }
    );
    if (!n) return fail(res, 404, 'Không tìm thấy thông báo');
    res.json({ notification: n });
  } catch (err) {
    next(err);
  }
};

// GET /notifications/email-logs  → lịch sử email gửi tới chính mình (để kiểm tra)
exports.myEmailLogs = async (req, res, next) => {
  try {
    const me = await User.findById(currentUserId(req)).select('email');
    const logs = await EmailLog.find({ recipientEmail: me ? me.email : '' })
      .sort({ createdAt: -1 })
      .limit(20);
    res.json({ emailLogs: logs });
  } catch (err) {
    next(err);
  }
};
