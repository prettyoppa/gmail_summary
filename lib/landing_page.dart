import 'package:flutter/material.dart';
import 'package:universal_html/html.dart' as html;
import 'main.dart'; // 중요: MainScreen을 불러오기 위해 필요합니다.
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class LandingPage extends StatelessWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 1. 고양이 로고
              InkWell(
                onTap: () {
                  // 로고를 누르면 화면 하단에 안내 메시지(SnackBar)를 띄웁니다.
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('스마트폰 홈 화면에 설치된 Catchy 앱을 실행해 주세요! 🐱'),
                      backgroundColor: Colors.blueAccent,
                      duration: Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating, // 공중에 떠 있는 스타일
                    ),
                  );
                },
                splashColor: Colors.transparent, // 클릭 시 물결 효과 제거 (깔끔함)
                highlightColor: Colors.transparent, // 클릭 시 하이라이트 제거
                child: Image.asset('assets/images/app_logo.png', width: 150),
              ),
              const SizedBox(height: 14),

              // 2. 서비스 슬로건
              const Text(
                "Catchy",
                style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
              ),
              const Text(
                "내가 원하는 메일만 쏙 ~ AI 캣",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 50),

              // 3. 기기별 맞춤 버튼 (안드로이드 다운로드 / 아이폰 가이드)
              _buildInstallButton(context),

              const SizedBox(height: 30), // 간격 조정
              // ★ 추가된 부분: 설치 없이 바로 시작하기 버튼
              TextButton(
                onPressed: () async {
                  // 1. 만약 현재 실행 중인 환경이 '웹'이라면 내부 페이지 이동을 합니다.
                  if (kIsWeb) {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MainScreen(),
                      ), // 로그인 페이지 클래스명으로 수정하세요!
                    );
                  }
                  // 2. 만약 웹이 아닌 '모바일 앱' 형태에서 이 버튼을 눌렀다면 원래대로 외부 브라우저를 엽니다.
                  else {
                    final Uri url = Uri.parse('https://ireadschool.com');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(
                        url,
                        mode: LaunchMode.externalApplication,
                      );
                    }
                  }
                },
                child: const Text(
                  "설치 없이 웹에서 바로 시작하기 >",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.blueAccent,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

              const SizedBox(height: 40),
              const Text(
                "이미 앱을 설치하셨다면 홈 화면의 앱 아이콘을 눌러 실행해주세요!",
                style: TextStyle(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstallButton(BuildContext context) {
    final userAgent = html.window.navigator.userAgent.toLowerCase();

    const String apkUrl =
        'https://firebasestorage.googleapis.com/v0/b/ireadschool-800f8.firebasestorage.app/o/app-release.apk?alt=media&token=fbe7f6de-445e-4026-8435-8500eaf92b51';

    if (userAgent.contains("android")) {
      return Column(
        children: [
          ElevatedButton.icon(
            onPressed: () => html.window.open(apkUrl, '_self'),
            icon: const Icon(Icons.android),
            label: const Text("안드로이드 앱 다운로드"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              backgroundColor: Colors.black, // 버튼 색상을 검정으로 주면 더 세련돼 보입니다.
              foregroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "* 설치 시 '무시하고 설치' 또는 '허용'을 눌러주세요.",
            style: TextStyle(fontSize: 11, color: Colors.redAccent),
          ),
        ],
      );
    } else if (userAgent.contains("iphone") || userAgent.contains("ipad")) {
      return Column(
        children: [
          const Icon(Icons.ios_share, color: Colors.blue, size: 30),
          const SizedBox(height: 10),
          const Text(
            "아이폰은 브라우저 하단 [공유] 클릭 후\n'홈 화면에 추가'를 눌러주세요!",
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      );
    } else {
      // PC 브라우저인 경우 (사실 main.dart 로직에서 걸러지지만 안전상 기록)
      return const Text("모바일 환경에서 최적화된 앱 설치가 가능합니다. 🐱");
    }
  }
}
