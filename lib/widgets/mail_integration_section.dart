import 'package:flutter/material.dart';
import '../services/naver_mail_service.dart';

class MailIntegrationSection extends StatefulWidget {
  const MailIntegrationSection({Key? key}) : super(key: key);

  @override
  _MailIntegrationSectionState createState() => _MailIntegrationSectionState();
}

class _MailIntegrationSectionState extends State<MailIntegrationSection> {
  final NaverMailService _naverMailService = NaverMailService();

  // 컨트롤러들을 여기서 관리합니다.
  late TextEditingController _naverIdController;
  late TextEditingController _naverPwController;
  late TextEditingController _daumIdController;
  late TextEditingController _daumPwController;

  @override
  void initState() {
    super.initState();
    _naverIdController = TextEditingController();
    _naverPwController = TextEditingController();
    _daumIdController = TextEditingController();
    _daumPwController = TextEditingController();
  }

  @override
  void dispose() {
    _naverIdController.dispose();
    _naverPwController.dispose();
    _daumIdController.dispose();
    _daumPwController.dispose();
    super.dispose();
  }

  void _testNaverConnection() async {
    final id = _naverIdController.text.trim();
    final pw = _naverPwController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('아이디와 앱 비밀번호를 모두 입력해주세요.')));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final mails = await _naverMailService.fetchNaverMails(
        userName: id,
        password: pw,
      );
      Navigator.pop(context); // 로딩 닫기

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("연동 성공!"),
            content: Text("최근 메일 ${mails.length}개를 성공적으로 가져왔습니다."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("확인"),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('연동 실패: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(),
        const SizedBox(height: 10),
        const Text(
          "외부 메일 연동 (IMAP)",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 14),
        _buildMailTile(
          title: "네이버 메일",
          hint: "네이버 아이디",
          idController: _naverIdController,
          pwController: _naverPwController,
          onTest: _testNaverConnection,
        ),
        const SizedBox(height: 14),
        _buildMailTile(
          title: "다음 메일",
          hint: "다음 아이디",
          idController: _daumIdController,
          pwController: _daumPwController,
          onTest: () {}, // 다음은 추후 구현
        ),
      ],
    );
  }

  Widget _buildMailTile({
    required String title,
    required String hint,
    required TextEditingController idController,
    required TextEditingController pwController,
    required VoidCallback onTest,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton(onPressed: onTest, child: const Text("연동 테스트")),
            ],
          ),
          TextField(
            controller: idController,
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: pwController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: "앱 비밀번호",
              isDense: true,
              filled: true,
              fillColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
