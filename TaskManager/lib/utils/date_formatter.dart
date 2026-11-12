class DateFormatter {
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// dd/MM/yyyy
  static String date(DateTime? d) {
    if (d == null) return '—';
    return '${_two(d.day)}/${_two(d.month)}/${d.year}';
  }

  /// dd/MM/yyyy HH:mm
  static String dateTime(DateTime? d) {
    if (d == null) return '—';
    return '${date(d)} ${_two(d.hour)}:${_two(d.minute)}';
  }
}
