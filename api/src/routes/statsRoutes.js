const express = require('express');
const controller = require('../controllers/statsController');
const requireAuth = require('../middleware/requireAuth');

const router = express.Router();
router.use(requireAuth);

router.get('/summary', controller.summary);

module.exports = router;
