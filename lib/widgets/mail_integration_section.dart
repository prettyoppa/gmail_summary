import 'package:flutter/material.dart';
import '../services/naver_mail_service.dart';
import '../services/daum_mail_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MailIntegrationSection extends StatefulWidget {
  const MailIntegrationSection({Key? key}) : super(key: key);

  @override
  _MailIntegrationSectionState createState() => _MailIntegrationSectionState();
}

class _MailIntegrationSectionState extends State<MailIntegrationSection> {
  final NaverMailService _naverMailService = NaverMailService();
  final DaumMailService _daumMailService = DaumMailService();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

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

    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    String? savedId = await _storage.read(key: 'naver_id');
    String? savedPw = await _storage.read(key: 'naver_pw');
    if (savedId != null) _naverIdController.text = savedId;
    if (savedPw != null) _naverPwController.text = savedPw;

    String? daumId = await _storage.read(key: 'daum_id');
    String? daumPw = await _storage.read(key: 'daum_pw');
    if (daumId != null) _daumIdController.text = daumId;
    if (daumPw != null) _daumPwController.text = daumPw;
  }

  @override
  void dispose() {
    _naverIdController.dispose();
    _naverPwController.dispose();
    _daumIdController.dispose();
    _daumPwController.dispose();
    super.dispose();
  }

  // ✅ 성공 다이얼로그 수정 (메일 개수 매개변수 제거)
  void _showSuccessDialog(String platform) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$platform 연동 성공"),
        content: Text("$platform 계정이 성공적으로 연동되었습니다.\n메인 화면에서 메일을 확인하실 수 있습니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  // ✅ 네이버 연동 로직 (checkConnection 적용)
  void _NaverConnection() async {
    FocusScope.of(context).unfocus();
    final id = _naverIdController.text.trim();
    final pw = _naverPwController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('네이버 아이디와 앱 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }

    _showLoading();

    try {
      // 🚀 무거운 fetchEmails 대신 가벼운 checkConnection 호출
      await _naverMailService.checkConnection(userName: id, password: pw);

      await _storage.write(key: 'naver_id', value: id);
      await _storage.write(key: 'naver_pw', value: pw);

      await _logIntegration('naver_integration');

      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기
      _showSuccessDialog("네이버");
    } catch (e) {
      _handleError("네이버", e);
    }
  }

  // ✅ 다음 연동 로직 (checkConnection 적용)
  void _DaumConnection() async {
    FocusScope.of(context).unfocus();
    final id = _daumIdController.text.trim();
    final pw = _daumPwController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('다음 아이디와 앱 비밀번호를 모두 입력해주세요.')),
      );
      return;
    }

    _showLoading();

    try {
      // 🚀 무거운 fetchEmails 대신 가벼운 checkConnection 호출
      await _daumMailService.checkConnection(userName: id, password: pw);

      await _storage.write(key: 'daum_id', value: id);
      await _storage.write(key: 'daum_pw', value: pw);

      await _logIntegration('daum_integration');

      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기
      _showSuccessDialog("다음");
    } catch (e) {
      _handleError("다음", e);
    }
  }

  // --- 보조 함수들 ---

  void _showLoading() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
  }

  void _handleError(String platform, dynamic e) {
    if (!mounted) return;
    Navigator.pop(context); // 로딩 인디케이터 닫기

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$platform 연동 실패"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "에러 내용:",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: const TextStyle(color: Colors.redAccent),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const Text("💡 해결 방법 체크리스트:"),
              Text("1. $platform 메일 설정에서 IMAP/SMTP가 '사용함'인지 확인"),
              const Text("2. 2단계 인증 사용 시 '앱 비밀번호'를 새로 생성해서 입력"),
              Text(
                "3. 아이디에 @${platform == '네이버' ? 'naver.com' : 'daum.net'}을 제외하고 입력해보기",
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  Future<void> _logIntegration(String fieldName) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        fieldName: {
          'is_linked': true,
          'linked_at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
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
        const SizedBox(height: 16),
        // ✅ 가로로 나란히 배치 (메일리스트 아이콘 스타일 적용)
        Row(
          children: [
            Expanded(
              child: _buildIntegrationCard(
                title: "네이버",
                source: "naver",
                idController: _naverIdController,
                pwController: _naverPwController,
                onTest: _NaverConnection,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIntegrationCard(
                title: "다음",
                source: "daum",
                idController: _daumIdController,
                pwController: _daumPwController,
                onTest: _DaumConnection,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIntegrationCard({
    required String title,
    required String source,
    required TextEditingController idController,
    required TextEditingController pwController,
    required VoidCallback onTest,
  }) {
    return InkWell(
      onTap: () => _showLoginSheet(title, idController, pwController, onTest),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            // ⭐ [메일리스트 아이콘 로직 그대로 적용]
            Container(
              width: 38,
              height: 38,
              decoration: source == "naver"
                  ? BoxDecoration(
                      color: const Color(0xFF03C75A),
                      borderRadius: BorderRadius.circular(10),
                    )
                  : BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFF3866E6).withOpacity(0.3),
                      ),
                    ),
              child: Center(
                child: Text(
                  source == "naver" ? "N" : "D",
                  style: TextStyle(
                    color: source == "naver"
                        ? Colors.white
                        : const Color(0xFF3866E6),
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 2. 입력 창 (Bottom Sheet)
  void _showLoginSheet(
    String title,
    TextEditingController idController,
    TextEditingController pwController,
    VoidCallback onTest,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // 키보드 대응
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom, // 키보드 높이만큼 패딩
          left: 24,
          right: 24,
          top: 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  "$title 연동",
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    // Firebase의 admin/guide 문서 내 필드명 지정
                    final String field = title == "네이버"
                        ? "naver_connection"
                        : "daum_connection";
                    _showGuideDialog(title, field);
                  },
                  icon: Icon(
                    Icons.help_outline,
                    color: title == "네이버"
                        ? const Color(0xFF03C75A)
                        : const Color(0xFF3866E6),
                    size: 30,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            // ------------------------------------------
            const SizedBox(height: 8),
            const Text(
              "IMAP/SMTP 설정에서 '앱 비밀번호'를 발급받아야 합니다.",
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: idController,
              decoration: InputDecoration(
                labelText: "아이디",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pwController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "앱 비밀번호",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                prefixIcon: const Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  onTest();
                  Navigator.pop(context); // 닫기
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: title == "네이버"
                      ? const Color(0xFF03C75A)
                      : const Color(0xFF3866E6),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  "연동 및 저장",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ✅ Firestore에서 가이드를 읽어와 팝업으로 보여주는 함수
  Future<void> _showGuideDialog(String title, String fieldName) async {
    try {
      // 로딩 표시
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Firestore에서 데이터 가져오기 (admin/guide)
      final doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc('guide')
          .get();

      if (!mounted) return;
      Navigator.pop(context); // 로딩 닫기

      if (doc.exists && doc.data()!.containsKey(fieldName)) {
        final String content = doc
            .get(fieldName)
            .toString()
            .replaceAll('\\n', '\n');

        // 가이드 상세 팝업
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              "$title 연동 가이드",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            content: SingleChildScrollView(
              child: Text(
                content,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("확인"),
              ),
            ],
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("가이드 정보를 찾을 수 없습니다.")));
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // 로딩 닫기
      debugPrint("가이드 로드 에러: $e");
    }
  }
}
