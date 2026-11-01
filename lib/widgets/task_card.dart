import 'package:flutter/material.dart';

import '../models/task.dart';
import '../utils/date_formatter.dart';
import 'priority_badge.dart';
import 'status_badge.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final VoidCallback onTap;
  const TaskCard({super.key, required this.task, required this.onTap});

  static String roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Của tôi';
      case 'assignee':
        return 'Được giao';
      case 'editor':
        return 'Chia sẻ (sửa)';
      case 'viewer':
        return 'Chia sẻ (xem)';
    }
    return role;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final overdue = task.isOverdue;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: task.status == TaskStatus.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(status: task.status),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PriorityBadge(priority: task.priority),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.event,
                        size: 14,
                        color: overdue ? theme.colorScheme.error : Colors.grey),
                    const SizedBox(width: 3),
                    Text(
                      overdue
                          ? 'Quá hạn ${DateFormatter.date(task.dueDate)}'
                          : 'Hạn ${DateFormatter.date(task.dueDate)}',
                      style: TextStyle(
                          fontSize: 12,
                          color: overdue ? theme.colorScheme.error : null),
                    ),
                  ]),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.person_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 3),
                    Text(roleLabel(task.myRole),
                        style: const TextStyle(fontSize: 12)),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
