import 'package:flutter/material.dart';

import '../models/task.dart';

class PriorityBadge extends StatelessWidget {
  final String priority;
  const PriorityBadge({super.key, required this.priority});

  Color get _color {
    switch (priority) {
      case TaskPriority.high:
        return Colors.red;
      case TaskPriority.medium:
        return Colors.orange;
      default:
        return Colors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag, size: 16, color: _color),
        const SizedBox(width: 2),
        Text(
          TaskPriority.label(priority),
          style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
