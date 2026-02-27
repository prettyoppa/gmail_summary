import 'dart:convert';
import 'package:flutter/foundation.dart'; // debugPrint용
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import '../models/integrated_mail.dart';

class GmailService {
  final GoogleSignIn googleSignIn;
  GmailService(this.googleSignIn);

  Future<List<IntegratedMail>> fetchEmails({required String query}) async {
    var httpClient = (await googleSignIn.authenticatedClient());
    if (httpClient == null) throw Exception("Gmail 인증 실패");

    var gmailApi = gmail.GmailApi(httpClient);

    // 1. 모든 메시지 참조(ID)를 담을 리스트
    List<gmail.Message> allMessageRefs = [];
    String? pageToken;

    try {
      // 2. 페이지네이션: 다음 페이지 토큰이 있을 때까지 반복해서 목록 조회
      do {
        var results = await gmailApi.users.messages.list(
          'me',
          q: query,
          maxResults: 500, // 구글 API의 실제 최대 한계치
          pageToken: pageToken,
        );

        if (results.messages != null) {
          allMessageRefs.addAll(results.messages!);
          debugPrint("📩 Gmail 목록 수집 중... 현재 ${allMessageRefs.length}건 확보");
        }

        pageToken = results.nextPageToken;

        // 최대 1500건까지만 가져오도록 제한 (필요시 조절 가능)
      } while (pageToken != null && allMessageRefs.length < 1500);
    } catch (e) {
      debugPrint("🚨 Gmail 목록 조회 에러: $e");
    }

    List<IntegratedMail> fetched = [];

    // 3. 수집된 모든 ID에 대해 상세 정보 가져오기
    if (allMessageRefs.isNotEmpty) {
      for (var msg in allMessageRefs) {
        try {
          var detail = await gmailApi.users.messages.get(
            'me',
            msg.id!,
            format: 'full',
          );

          final String? threadId = detail.threadId;
          String subject = "";
          String from = "";

          detail.payload?.headers?.forEach((h) {
            if (h.name?.toLowerCase() == 'subject') subject = h.value ?? "";
            if (h.name?.toLowerCase() == 'from') from = h.value ?? "";
          });

          DateTime emailDate = DateTime.fromMillisecondsSinceEpoch(
            int.parse(detail.internalDate!),
          ).toLocal();

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

          // 상세 정보를 가져온 결과도 1500건이 넘지 않도록 안전장치
          if (fetched.length >= 1500) break;
        } catch (e) {
          debugPrint("🚨 Gmail 상세 조회 에러 (ID: ${msg.id}): $e");
          continue; // 한 건 실패해도 다음 메일로 진행
        }
      }
    }

    debugPrint("✅ Gmail 최종 수집 완료: ${fetched.length}건");
    return fetched;
  }

  String _extractBody(gmail.MessagePart part) {
    String text = "";
    if (part.body?.data != null) {
      try {
        text = utf8
            .decode(base64Url.decode(part.body!.data!))
            .replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ');
      } catch (e) {
        text = "";
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
