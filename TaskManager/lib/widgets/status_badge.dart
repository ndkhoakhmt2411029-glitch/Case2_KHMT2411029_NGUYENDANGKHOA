import 'package:flutter/material.dart';

import '../models/task.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  static Color color(String status) {
    switch (status) {
      case TaskStatus.inProgress:
        return Colors.blue;
      case TaskStatus.completed:
        return Colors.green;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final c = color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.5)),
      ),
      child: Text(TaskStatus.label(status),
          style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
    );
  }
}
