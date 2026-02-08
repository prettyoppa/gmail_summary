import 'dart:convert';
import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';

class GmailService {
  final GoogleSignIn googleSignIn;
  GmailService(this.googleSignIn);

  Future<List<Map<String, String>>> fetchEmails({required String query}) async {
    var httpClient = (await googleSignIn.authenticatedClient())!;
    var gmailApi = gmail.GmailApi(httpClient);
    var results = await gmailApi.users.messages.list(
      'me',
      q: query,
      maxResults: 15,
    );

    List<Map<String, String>> fetched = [];
    if (results.messages != null) {
      for (var msg in results.messages!) {
        var detail = await gmailApi.users.messages.get('me', msg.id!);
        String sub = "", from = "";
        DateTime emailDate = DateTime.fromMillisecondsSinceEpoch(
          int.parse(detail.internalDate!),
        ).toLocal();

        detail.payload?.headers?.forEach((h) {
          if (h.name?.toLowerCase() == 'subject') sub = h.value ?? "";
          if (h.name?.toLowerCase() == 'from') from = h.value ?? "";
        });

        fetched.add({
          'subject': sub,
          'from': from,
          'body': _extractBody(detail.payload!),
          // 아래 date 부분을 수정합니다: 연/월/일 시:분 형식
          'date':
              "${emailDate.year}/${emailDate.month.toString().padLeft(2, '0')}/${emailDate.day.toString().padLeft(2, '0')} "
              "${emailDate.hour.toString().padLeft(2, '0')}:${emailDate.minute.toString().padLeft(2, '0')}",
        });
      }
    }
    return fetched;
  }

  String _extractBody(gmail.MessagePart part) {
    String text = "";
    if (part.body?.data != null) {
      text = utf8
          .decode(base64Url.decode(part.body!.data!))
          .replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ');
    }
    if (part.parts != null) for (var p in part.parts!) text += _extractBody(p);
    return text.replaceAll(RegExp(r'\s+'), ' ');
  }
}
