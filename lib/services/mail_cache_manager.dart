import 'package:hive_flutter/hive_flutter.dart';
import '../models/integrated_mail.dart';
import 'package:flutter/foundation.dart';

class MailCacheManager {
  // ✅ 1. 고정 상수가 아닌, 현재 로그인한 계정에 따라 바뀔 변수로 선언합니다.
  static String _mailBoxName = 'mail_cache_box';
  static String _deletedIdsBoxName = 'deletedIdsBox';
  static String _settingsBoxName = 'settings_box';

  // ✅ 2. 초기화 로직 분리 (앱 시작 시 호출)
  static Future<void> setupHive() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MailSourceAdapter());
    if (!Hive.isAdapterRegistered(1))
      Hive.registerAdapter(IntegratedMailAdapter());
  }

  // ✅ 3. 계정별 박스 열기 (로그인 직후 호출)
  static Future<void> initUserBox(String userEmail) async {
    // 이메일 주소에서 특수문자를 제거하여 안전한 파일 이름 생성
    final String safeEmail = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');

    _mailBoxName = 'mail_cache_box_$safeEmail';
    _deletedIdsBoxName = 'deletedIdsBox_$safeEmail';
    _settingsBoxName = 'settings_box_$safeEmail';

    await Hive.openBox<IntegratedMail>(_mailBoxName);
    await Hive.openBox<String>(_deletedIdsBoxName);
    await Hive.openBox(_settingsBoxName);

    debugPrint("✅ Hive Box Open 완료 (계정: $userEmail)");
  }

  static Future<List<IntegratedMail>> getAllMails() async {
    final box = Hive.box<IntegratedMail>(_mailBoxName);
    return box.values.toList();
  }

  static Future<void> saveMails(List<IntegratedMail> newMails) async {
    final box = Hive.box<IntegratedMail>(_mailBoxName);
    final deletedBox = Hive.box<String>(_deletedIdsBoxName);

    for (var mail in newMails) {
      if (deletedBox.values.contains(mail.id)) continue;

      final filteredEvents = _filterPastEvents(mail.calendarEvents);

      final mailToSave = IntegratedMail(
        source: mail.source,
        id: mail.id,
        threadId: mail.threadId,
        subject: mail.subject,
        sender: mail.sender,
        dateTime: mail.dateTime,
        body: mail.body,
        isRead: mail.isRead,
        calendarEvents: filteredEvents,
      );

      await box.put(mail.id, mailToSave);
    }
    if (kIsWeb) await box.flush();

    if (box.length > 5000) {
      final allMails = box.values.toList();
      allMails.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      int toDeleteCount = box.length - 5000;
      for (int i = 0; i < toDeleteCount; i++) {
        await box.delete(allMails[i].id);
      }
    }
    if (kIsWeb) await box.flush();
  }

  static List<dynamic>? _filterPastEvents(List<dynamic>? events) {
    if (events == null || events.isEmpty) return events;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return events.where((e) {
      try {
        final dateStr = e['start_time'] ?? e['date'];
        if (dateStr == null) return false;
        return DateTime.parse(
          dateStr,
        ).isAfter(todayStart.subtract(const Duration(seconds: 1)));
      } catch (_) {
        return false;
      }
    }).toList();
  }

  static Future<void> deleteMail(String mailId) async {
    await Hive.box<IntegratedMail>(_mailBoxName).delete(mailId);
    await Hive.box<String>(_deletedIdsBoxName).add(mailId);
  }

  static Future<void> deleteMails(List<String> mailIds) async {
    final mailBox = Hive.box<IntegratedMail>(_mailBoxName);
    final deletedBox = Hive.box<String>(_deletedIdsBoxName);

    for (var id in mailIds) {
      await mailBox.delete(id);
      if (!deletedBox.values.contains(id)) {
        await deletedBox.add(id);
      }
    }
  }

  static List<IntegratedMail> getCachedMails() {
    if (!Hive.isBoxOpen(_mailBoxName)) {
      debugPrint("⚠️ Hive Box($_mailBoxName)가 아직 열리지 않았습니다.");
      return [];
    }
    final box = Hive.box<IntegratedMail>(_mailBoxName);
    final list = box.values.toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return list;
  }

  static DateTime? getLastSyncTime(String service) {
    if (!Hive.isBoxOpen(_settingsBoxName)) return null;
    final box = Hive.box(_settingsBoxName);
    final String? timestamp = box.get('last_sync_$service');
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  static Future<void> saveLastSyncTime(String service, DateTime time) async {
    if (!Hive.isBoxOpen(_settingsBoxName)) return;
    final box = Hive.box(_settingsBoxName);
    await box.put('last_sync_$service', time.toIso8601String());
  }
}
