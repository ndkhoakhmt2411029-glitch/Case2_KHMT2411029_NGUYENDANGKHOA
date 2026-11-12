const express = require('express');
const controller = require('../controllers/taskShareController');
const requireAuth = require('../middleware/requireAuth');
const { loadTask, requireRole } = require('../middleware/permissionMiddleware');

// Gắn tại /api/tasks/:id/shares
const router = express.Router({ mergeParams: true });

router.use(requireAuth, loadTask);

router.get('/', controller.listShares);
// Chỉ người tạo mới được quản lý chia sẻ (editor không mặc nhiên có quyền này)
router.post('/', requireRole('owner'), controller.addShares);
router.patch('/:shareId', requireRole('owner'), controller.updateShare);
router.delete('/:shareId', requireRole('owner'), controller.revokeShare);

module.exports = router;
