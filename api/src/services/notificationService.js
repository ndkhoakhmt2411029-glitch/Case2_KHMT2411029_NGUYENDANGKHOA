// Tạo thông báo trong ứng dụng (notifications) và gửi email (email_logs) cho các sự kiện:
// giao việc, chia sẻ, đổi hạn hoàn thành, đổi trạng thái / hoàn thành.
// Các hàm notify* chạy nền (không chặn phản hồi API) và không bao giờ ném lỗi.
const Notification = require('../models/Notification');
const User = require('../models/User');
const { sendEmail } = require('./emailService');

const idOf = (x) => String(x && x._id ? x._id : x);
const fmtDate = (d) => (d ? new Date(d).toLocaleDateString('vi-VN') : 'chưa đặt');
const STATUS_LABEL = { todo: 'Chưa thực hiện', in_progress: 'Đang thực hiện', completed: 'Đã hoàn thành' };

async function nameOf(userId) {
  const u = await User.findById(idOf(userId)).select('fullName email');
  return u ? u.fullName || u.email : 'Một người dùng';
}

// Gửi cho từng người nhận (trừ người thực hiện hành động).
async function deliver({ task, actorId, recipientIds, type, title, message, email }) {
  const ids = [...new Set(recipientIds.map(idOf))].filter((i) => i && i !== idOf(actorId));
  if (!ids.length) return;
  const users = await User.find({ _id: { $in: ids } }).select('email fullName');
  await Promise.all(
    users.map(async (u) => {
      await Notification.create({ userId: u._id, taskId: task._id, type, title, message });
      if (email) {
        await sendEmail({
          to: u.email,
          subject: email.subject,
          text: `Xin chào ${u.fullName || u.email},\n\n${email.body}\n\nTask Manager`,
          taskId: task._id,
          eventType: type,
        });
      }
    })
  );
}

const safe = (fn) => (...args) =>
  fn(...args).catch((err) => console.error('Lỗi thông báo:', err.message));

// Giao việc cho người mới
exports.notifyAssigned = safe(async (task, users, actorId) => {
  const actor = await nameOf(actorId);
  await deliver({
    task,
    actorId,
    recipientIds: users.map((u) => u._id),
    type: 'task_assigned',
    title: 'Bạn được giao công việc mới',
    message: `${actor} đã giao cho bạn: ${task.title}`,
    email: {
      subject: `[Task Manager] Bạn được giao công việc: ${task.title}`,
      body: `${actor} đã giao cho bạn công việc "${task.title}".\nHạn hoàn thành: ${fmtDate(task.dueDate)}.`,
    },
  });
});

// Chia sẻ / mời xem công việc. targets = [{ user, permission }]
exports.notifyShared = safe(async (task, targets, actorId) => {
  const actor = await nameOf(actorId);
  await Promise.all(
    targets.map((t) => {
      const role = t.permission === 'editor' ? 'chỉnh sửa' : 'xem';
      return deliver({
        task,
        actorId,
        recipientIds: [t.user._id],
        type: 'task_shared',
        title: 'Công việc được chia sẻ với bạn',
        message: `${actor} đã chia sẻ "${task.title}" (quyền ${role})`,
        email: {
          subject: `[Task Manager] Bạn được mời ${role} công việc: ${task.title}`,
          body: `${actor} đã chia sẻ công việc "${task.title}" với bạn, quyền ${role}.`,
        },
      });
    })
  );
});

const stakeholders = (task) => [task.createdBy, ...(task.assigneeIds || [])];

// Đổi hạn hoàn thành
exports.notifyDueChanged = safe(async (task, oldDue, actorId) => {
  const actor = await nameOf(actorId);
  await deliver({
    task,
    actorId,
    recipientIds: stakeholders(task),
    type: 'task_due_changed',
    title: 'Hạn hoàn thành đã thay đổi',
    message: `${actor} đổi hạn "${task.title}": ${fmtDate(oldDue)} → ${fmtDate(task.dueDate)}`,
    email: {
      subject: `[Task Manager] Đổi hạn hoàn thành: ${task.title}`,
      body: `${actor} đã đổi hạn hoàn thành của "${task.title}" từ ${fmtDate(oldDue)} sang ${fmtDate(task.dueDate)}.`,
    },
  });
});

// Đổi trạng thái: thông báo trong ứng dụng cho mọi trạng thái; email khi hoàn thành.
exports.notifyStatusChanged = safe(async (task, oldStatus, actorId) => {
  const actor = await nameOf(actorId);
  const done = task.status === 'completed';
  await deliver({
    task,
    actorId,
    recipientIds: stakeholders(task),
    type: done ? 'task_completed' : 'task_status_changed',
    title: done ? 'Công việc đã hoàn thành' : 'Trạng thái công việc thay đổi',
    message: `${actor}: "${task.title}" ${STATUS_LABEL[oldStatus] || oldStatus} → ${STATUS_LABEL[task.status] || task.status}`,
    email: done
      ? {
          subject: `[Task Manager] Công việc đã hoàn thành: ${task.title}`,
          body: `${actor} đã đánh dấu công việc "${task.title}" là hoàn thành.`,
        }
      : null,
  });
});
