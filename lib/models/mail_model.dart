// lib/models/mail_model.dart

class MailModel {
  final String subject;
  final String from;
  final String body;
  final String date;

  MailModel({
    required this.subject,
    required this.from,
    required this.body,
    required this.date,
  });

  // Map 데이터를 MailModel 객체로 변환하는 생성자
  factory MailModel.fromMap(Map<String, String> map) {
    return MailModel(
      subject: map['subject'] ?? "제목 없음",
      from: map['from'] ?? "알 수 없는 발신자",
      body: map['body'] ?? "",
      date: map['date'] ?? "",
    );
  }
}
