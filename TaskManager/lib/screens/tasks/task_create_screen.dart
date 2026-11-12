import 'package:flutter/material.dart';

import '../../services/task_service.dart';
import '../../widgets/task_form.dart';

class TaskCreateScreen extends StatelessWidget {
  const TaskCreateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final service = TaskService();
    return Scaffold(
      appBar: AppBar(title: const Text('Thêm công việc')),
      body: TaskForm(
        submitLabel: 'Tạo công việc',
        onSubmit: ({
          required title,
          required description,
          required startDate,
          required dueDate,
          required priority,
          required status,
        }) async {
          await service.createTask(
            title: title,
            description: description,
            startDate: startDate,
            dueDate: dueDate,
            priority: priority,
            status: status,
          );
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Đã tạo công việc')));
          Navigator.pop(context, true);
        },
      ),
    );
  }
}
