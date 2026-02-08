import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';

class EmailLinkManager {
  /// 메일 원문 열기 (플랫폼 및 서비스별 대응)
  static Future<void> openOriginalEmail({
    required Map<String, dynamic> email,
    String service = 'gmail', // 나중에 'naver', 'outlook' 등으로 확장 가능
  }) async {
    String urlString = "";

    if (service == 'gmail') {
      final String internalId = email['id'] ?? '';
      final String threadId = email['threadId'] ?? '';
      String targetId = threadId.isNotEmpty ? threadId : internalId;

      // 1. 웹 환경인 경우 (Gmail 웹 표준 링크)
      if (kIsWeb) {
        urlString = "https://mail.google.com/mail/u/0/#inbox/$targetId";
      }
      // 2. 모바일 환경인 경우 (Gmail 모바일 전용 뷰)
      else {
        urlString =
            "https://mail.google.com/mail/mu/mp/0/#cv/priority/%5Esmartlabel_personal/$targetId";
      }
    }

    if (urlString.isEmpty) return;

    final Uri url = Uri.parse(urlString);

    try {
      // 외부 앱(Gmail 앱 등)으로 열기 시도
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      // 실패 시 백업 링크 (범용 웹 링크) 시도
      if (!launched && service == 'gmail') {
        final String backupUrl =
            "https://mail.google.com/mail/u/0/#all/${email['id']}";
        await launchUrl(
          Uri.parse(backupUrl),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint("메일 링크 실행 중 에러 발생: $e");
    }
  }
}
