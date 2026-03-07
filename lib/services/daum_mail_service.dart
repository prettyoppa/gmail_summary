import 'dart:convert';
import 'package:enough_mail/enough_mail.dart';
import '../models/integrated_mail.dart';
import 'package:cp949_codec/cp949_codec.dart';
// import 'package:flutter/foundation.dart';

class DaumMailService {
  final String _imapServerHost = 'imap.daum.net';
  final int _imapServerPort = 993;
  final bool _isSecure = true;

  // ✅ [추가] 로그인 정보를 저장할 변수
  String? _userName;
  String? _password;

  // ✅ [추가] 연동 여부를 확인하는 Getter
  bool get isConnected => _userName != null && _password != null;

  // ✅ [추가] 로그인 정보를 설정하는 메서드 (연동 성공 시 호출용)
  void setCredentials(String id, String pw) {
    _userName = id;
    _password = pw;
  }

  Future<bool> checkConnection({
    required String userName,
    required String password,
  }) async {
    final client = ImapClient(isLogEnabled: false);
    try {
      await client.connectToServer(
        _imapServerHost,
        _imapServerPort,
        isSecure: _isSecure,
      );
      await client.login(userName, password);
      // ✅ [추가] 연결 성공 시 내부 변수에 저장
      _userName = userName;
      _password = password;
      return true;
    } finally {
      if (client.isLoggedIn) await client.logout();
    }
  }

  // ---------------------------------------------------------
  // ✅ [최종 에러 해결] 문제 되는 메서드를 제거한 안전한 디코더
  // ---------------------------------------------------------
  String _decodeDaumSubject(MimeMessage message) {
    String? rawSubject = message.getHeaderValue('Subject');
    if (rawSubject == null || rawSubject.isEmpty) {
      return message.decodeSubject() ?? '(제목 없음)';
    }

    if (rawSubject.contains('=?')) {
      try {
        // 대소문자 구분 없이 매칭하기 위해 i 옵션을 뺄 수도 있지만,
        // 확실하게 그룹 데이터를 가져온 뒤 toUpperCase()로 비교합니다.
        final mimeRegex = RegExp(r'=\?([^?]+)\?([bBqQ])\?([^?]+)\?=');

        return rawSubject
            .splitMapJoin(
              mimeRegex,
              onMatch: (Match m) {
                final String charset = m.group(1)!.toLowerCase();
                final String encoding = m
                    .group(2)!
                    .toUpperCase(); // ✅ 여기서 대문자로 통일!
                final String data = m.group(3)!;

                try {
                  List<int> bytes;
                  if (encoding == 'B') {
                    // Base64 처리 (이제 'b', 'B' 모두 여기로 옵니다)
                    bytes = base64.decode(data);
                  } else if (encoding == 'Q') {
                    // Quoted-Printable 처리 (이제 'q', 'Q' 모두 여기로 옵니다)
                    String decodedStr = data.replaceAll('_', ' ');
                    List<int> resultBytes = [];
                    for (int i = 0; i < decodedStr.length; i++) {
                      if (decodedStr[i] == '=' && i + 2 < decodedStr.length) {
                        final hex = decodedStr.substring(i + 1, i + 3);
                        resultBytes.add(int.parse(hex, radix: 16));
                        i += 2;
                      } else {
                        resultBytes.add(decodedStr.codeUnitAt(i));
                      }
                    }
                    bytes = resultBytes;
                  } else {
                    return m.group(0)!;
                  }

                  // charset 판별 및 디코딩
                  if (charset.contains('euc-kr') ||
                      charset.contains('cp949') ||
                      charset.contains('ks_c_5601')) {
                    return cp949.decode(bytes);
                  }
                  return utf8.decode(bytes, allowMalformed: true);
                } catch (_) {
                  return m.group(0)!;
                }
              },
              onNonMatch: (n) => n,
            )
            .replaceAll('\r', '')
            .replaceAll('\n', '');
      } catch (e) {
        return message.decodeSubject() ?? rawSubject;
      }
    }
    return message.decodeSubject() ?? rawSubject;
  }

  Future<List<IntegratedMail>> fetchEmails({
    required String userName,
    required String password,
    required List<String> whitelist,
    DateTime? startDate,
    DateTime? endDate, // ✅ 종료 날짜 인자 추가
  }) async {
    final client = ImapClient(isLogEnabled: false);
    List<IntegratedMail> fetchedMails = [];

    try {
      await client.connectToServer(
        _imapServerHost,
        _imapServerPort,
        isSecure: _isSecure,
      );
      await client.login(userName, password);
      await client.selectInbox();

      String searchCriteria = (startDate != null)
          ? 'SINCE ${_formatImapDate(startDate)}'
          : 'ALL';

      final searchResult = await client.searchMessages(
        searchCriteria: searchCriteria,
      );

      if (searchResult.matchingSequence != null &&
          searchResult.matchingSequence!.isNotEmpty) {
        var sequence = searchResult.matchingSequence!;
        if (sequence.length > 1500) {
          final allIds = sequence.toList();
          final last1500Ids = allIds.sublist(allIds.length - 1500);
          sequence = MessageSequence();
          for (var id in last1500Ids) sequence.add(id);
        }

        final fetchResult = await client.fetchMessages(
          sequence,
          '(UID FLAGS BODY.PEEK[])',
        );

        for (final message in fetchResult.messages) {
          try {
            final sender = message.fromEmail ?? '알 수 없음';
            final emailDate = message.decodeDate() ?? DateTime.now();

            // 2. 다음 진짜 ID 추출 로직
            String? foundDaumId;

            // 1순위: 다음 전용 헤더 확인 (가장 확실함)
            final xDaumId = message.getHeaderValue('X-Daum-ID');
            final xKakaoId = message.getHeaderValue('X-Kakaomail-ID');

            if (xDaumId != null && xDaumId.isNotEmpty) {
              foundDaumId = xDaumId.trim();
            } else if (xKakaoId != null && xKakaoId.isNotEmpty) {
              foundDaumId = xKakaoId.trim();
            }
            // 2순위: Message-ID 헤더 분석
            else {
              final msgId = message.getHeaderValue('Message-ID');
              if (msgId != null) {
                String clean = msgId
                    .replaceAll('<', '')
                    .replaceAll('>', '')
                    .trim();
                if (clean.contains('daum.net')) {
                  foundDaumId = clean.split('@').first;
                }
              }
            }

            final String daumOriginalId =
                foundDaumId ??
                (message.uid?.toString() ?? message.hashCode.toString());

            // 3. 필터링 로직 (emailDate 변수 사용)
            if (endDate != null) {
              if (emailDate.isAfter(endDate.add(const Duration(days: 1)))) {
                continue;
              }
            }
            if (startDate != null && emailDate.isBefore(startDate)) continue;

            // 4. 화이트리스트 필터링 (sender 변수 사용)
            bool isWhitelisted =
                whitelist.isEmpty ||
                whitelist.any(
                  (email) =>
                      sender.toLowerCase().contains(email.toLowerCase().trim()),
                );
            if (!isWhitelisted) continue;

            // 5. 본문 디코딩
            String? bodyText;
            try {
              bodyText =
                  message.decodeTextPlainPart() ?? message.decodeTextHtmlPart();
            } on FormatException {
              bodyText = "내용을 표시할 수 없는 메일입니다.";
            } catch (e) {
              bodyText = "본문 로드 실패";
            }
            print(
              "🔍 본문 추출 결과: plain=${message.decodeTextPlainPart() != null}, html=${message.decodeTextHtmlPart() != null}",
            );
            print(
              "🔍 메일 구조 확인: ${message.mimeData?.contentType?.toString()}",
            ); // toString()으로 전체 정보 출력
            if (bodyText != null && bodyText.isNotEmpty) {
              print("--------- [Daum Body 분석 시작] ---------");
              // 본문 전체에서 B로 시작하는 15자리 식별자 패턴을 찾습니다.
              final RegExp bidRegex = RegExp(r'B[A-Z0-9]{14,15}');
              final Iterable<RegExpMatch> matches = bidRegex.allMatches(
                bodyText,
              );

              if (matches.isNotEmpty) {
                print(
                  "🎯 본문에서 B-ID 후보 발견: ${matches.map((m) => m.group(0)).toList()}",
                );
              } else {
                print("❌ 본문 텍스트 내에 B-ID 패턴이 없습니다.");
              }

              // 실제 본문 앞부분을 찍어서 눈으로 확인 (필요시)
              // print("본문 스니펫: ${bodyText.substring(0, bodyText.length > 500 ? 500 : bodyText.length)}");
              print("--------- [Daum Body 분석 종료] ---------");
            }
            // 6. 리스트에 추가
            fetchedMails.add(
              IntegratedMail(
                source: MailSource.daum,
                id: 'daum_$daumOriginalId',
                subject: _decodeDaumSubject(message),
                sender: sender,
                dateTime: emailDate,
                body: bodyText ?? '',
                isRead: message.flags?.contains(MessageFlags.seen) ?? false,
              ),
            );
          } catch (e) {
            continue;
          }
        }
      }
      return fetchedMails.reversed.toList();
    } finally {
      if (client.isLoggedIn) await client.logout();
    }
  }

  String _formatImapDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day.toString().padLeft(2, '0')}-${months[date.month - 1]}-${date.year}';
  }
}
