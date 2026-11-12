const mongoose = require('mongoose');
const User = require('../models/User');

const FIELDS = 'fullName email avatarUrl';

// GET /users/search?q=  → tìm theo tên hoặc email
exports.searchUsers = async (req, res, next) => {
  try {
    const q = String(req.query.q || '').trim();
    if (q.length < 2) return res.json({ users: [] });

    const safe = q.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const regex = new RegExp(safe, 'i');
    const me = String((req.user && (req.user._id || req.user.id)) || req.userId || '');
    const filter = { $or: [{ fullName: regex }, { email: regex }] };
    if (mongoose.isValidObjectId(me)) filter._id = { $ne: me };

    const users = await User.find(filter).select(FIELDS).limit(10);
    res.json({ users });
  } catch (err) {
    next(err);
  }
};

// GET /users/:id  → thông tin công khai
exports.getUser = async (req, res, next) => {
  try {
    const { id } = req.params;
    if (!mongoose.isValidObjectId(id)) {
      return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    }
    const user = await User.findById(id).select(FIELDS);
    if (!user) return res.status(404).json({ message: 'Không tìm thấy người dùng' });
    res.json({ user });
  } catch (err) {
    next(err);
  }
};
