const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const { currentUserId } = require('../middleware/permissionMiddleware');

const STATUSES = ['todo', 'in_progress', 'completed'];
const DAY = 24 * 3600 * 1000;

const counts = (tasks) => {
  const c = { total: tasks.length, todo: 0, in_progress: 0, completed: 0, percent: 0 };
  for (const t of tasks) if (STATUSES.includes(t.status)) c[t.status] += 1;
  c.percent = c.total ? Math.round((c.completed / c.total) * 100) : 0;
  return c;
};

const brief = (t) => ({
  _id: t._id,
  title: t.title,
  status: t.status,
  priority: t.priority,
  dueDate: t.dueDate,
});

// GET /stats/summary?days=3
//  - Tổng số công việc theo trạng thái (mọi công việc người dùng truy cập được)
//  - Công việc được giao cho tôi / tôi là người phụ trách chính
//  - Công việc sắp đến hạn (trong `days` ngày tới) và đã quá hạn
exports.summary = async (req, res, next) => {
  try {
    const me = currentUserId(req);
    const days = Math.min(Math.max(parseInt(req.query.days, 10) || 3, 1), 30);

    const sharedIds = await TaskShare.find({ userId: me }).distinct('taskId');
    const tasks = await Task.find({
      $or: [{ createdBy: me }, { assigneeIds: me }, { _id: { $in: sharedIds } }],
    })
      .select('title status priority dueDate assigneeIds primaryAssigneeId')
      .lean();

    const now = Date.now();
    const open = tasks.filter((t) => t.status !== 'completed' && t.dueDate);
    const byDue = (a, b) => new Date(a.dueDate) - new Date(b.dueDate);

    const overdue = open.filter((t) => new Date(t.dueDate).getTime() < now).sort(byDue);
    const dueSoon = open
      .filter((t) => {
        const d = new Date(t.dueDate).getTime();
        return d >= now && d <= now + days * DAY;
      })
      .sort(byDue);

    res.json({
      byStatus: counts(tasks),
      assignedToMe: counts(tasks.filter((t) => (t.assigneeIds || []).some((u) => String(u) === me))),
      primaryByMe: counts(tasks.filter((t) => t.primaryAssigneeId && String(t.primaryAssigneeId) === me)),
      dueSoonDays: days,
      dueSoon: dueSoon.slice(0, 20).map(brief),
      overdue: overdue.slice(0, 20).map(brief),
      overdueCount: overdue.length,
      dueSoonCount: dueSoon.length,
    });
  } catch (err) {
    next(err);
  }
};
