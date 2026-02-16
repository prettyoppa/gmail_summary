import 'package:enough_mail/enough_mail.dart';
import '../models/integrated_mail.dart';

class NaverMailService {
  // 네이버 IMAP 서버 설정 정보
  final String _imapServerHost = 'imap.naver.com';
  final int _imapServerPort = 993;
  final bool _isSecure = true;

  /// 네이버 메일 가져오기 테스트 함수
  Future<List<IntegratedMail>> fetchNaverMails({
    required String userName, // 네이버 아이디
    required String password, // 네이버 앱 비밀번호
  }) async {
    final client = ImapClient(isLogEnabled: false);
    List<IntegratedMail> fetchedMails = [];

    try {
      // 1. 서버 연결
      await client.connectToServer(
        _imapServerHost,
        _imapServerPort,
        isSecure: _isSecure,
      );

      // 2. 로그인
      await client.login(userName, password);

      // 3. 편지함 선택 (기본 받은편지함은 'INBOX')
      await client.selectInbox();

      // 4. 최근 메일 10개 검색
      final fetchResult = await client.fetchRecentMessages(
        messageCount: 10,
        criteria: 'BODY.PEEK[]',
      );

      for (final message in fetchResult.messages) {
        // message.envelope나 message.uid 등을 활용할 수 있지만,
        // 가장 안전하게 제목과 날짜를 조합해 임시 ID를 생성하거나
        // 패키지에서 제공하는 기본 정보만 추출합니다.

        fetchedMails.add(
          IntegratedMail(
            source: MailSource.naver,
            // 에러 발생 지점: 안전하게 고유값 생성 또는 메일 내부 ID 사용
            id: message.hashCode.toString(),
            subject: message.decodeSubject() ?? '(제목 없음)',
            sender: message.fromEmail ?? '알 수 없음',
            dateTime: message.decodeDate() ?? DateTime.now(),
            body: message.decodeTextPlainPart() ?? '',
            // MessageFlag 대신 문자열 직접 비교
            isRead: message.flags?.contains('\\Seen') ?? false,
          ),
        );
      }

      return fetchedMails;
    } catch (e) {
      print('네이버 메일 가져오기 실패: $e');
      rethrow;
    } finally {
      // 5. 연결 종료
      if (client.isLoggedIn) {
        await client.logout();
      }
    }
  }
}
