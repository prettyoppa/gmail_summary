/// 메일 리스트와 동일하게 `yyyy/MM/dd HH:mm` 형식으로 수신 시각을 만듭니다.
String formatEmailReceivedAt(Map<String, dynamic> email) {
  final dynamic ts = email['timestamp'];
  if (ts is! DateTime) return '';
  final DateTime dt = ts;
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final min = dt.minute.toString().padLeft(2, '0');
  return '${dt.year}/$m/$d $h:$min';
}
