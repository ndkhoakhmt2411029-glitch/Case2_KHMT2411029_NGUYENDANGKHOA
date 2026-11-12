const express = require('express');
const controller = require('../controllers/taskController');
const authModule = require('../middleware/authMiddleware');

// Tương thích nhiều cách export của authMiddleware:
//   module.exports = fn            |  module.exports = { authMiddleware }
//   module.exports = { protect }   |  module.exports = { authenticate }
const auth =
  typeof authModule === 'function'
    ? authModule
    : authModule.authMiddleware ||
      authModule.protect ||
      authModule.authenticate ||
      authModule.auth ||
      authModule.verifyToken;

if (typeof auth !== 'function') {
  throw new Error('Không tìm thấy hàm xác thực trong middleware/authMiddleware.js');
}

const router = express.Router();

router.use(auth); // mọi API công việc đều cần token

router.get('/', controller.listTasks);
router.get('/:id', controller.getTask);

module.exports = router;
