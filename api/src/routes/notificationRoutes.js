const express = require('express');
const controller = require('../controllers/notificationController');
const requireAuth = require('../middleware/requireAuth');

const router = express.Router();
router.use(requireAuth);

router.get('/', controller.list);
router.get('/unread-count', controller.unreadCount);
router.get('/email-logs', controller.myEmailLogs);
router.patch('/read-all', controller.markAllRead);
router.patch('/:id/read', controller.markRead);

module.exports = router;
