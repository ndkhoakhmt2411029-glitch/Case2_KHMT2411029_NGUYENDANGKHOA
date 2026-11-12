// Tạo vài công việc mẫu trong MongoDB để thử API GET (Buổi 1 chưa có chức năng thêm).
// Cách chạy (trong thư mục api):  node scripts/seedTasks.js email_da_dang_ky@gmail.com
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('../src/models/User');
const Task = require('../src/models/Task');

async function main() {
  const email = (process.argv[2] || '').trim().toLowerCase();
  if (!email) throw new Error('Cách dùng: node scripts/seedTasks.js <email>');
  await mongoose.connect(process.env.MONGODB_URI);
  const user = await User.findOne({ email });
  if (!user) throw new Error('Không tìm thấy người dùng ' + email);

  const day = 24 * 3600 * 1000;
  const now = Date.now();
  await Task.insertMany([
    { title: 'Viết báo cáo tuần', description: 'Tổng hợp tiến độ nhóm', createdBy: user._id,
      assigneeIds: [user._id], primaryAssigneeId: user._id, priority: 'high', status: 'in_progress',
      startDate: new Date(now), dueDate: new Date(now + 3 * day) },
    { title: 'Thiết kế màn hình đăng nhập', description: '', createdBy: user._id,
      priority: 'medium', status: 'todo', dueDate: new Date(now + 7 * day) },
    { title: 'Kiểm thử API', description: 'Thử các API bằng Postman', createdBy: user._id,
      priority: 'low', status: 'completed', dueDate: new Date(now - 2 * day) },
  ]);
  console.log('Đã tạo 3 công việc mẫu cho', email);
  await mongoose.disconnect();
}

main().catch((e) => { console.error(e.message); process.exit(1); });
