import 'package:flutter/material.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/tasks/task_list_screen.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';

class TaskManagerApp extends StatelessWidget {
  const TaskManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const _Splash(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/tasks': (_) => const TaskListScreen(),
        '/profile': (_) => const ProfileScreen(),
      },
    );
  }
}

/// Kiểm tra token đã lưu: còn hợp lệ -> vào danh sách công việc, ngược lại -> đăng nhập.
class _Splash extends StatefulWidget {
  const _Splash();

  @override
  State<_Splash> createState() => _SplashState();
}

class _SplashState extends State<_Splash> {
  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final auth = AuthService();
    String route = '/login';
    if (await auth.hasToken()) {
      try {
        await auth.getMe();
        route = '/tasks';
      } on ApiException catch (e) {
        if (e.statusCode == 401) await auth.logout();
      }
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(route);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
