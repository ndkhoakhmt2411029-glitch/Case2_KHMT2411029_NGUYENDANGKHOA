// Kiểm thử tích hợp: gọi API thật của backend (cần backend + MongoDB đang chạy).
// Cách chạy (trong thư mục api):   node scripts/integrationTest.js [http://localhost:3000/api]
// Script tự tạo 3 tài khoản ngẫu nhiên và dữ liệu thử; không xóa tài khoản (xóa tay trong Atlas nếu cần).
const BASE = process.argv[2] || 'http://localhost:3000/api';
const stamp = Date.now();
let passed = 0;
let failed = 0;

async function call(method, path, token, body) {
  const res = await fetch(BASE + path, {
    method,
    headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    body: body ? JSON.stringify(body) : undefined,
  });
  let data = {};
  try { data = await res.json(); } catch (_) { /* không có body */ }
  return { status: res.status, data };
}

function check(name, cond, extra = '') {
  if (cond) { passed += 1; console.log(`  PASS  ${name}`); }
  else { failed += 1; console.log(`  FAIL  ${name} ${extra}`); }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function register(label) {
  const email = `test_${label}_${stamp}@example.com`;
  const r = await call('POST', '/auth/register', null, { fullName: `Test ${label}`, email, password: '123456' });
  return { email, token: r.data.token, id: r.data.user && (r.data.user._id || r.data.user.id), status: r.status };
}

(async () => {
  console.log(`Kiểm thử tích hợp: ${BASE}\n`);

  console.log('1) Tài khoản & xác thực');
  const A = await register('owner');
  const B = await register('assignee');
  const C = await register('viewer');
  check('Đăng ký 3 tài khoản', [A, B, C].every((u) => u.token), `(status ${A.status})`);
  const login = await call('POST', '/auth/login', null, { email: A.email, password: '123456' });
  check('Đăng nhập trả về token', !!login.data.token);
  check('API riêng tư không có token -> 401', (await call('GET', '/tasks')).status === 401);

  console.log('\n2) Thêm / sửa / xóa & phân quyền người tạo');
  const created = await call('POST', '/tasks', A.token, { title: 'Viết báo cáo', priority: 'high', dueDate: new Date(Date.now() + 2 * 86400000).toISOString() });
  const taskId = created.data.task && created.data.task._id;
  check('Tạo công việc (201)', created.status === 201 && !!taskId);
  check('Thiếu tên -> 400', (await call('POST', '/tasks', A.token, { title: '' })).status === 400);
  check('Người lạ xem công việc -> 404', (await call('GET', `/tasks/${taskId}`, B.token)).status === 404);
  const upd = await call('PUT', `/tasks/${taskId}`, A.token, { title: 'Viết báo cáo tuần', priority: 'high' });
  check('Sửa công việc', upd.status === 200 && upd.data.task.title === 'Viết báo cáo tuần');

  console.log('\n3) Giao việc nhiều người');
  const asg = await call('POST', `/tasks/${taskId}/assignees`, A.token, { emails: [B.email], primaryEmail: B.email });
  check('Giao việc cho B (201)', asg.status === 201 && asg.data.assignees.length === 1);
  check('B là người phụ trách chính', asg.data.assignees[0] && asg.data.assignees[0].isPrimary === true);
  check('Giao cho email không tồn tại -> 400', (await call('POST', `/tasks/${taskId}/assignees`, A.token, { emails: ['khong.co@example.com'] })).status === 400);
  const bList = await call('GET', '/tasks?scope=assigned', B.token);
  check('B thấy việc trong mục "Được giao"', bList.data.tasks && bList.data.tasks.some((t) => t._id === taskId));

  console.log('\n4) Chia sẻ viewer / editor và kiểm tra quyền');
  const sh = await call('POST', `/tasks/${taskId}/shares`, A.token, { items: [{ email: C.email, permission: 'viewer' }] });
  check('Chia sẻ viewer cho C (201)', sh.status === 201);
  const shareId = sh.data.shares && sh.data.shares[0] && sh.data.shares[0]._id;
  check('C (viewer) xem được', (await call('GET', `/tasks/${taskId}`, C.token)).status === 200);
  check('C (viewer) sửa -> 403', (await call('PUT', `/tasks/${taskId}`, C.token, { title: 'x' })).status === 403);
  check('C (viewer) đổi trạng thái -> 403', (await call('PATCH', `/tasks/${taskId}/status`, C.token, { status: 'completed' })).status === 403);
  check('C (viewer) xóa -> 403', (await call('DELETE', `/tasks/${taskId}`, C.token)).status === 403);
  check('Đổi quyền C thành editor', (await call('PATCH', `/tasks/${taskId}/shares/${shareId}`, A.token, { permission: 'editor' })).status === 200);
  check('C (editor) sửa được', (await call('PUT', `/tasks/${taskId}`, C.token, { title: 'Viết báo cáo tuần (C sửa)' })).status === 200);
  check('C (editor) xóa -> 403', (await call('DELETE', `/tasks/${taskId}`, C.token)).status === 403);
  check('C (editor) quản lý chia sẻ -> 403', (await call('POST', `/tasks/${taskId}/shares`, C.token, { items: [{ email: B.email, permission: 'viewer' }] })).status === 403);
  check('B (assignee) sửa nội dung -> 403', (await call('PUT', `/tasks/${taskId}`, B.token, { title: 'y' })).status === 403);

  console.log('\n5) Thông báo trong ứng dụng & email');
  await sleep(2500); // thông báo/email chạy nền
  const nB = await call('GET', '/notifications', B.token);
  check('B nhận thông báo giao việc', nB.data.notifications && nB.data.notifications.some((n) => n.type === 'task_assigned'));
  const nC = await call('GET', '/notifications', C.token);
  check('C nhận thông báo chia sẻ', nC.data.notifications && nC.data.notifications.some((n) => n.type === 'task_shared'));
  const logsB = await call('GET', '/notifications/email-logs', B.token);
  check('Có lịch sử email cho B (email_logs)', logsB.data.emailLogs && logsB.data.emailLogs.length > 0);
  if (logsB.data.emailLogs && logsB.data.emailLogs[0]) {
    const l = logsB.data.emailLogs[0];
    console.log(`        email_logs: trạng thái=${l.status}, số lần thử=${l.attempts}${l.errorMessage ? `, lỗi="${l.errorMessage}"` : ''}`);
  }
  const first = nB.data.notifications && nB.data.notifications[0];
  if (first) {
    check('Đánh dấu đã đọc', (await call('PATCH', `/notifications/${first._id}/read`, B.token)).status === 200);
    const cnt = await call('GET', '/notifications/unread-count', B.token);
    check('Đếm chưa đọc giảm', cnt.data.unreadCount === (nB.data.unreadCount - 1));
  }
  check('Người khác không đọc được thông báo của B -> 404', first ? (await call('PATCH', `/notifications/${first._id}/read`, C.token)).status === 404 : false);

  console.log('\n6) Đổi trạng thái -> thông báo cho người tạo');
  check('B (assignee) đổi trạng thái', (await call('PATCH', `/tasks/${taskId}/status`, B.token, { status: 'completed' })).status === 200);
  await sleep(1500);
  const nA = await call('GET', '/notifications', A.token);
  check('A nhận thông báo hoàn thành', nA.data.notifications && nA.data.notifications.some((n) => n.type === 'task_completed'));

  console.log('\n7) Tìm kiếm, lọc, sắp xếp');
  await call('POST', '/tasks', A.token, { title: 'Thiết kế giao diện', priority: 'low' });
  check('Tìm theo tên', (await call('GET', '/tasks?q=giao%20di%E1%BB%87n', A.token)).data.tasks.length === 1);
  check('Lọc theo trạng thái completed', (await call('GET', '/tasks?status=completed', A.token)).data.tasks.every((t) => t.status === 'completed'));
  check('Lọc theo mức ưu tiên high', (await call('GET', '/tasks?priority=high', A.token)).data.tasks.every((t) => t.priority === 'high'));
  const sorted = (await call('GET', '/tasks?sortBy=priority&order=desc', A.token)).data.tasks.map((t) => t.priority);
  const rank = { low: 1, medium: 2, high: 3 };
  check('Sắp xếp theo ưu tiên giảm dần', sorted.every((p, i) => i === 0 || rank[sorted[i - 1]] >= rank[p]));

  console.log('\n8) Thống kê');
  const st = await call('GET', '/stats/summary', A.token);
  check('Thống kê trả về số liệu', st.status === 200 && st.data.byStatus && st.data.byStatus.total === 2);
  check('Tổng theo trạng thái khớp', st.data.byStatus.completed === 1 && st.data.byStatus.todo === 1);
  check('Có mục quá hạn / sắp đến hạn', Array.isArray(st.data.overdue) && Array.isArray(st.data.dueSoon));
  const stB = await call('GET', '/stats/summary', B.token);
  check('Thống kê của B: được giao 1, phụ trách chính 1', stB.data.assignedToMe.total === 1 && stB.data.primaryByMe.total === 1);

  console.log('\n9) Thu hồi quyền và xóa');
  check('Thu hồi quyền của C', (await call('DELETE', `/tasks/${taskId}/shares/${shareId}`, A.token)).status === 200);
  check('C không còn truy cập -> 404', (await call('GET', `/tasks/${taskId}`, C.token)).status === 404);
  check('Hủy giao việc cho B', (await call('DELETE', `/tasks/${taskId}/assignees/${B.id}`, A.token)).status === 200);
  check('Người tạo xóa công việc', (await call('DELETE', `/tasks/${taskId}`, A.token)).status === 200);

  console.log(`\nKết quả: ${passed} đạt, ${failed} lỗi`);
  process.exit(failed ? 1 : 0);
})().catch((e) => { console.error('Không chạy được kiểm thử:', e.message); process.exit(1); });
