import 'package:enough_mail/enough_mail.dart';
import '../models/integrated_mail.dart';

class NaverMailService {
  final String _imapServerHost = 'imap.naver.com';
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
            final emailDate =
                message.decodeDate() ?? DateTime.now(); // ✅ 여기서 emailDate 선언

            // 1. 종료 날짜(endDate) 필터링 추가
            if (endDate != null) {
              // 선택한 종료일의 다음날 00시 이전까지만 포함
              if (emailDate.isAfter(endDate.add(const Duration(days: 1)))) {
                continue;
              }
            }

            // 2. 시작 날짜(startDate) 필터링 (IMAP SINCE 보완용)
            if (startDate != null && emailDate.isBefore(startDate)) continue;

            // 3. 화이트리스트 필터링
            bool isWhitelisted =
                whitelist.isEmpty ||
                whitelist.any(
                  (email) =>
                      sender.toLowerCase().contains(email.toLowerCase().trim()),
                );
            if (!isWhitelisted) continue;

            String? bodyText;
            try {
              bodyText =
                  message.decodeTextPlainPart() ?? message.decodeTextHtmlPart();
            } on FormatException {
              bodyText = "내용을 표시할 수 없는 메일입니다.";
            } catch (e) {
              bodyText = "본문 로드 실패";
            }

            fetchedMails.add(
              IntegratedMail(
                source: MailSource.naver,
                id: 'naver_${message.uid ?? message.hashCode}',
                subject: message.decodeSubject() ?? '(제목 없음)',
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
