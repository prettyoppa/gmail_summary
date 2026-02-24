import 'package:hive_flutter/hive_flutter.dart';
import '../models/integrated_mail.dart';
import 'package:flutter/foundation.dart';

class MailCacheManager {
  static const String _mailBoxName = 'mail_cache_box';
  static const String _deletedIdsBoxName = 'deletedIdsBox';
  static const String _settingsBoxName = 'settings_box';

  // 1. 하이브 초기화 및 박스 열기
  static Future<void> init() async {
    await Hive.initFlutter();

    // 어댑터 등록 (빌드러너로 생성된 어댑터들)
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(MailSourceAdapter());
    if (!Hive.isAdapterRegistered(1))
      Hive.registerAdapter(IntegratedMailAdapter());

    await Hive.openBox<IntegratedMail>(_mailBoxName);
    await Hive.openBox<String>(_deletedIdsBoxName);
    await Hive.openBox(_settingsBoxName);
    debugPrint("✅ Hive Box Open 완료 (Mail, Deleted, Settings)");
  }

  // 2. 메일 저장 (중복 제거, 과거 일정 필터링, 1,000개 유지)
  static Future<void> saveMails(List<IntegratedMail> newMails) async {
    final box = Hive.box<IntegratedMail>(_mailBoxName);
    final deletedBox = Hive.box<String>(_deletedIdsBoxName);

    for (var mail in newMails) {
      // 이미 삭제된 ID거나 중복이면 저장 안 함
      if (deletedBox.values.contains(mail.id)) continue;

      // ✅ 요청하신 과거 일정 2차 필터링 (시스템 현재 시간 기준)
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
    if (kIsWeb) {
      // 웹에서는 flush를 호출해야 IndexedDB에 안정적으로 기록됩니다.
      await box.flush();
    }
    // ✅ 보관 주기 관리: 1,000개 초과 시 오래된 것 삭제
    if (box.length > 5000) {
      final allMails = box.values.toList();
      allMails.sort((a, b) => a.dateTime.compareTo(b.dateTime)); // 과거순 정렬

      int toDeleteCount = box.length - 5000;
      for (int i = 0; i < toDeleteCount; i++) {
        await box.delete(allMails[i].id);
      }
    }
    if (kIsWeb) {
      await box.flush();
    }
  }

  // 3. 과거 일정 필터링 헬퍼 (요청하신 대로 한 번 더 걸러줌)
  static List<dynamic>? _filterPastEvents(List<dynamic>? events) {
    if (events == null || events.isEmpty) return events;

    final now = DateTime.now();
    // 오늘 날짜 00:00:00 기준
    final todayStart = DateTime(now.year, now.month, now.day);

    return events.where((e) {
      try {
        final dateStr = e['start_time'] ?? e['date'];
        if (dateStr == null) return false;
        // 시스템 날짜보다 이전이면 false 리턴하여 제외
        return DateTime.parse(
          dateStr,
        ).isAfter(todayStart.subtract(const Duration(seconds: 1)));
      } catch (_) {
        return false;
      }
    }).toList();
  }

  // 4. 앱 내부 메일 삭제 (Deleted ID 리스트에 추가하여 재수집 방지)
  static Future<void> deleteMail(String mailId) async {
    await Hive.box<IntegratedMail>(_mailBoxName).delete(mailId);
    await Hive.box<String>(_deletedIdsBoxName).add(mailId);
  }

  static Future<void> deleteMails(List<String> mailIds) async {
    final mailBox = Hive.box<IntegratedMail>(_mailBoxName);
    final deletedBox = Hive.box<String>(_deletedIdsBoxName);

    for (var id in mailIds) {
      await mailBox.delete(id);
      // 삭제된 ID 목록에 중복으로 들어가지 않도록 체크 후 추가
      if (!deletedBox.values.contains(id)) {
        await deletedBox.add(id);
      }
    }
  }

  // 5. 캐시된 메일 읽기 (최신순 정렬)
  static List<IntegratedMail> getCachedMails() {
    // ✅ 1. 박스가 열려있는지 먼저 확인 (에러 방지 핵심)
    if (!Hive.isBoxOpen(_mailBoxName)) {
      debugPrint("⚠️ Hive Box($_mailBoxName)가 아직 열리지 않아 빈 리스트를 반환합니다.");
      return [];
    }

    // ✅ 2. 안전하게 박스 참조
    final box = Hive.box<IntegratedMail>(_mailBoxName);

    // ✅ 3. 데이터 가져오기 및 정렬
    final list = box.values.toList();
    list.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return list;
  }

  // ✅ 6. [추가] 특정 서비스의 마지막 동기화 시간 가져오기
  static DateTime? getLastSyncTime(String service) {
    if (!Hive.isBoxOpen(_settingsBoxName)) {
      debugPrint("⚠️ $_settingsBoxName이 열려있지 않습니다.");
      return null;
    }
    final box = Hive.box(_settingsBoxName);
    final String? timestamp = box.get('last_sync_$service');
    return timestamp != null ? DateTime.parse(timestamp) : null;
  }

  // ✅ 7. [추가] 특정 서비스의 마지막 동기화 시간 저장하기
  static Future<void> saveLastSyncTime(String service, DateTime time) async {
    if (!Hive.isBoxOpen(_settingsBoxName)) return;
    final box = Hive.box(_settingsBoxName);
    await box.put('last_sync_$service', time.toIso8601String());
  }
}
