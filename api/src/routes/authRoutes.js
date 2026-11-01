const express = require('express');
const auth = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.post('/register', auth.register);
router.post('/login', auth.login);
router.get('/me', authMiddleware, auth.getMe);
router.put('/me', authMiddleware, auth.updateMe);
router.put('/change-password', authMiddleware, auth.changePassword);

module.exports = router;
