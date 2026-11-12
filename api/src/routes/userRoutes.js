const express = require('express');
const controller = require('../controllers/userController');
const requireAuth = require('../middleware/requireAuth');

const router = express.Router();

router.use(requireAuth);

router.get('/search', controller.searchUsers);
router.get('/:id', controller.getUser);

module.exports = router;
