import 'dart:async';

import 'package:flutter/material.dart';

import '../models/task_share.dart';
import '../services/api_client.dart';
import '../services/user_service.dart';

/// Tìm người theo tên/email và chọn một hoặc nhiều người.
/// Nếu nhập một địa chỉ email chưa có trong kết quả, có thể thêm trực tiếp bằng email.
class UserSelector extends StatefulWidget {
  final List<PersonRef> selected;
  final Set<String> excludeIds;
  final ValueChanged<List<PersonRef>> onChanged;

  const UserSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.excludeIds = const {},
  });

  @override
  State<UserSelector> createState() => _UserSelectorState();
}

class _UserSelectorState extends State<UserSelector> {
  static final _emailRe = RegExp(r'^[\w\.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');

  final _ctrl = TextEditingController();
  final _service = UserService();
  Timer? _debounce;
  List<PersonRef> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  String _key(PersonRef p) => p.id.isNotEmpty ? p.id : p.email.toLowerCase();

  bool _isSelected(PersonRef p) =>
      widget.selected.any((s) => _key(s) == _key(p));

  void _toggle(PersonRef p) {
    final list = [...widget.selected];
    if (_isSelected(p)) {
      list.removeWhere((s) => _key(s) == _key(p));
    } else {
      list.add(p);
    }
    widget.onChanged(list);
  }

  void _onTextChanged(String text) {
    _debounce?.cancel();
    if (text.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
        _loading = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _search(text));
  }

  Future<void> _search(String text) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.search(text);
      if (!mounted) return;
      setState(() => _results =
          list.where((u) => !widget.excludeIds.contains(u.id)).toList());
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typed = _ctrl.text.trim();
    final canAddEmail = _emailRe.hasMatch(typed) &&
        !_results.any((u) => u.email.toLowerCase() == typed.toLowerCase()) &&
        !widget.selected.any((s) => s.email.toLowerCase() == typed.toLowerCase());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.selected.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final p in widget.selected)
                  InputChip(
                    label: Text(p.label),
                    onDeleted: () => _toggle(p),
                  ),
              ],
            ),
          ),
        TextField(
          controller: _ctrl,
          onChanged: (t) {
            setState(() {});
            _onTextChanged(t);
          },
          decoration: const InputDecoration(
            labelText: 'Tìm theo tên hoặc email',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        for (final u in _results)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 16,
              child: Text(u.label.isNotEmpty ? u.label[0].toUpperCase() : '?'),
            ),
            title: Text(u.label),
            subtitle: Text(u.email),
            trailing: Icon(
              _isSelected(u) ? Icons.check_circle : Icons.add_circle_outline,
              color: _isSelected(u) ? Colors.green : null,
            ),
            onTap: () => _toggle(u),
          ),
        if (canAddEmail)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.alternate_email),
            title: Text('Thêm bằng email: $typed'),
            onTap: () {
              _toggle(PersonRef(id: '', email: typed.toLowerCase()));
              _ctrl.clear();
              setState(() => _results = []);
            },
          ),
        if (!_loading &&
            _error == null &&
            typed.length >= 2 &&
            _results.isEmpty &&
            !canAddEmail)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Không tìm thấy người dùng phù hợp'),
          ),
      ],
    );
  }
}
