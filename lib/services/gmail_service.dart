import 'dart:convert';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/integrated_mail.dart'; // 모델 임포트 확인

class GmailService {
  final GoogleSignIn googleSignIn;
  GmailService(this.googleSignIn);

  /// Gmail API를 사용하여 메일을 가져오고 IntegratedMail 리스트로 반환합니다.
  Future<List<IntegratedMail>> fetchEmails({required String query}) async {
    // 1. 인증된 클라이언트 획득
    var httpClient = (await googleSignIn.authenticatedClient());
    if (httpClient == null) throw Exception("Gmail 인증 실패");

    var gmailApi = gmail.GmailApi(httpClient);

    // 2. 메시지 목록 조회
    var results = await gmailApi.users.messages.list(
      'me',
      q: query,
      maxResults: 1500,
    );

    List<IntegratedMail> fetched = [];

    if (results.messages != null) {
      for (var msg in results.messages!) {
        // 3. 메시지 상세 정보 가져오기
        var detail = await gmailApi.users.messages.get(
          'me',
          msg.id!,
          format: 'full',
        );
        final String? threadId = detail.threadId;

        String subject = "";
        String from = "";
        // String messageId = "";

        // 헤더 정보 파싱
        detail.payload?.headers?.forEach((h) {
          if (h.name?.toLowerCase() == 'subject') subject = h.value ?? "";
          if (h.name?.toLowerCase() == 'from') from = h.value ?? "";
          // if (h.name?.toLowerCase() == 'message-id') messageId = h.value ?? "";
        });

        // 내부 날짜 변환
        DateTime emailDate = DateTime.fromMillisecondsSinceEpoch(
          int.parse(detail.internalDate!),
        ).toLocal();

        // 4. IntegratedMail 객체로 변환하여 추가
        fetched.add(
          IntegratedMail(
            source: MailSource.gmail,
            id: msg.id ?? '',
            threadId: threadId,
            subject: subject,
            sender: from,
            dateTime: emailDate,
            body: _extractBody(detail.payload!),
            isRead: !(detail.labelIds?.contains('UNREAD') ?? false),
          ),
        );
      }
    }
    return fetched;
  }

  /// 메일 본문 추출 (기존 로직 유지 및 개선)
  String _extractBody(gmail.MessagePart part) {
    String text = "";
    if (part.body?.data != null) {
      try {
        text = utf8
            .decode(base64Url.decode(part.body!.data!))
            .replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ');
      } catch (e) {
        text = ""; // 디코딩 에러 시 빈 문자열
      }
    }
    if (part.parts != null) {
      for (var p in part.parts!) {
        text += _extractBody(p);
      }
    }
    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
