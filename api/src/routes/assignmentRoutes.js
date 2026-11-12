const express = require('express');
const controller = require('../controllers/assignmentController');
const requireAuth = require('../middleware/requireAuth');
const { loadTask, requireRole } = require('../middleware/permissionMiddleware');

// Gắn tại /api/tasks/:id/assignees
const router = express.Router({ mergeParams: true });

router.use(requireAuth, loadTask);

router.get('/', controller.listAssignees);
router.post('/', requireRole('owner', 'editor'), controller.addAssignees);
router.patch('/:userId', requireRole('owner', 'editor'), controller.setPrimary);
router.delete('/:userId', requireRole('owner', 'editor'), controller.removeAssignee);

module.exports = router;
