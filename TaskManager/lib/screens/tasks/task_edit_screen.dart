import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/task_service.dart';
import '../../widgets/task_form.dart';

class TaskEditScreen extends StatelessWidget {
  final Task task;
  const TaskEditScreen({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final service = TaskService();
    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa công việc')),
      body: TaskForm(
        initial: task,
        submitLabel: 'Lưu thay đổi',
        onSubmit: ({
          required title,
          required description,
          required startDate,
          required dueDate,
          required priority,
          required status,
        }) async {
          await service.updateTask(
            task.id,
            title: title,
            description: description,
            startDate: startDate,
            dueDate: dueDate,
            priority: priority,
            status: status,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã cập nhật công việc')));
          Navigator.pop(context, true);
        },
      ),
    );
  }
}
