// Collection email_logs (đề mục 4.5): lịch sử gửi email và trạng thái.
const mongoose = require('mongoose');

const emailLogSchema = new mongoose.Schema(
  {
    taskId: { type: mongoose.Schema.Types.ObjectId, ref: 'Task', default: null },
    recipientEmail: { type: String, required: true, index: true },
    eventType: { type: String, required: true },
    subject: { type: String, required: true },
    status: { type: String, enum: ['pending', 'sent', 'failed'], default: 'pending' },
    attempts: { type: Number, default: 0 },
    errorMessage: { type: String, default: '' },
    sentAt: { type: Date, default: null },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

module.exports = mongoose.models.EmailLog || mongoose.model('EmailLog', emailLogSchema);
