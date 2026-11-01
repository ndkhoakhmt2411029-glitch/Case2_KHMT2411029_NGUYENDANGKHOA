import 'package:flutter/material.dart';

import '../models/task.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge({super.key, required this.priority});

  static Color color(String priority) {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
    }
    return Colors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final c = color(priority);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag, size: 14, color: c),
        const SizedBox(width: 2),
        Text(TaskPriority.label(priority),
            style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
