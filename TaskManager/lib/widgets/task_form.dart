import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../utils/date_formatter.dart';
import '../utils/validators.dart';

/// Form dùng chung cho màn hình Thêm và Chỉnh sửa công việc.
class TaskForm extends StatefulWidget {
  final Task? initial;
  final String submitLabel;
  final Future<void> Function({
    required String title,
    required String description,
    required DateTime? startDate,
    required DateTime? dueDate,
    required String priority,
    required String status,
  }) onSubmit;

  const TaskForm({
    super.key,
    this.initial,
    required this.submitLabel,
    required this.onSubmit,
  });

  @override
  State<TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  DateTime? _start;
  DateTime? _due;
  late String _priority;
  late String _status;
  bool _saving = false;
  String? _dateError;

  @override
  void initState() {
    super.initState();
    final t = widget.initial;
    _titleCtrl = TextEditingController(text: t?.title ?? '');
    _descCtrl = TextEditingController(text: t?.description ?? '');
    _start = t?.startDate;
    _due = t?.dueDate;
    _priority = t?.priority ?? TaskPriority.medium;
    _status = t?.status ?? TaskStatus.todo;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initial = (isStart ? _start : _due) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        // Hạn hoàn thành tính đến cuối ngày.
        _due = DateTime(picked.year, picked.month, picked.day, 23, 59);
      }
      _dateError = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start != null && _due != null && _due!.isBefore(_start!)) {
      setState(() => _dateError = 'Hạn hoàn thành phải sau ngày bắt đầu');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(
        title: _titleCtrl.text,
        description: _descCtrl.text,
        startDate: _start,
        dueDate: _due,
        priority: _priority,
        status: _status,
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text(e.message),
              backgroundColor: Theme.of(context).colorScheme.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateTile(String label, DateTime? value, VoidCallback onTap,
      VoidCallback onClear) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          suffixIcon: value == null
              ? null
              : IconButton(icon: const Icon(Icons.clear), onPressed: onClear),
        ),
        child: Text(value == null ? 'Chọn ngày' : DateFormatter.date(value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _titleCtrl,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Tên công việc *',
              prefixIcon: Icon(Icons.title),
            ),
            validator: (v) => Validators.requiredField(v, 'Tên công việc'),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Mô tả',
              alignLabelWithHint: true,
              prefixIcon: Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.notes),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _dateTile('Ngày bắt đầu', _start, () => _pickDate(isStart: true),
              () => setState(() => _start = null)),
          const SizedBox(height: 16),
          _dateTile('Hạn hoàn thành', _due, () => _pickDate(isStart: false),
              () => setState(() => _due = null)),
          if (_dateError != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 12),
              child: Text(_dateError!,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error, fontSize: 12)),
            ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _priority,
            decoration: const InputDecoration(
              labelText: 'Mức độ ưu tiên',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
            items: TaskPriority.all
                .map((p) =>
                    DropdownMenuItem(value: p, child: Text(TaskPriority.label(p))))
                .toList(),
            onChanged: (v) => setState(() => _priority = v ?? _priority),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: _status,
            decoration: const InputDecoration(
              labelText: 'Trạng thái',
              prefixIcon: Icon(Icons.timelapse),
            ),
            items: TaskStatus.all
                .map((s) =>
                    DropdownMenuItem(value: s, child: Text(TaskStatus.label(s))))
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(widget.submitLabel),
            ),
          ),
        ],
      ),
    );
  }
}
