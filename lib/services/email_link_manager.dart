import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'; // ✅ SnackBar 사용을 위해 추가

class EmailLinkManager {
  static Future<void> openOriginalEmail({
    required BuildContext context, // ✅ context를 인자로 받아야 빨간 줄이 안 생깁니다.
    required Map<String, dynamic> email,
  }) async {
    final String fullId = email['id']?.toString() ?? '';
    if (fullId.isEmpty) return;

    String urlString = "";

    // 1. 서비스 판별 및 순수 ID 추출
    if (fullId.startsWith('naver_')) {
      final String pureId = fullId.replaceFirst('naver_', '');
      urlString = "https://mail.naver.com/v2/read/0/$pureId";
    } else if (fullId.startsWith('daum_')) {
      // 🚀 다음 메일: 안내 메시지만 띄우고 종료
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('다음 메일은 보안상 원문 직접 연결이 지원되지 않습니다.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return; // ⬅️ 여기서 함수를 종료하여 아래 urlLauncher가 실행되지 않게 합니다.
    } else {
      // 구글: 기존 로직 유지
      final String threadId = email['threadId']?.toString() ?? '';
      final String targetId = (threadId != 'null' && threadId.isNotEmpty)
          ? threadId
          : fullId;

      if (kIsWeb) {
        urlString = "https://mail.google.com/mail/u/0/#inbox/$targetId";
      } else {
        urlString =
            "https://mail.google.com/mail/mu/mp/0/#cv/priority/%5Esmartlabel_personal/$targetId";
      }
    }

    // 2. 링크 실행 (구글, 네이버만 도달함)
    debugPrint("🚀 생성된 최종 URL: $urlString");
    if (urlString.isEmpty) return;

    final Uri url = Uri.parse(urlString);

    try {
      bool launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && !fullId.contains('_')) {
        final String backupUrl =
            "https://mail.google.com/mail/u/0/#all/$fullId";
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
