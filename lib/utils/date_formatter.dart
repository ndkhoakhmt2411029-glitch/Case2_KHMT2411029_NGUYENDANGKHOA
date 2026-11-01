class DateFormatter {
  static String _two(int n) => n.toString().padLeft(2, '0');

  /// dd/MM/yyyy, hoặc "Chưa đặt" nếu null
  static String date(DateTime? d, {String empty = 'Chưa đặt'}) {
    if (d == null) return empty;
    return '${_two(d.day)}/${_two(d.month)}/${d.year}';
  }

  static String dateTime(DateTime? d, {String empty = '—'}) {
    if (d == null) return empty;
    return '${date(d)} ${_two(d.hour)}:${_two(d.minute)}';
  }
}
