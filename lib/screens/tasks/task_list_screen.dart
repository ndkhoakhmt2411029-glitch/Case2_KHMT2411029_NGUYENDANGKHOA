import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';

/// Màn hình tạm cho Phần A: hiển thị người dùng đã đăng nhập.

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  final _auth = AuthService();
  User? _user;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final u = await _auth.getMe();
      if (mounted) setState(() => _user = u);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _auth.logout();
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Công việc'),
        actions: [
          IconButton(
            tooltip: 'Cá nhân',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () async {
              await Navigator.of(context).pushNamed('/profile');
              if (mounted) _load();
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      const SizedBox(height: 8),
                      OutlinedButton(onPressed: _load, child: const Text('Thử lại')),
                    ],
                  ),
                )
              : Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Xin chào, ${_user?.fullName ?? ''}!\n(${_user?.email ?? ''}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
    );
  }
}
