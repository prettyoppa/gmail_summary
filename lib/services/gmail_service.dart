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

    List<gmail.Message> allMessageRefs = [];
    String? pageToken;

    try {
      // 1. 메시지 목록(ID) 조회
      do {
        debugPrint("🚀 Gmail API 요청 시작 (pageToken: $pageToken)");
        var results = await gmailApi.users.messages.list(
          'me',
          q: query,
          maxResults: 500,
          pageToken: pageToken,
        );

        if (results.messages != null) {
          allMessageRefs.addAll(results.messages!);
          debugPrint(
            "📩 현재 페이지에서 ${results.messages!.length}건 추가됨. (총 ${allMessageRefs.length}건)",
          );
        }

        pageToken = results.nextPageToken;
      } while (pageToken != null && allMessageRefs.length < 1500);
    } catch (e) {
      debugPrint("🚨 Gmail 목록 조회 에러: $e");
    }

    List<IntegratedMail> fetched = [];

    // 2. 수집된 ID들에 대해 10개씩 묶어서 상세 정보 수집 (429 에러 방지)
    if (allMessageRefs.isNotEmpty) {
      for (int i = 0; i < allMessageRefs.length; i += 50) {
        // 💡 10 -> 50으로 상향
        int end = (i + 50 < allMessageRefs.length)
            ? i + 50
            : allMessageRefs.length;
        final chunk = allMessageRefs.sublist(i, end);

        debugPrint("⏳ Gmail 상세 조회 중... ($i / ${allMessageRefs.length})");

        final List<IntegratedMail?> chunkResults = await Future.wait(
          chunk.map((msg) async {
            try {
              var detail = await gmailApi.users.messages.get(
                'me',
                msg.id!,
                format: 'full',
              );

              String subject = "";
              String from = "";

              detail.payload?.headers?.forEach((h) {
                if (h.name?.toLowerCase() == 'subject') subject = h.value ?? "";
                if (h.name?.toLowerCase() == 'from') from = h.value ?? "";
              });

              DateTime emailDate = DateTime.fromMillisecondsSinceEpoch(
                int.parse(detail.internalDate!),
              ).toLocal();

              return IntegratedMail(
                source: MailSource.gmail,
                id: msg.id ?? '',
                threadId: detail.threadId,
                subject: subject,
                sender: from,
                dateTime: emailDate,
                body: _extractBody(detail.payload!),
                isRead: !(detail.labelIds?.contains('UNREAD') ?? false),
              );
            } catch (e) {
              debugPrint("🚨 Gmail 상세 조회 에러 (ID: ${msg.id}): $e");
              return null;
            }
          }),
        );

        // null이 아닌 결과만 리스트에 추가
        fetched.addAll(chunkResults.whereType<IntegratedMail>());

        // API 할당량 보호를 위한 미세 지연
        await Future.delayed(const Duration(milliseconds: 150));
      }
    }

    debugPrint("✅ Gmail 최종 수집 완료: ${fetched.length}건");
    return fetched; // 👈 이 반환문이 반드시 있어야 합니다.
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
