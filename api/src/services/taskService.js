const TaskShare = require('../models/TaskShare');

const idOf = (v) => String(v && v._id ? v._id : v);

// Vai trò của người dùng trên một công việc: owner | editor | assignee | viewer | null
function resolveRole(task, userId, share) {
  const uid = String(userId);
  if (idOf(task.createdBy) === uid) return 'owner';
  if (share && share.permission === 'editor') return 'editor';
  if ((task.assigneeIds || []).some((a) => idOf(a) === uid)) return 'assignee';
  if (share) return 'viewer';
  return null;
}

// Quyền theo đề: viewer chỉ xem; editor không được xóa hay quản lý chia sẻ.
function permissionsFor(role) {
  return {
    canEdit: role === 'owner' || role === 'editor',
    canDelete: role === 'owner',
    canChangeStatus: ['owner', 'editor', 'assignee'].includes(role),
    canManageShares: role === 'owner',
  };
}

async function getRole(task, userId) {
  const share = await TaskShare.findOne({ taskId: task._id, userId });
  return resolveRole(task, userId, share);
}

function serialize(task, role) {
  const obj = task.toJSON();
  obj.myRole = role;
  obj.permissions = permissionsFor(role);
  return obj;
}

module.exports = { resolveRole, permissionsFor, getRole, serialize };
