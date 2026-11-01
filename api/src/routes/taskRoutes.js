const express = require('express');
const tasks = require('../controllers/taskController');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.use(authMiddleware);

router.get('/', tasks.list);
router.post('/', tasks.create);
router.get('/:id', tasks.getOne);
router.put('/:id', tasks.update);
router.delete('/:id', tasks.remove);
router.patch('/:id/status', tasks.updateStatus);

module.exports = router;
