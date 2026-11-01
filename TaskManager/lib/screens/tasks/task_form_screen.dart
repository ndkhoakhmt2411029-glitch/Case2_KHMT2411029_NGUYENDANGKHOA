import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../services/api_client.dart';
import '../../services/task_service.dart';
import '../../utils/date_formatter.dart';
import '../../utils/validators.dart';

/// Dùng chung cho Thêm công việc (task == null) và Chỉnh sửa (task != null).
/// Pop với giá trị true khi đã lưu thành công.
class TaskFormScreen extends StatefulWidget {
  final Task? task;
  const TaskFormScreen({super.key, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = TaskService();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  DateTime? _start;
  DateTime? _due;
  late String _priority;
  late String _status;
  bool _saving = false;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
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
    final current = isStart ? _start : _due;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
      } else {
        // Hạn hoàn thành mặc định đến hết ngày được chọn
        _due = DateTime(picked.year, picked.month, picked.day, 23, 59);
      }
    });
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_start != null && _due != null && _due!.isBefore(_start!)) {
      _snack('Hạn hoàn thành phải sau hoặc bằng ngày bắt đầu', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      if (_isEdit) {
        await _service.updateTask(widget.task!.id,
            title: _titleCtrl.text,
            description: _descCtrl.text,
            startDate: _start,
            dueDate: _due,
            priority: _priority,
            status: _status);
      } else {
        await _service.createTask(
            title: _titleCtrl.text,
            description: _descCtrl.text,
            startDate: _start,
            dueDate: _due,
            priority: _priority,
            status: _status);
      }
      if (!mounted) return;
      _snack(_isEdit ? 'Đã cập nhật công việc' : 'Đã tạo công việc');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _dateField(String label, DateTime? value, bool isStart) {
    return InkWell(
      onTap: () => _pickDate(isStart: isStart),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.event),
          suffixIcon: value == null
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () =>
                      setState(() => isStart ? _start = null : _due = null),
                ),
        ),
        child: Text(DateFormatter.date(value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Chỉnh sửa công việc' : 'Thêm công việc')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      textInputAction: TextInputAction.next,
                      maxLength: 200,
                      decoration: const InputDecoration(
                        labelText: 'Tên công việc',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (v) => Validators.requiredField(v, 'Tên công việc'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descCtrl,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Mô tả',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _dateField('Ngày bắt đầu', _start, true),
                    const SizedBox(height: 16),
                    _dateField('Hạn hoàn thành', _due, false),
                    const SizedBox(height: 20),
                    const Text('Mức độ ưu tiên'),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        for (final p in TaskPriority.all)
                          ButtonSegment(value: p, label: Text(TaskPriority.label(p))),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (s) => setState(() => _priority = s.first),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: InputDecoration(
                        labelText: _isEdit ? 'Trạng thái' : 'Trạng thái ban đầu',
                        prefixIcon: const Icon(Icons.flag_outlined),
                      ),
                      items: [
                        for (final s in TaskStatus.all)
                          DropdownMenuItem(value: s, child: Text(TaskStatus.label(s))),
                      ],
                      onChanged: (v) => setState(() => _status = v ?? _status),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_isEdit ? 'Lưu thay đổi' : 'Tạo công việc'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
