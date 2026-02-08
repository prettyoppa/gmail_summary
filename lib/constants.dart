// lib/constants.dart

class AppConstants {
  // Google 로그인 클라이언트 ID (사용자님의 ID를 넣으세요)
  static const String googleClientId =
      // main 프로젝트 웹 client Id
      '474725837334-dr5ulbt7a59rjnv5kumon6he56n1fibu.apps.googleusercontent.com';
  // qas 프로젝트 웹 client Id
  // '512126694471-cl8ehil75dt9htddkorufcqolets0tfi.apps.googleusercontent.com';
  // dev 프로젝트 웹 client Id
  // '877541084240-7c8sqajvr2pk2f3uba2ejrdcr66ep46f.apps.googleusercontent.com';

  // Gemini API 키 (사용자님의 키를 넣으세요)
  // static const String geminiApiKey = 'AIz*******FPA';
  static const String summaryServerUrl =
      // 'https://us-central1-ireadschool-800f8.cloudfunctions.net/getSummary';
      'https://getsummary-nqyhetdnsq-uc.a.run.app';

  // 앱 전체 타이틀
  static const String appTitle = 'AI 메일 비서';
}
