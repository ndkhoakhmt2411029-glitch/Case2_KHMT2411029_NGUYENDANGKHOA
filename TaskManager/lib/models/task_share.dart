/// Thông tin một người dùng (dùng cho giao việc và chia sẻ).
class PersonRef {
  final String id; // rỗng nếu mới chỉ nhập email
  final String fullName;
  final String email;
  final String? avatarUrl;

  const PersonRef({
    required this.id,
    this.fullName = '',
    required this.email,
    this.avatarUrl,
  });

  String get label => fullName.isNotEmpty ? fullName : email;

  factory PersonRef.fromJson(Map<String, dynamic> j) => PersonRef(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        fullName: (j['fullName'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        avatarUrl: j['avatarUrl']?.toString(),
      );
}

/// Người được giao việc.
class Assignee {
  final PersonRef person;
  final bool isPrimary;
  const Assignee({required this.person, required this.isPrimary});
}

/// Một bản ghi chia sẻ (collection task_shares).
class TaskShare {
  static const viewer = 'viewer';
  static const editor = 'editor';
  static const permissions = [viewer, editor];

  static String permissionLabel(String p) =>
      p == editor ? 'Chỉnh sửa (editor)' : 'Chỉ xem (viewer)';

  final String id;
  final String permission;
  final PersonRef? user;
  final DateTime? createdAt;

  const TaskShare({
    required this.id,
    required this.permission,
    this.user,
    this.createdAt,
  });

  factory TaskShare.fromJson(Map<String, dynamic> j) => TaskShare(
        id: (j['_id'] ?? j['id'] ?? '').toString(),
        permission: (j['permission'] ?? viewer).toString(),
        user: j['user'] is Map<String, dynamic>
            ? PersonRef.fromJson(j['user'] as Map<String, dynamic>)
            : null,
        createdAt: j['createdAt'] == null
            ? null
            : DateTime.tryParse(j['createdAt'].toString())?.toLocal(),
      );
}
