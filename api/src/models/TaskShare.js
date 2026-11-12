// Collection task_shares (theo đề). Buổi 1 chỉ ĐỌC bảng này để biết công việc nào được chia sẻ cho người dùng.
const mongoose = require('mongoose');

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
    permission: { type: String, enum: ['viewer', 'editor'], default: 'viewer' },
    sharedBy: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  },
  { timestamps: { createdAt: true, updatedAt: false } }
);

taskShareSchema.index({ taskId: 1, userId: 1 }, { unique: true });

module.exports =
  mongoose.models.TaskShare || mongoose.model('TaskShare', taskShareSchema);
