import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:googleapis/gmail/v1.dart' as gmail;
import 'package:http/http.dart' as http;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:googleapis/calendar/v3.dart' as cal;

import 'dart:convert';
import 'services/app_login.dart';

import 'constants.dart';
import 'firebase_options.dart';
import 'widgets/filter_drawer.dart';
import 'widgets/profile_drawer.dart';
import 'widgets/manual_button.dart';
import 'models/user_model.dart';
import 'email_detail_screen.dart';
import 'web_email_detail_view.dart';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'landing_page.dart';
import 'video_splash.dart';
import 'package:flutter/gestures.dart';

// 🎯 [추가] 실행 시 환경을 결정하는 변수 (기본값은 dev)
// 터미널에서 flutter run --dart-define=APP_FLAVOR=qas 로 실행하면 qas로 붙습니다.
const String appFlavor = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'qas',
);

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    GestureBinding.instance.resamplingEnabled = true;

    // 🎯 복잡한 if-else 대신 딱 한 줄로 정리됩니다.
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {}

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Catchy - AI eMail Analyzer',
      debugShowCheckedModeBanner: false,
      home: kIsWeb
          ? _getHomeScreen()
          : VideoSplashScreen(nextScreen: _getHomeScreen()),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        CountryLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
      locale: const Locale('ko', 'KR'),
    );
  }

  /// 사용자가 브라우저로 들어왔는지, 설치된 앱으로 들어왔는지 판별하는 함수
  Widget _getHomeScreen() {
    // 1. 웹 환경인지 확인
    if (kIsWeb) {
      final userAgent = html.window.navigator.userAgent.toLowerCase();

      // 2. 모바일 기기(iPhone, Android 등)인지 확인
      bool isMobileDevice =
          userAgent.contains("iphone") ||
          userAgent.contains("ipad") ||
          userAgent.contains("android");

      // 3. '홈 화면에 추가'를 통해 실행된 상태(Standalone)인지 확인
      bool isStandalone = html.window
          .matchMedia('(display-mode: standalone)')
          .matches;

      // 모바일이면서 + 아직 앱으로 실행한 게 아니라면(브라우저라면) -> 랜딩 페이지
      if (isMobileDevice && !isStandalone) {
        return const LandingPage();
      }
    }

    // PC 접속이거나, 이미 앱으로 실행 중인 모바일 사용자는 바로 메인 화면으로!
    return const MainScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  GoogleSignInAccount? _googleUser;
  UserModel? _currentUserModel;

  bool _isLoading = false;
  bool _isAdmin = false;
  List<String> _adminEmails = [];
  List<String> _whiteList = [];
  String _customPrompt = "핵심 내용을 3줄로 요약해줘.";
  String _galleryPrompt = "";
  int _selectedPromptType = 0; // 0: 사용자1, 1: 사용자2
  DateTimeRange? _selectedDateRange;
  List<Map<String, dynamic>> _filteredEmails = [];
  bool _isFilterEnabled = true; // 필터링 활성화 여부 상태 변수

  bool _isMobileDetailOpen = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Set<String> _summarizedIds = {}; // 요약된 메일 ID 세트
  Map<String, dynamic>? _selectedEmail; // 현재 웹에서 선택된 메일을 저장
  Map<String, dynamic> _summarizedContent = {}; // 요약 텍스트 저장용

  // dynamic _currentDetectedEvent; // List가 들어올 수 있도록 dynamic으로 변경
  Map<String, dynamic> _extractedEventData = {}; // value 타입을 dynamic으로 변경
  double _leftWidth = 350; // 기본 왼쪽 리스트 너비
  Set<String> _readIds = {};

  Future<void> _preloadAdminConfig() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('config')
          .get();
      if (doc.exists) {
        final List<dynamic> emails = doc.data()?['admin_emails'] ?? [];
        setState(() {
          _adminEmails = emails
              .map((e) => e.toString().trim().toLowerCase())
              .toList();
        });
        debugPrint("✅ 관리자 목록 예비 로드 완료: $_adminEmails");
      }
    } catch (e) {
      debugPrint("⚠️ 관리자 목록 예비 로드 실패: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _preloadAdminConfig();

    // 🎯 AppLogin 서비스의 객체를 사용하도록 수정
    AppLogin.googleSignIn.onCurrentUserChanged.listen((
      GoogleSignInAccount? account,
    ) {
      setState(() {
        _googleUser = account;
      });
      if (account != null) {
        bool isMatched = _adminEmails.contains(account.email.toLowerCase());
        setState(() {
          _isAdmin = isMatched;
        });
        _loadInitialData();
      }
    });

    try {
      AppLogin.googleSignIn.signInSilently();
    } catch (e) {
      debugPrint("Silent Sign-in Error: $e");
    }
  }

  Future<void> _handleFullSignOut() async {
    await AppLogin.signOut();
    setState(() {
      _googleUser = null;
      _currentUserModel = null;
      _filteredEmails = [];
    });
  }

  Future<void> _loadInitialData() async {
    if (_googleUser == null) return;

    setState(() {
      _currentUserModel = null;
      _filteredEmails = [];
      _selectedDateRange = null;
      _whiteList = [];
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final doc = await userDocRef.get();

      final readDocs = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('read_mails')
          .get();

      if (doc.exists) {
        final data = doc.data()!;

        // 1. [유지] 날짜 파싱 로직
        DateTimeRange? loadedRange;
        if (data['startDate'] != null && data['endDate'] != null) {
          try {
            loadedRange = DateTimeRange(
              start: DateTime.parse(data['startDate']),
              end: DateTime.now(),
            );
          } catch (e) {
            debugPrint("날짜 파싱 에러: $e");
          }
        }

        if (!mounted) return;

        setState(() {
          // 2. [유지] 읽음 ID 목록 업데이트
          _readIds = readDocs.docs.map((doc) => doc.id).toSet();

          // 3. [유지] 화이트리스트 처리
          if (data['whiteListMap'] != null) {
            Map<String, dynamic> storedMap = Map<String, dynamic>.from(
              data['whiteListMap'],
            );
            var sortedKeys = storedMap.keys.toList()..sort();
            _whiteList = sortedKeys.map((key) {
              bool isActive = storedMap[key] == true;
              return "$key:$isActive";
            }).toList();
          }

          // 4. [중요] 사용자 정보 불러오기
          // 이제 AppLogin에서 저장을 마쳤으므로, 여기서는 '불러오기'만 합니다.
          _currentUserModel = UserModel.fromMap(data);
          _customPrompt = data['customPrompt'] ?? "핵심 내용을 3줄로 요약해줘.";
          _galleryPrompt = data['galleryPrompt'] ?? "";
          _selectedPromptType = data['selectedPromptType'] ?? 0;
          _selectedDateRange = loadedRange;
        });

        debugPrint("🚩 데이터 로드 완료: ${data['email']}");

        await _checkSummarizedStatus();

        if (loadedRange != null) {
          await _fetchEmails();
        }
      } else {
        // 데이터가 없는 경우
        if (!mounted) return;
        setState(() {
          _currentUserModel = UserModel.empty();
        });
      }
    } catch (e) {
      debugPrint("로드 에러: $e");
    }
  }

  String _decodeBody(gmail.MessagePart part) {
    String text = "";
    // 1. 현재 파트에 직접 데이터가 있는 경우
    if (part.body?.data != null) {
      try {
        text += utf8.decode(base64Url.decode(part.body!.data!));
      } catch (e) {
        debugPrint("Decode error: $e");
      }
    }
    // 2. 하위 파트가 있는 경우 (재귀 탐색)
    if (part.parts != null) {
      for (var subPart in part.parts!) {
        text += _decodeBody(subPart);
      }
    }
    // 태그 제거 및 공백 정리
    return text
        .replaceAll(RegExp(r'<[^>]*>|&nbsp;'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _fetchEmails() async {
    debugPrint("로그 1: _fetchEmails 함수 시작됨"); // <--- 추가
    // 1. 구글 유저 객체가 없으면 복구 시도
    if (_googleUser == null) {
      _googleUser = await AppLogin.googleSignIn.signInSilently();
      debugPrint("로그 2: 구글 유저 로그인 상태: ${_googleUser?.email}"); // <--- 추가
      if (_googleUser == null) return;
    }

    if (_selectedDateRange == null) {
      debugPrint(
        "로그 3: 🚨 날짜 범위(_selectedDateRange)가 null입니다! 그래서 종료됨.",
      ); // <--- 추가
      setState(() {
        _filteredEmails = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 2. [가장 중요] 401 에러의 핵심 해결책: 토큰 강제 체크 및 재인증
      // 웹에서는 Hot Restart 후 액세스 토큰이 유효하지 않은 경우가 많습니다.
      final auth = await _googleUser!.authentication;

      // 만약 토큰이 없으면 강제로 다시 로그인 창을 띄우거나 세션을 갱신합니다.
      if (auth.accessToken == null) {
        debugPrint("토큰 만료 감지: 재인증 시도");
        try {
          _googleUser = await AppLogin.googleSignIn.signIn(); // 다시 로그인 유도
          if (_googleUser == null) {
            debugPrint("🚨 사용자가 로그인창을 닫았거나 취소했습니다.");
            throw Exception("인증 실패");
          }
        } catch (error) {
          // ★★★ 이 부분이 가장 중요합니다! ★★★
          debugPrint("🚨 구글 로그인 에러 상세 발생: $error");
          throw error;
        }
      }

      final authHeaders = await _googleUser!.authHeaders;
      final authenticateClient = GoogleAuthClient(authHeaders);
      final gmailApi = gmail.GmailApi(authenticateClient);

      // 3. 쿼리 생성 (기존 로직 유지)
      // 3. 쿼리 생성 (타임스탬프 방식으로 정밀도 향상)

      // 시작일의 00:00:00 (초 단위)
      int startTimestamp =
          DateTime(
            _selectedDateRange!.start.year,
            _selectedDateRange!.start.month,
            _selectedDateRange!.start.day,
          ).millisecondsSinceEpoch ~/
          1000;

      // 종료일의 23:59:59 (초 단위)
      // 사용자가 선택한 종료일의 마지막 순간까지 포함하도록 설정합니다.
      int endTimestamp =
          DateTime(
            _selectedDateRange!.end.year,
            _selectedDateRange!.end.month,
            _selectedDateRange!.end.day,
            23,
            59,
            59,
          ).millisecondsSinceEpoch ~/
          1000;

      // Gmail API 쿼리에 타임스탬프를 직접 사용
      String q = "after:$startTimestamp before:$endTimestamp";

      debugPrint("🚀 생성된 쿼리 시점: $q");
      debugPrint(
        "시작: ${DateTime.fromMillisecondsSinceEpoch(startTimestamp * 1000)}",
      );
      debugPrint(
        "종료: ${DateTime.fromMillisecondsSinceEpoch(endTimestamp * 1000)}",
      );

      // 1. 화이트리스트에서 활성화된(true) 항목만 추출
      List<String> activeSenders = _whiteList
          .where((item) => item.contains(':true'))
          .map((item) => item.split(':')[0].trim())
          .toList();

      if (_isFilterEnabled) {
        if (activeSenders.isEmpty) {
          // 🚩 필터는 켜졌는데 허용된 보낸이가 하나도 없다면?
          // 결과는 무조건 0이어야 하므로 여기서 종료합니다.
          debugPrint("로그: 필터가 On이지만 활성화된 화이트리스트가 없음. 조회를 중단합니다.");
          setState(() {
            _filteredEmails = [];
            _isLoading = false;
          });
          return;
        }
        // 1. 도메인(@가 없는 항목)과 전체 이메일(@가 있는 항목) 분리
        List<String> domains = activeSenders
            .where((e) => !e.contains('@'))
            .toList();
        List<String> fullEmails = activeSenders
            .where((e) => e.contains('@'))
            .toList();

        List<String> queryParts = [];

        // 2. 전체 이메일 주소 쿼리 추가
        if (fullEmails.isNotEmpty) {
          queryParts.add(fullEmails.map((e) => 'from:$e').join(' OR '));
        }

        // 3. 도메인 주소 쿼리 추가
        if (domains.isNotEmpty) {
          queryParts.add(domains.map((e) => 'from:$e').join(' OR '));
        }

        // 4. 최종 쿼리 조합
        if (queryParts.isNotEmpty) {
          String senderQuery = queryParts.join(' OR ');
          q += " ($senderQuery)";
        }
      }

      // 4. API 호출
      debugPrint("로그 4: API 요청 쿼리(q) -> $q"); // <--- 추가
      final list = await gmailApi.users.messages.list(
        'me',
        q: q,
        maxResults: 100,
      );
      debugPrint("로그 5: 검색된 메일 개수 -> ${list.messages?.length ?? 0}"); // <--- 추가
      List<Map<String, dynamic>> fetchedEmails = [];

      if (list.messages != null) {
        for (var msg in list.messages!) {
          final details = await gmailApi.users.messages.get(
            'me',
            msg.id!,
            format: 'full',
          );

          DateTime timestamp = DateTime.fromMillisecondsSinceEpoch(
            int.parse(details.internalDate!),
          ).toLocal();

          String subject = '제목 없음';
          String from = '알 수 없음';
          String dateStr = '';
          String messageId = '';

          final headers = details.payload?.headers;
          if (headers != null) {
            for (var h in headers) {
              if (h.name == 'Subject') subject = h.value ?? '';
              if (h.name == 'From') from = h.value ?? '';
              if (h.name == 'Date') dateStr = h.value ?? '';
              if (h.name == 'Message-ID' || h.name == 'Message-Id') {
                messageId = h.value ?? '';
              }
            }
          }

          fetchedEmails.add({
            'id': msg.id,
            'threadId': msg.threadId,
            'subject': subject,
            'from': from,
            'date': dateStr,
            'timestamp': timestamp,
            'body': _decodeBody(details.payload!),
            'messageId': messageId,
          });
        }
      }

      setState(() {
        _filteredEmails = fetchedEmails;
        _isLoading = false;
      });
      await _checkSummarizedStatus();
    } catch (e) {
      debugPrint("메일 가져오기 에러: $e");
      // 401 에러가 나면 사용자에게 재로그인을 권유하거나 세션을 초기화합니다.
      if (e.toString().contains('401')) {
        debugPrint("인증 만료됨. 다시 로그인이 필요합니다.");
        // 필요 시 _googleSignIn.signIn()을 여기서 부를 수도 있습니다.
        setState(() {
          _googleUser = null; // 이 줄이 핵심입니다. 다시 로그인 버튼 화면으로 보냅니다.
          _isLoading = false;
        });
        await _checkSummarizedStatus();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _checkSummarizedStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('summaries')
        .get();

    if (mounted) {
      setState(() {
        _summarizedIds = snapshot.docs.map((doc) => doc.id).toSet();
      });
    }
  }

  String _extractEmail(String from) {
    final match = RegExp(r'<([^>]+)>').firstMatch(from);
    if (match != null) {
      return match.group(1) ?? from;
    }
    return from.trim();
  }

  void _addToWhiteListDirectly(String fromHeader, bool isDomainOnly) async {
    String fullEmail = _extractEmail(fromHeader);
    String entryToAdd = fullEmail;

    if (isDomainOnly) {
      final parts = fullEmail.split('@');
      if (parts.length > 1) {
        // [수정 포인트] 도메인 앞에 @를 추가합니다.
        entryToAdd = "@${parts[1]}";
      }
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // 중복 체크 시에도 @가 포함된 entryToAdd를 기준으로 확인합니다.
      bool alreadyExists = _whiteList.any(
        (item) => item.split(':')[0].trim() == entryToAdd,
      );

      if (alreadyExists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("'$entryToAdd'은(는) 이미 등록되어 있습니다.")),
        );
        return;
      }

      List<String> newList = List.from(_whiteList);
      // @가 포함된 상태로 리스트에 추가됩니다.
      newList.add("$entryToAdd:true");

      Map<String, bool> whiteListMap = {};
      for (var item in newList) {
        final p = item.split(':');
        if (p.length >= 2) {
          whiteListMap[p[0].trim()] = p[1].trim().toLowerCase() == 'true';
        }
      }

      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'whiteListMap': whiteListMap});

        setState(() {
          _whiteList = newList;
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("'$entryToAdd' 추가 완료!")));

        // _fetchEmails();
      } catch (e) {
        debugPrint("에러: $e");
      }
    }
  }

  // 1. 요약 실행 로직 (서버 호출 방식으로 수정됨)
  Future<void> _summarizeEmail(
    Map<String, dynamic> email, {
    bool forceRefresh = false,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('DEBUG: [로그인 에러] 사용자가 로그인되어 있지 않음');
      return;
    }

    final mailId = email['id'];
    print('DEBUG: [분석 시작] mailId: $mailId, forceRefresh: $forceRefresh');
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('summaries')
        .doc(mailId);

    // 1. 캐시 데이터 로드 로직
    if (!forceRefresh) {
      final doc = await docRef.get();
      if (doc.exists) {
        print('DEBUG: [캐시 발견] Firestore에서 기존 데이터를 불러옵니다.');
        final data = doc.data()!;
        setState(() {
          // Firestore에 'result'로 저장된 값이 Map인지 확인 후 처리
          _summarizedContent[mailId] = data['result'];
          _extractedEventData[mailId] = data['eventData'];
          // _currentDetectedEvent = data['eventData'];
        });
        return;
      }
    }
    print('DEBUG: [서버 요청] 캐시가 없거나 강제 새로고침입니다. 서버로 요청을 보냅니다.');
    setState(() {
      // _summarizedContent[mailId] = "요약 중...";
      _summarizedContent.remove(mailId);
      // _currentDetectedEvent = null; // 요청 시작 시 이전 일정 초기화
    });

    final String activePrompt = (_selectedPromptType == 0)
        ? _customPrompt
        : _galleryPrompt;
    final String finalInstruction = activePrompt.isEmpty
        ? _customPrompt
        : activePrompt;

    try {
      print('DEBUG: [HTTP POST] URL: ${AppConstants.summaryServerUrl}');
      final response = await http
          .post(
            Uri.parse(AppConstants.summaryServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'mailId': mailId,
              'emailContent':
                  """
Message-ID: ${email['messageId'] ?? ''} 
Subject: ${email['subject']}
From: ${email['from']}
Body: ${email['body']}
""",
              'promptInstruction': finalInstruction,
            }),
          )
          .timeout(const Duration(seconds: 20)); // 20초 안에 응답 없으면 에러로 간주
      print('DEBUG: [서버 응답 받음] StatusCode: ${response.statusCode}');
      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> parsedJson = jsonDecode(response.body);
          print('DEBUG: [응답 데이터] $parsedJson');
          if (parsedJson['status'] == 'error') {
            print('DEBUG: [서버 비즈니스 에러] status가 error입니다. 가이드를 표시합니다.');
            _setErrorState(mailId);
            // 가이드 메시지이므로 이후 '정상 분석' 로직을 타지 않고 종료
            return;
          }
          // 1. event_info 추출 (List일 수도, Map일 수도 있음)
          final dynamic rawEventData = parsedJson['event_info'];
          List<dynamic> eventList = [];

          if (rawEventData is List) {
            // 이미 배열인 경우: 비어있지 않은 것만 필터링
            eventList = rawEventData
                .where(
                  (e) => e['title'] != null && e['title'].toString().isNotEmpty,
                )
                .toList();
          } else if (rawEventData is Map && rawEventData.isNotEmpty) {
            // 단일 객체인 경우: 리스트로 감싸줌
            if (rawEventData['title']?.toString().isNotEmpty ?? false) {
              eventList = [rawEventData];
            }
          }

          final String? finalMessageId = parsedJson['message_id'];

          setState(() {
            _summarizedContent[mailId] = parsedJson;

            // 2. 일정 데이터 처리 (비어있으면 null, 있으면 리스트 저장)
            if (eventList.isEmpty) {
              _extractedEventData[mailId] = null;
              // _currentDetectedEvent = null;
            } else {
              // 여러 개가 들어와도 그대로 저장 (나중에 위젯에서 ListView.builder 등으로 표시)
              _extractedEventData[mailId] = eventList;
              // _currentDetectedEvent = eventList;
            }
          });

          // 3. Firestore 저장
          await docRef.set({
            'result': parsedJson,
            'eventData': eventList.isEmpty ? null : eventList, // 배열 형태로 저장됨
            'messageId': finalMessageId,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('DEBUG: [성공] 데이터를 화면에 표시하고 Firestore에 저장합니다.');
        } catch (e) {
          debugPrint("❌ JSON 파싱 에러: $e");
          _setErrorState(mailId); // 👈 헬퍼 함수로 통일
        }
      } else {
        print('DEBUG: [서버 응답 오류] StatusCode가 200이 아닙니다.');
        _setErrorState(mailId); // 👈 서버 응답 오류 시에도 가이드 표시
      }
    } catch (e) {
      debugPrint("에러 발생: $e");
      _setErrorState(mailId); // 👈 타임아웃 등 통신 에러 시에도 가이드 표시
    }
  }

  void _setErrorState(String mailId) {
    setState(() {
      _summarizedContent[mailId] = {
        "status": "error",
        "message": "분석을 완료하지 못했습니다.",
        "guide":
            "여러 번의 회신이 겹친 **스레드 메일**의 경우, 프롬프트에 복잡한 가정이나 모호한 지시가 포함되면 AI가 분석 중 오류가 발생할 수 있습니다.\n"
            "프롬프트에서 AI가 **판단** 또는 **가정**을 하도록 지시하는 내용 대신 **단순**하고 **명확**하게 지시해 주시면,\n"
            "훨씬 빠르고 정확한 요약 결과를 얻으실 수 있습니다.",
      };
    });
  }

  List<Map<String, dynamic>> get _displayEmails {
    if (_searchQuery.isEmpty) return _filteredEmails;
    return _filteredEmails.where((email) {
      final subject = (email['subject'] ?? '').toLowerCase();
      final from = (email['from'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return subject.contains(query) || from.contains(query);
    }).toList();
  }

  Widget _buildCalendarEventCard(dynamic eventData) {
    if (eventData == null) return const SizedBox.shrink();

    List<dynamic> events = [];
    if (eventData is List) {
      events = eventData;
    } else if (eventData is Map) {
      events = [eventData];
    }

    final validEvents = events
        .where(
          (e) =>
              e is Map &&
              e['title'] != null &&
              e['title'].toString().trim().isNotEmpty,
        )
        .toList();

    if (validEvents.isEmpty) return const SizedBox.shrink();

    // 내부적으로 반복되는 카드 UI를 정의 (웹/모바일 공통 사용)
    Widget buildSingleCard(Map<String, dynamic> event, {bool isWeb = false}) {
      return Container(
        margin: isWeb
            ? const EdgeInsets.only(bottom: 12) // 웹은 아래로 간격
            : const EdgeInsets.only(right: 12), // 모바일은 옆으로 간격
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // 웹에서 세로로 보일 때 공간 최적화
          children: [
            Text(
              "📌 제목: ${event['title']}",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Divider(height: 20),
            Text(
              "⏰ 일시: ${event['start']}",
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 4),
            if (event['location'] != null && event['location'] != '')
              Text(
                "📍 장소: ${event['location']}",
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _addToGoogleCalendar(event),
                icon: const Icon(Icons.add, size: 18),
                label: const Text("내 캘린더에 추가"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // --- 메인 레이아웃 ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            children: [
              const Icon(Icons.calendar_month, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              Text(
                "감지된 일정 (${validEvents.length}개)",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              if (!kIsWeb && validEvents.length > 1) // 모바일에서만 가이드 텍스트 표시
                const Expanded(
                  child: Text(
                    "옆으로 밀어서 확인 ➔",
                    textAlign: TextAlign.end,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 환경별 분기 처리
        kIsWeb
            ? Column(
                // 💻 웹: 세로로 쭉 나열
                children: validEvents
                    .map(
                      (e) => buildSingleCard(
                        e as Map<String, dynamic>,
                        isWeb: true,
                      ),
                    )
                    .toList(),
              )
            : SizedBox(
                // 📱 모바일: 가로 슬라이드
                height: 240, // 카드 높이에 맞춰 조절
                child: PageView.builder(
                  controller: PageController(viewportFraction: 0.85),
                  itemCount: validEvents.length,
                  itemBuilder: (context, index) {
                    return buildSingleCard(
                      validEvents[index] as Map<String, dynamic>,
                    );
                  },
                ),
              ),
      ],
    );
  }

  Future<void> _addToGoogleCalendar(Map<String, dynamic> eventData) async {
    try {
      // 1. [수정] 매번 disconnect()를 하면 로그인을 다시 해야 하므로 삭제합니다.
      // 대신 현재 로그인된 유저가 있는지 확인합니다.
      GoogleSignInAccount? googleUser = AppLogin.googleSignIn.currentUser;

      // 만약 로그인 정보가 없다면 새로 로그인을 시도합니다.
      if (googleUser == null) {
        googleUser = await AppLogin.googleSignIn.signInSilently(); // 먼저 조용히 시도
        googleUser ??= await AppLogin.googleSignIn.signIn(); // 안되면 로그인창 띄움
      }

      if (googleUser == null) return;

      // 2. [핵심 수정] 모바일에서 에러 나는 hasAccess 대신 requestScopes만 사용합니다.
      // requestScopes는 이미 권한이 있으면 창을 띄우지 않고 바로 true를 반환합니다.
      final bool granted = await AppLogin.googleSignIn.requestScopes([
        'https://www.googleapis.com/auth/calendar.events',
      ]);

      if (!granted) {
        throw Exception("캘린더 권한이 거부되었습니다.");
      }

      // 3. 인증 정보 가져오기
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // 4. AuthClient 생성 (기존 로직 유지)
      final httpClient = authenticatedClient(
        http.Client(),
        AccessCredentials(
          AccessToken(
            'Bearer',
            googleAuth.accessToken!,
            DateTime.now().add(const Duration(hours: 1)).toUtc(),
          ),
          null,
          ['https://www.googleapis.com/auth/calendar.events'],
        ),
      );

      final calendarApi = cal.CalendarApi(httpClient);

      // 5. 이벤트 객체 구성 (기존 로직 유지)
      DateTime startDateTime = DateTime.parse(eventData['start']);

      final event = cal.Event()
        ..summary = eventData['title']
        ..location = eventData['location'] ?? ""
        ..description = "Gemini AI가 메일에서 추출한 일정입니다."
        ..start = (cal.EventDateTime()
          ..dateTime = startDateTime.toUtc()
          ..timeZone = "UTC")
        ..end = (cal.EventDateTime()
          ..dateTime = startDateTime.add(const Duration(hours: 1)).toUtc()
          ..timeZone = "UTC");

      // 6. 캘린더에 삽입
      await calendarApi.events.insert(event, "primary");

      // 7. 성공 알림
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ 구글 캘린더에 일정이 성공적으로 등록되었습니다!")),
        );
      }
    } catch (e) {
      debugPrint("캘린더 등록 에러: $e");
      if (mounted) {
        // 에러 메시지가 너무 길면 사용자에게 불편하므로 간단히 표시
        String errorMessage = e.toString().contains("Unimplemented")
            ? "라이브러리 구현 오류가 발생했습니다. 앱을 재시작해 보세요."
            : e.toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("❌ 캘린더 등록 실패: $errorMessage")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // [1] 로그인 전 화면
    if (_googleUser == null) {
      return Scaffold(
        body: Center(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.login),
            label: const Text("구글 로그인으로 시작하기"),
            onPressed: () async {
              // 1. AppLogin 서비스를 통해 로그인 실행
              final user = await AppLogin.signInWithGoogle();

              if (user != null) {
                setState(() {
                  _googleUser = AppLogin.googleSignIn.currentUser;
                });

                // 3. 데이터 로드 및 이메일 가져오기
                await _loadInitialData();
                _fetchEmails();
              }
            },
          ),
        ),
      );
    }

    // [2] 로그인 후 화면 (반응형 레이아웃)
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 42,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            style: const TextStyle(fontSize: 15),
            decoration: InputDecoration(
              hintText: _searchQuery.isEmpty
                  ? "전체 ${_filteredEmails.length}건의 메일 검색"
                  : "검색 결과 ${_displayEmails.length}건",
              hintStyle: TextStyle(fontSize: 14, color: Colors.grey[400]),
              prefixIcon: Icon(
                Icons.search,
                color: Colors.blueAccent[700],
                size: 22,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.clear,
                        size: 20,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.account_circle, size: 30),
              onPressed: () {
                // 1. 상태를 true로 변경하여 endDrawer 위젯이 생성되게 함
                print("GOOGLE USER: $_googleUser");
                print("USER MODEL: $_currentUserModel");
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      drawer: FilterDrawer(
        whiteList: _whiteList,
        isFilterEnabled: _isFilterEnabled,
        isProfileRegistered:
            _currentUserModel != null && _currentUserModel!.name.isNotEmpty,
        onFilterModeChanged: (val) => setState(() => _isFilterEnabled = val),
        customPrompt: _customPrompt,
        galleryPrompt: _galleryPrompt,
        selectedPromptType: _selectedPromptType,
        selectedDateRange: _selectedDateRange,
        nickname: _currentUserModel?.nickname,
        onSave:
            (
              newList,
              newPrompt,
              newGalleryPrompt,
              newRange,
              selectedTab,
            ) async {
              setState(() {
                _selectedEmail = null;
                // _currentDetectedEvent = null;
              });
              Map<String, bool> whiteListMap = {};
              for (var item in newList) {
                final parts = item.toString().split(':');
                if (parts.length >= 2) {
                  whiteListMap[parts[0].trim()] =
                      parts[1].trim().toLowerCase() == 'true';
                } else {
                  whiteListMap[item.toString().trim()] = true;
                }
              }
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                Map<String, dynamic> saveData = {
                  'whiteListMap': whiteListMap,
                  'customPrompt': newPrompt,
                  'galleryPrompt': newGalleryPrompt,
                  'selectedPromptType': selectedTab,
                };
                if (newRange != null) {
                  saveData['startDate'] = newRange.start.toIso8601String();
                  saveData['endDate'] = newRange.end.toIso8601String();
                }
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update(saveData);
                setState(() {
                  _whiteList = newList;
                  _customPrompt = newPrompt;
                  _galleryPrompt = newGalleryPrompt ?? "";
                  _selectedPromptType = selectedTab;
                  _selectedDateRange = newRange;
                });
                _fetchEmails();
              }
            },
        // isProfileRegistered:
        //     _currentUserModel != null && _currentUserModel!.isRegistered,
      ),
      endDrawer: _googleUser == null
          ? null // 구글 로그인조차 안 되어 있으면 표시 안 함
          : ProfileDrawer(
              // 데이터가 없으면(null이면) 구글 계정 이름이라도 넣어서 창을 만듭니다.
              key: ValueKey('profile_drawer_$_isAdmin'),
              user:
                  _currentUserModel ??
                  UserModel(
                    name: _googleUser?.displayName ?? "사용자",
                    englishName: '',
                    nickname: '',
                    gender: '',
                    birthday: '',
                    country: '',
                    address: '',
                  ),
              googleSignIn: AppLogin.googleSignIn,
              onLogout: _handleFullSignOut,
              isAdmin: _isAdmin,
              onSave: (updatedUser) async {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(user.uid)
                      .set({
                        'name': updatedUser.name,
                        'englishName': updatedUser.englishName,
                        'nickname': updatedUser.nickname,
                        'gender': updatedUser.gender,
                        'birthday': updatedUser.birthday,
                        'country': updatedUser.country,
                        'address': updatedUser.address,
                      }, SetOptions(merge: true));

                  setState(() {
                    _currentUserModel = updatedUser;
                  });
                }
              },
            ),

      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 700) {
            return Row(
              children: [
                // [1] 왼쪽 리스트 영역
                SizedBox(
                  width: _leftWidth,
                  child: Stack(
                    // Column을 Stack으로 감싸서 버튼을 위에 올립니다.
                    children: [
                      Column(
                        children: [
                          if (_selectedDateRange != null) _buildDateHeader(),
                          Expanded(child: _buildMainEmailList()),
                        ],
                      ),
                    ],
                  ),
                ),

                // [2] 마우스로 조절 가능한 경계선
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: (details) {
                    setState(() {
                      // 마우스 이동만큼 너비를 조절 (최소 200, 최대는 전체 너비의 70%)
                      _leftWidth += details.delta.dx;
                      if (_leftWidth < 200) _leftWidth = 200;
                      if (_leftWidth > constraints.maxWidth * 0.7)
                        _leftWidth = constraints.maxWidth * 0.7;
                    });
                  },
                  child: MouseRegion(
                    cursor: SystemMouseCursors.resizeLeftRight, // 마우스 커서 모양 변경
                    child: Container(
                      width: 6, // 실제 클릭 가능한 영역은 약간 넓게
                      color: Colors.grey[200], // 아주 연한 회색 실선
                      child: Center(
                        child: Container(
                          width: 1,
                          color: Colors.grey[400],
                        ), // 가운데 진한 선
                      ),
                    ),
                  ),
                ),

                // [3] 오른쪽 요약 상세 영역
                Expanded(
                  flex: 2,
                  child: _selectedEmail == null
                      ? const Center(child: Text("메일을 선택해 주세요."))
                      : WebEmailDetailView(
                          email: _selectedEmail!,
                          rawData: _summarizedContent[_selectedEmail!['id']],
                          analysisMap:
                              _summarizedContent[_selectedEmail!['id']] is Map
                              ? _summarizedContent[_selectedEmail!['id']]
                              : null,
                          // ✅ 일정 데이터 전달
                          eventData: _extractedEventData[_selectedEmail!['id']],
                          onRefresh: () {
                            _summarizeEmail(
                              _selectedEmail!,
                              forceRefresh: true,
                            );
                          },
                          // ✅ 캘린더 추가 함수 연결
                          onAddToCalendar: (event) =>
                              _addToGoogleCalendar(event),
                        ),
                ),
              ],
            );
          }

          // 모바일 레이아웃 (기존 동일)
          return Column(
            children: [
              if (_selectedDateRange != null) _buildDateHeader(),
              Expanded(child: _buildMainEmailList()),
            ],
          );
        },
      ),
      // Scaffold의 마지막 부분입니다.
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          // 1. 모바일 환경 (너비 700 이하)
          if (constraints.maxWidth <= 700) {
            // 상세창이 열려있을 때만 숨기고, 리스트에서는 선택 여부 상관없이 보여줌
            return _isMobileDetailOpen
                ? const SizedBox.shrink()
                : const ManualButton();
          }
          // 2. 웹 환경 (너비 700 초과)
          else {
            // 기존 로직 유지: 메일이 선택되지 않았을 때만 보여줌
            return _selectedEmail == null
                ? const ManualButton()
                : const SizedBox.shrink();
          }
        },
      ),
    ); // Scaffold 끝
  }

  // --- 아래는 가독성을 위해 build 함수에서 로직을 분리한 보조 위젯들입니다 ---

  // 1. 상단 날짜 표시 바
  Widget _buildDateHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey[100],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 14, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            "${_selectedDateRange!.start.year}/${_selectedDateRange!.start.month.toString().padLeft(2, '0')}/${_selectedDateRange!.start.day.toString().padLeft(2, '0')} ~ "
            "${_selectedDateRange!.end.year}/${_selectedDateRange!.end.month.toString().padLeft(2, '0')}/${_selectedDateRange!.end.day.toString().padLeft(2, '0')}",
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // 2. 메일 리스트 (기존 로직 유지)
  Widget _buildMainEmailList() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_displayEmails.isEmpty) {
      return const Center(child: Text("조건에 맞는 메일이 없습니다."));
    }

    // [수정] RefreshIndicator로 ListView를 감쌉니다.
    return RefreshIndicator(
      onRefresh: () async {
        // 화면을 당겼을 때 실행될 함수 (메일 목록 새로고침)
        await _fetchEmails();
      },
      child: ListView.builder(
        // [중요] 리스트가 짧아도 당겨지도록 물리 효과를 강제 적용합니다.
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _displayEmails.length,
        itemBuilder: (context, index) {
          final email = _displayEmails[index];
          final from = email['from'] ?? '알 수 없음';
          final bool isSelected =
              _selectedEmail != null && _selectedEmail!['id'] == email['id'];

          return ListTile(
            tileColor: isSelected ? Colors.blue[50] : Colors.white,
            title: Text(
              email['subject'],
              style: TextStyle(
                fontWeight: _readIds.contains(email['id'])
                    ? FontWeight.normal
                    : FontWeight.bold,
                color: _readIds.contains(email['id'])
                    ? Colors.grey
                    : Colors.black,
              ),
            ),
            subtitle: Text(
              "$from\n${_formatDate(email['timestamp'])}",
              style: TextStyle(
                fontSize: 12,
                color: _summarizedIds.contains(email['id'])
                    ? Colors.grey[400]
                    : Colors.grey[600],
              ),
            ),
            onTap: () async {
              final bool isMobile = MediaQuery.of(context).size.width <= 700;
              final selectedEmail = Map<String, dynamic>.from(email);

              if (isMobile) {
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  barrierColor: Colors.transparent,
                  builder: (context) =>
                      const Center(child: CircularProgressIndicator()),
                );
              }

              try {
                setState(() {
                  _selectedEmail = selectedEmail;
                  _isMobileDetailOpen = true;
                  if (!_readIds.contains(email['id'])) {
                    _readIds.add(email['id']);
                  }
                });

                _markAsRead(email['id']);

                if (isMobile) {
                  // 1. 여기서 새로운 _summarizeEmail이 실행되며 _currentDetectedEvent에 JSON 일정이 담깁니다.
                  await _summarizeEmail(selectedEmail, forceRefresh: false);

                  if (!mounted) return;
                  Navigator.of(context, rootNavigator: true).pop();

                  // 2. 상세 페이지로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) {
                        // 1. 공통으로 사용할 데이터 추출 로직
                        final dynamic rawData =
                            _summarizedContent[selectedEmail['id']];

                        // 데이터가 Map일 경우 내부 값을 추출하고, 아니면 null 처리
                        // final Map<String, dynamic>? analysisMap =
                        //     (rawData is Map<String, dynamic>) ? rawData : null;
                        // final String? extractedSummary = analysisMap != null
                        //     ? analysisMap['summary']
                        //     : rawData?.toString();
                        // final String? extractedMessageId = analysisMap != null
                        //     ? analysisMap['message_id']
                        //     : null;

                        return EmailDetailScreen(
                          email: selectedEmail,
                          summary: rawData,
                          messageIdFromGemini: (rawData is Map)
                              ? rawData['message_id']
                              : null,
                          calendarCard: _buildCalendarEventCard(
                            _extractedEventData[selectedEmail['id']],
                          ),
                          onRefresh: () async {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            );

                            await _summarizeEmail(
                              selectedEmail,
                              forceRefresh: true,
                            );

                            if (context.mounted) Navigator.of(context).pop();

                            if (context.mounted) {
                              // 새로고침 후 다시 그릴 때도 동일한 로직 적용
                              final dynamic freshRawData =
                                  _summarizedContent[selectedEmail['id']];
                              // final Map<String, dynamic>? freshMap =
                              //     (freshRawData is Map<String, dynamic>)
                              //     ? freshRawData
                              //     : null;

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => EmailDetailScreen(
                                    email: selectedEmail,
                                    summary: freshRawData,
                                    messageIdFromGemini: (freshRawData is Map)
                                        ? freshRawData['message_id']
                                        : null,
                                    calendarCard: _buildCalendarEventCard(
                                      _extractedEventData[selectedEmail['id']],
                                    ),
                                    onRefresh: () {},
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ).then((_) {
                    setState(() {
                      _isMobileDetailOpen =
                          false; // 상세창 상태만 해제 (선택된 메일 강조는 유지됨)
                    });
                  });
                } else {
                  _summarizeEmail(selectedEmail, forceRefresh: false);
                }
              } catch (e) {
                if (isMobile && mounted)
                  Navigator.of(context, rootNavigator: true).pop();
                debugPrint("메일 선택 중 에러 발생: $e");
              }
            },
            onLongPress: () => _showWhiteListDialog(context, from),
          );
        },
      ),
    );
  }

  Future<void> _markAsRead(String mailId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('read_mails') // 읽음 전용 컬렉션
          .doc(mailId)
          .set({'readAt': FieldValue.serverTimestamp()});
    } catch (e) {
      debugPrint("읽음 표시 저장 실패: $e");
    }
  }

  // 4. 화이트리스트 팝업 (기존 로직 보존)
  void _showWhiteListDialog(BuildContext context, String from) {
    if (_whiteList.length >= 10) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "알림",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text("베타 테스트 기간에는 발신 주소를 최대 10개까지 등록 가능합니다. 🐱"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("확인"),
            ),
          ],
        ),
      );
      return; // 10개 이상이면 여기서 함수를 종료하여 추가 창 자체를 띄우지 않습니다.
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "화이트리스트 추가",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("이 발신자를 필터에 추가하시겠습니까?"),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                from,
                style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              _addToWhiteListDirectly(from, false);
              Navigator.pop(context);
            },
            child: const Text("이메일 추가"),
          ),
          ElevatedButton(
            onPressed: () {
              _addToWhiteListDirectly(from, true);
              Navigator.pop(context);
            },
            child: const Text("도메인 추가"),
          ),
        ],
      ),
    );
  }

  // 헬퍼 함수 수정

  String _formatDate(DateTime dt) {
    String month = dt.month.toString().padLeft(2, '0');
    String day = dt.day.toString().padLeft(2, '0');
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');
    return "${dt.year}/$month/$day $hour:$minute";
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}
