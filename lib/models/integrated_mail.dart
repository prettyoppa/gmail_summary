import 'package:hive/hive.dart';

// ✅ 터미널에서 명령어를 실행하면 이 파일이 자동으로 생성됩니다.
part 'integrated_mail.g.dart';

@HiveType(typeId: 0)
enum MailSource {
  @HiveField(0)
  gmail,
  @HiveField(1)
  naver,
  @HiveField(2)
  daum,
}

@HiveType(typeId: 1)
class IntegratedMail extends HiveObject {
  @HiveField(0)
  final MailSource source;

  @HiveField(1)
  final String id;

  @HiveField(2)
  final String? threadId; // 👈 기존 필드 유지

  @HiveField(3)
  final String subject;

  @HiveField(4)
  final String sender;

  @HiveField(5)
  final DateTime dateTime;

  @HiveField(6)
  final String body;

  @HiveField(7)
  final bool isRead;

  @HiveField(8)
  final List<dynamic>? calendarEvents; // 👈 일정 감지 정보 저장용 추가

  IntegratedMail({
    required this.source,
    required this.id,
    this.threadId,
    required this.subject,
    required this.sender,
    required this.dateTime,
    required this.body,
    this.isRead = false,
    this.calendarEvents,
  });
}
