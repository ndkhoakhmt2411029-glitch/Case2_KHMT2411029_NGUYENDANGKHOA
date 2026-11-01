const mongoose = require('mongoose');

// Dùng để kiểm tra quyền ở phần B; các API chia sẻ sẽ làm ở phần C.
const taskShareSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      required: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    permission: {
      type: String,
      enum: ['viewer', 'editor'],
      default: 'viewer',
    },
    sharedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

taskShareSchema.index({ taskId: 1, userId: 1 }, { unique: true });

module.exports = mongoose.model('TaskShare', taskShareSchema);
