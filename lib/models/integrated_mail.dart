enum MailSource { gmail, naver, daum }

class IntegratedMail {
  final MailSource source;
  final String id;
  final String subject;
  final String sender;
  final DateTime dateTime;
  final String body;
  final bool isRead;

  IntegratedMail({
    required this.source,
    required this.id,
    required this.subject,
    required this.sender,
    required this.dateTime,
    required this.body,
    this.isRead = false,
  });
}
