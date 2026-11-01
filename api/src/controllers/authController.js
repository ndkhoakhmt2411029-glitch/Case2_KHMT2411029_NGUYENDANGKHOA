const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const {
  validateRegister,
  validateLogin,
  validateUpdateProfile,
  validateChangePassword,
} = require('../validators/authValidator');

function signToken(user) {
  return jwt.sign({ id: user._id.toString() }, process.env.JWT_SECRET, {
    expiresIn: process.env.JWT_EXPIRES_IN || '7d',
  });
}

// POST /auth/register
exports.register = async (req, res, next) => {
  try {
    const error = validateRegister(req.body);
    if (error) return res.status(400).json({ message: error });

    const email = req.body.email.trim().toLowerCase();
    if (await User.findOne({ email })) {
      return res.status(409).json({ message: 'Email đã được sử dụng' });
    }

    const passwordHash = await bcrypt.hash(req.body.password, 10);
    const user = await User.create({
      fullName: req.body.fullName.trim(),
      email,
      passwordHash,
    });

    res.status(201).json({ token: signToken(user), user });
  } catch (err) {
    next(err);
  }
};

// POST /auth/login
exports.login = async (req, res, next) => {
  try {
    const error = validateLogin(req.body);
    if (error) return res.status(400).json({ message: error });

    const email = req.body.email.trim().toLowerCase();
    const user = await User.findOne({ email });
    const ok = user && (await bcrypt.compare(req.body.password, user.passwordHash));
    if (!ok) {
      return res.status(401).json({ message: 'Email hoặc mật khẩu không đúng' });
    }

    res.json({ token: signToken(user), user });
  } catch (err) {
    next(err);
  }
};

// GET /auth/me
exports.getMe = (req, res) => {
  res.json({ user: req.user });
};

// PUT /auth/me
exports.updateMe = async (req, res, next) => {
  try {
    const error = validateUpdateProfile(req.body);
    if (error) return res.status(400).json({ message: error });

    req.user.fullName = req.body.fullName.trim();
    if (req.body.avatarUrl !== undefined) req.user.avatarUrl = req.body.avatarUrl;
    await req.user.save();

    res.json({ user: req.user });
  } catch (err) {
    next(err);
  }
};

// PUT /auth/change-password
exports.changePassword = async (req, res, next) => {
  try {
    const error = validateChangePassword(req.body);
    if (error) return res.status(400).json({ message: error });

    const match = await bcrypt.compare(
      req.body.currentPassword,
      req.user.passwordHash
    );
    if (!match) {
      return res.status(400).json({ message: 'Mật khẩu hiện tại không đúng' });
    }

    req.user.passwordHash = await bcrypt.hash(req.body.newPassword, 10);
    await req.user.save();

    res.json({ message: 'Đổi mật khẩu thành công' });
  } catch (err) {
    next(err);
  }
};
