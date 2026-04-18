import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:http/http.dart' as http;
import 'package:googleapis_auth/googleapis_auth.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:googleapis/calendar/v3.dart' as cal;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'services/mail_cache_manager.dart';
import 'widgets/calendar_range_picker.dart';

import 'dart:convert';
import 'services/app_login.dart';
import 'dart:async';

import 'constants.dart';
import 'firebase_options.dart';
import 'widgets/filter_drawer.dart';
import 'widgets/profile_drawer.dart';
// import 'widgets/manual_button.dart';
import 'models/user_model.dart';
import 'email_detail_screen.dart';
import 'web_email_detail_view.dart';

import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;
import 'landing_page.dart';
import 'video_splash.dart';
import 'package:flutter/gestures.dart';
import 'services/gmail_service.dart';
import 'models/integrated_mail.dart';
import 'services/naver_mail_service.dart';
import 'services/daum_mail_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'manual_manager.dart';
import 'widgets/ai_prompt_button.dart';

// 🎯 [추가] 실행 시 환경을 결정하는 변수 (기본값은 dev)
// 터미널에서 flutter run --dart-define=APP_FLAVOR=qas 로 실행하면 qas로 붙습니다.
const String appFlavor = String.fromEnvironment(
  'APP_FLAVOR',
  defaultValue: 'qas',
);

/// 이메일 AI 요약 디버그. Chrome 개발자 도구 콘솔·`flutter run` 로그에서 **`CatchySummary`** 로 검색.
void logCatchySummary(String phase, String detail, {Object? error}) {
  final iso = DateTime.now().toUtc().toIso8601String();
  final platform = kIsWeb ? 'web' : 'native';
  final err = error != null ? '|err=$error' : '';
  print('CatchySummary|$iso|$platform|$phase|$detail$err');
}

String _catchySummaryTruncate(String? text, int maxChars) {
  if (text == null || text.isEmpty) return '(empty)';
  if (text.length <= maxChars) return text;
  return '${text.substring(0, maxChars)}...(totalLen=${text.length})';
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    GestureBinding.instance.resamplingEnabled = true;

    // Firebase 초기화
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // ✅ [변경] 로컬 캐시(Hive) 환경 설정만 초기화
    // 이전의 init() 대신 setupHive()를 호출하여 어댑터 등록까지만 마칩니다.
    // 실제 데이터 박스는 로그인 성공 후 이메일을 받아 initUserBox(email)에서 열게 됩니다.
    await MailCacheManager.setupHive();

    debugPrint("✅ Hive 환경 설정 완료 (어댑터 등록됨)");
  } catch (e) {
    debugPrint("초기화 에러: $e");
  }

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

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  Timer? _autoSyncTimer;
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
  DateTime _lastPromptUpdateTime = DateTime.now(); // 프롬프트가 마지막으로 바뀐 시간

  List<IntegratedMail> _filteredEmails = [];
  List<IntegratedMail> _displayEmails = [];
  bool _isFilterEnabled = false; // 필터링 활성화 여부 상태 변수

  bool _isMobileDetailOpen = false;
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();
  Set<String> _summarizedIds = {}; // 요약된 메일 ID 세트
  Map<String, dynamic>? _selectedEmail; // 현재 웹에서 선택된 메일을 저장
  Map<String, dynamic> _summarizedContent = {}; // 요약 텍스트 저장용

  Map<String, dynamic> _extractedEventData = {}; // value 타입을 dynamic으로 변경
  double _leftWidth = 350; // 기본 왼쪽 리스트 너비
  Set<String> _readIds = {};
  late final GmailService _gmailService;
  late final NaverMailService _naverService;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = AppLogin.googleSignIn;
  final _daumService = DaumMailService();
  final ScrollController _scrollController = ScrollController();

  bool _hasNewMails = false; // 새 메일 알림 버튼 표시 여부
  // bool _showScrollButtons = false; // 버튼 표시 상태
  bool _showScrollHUD = false; // HUD 표시 여부
  Timer? _hudTimer; // 2~3초 후 숨기기 위한 타이머
  // List<IntegratedMail> _latestServerMails = []; // 서버에서 방금 가져온 메일 임시 보관
  bool _isInitialized = false; // 앱이 최소 한 번은 데이터를 가져왔는지 여부
  double _loadingProgress = 0.0; // 0.0 ~ 1.0 사이의 진척도
  bool _isSelectionMode = false; // 현재 선택 모드인지 여부
  Set<String> _selectedMailIds = {}; // 선택된 메일의 ID들 (중복 방지를 위해 Set 사용)
  final FocusNode _searchFocusNode = FocusNode(); // 검색창 포커스 감지
  bool _isSearchFocused = false; // 현재 검색창이 활성화되었는지 여부
  /// true이면 읽은 메일(`_readIds`)은 목록에서 제외하고 안읽은 메일만 표시
  bool _filterUnreadOnly = false;
  Timer? _syncTimer;
  bool _isSyncing = false; // 현재 동기화 중인지 체크하는 플래그

  /// [ _loadInitialData ] 동시 호출을 한 줄로 묶어 서로 상태를 덮어쓰지 않게 합니다.
  Future<void>? _profileLoadInFlight;

  // 초기값은 모든 메일사가 선택된 상태 (Set을 활용해 멀티 선택 구현)
  Set<MailSource> _selectedSources = {
    MailSource.gmail,
    MailSource.naver,
    MailSource.daum,
  };

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
    WidgetsBinding.instance.addObserver(this);

    final now = DateTime.now();
    _selectedDateRange = DateTimeRange(
      start: DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 90)),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    _gmailService = GmailService(_googleSignIn);
    _naverService = NaverMailService();
    _preloadAdminConfig();

    Future.microtask(() async {
      // (A) 먼저 모든 하이브 박스를 엽니다.
      await MailCacheManager.setupHive();
      debugPrint("📦 모든 Hive 박스 준비 완료");

      setState(() {
        _isLoading = true;
        _loadingProgress = 0.05; // 5% 지점 표시
        _isInitialized = false;
      });

      _loadCachedDataOnly();
      await _fetchEmails(isBackground: false);
    });

    _autoSyncTimer = Timer.periodic(const Duration(minutes: 3), (timer) {
      debugPrint("⏰ [타이머] 정기 자동 동기화 시작...");
      _fetchEmails(isBackground: false);
    });

    AppLogin.googleSignIn.onCurrentUserChanged.listen((
      GoogleSignInAccount? account,
    ) async {
      // ✅ async 추가
      setState(() {
        _googleUser = account;
      });
      if (account != null) {
        // ✅ [추가] 자동 로그인 성공 시에도 해당 이메일로 Hive 박스 열기
        await MailCacheManager.initUserBox(account.email);

        bool isMatched = _adminEmails.contains(account.email.toLowerCase());
        setState(() {
          _isAdmin = isMatched;
        });
        // FirebaseAuth 반영 전에 돌면 프로필만 비우고 끝나는 레이스 방지 + 중복 호출 합침
        await _requestLoadInitialData();
      }
    });

    try {
      AppLogin.googleSignIn.signInSilently();
    } catch (e) {
      debugPrint("Silent Sign-in Error: $e");
    }
    _scrollController.addListener(() {
      // 스크롤 동작이 감지되면 실행
      if (mounted) {
        setState(() {
          _showScrollHUD = true;
        });

        // 기존 타이머가 있다면 취소하고 새로 시작 (스크롤 중에는 계속 유지)
        _hudTimer?.cancel();
        _hudTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showScrollHUD = false;
            });
          }
        });
      }
    });
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  // ✅ [추가] 캐시 데이터 로드 헬퍼 함수
  void _loadCachedDataOnly() {
    if (Hive.isBoxOpen('mail_cache_box')) {
      // 1. 먼저 캐시에 있는 거라도 보여줍니다.
      _updateUI();

      // 2. 웹 환경인데 캐시된 메일이 너무 적다면? 서버에서 새로 가져오도록 유도
      if (kIsWeb) {
        final cachedCount = MailCacheManager.getCachedMails().length;
        if (cachedCount < 5) {
          // 기준은 편하신 대로 조절 가능 (예: 5개 미만)
          debugPrint("🌐 웹 환경: 캐시가 부족하여 서버 동기화를 실행합니다.");
          _fetchEmails(isBackground: false);
          return; // 아래 로그 출력을 건너뜁니다.
        }
      }

      debugPrint("📂 로컬 캐시 로드 및 필터링 완료");
    } else {
      // 박스가 아직 안 열렸다면 0.2초 뒤에 다시 시도
      Future.delayed(
        const Duration(milliseconds: 200),
        () => _loadCachedDataOnly(),
      );
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

  @override
  void dispose() {
    _syncTimer?.cancel(); // ✅ 앱 종료 시 타이머를 반드시 해제
    // ✅ [추가] 감지기 해제
    WidgetsBinding.instance.removeObserver(this);
    // ✅ [추가] 타이머 해제
    _autoSyncTimer?.cancel();
    _searchController.dispose(); // 기존 컨트롤러가 있다면 함께 정리
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ✅ [추가] 다른 앱을 쓰다가 우리 앱으로 돌아왔을 때 실행되는 로직
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 'Resumed'(다시 활성화) 상태가 되었을 때
    if (state == AppLifecycleState.resumed) {
      if (!_isLoading) {
        debugPrint("🔙 [복귀] 앱 활성화: 최신 메일 체크 시작");
        _fetchEmails(isBackground: false);
      }
    }
  }

  /// 구글 [ onCurrentUserChanged ]와 로그인 버튼이 동시에 불러와도 한 번만 실행되도록 합니다.
  Future<void> _requestLoadInitialData() async {
    if (_profileLoadInFlight != null) {
      await _profileLoadInFlight;
      return;
    }
    _profileLoadInFlight = _runLoadInitialDataWhenFirebaseReady();
    try {
      await _profileLoadInFlight;
    } finally {
      _profileLoadInFlight = null;
    }
  }

  /// Google 계정은 잡혔는데 아직 [ FirebaseAuth.currentUser ]가 없을 때 잠깐 기다린 뒤 로드합니다.
  Future<void> _runLoadInitialDataWhenFirebaseReady() async {
    if (_googleUser == null) return;
    for (var i = 0; i < 40; i++) {
      if (!mounted) return;
      if (FirebaseAuth.instance.currentUser != null) {
        await _loadInitialData();
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    debugPrint(
      '⚠️ FirebaseAuth.currentUser 지연: 프로필/초기데이터 로드 생략 (최대 2초 대기)',
    );
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
          _currentUserModel = UserModel.fromMap(data);
          _customPrompt = data['customPrompt'] ?? "핵심 내용을 3줄로 요약해줘.";
          _galleryPrompt = data['galleryPrompt'] ?? "";
          _selectedPromptType = (data['selectedPromptType'] is int)
              ? data['selectedPromptType']
              : 0;
          _isFilterEnabled = data['filterOn'] ?? false;
          _selectedDateRange = loadedRange;
        });

        debugPrint("🚩 데이터 로드 완료: ${data['email']}");
        await _updateUI();
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

  // ✅ 1. UI 필터링만 전담하는 함수 (main.dart 내부에 추가)
  Future<void> _updateUI() async {
    // 1. DB에서 모든 메일 목록을 가져옴
    final allSavedMails = await MailCacheManager.getAllMails();

    if (!mounted) return;

    setState(() {
      final DateTime now = DateTime.now();
      final rangeStart =
          _selectedDateRange?.start ?? now.subtract(const Duration(days: 30));
      final rangeEnd = _selectedDateRange?.end ?? now;

      // --- (A) 1단계: 기간 및 화이트리스트 필터링 ---
      List<IntegratedMail> tempList = allSavedMails.where((mail) {
        final end = DateTime(
          rangeEnd.year,
          rangeEnd.month,
          rangeEnd.day,
          23,
          59,
          59,
        );

        bool inRange =
            mail.dateTime.isAfter(
              rangeStart.subtract(const Duration(seconds: 1)),
            ) &&
            mail.dateTime.isBefore(end.add(const Duration(seconds: 1)));

        if (!inRange) return false;

        bool isAllowed = true;
        if (_isFilterEnabled) {
          final activeWhitelist = _whiteList
              .where((item) => item.contains(':true'))
              .map((item) => item.split(':')[0].trim().toLowerCase())
              .toList();

          if (activeWhitelist.isEmpty) {
            isAllowed = false;
          } else {
            isAllowed = activeWhitelist.any(
              (w) =>
                  mail.sender.toLowerCase().contains(w) ||
                  mail.subject.toLowerCase().contains(w),
            );
          }
        }
        return isAllowed;
      }).toList();

      // --- (B) 2단계: 최신순 정렬 ---
      tempList.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      _filteredEmails = tempList; // 필터링+정렬된 원본 보관

      // --- (C) 3단계: 검색·소스·안읽음 등은 _applyAdvancedFilter()와 동일 로직 ---
      _displayEmails = _applyAdvancedFilter();
    });

    debugPrint(
      "📺 UI 업데이트 완료: ${_displayEmails.length}건 표시됨 (필터: $_isFilterEnabled)",
    );
  }

  // ✅ 1. 각 서비스(Naver, Daum) 호출을 위한 공통 보조 함수
  Future<List<IntegratedMail>> _fetchServiceEmails(
    String serviceName,
    dynamic serviceInstance,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // 로그 1: 함수 진입 확인
    debugPrint("🔍 [$serviceName] 동기화 시도 시작...");

    String? id = await _storage.read(key: '${serviceName}_id');
    String? pw = await _storage.read(key: '${serviceName}_pw');

    if (id == null || pw == null) {
      if (serviceName == 'naver') {
        id = _currentUserModel?.naverId;
        pw = _currentUserModel?.naverPw;
      } else if (serviceName == 'daum') {
        id = _currentUserModel?.daumId;
        pw = _currentUserModel?.daumPw;
      }
    }

    // 로그 2: 계정 정보 존재 여부 확인 (비밀번호는 보안상 일부만 출력)
    if (id == null || id.isEmpty || pw == null || pw.isEmpty) {
      debugPrint("⚠️ [$serviceName] 계정 ID 또는 PW가 없습니다. 수집을 중단합니다.");
      return [];
    }

    try {
      final mails = await serviceInstance.fetchEmails(
        userName: id,
        password: pw, // 💡 이제 pw가 절대 null이 아니므로 !가 필요 없습니다.
        whitelist: <String>[],
        startDate: startDate,
        endDate: endDate,
      );

      // 로그 3: 성공 결과 확인
      debugPrint("✅ [$serviceName] 수집 성공: ${mails.length}통의 메일을 가져왔습니다.");
      _logSyncActivity(serviceName, mails.length);
      return mails;
    } catch (e) {
      // 로그 4: 구체적인 에러 내용 확인
      debugPrint("🚨 [$serviceName] 수집 중 실제 에러 발생: $e");
      return [];
    }
  }

  // ✅ 2. 메인 통합 동기화 함수
  Future<void> _fetchEmails({
    bool isBackground = false,
    bool forceReSync = false,
  }) async {
    if (_isSyncing) {
      debugPrint("⏳ 이미 동기화가 진행 중입니다. 호출을 무시합니다.");
      return;
    }

    _isSyncing = true; // 실행 시작 표시
    // 0. 안전장치: 날짜 범위 설정
    if (_selectedDateRange == null) {
      final now = DateTime.now();
      _selectedDateRange = DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      );
    }

    try {
      final now = DateTime.now();

      // 현재 각 서비스의 동기화 기록 확인
      final lastSyncs = {
        'gmail': MailCacheManager.getLastSyncTime('gmail'),
        'naver': MailCacheManager.getLastSyncTime('naver'),
        'daum': MailCacheManager.getLastSyncTime('daum'),
      };

      // ✅ 하나라도 동기화 기록이 없으면 최초 실행으로 간주
      bool isFirstRun = lastSyncs.values.any((t) => t == null);

      // 1단계 시작 전 로딩바 설정 (최초 실행 혹은 강제 재시도일 때만)
      if (!isBackground) {
        setState(() {
          _isLoading = true;
          _loadingProgress = 0.1;
        });
      }

      // ---------------------------------------------------------
      // 1단계: 우선순위 수집 (최초 7일치 or 기존 증분 수집)
      // ---------------------------------------------------------
      DateTime? firstStepStart;
      if (isFirstRun && !forceReSync) {
        firstStepStart = now.subtract(const Duration(days: 7));
        debugPrint("🚀 [1단계] 최근 7일치 우선 수집 시작...");
      }

      // 헬퍼를 통해 시작 날짜 결정
      DateTime getStart(String s) {
        if (forceReSync) return _selectedDateRange!.start;
        if (firstStepStart != null) return firstStepStart; // 7일치
        final lastSync = lastSyncs[s];
        if (lastSync == null) return _selectedDateRange!.start;
        return lastSyncs[s]?.subtract(const Duration(hours: 1)) ??
            _selectedDateRange!.start;
      }

      await _executeFetchTasks(
        startDateGmail: getStart('gmail'),
        startDateNaver: getStart('naver'),
        startDateDaum: getStart('daum'),
        now: now,
        isBackground: isBackground,
        updateProgress: true,
        isFirstRun: isFirstRun,
      );

      // ✅ [중요] 1단계 완료 즉시 동기화 시간 기록 (무한루프 방지 핵심)
      // await MailCacheManager.saveLastSyncTime('gmail', now);
      // await MailCacheManager.saveLastSyncTime('naver', now);
      // await MailCacheManager.saveLastSyncTime('daum', now);

      // ✅ [중요] 1단계 결과 즉시 노출 및 로딩 바 제거
      await _updateUI();
      if (!isBackground) {
        setState(() {
          _isLoading = false; // 여기서 사용자는 메일을 즉시 보게 됨
          _loadingProgress = 1.0;
        });
      }

      // ---------------------------------------------------------
      // 2단계: 최초 실행 시 나머지 23일치 백그라운드 보충
      // ---------------------------------------------------------
      if (isFirstRun && !forceReSync) {
        debugPrint("🌙 [2단계] 나머지 23일치 5일 단위 분할 수집 시작...");

        // 1단계(7일치) 바로 이전 날부터 시작하여 설정된 전체 기간의 시작일까지 역순 수집
        DateTime currentEnd = now.subtract(const Duration(days: 8));
        DateTime finalStart =
            _selectedDateRange?.start ?? now.subtract(const Duration(days: 30));

        while (currentEnd.isAfter(finalStart)) {
          // 5일 단위로 구간 설정
          DateTime currentStart = currentEnd.subtract(const Duration(days: 5));
          if (currentStart.isBefore(finalStart)) currentStart = finalStart;

          debugPrint(
            "📅 [2단계 구간] ${currentStart.toString().split(' ')[0]} ~ ${currentEnd.toString().split(' ')[0]} 수집 중...",
          );

          await _executeFetchTasks(
            startDateGmail: currentStart,
            endDateGmail: currentEnd, // 💡 종료일 인자 추가
            startDateNaver: currentStart,
            startDateDaum: currentStart,
            now: now,
            isBackground: true,
            updateProgress: false,
            isFirstRun: isFirstRun,
          ).catchError((e) {
            debugPrint("🚨 구간 수집 중 상세 에러: $e");
          });

          // ✅ 한 구간 수집 완료될 때마다 UI 즉시 갱신 (사용자는 메일이 늘어나는 것을 실시간으로 봄)
          await _updateUI();

          // 다음 구간 설정을 위해 종료일을 현재 시작일의 1초 전으로 변경
          currentEnd = currentStart.subtract(const Duration(seconds: 1));

          // API 연속 호출 부하를 줄이기 위한 매너 타임
          await Future.delayed(const Duration(milliseconds: 300));
        }
        debugPrint("✅ [2단계] 모든 구간 분할 수집 완료");
      }

      _isInitialized = true;
      await _checkSummarizedStatus();
    } catch (e) {
      debugPrint("🚨 통합 동기화 에러: $e");
    } finally {
      // ✅ 어떤 상황에서도 함수가 끝나면 플래그를 해제
      _isSyncing = false;
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 중복되는 수집 및 저장 로직을 분리한 헬퍼 메서드
  Future<void> _executeFetchTasks({
    required DateTime startDateGmail,
    DateTime? endDateGmail,
    required DateTime startDateNaver,
    required DateTime startDateDaum,
    required DateTime now,
    required bool isBackground,
    required bool updateProgress,
    required bool isFirstRun,
  }) async {
    List<Future<List<IntegratedMail>>> tasks = [];
    List<String> activeServices = [];

    // 1. Gmail 수집 등록
    tasks.add(
      _gmailService.fetchEmails(
        query: _buildGmailQuery(
          startDate: startDateGmail,
          endDate: endDateGmail ?? now,
        ),
      ),
    );
    activeServices.add('gmail');

    final naverId = await _storage.read(key: 'naver_id');
    if (naverId != null && naverId.isNotEmpty) {
      debugPrint("📡 네이버 계정 감지됨. 수집 리스트에 추가합니다.");
      tasks.add(
        _fetchServiceEmails('naver', _naverService, startDateNaver, now),
      );
      activeServices.add('naver');
    }

    final daumId = await _storage.read(key: 'daum_id');
    if (daumId != null && daumId.isNotEmpty) {
      debugPrint("📡 다음 계정 감지됨. 수집 리스트에 추가합니다.");
      tasks.add(_fetchServiceEmails('daum', _daumService, startDateDaum, now));
      activeServices.add('daum');
    }

    if (tasks.isEmpty) return;
    int completedTasks = 0;

    // 2. 서비스별 실행 결과 수집 (실패 시 null을 반환하여 구분)
    final results = await Future.wait(
      tasks.asMap().entries.map((entry) async {
        try {
          final res = await entry.value;
          if (updateProgress && !isBackground && mounted) {
            completedTasks++;
            setState(() {
              _loadingProgress = 0.1 + (completedTasks / tasks.length * 0.9);
            });
          }
          return res; // 성공 시 리스트 반환
        } catch (e) {
          debugPrint("🚨 ${activeServices[entry.key]} 수집 실패: $e");
          return null; // 💡 실패 시 null 반환 (빈 리스트와 구분)
        }
      }),
    );

    // 3. 결과 처리 및 개별 동기화 시간 갱신
    List<IntegratedMail> allServerMails = [];

    for (int i = 0; i < results.length; i++) {
      final serviceName = activeServices[i];
      final serviceMails = results[i];

      // ✅ 해당 서비스가 'null'이 아니라는 것은 수집 프로세스가 성공했다는 뜻입니다.
      if (serviceMails != null) {
        if (serviceMails.isNotEmpty) {
          allServerMails.addAll(serviceMails);

          // 💡 최신 메일 날짜 추출 (성능 저하 없음)
          DateTime maxDate = serviceMails
              .map((m) => m.dateTime)
              .reduce((a, b) => a.isAfter(b) ? a : b);

          if (isBackground || !isFirstRun) {
            await MailCacheManager.saveLastSyncTime(serviceName, maxDate);
            debugPrint("💾 $serviceName: 최신 메일 날짜($maxDate)로 갱신 완료");
          }
        } else {
          // 메일은 없지만 에러 없이 수집을 마친 경우
          if (isBackground || !isFirstRun) {
            await MailCacheManager.saveLastSyncTime(serviceName, now);
            debugPrint("💾 $serviceName: 새 메일 없음. $now로 갱신");
          }
        }
      } else {
        // 💡 수집 실패(null)인 경우, 시간 갱신을 건너뛰어 다음 실행 시 누락 없이 재수집합니다.
        debugPrint("⚠️ $serviceName 수집 실패로 인해 시간 갱신을 건너뜁니다.");
      }
    }

    // 4. 최종 캐시 저장
    if (allServerMails.isNotEmpty) {
      await MailCacheManager.saveMails(allServerMails);
    }
  }

  Future<void> _showMobileDateSyncDialog(BuildContext context) async {
    final DateTime now = DateTime.now();
    // ✅ 기준을 3개월에서 1개월(30일)로 수정
    final DateTime oneMonthAgo = DateTime(now.year, now.month, now.day - 30);

    // ✅ 공통 위젯 호출 (하이라이트 및 테마가 이미 적용된 버전)
    final DateTimeRange? pickedRange = await CalendarRangePicker.show(
      context,
      initialRange: _selectedDateRange,
      onReSync: () {
        // ✅ '재수집' 버튼 클릭 시 실행될 로직
        setState(() {
          _selectedDateRange = DateTimeRange(start: oneMonthAgo, end: now);
        });
        _fetchEmails(forceReSync: true); // 강제 재동기화 실행
      },
    );

    // ✅ 일반 날짜 선택 결과가 있을 경우 적용
    if (pickedRange != null) {
      setState(() {
        _selectedDateRange = pickedRange;
      });
      _fetchEmails();
    }
  }

  Future<void> _showForceResyncDialog() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("전체 동기화"),
        content: const Text(
          "최근 90일간의 모든 데이터를 다시 동기화하시겠습니까?\n(데이터 양에 따라 시간이 걸릴 수 있습니다.)",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
            child: const Text("확인"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // 사용자가 확인을 눌렀을 때만 강제 재동기화 실행
      _fetchEmails(isBackground: false, forceReSync: true);
    }
  }

  List<IntegratedMail> _applyAdvancedFilter() {
    return _filteredEmails.where((email) {
      // 검색어 필터링
      final bool matchesSearch =
          _searchQuery.isEmpty ||
          email.subject.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          email.sender.toLowerCase().contains(_searchQuery.toLowerCase());

      // 소스(Gmail, Naver, Daum) 필터링
      final bool matchesSource = _selectedSources.contains(email.source);

      // 안읽음 전용: 읽은 메일 제외
      final bool matchesUnread =
          !_filterUnreadOnly || !_readIds.contains(email.id);

      return matchesSearch && matchesSource && matchesUnread;
    }).toList();
  }

  // 4. [추가] 상단 알림 인디케이터 위젯 (build 함수 상단에서 호출)
  Widget _buildNewMailIndicator() {
    if (!_hasNewMails) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () {
        setState(() {
          _updateUI();
          _hasNewMails = false;
        });
      },
      child: Container(
        width: double.infinity,
        color: Colors.blueAccent.withOpacity(0.9),
        padding: const EdgeInsets.symmetric(
          vertical: 10,
          horizontal: 16,
        ), // 가로 패딩 추가
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.refresh, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Flexible(
              child: Text(
                "새로운 메일이 도착했습니다. 확인하려면 클릭하세요.",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis, // 혹시 넘치면 ... 처리
                softWrap: false, // 줄바꿈 방지 (취향에 따라 true 가능)
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Firestore 로그 기록을 위한 헬퍼 함수 (코드 깔끔화)
  Future<void> _logSyncActivity(String platform, int count) async {
    if (count == 0) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        '${platform}_integration': {
          'last_sync_at': FieldValue.serverTimestamp(),
          'last_mail_count': count,
        },
      }, SetOptions(merge: true));
    }
  }

  // ✅ _fetchEmails 함수 아래에 추가
  String _buildGmailQuery({DateTime? startDate, DateTime? endDate}) {
    if (_selectedDateRange == null) return "";

    // ✅ 1. 외부에서 넘겨준 시작일이 있으면 그것을 우선 사용, 없으면 설정된 범위 사용
    final DateTime effectiveStart = startDate ?? _selectedDateRange!.start;
    final DateTime effectiveEnd = endDate ?? _selectedDateRange!.end;

    // 시작 시각 (Unix Timestamp 변환)
    int startTimestamp =
        DateTime(
          effectiveStart.year,
          effectiveStart.month,
          effectiveStart.day,
          effectiveStart.hour,
          effectiveStart.minute,
        ).millisecondsSinceEpoch ~/
        1000;

    int endTimestamp =
        DateTime(
          effectiveEnd.year,
          effectiveEnd.month,
          effectiveEnd.day,
          23,
          59,
          59, // 해당 날짜의 끝 시간까지 포함
        ).millisecondsSinceEpoch ~/
        1000;

    return "after:$startTimestamp before:$endTimestamp";
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
      logCatchySummary('auth', 'no_firebase_user abort');
      return;
    }

    final mailId = email['id'];
    logCatchySummary(
      'start',
      'mailId=$mailId forceRefresh=$forceRefresh subject=${_catchySummaryTruncate(email['subject']?.toString(), 80)}',
    );
    final docRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('summaries')
        .doc(mailId);

    // 1. 캐시 데이터 로드 로직 (시간 비교 로직 추가)
    if (!forceRefresh) {
      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data()!;

        // [핵심 추가: 시간차 오류 해결]
        // Firestore의 저장된 시간(updatedAt)을 가져옴
        final dynamic updatedAtRaw = data['updatedAt'];
        DateTime? updatedTime;

        if (updatedAtRaw is Timestamp) {
          updatedTime = updatedAtRaw.toDate();
        }

        // 분석된 시간이 프롬프트 수정 시간보다 이전이면 캐시 무시
        bool isOutdated =
            (updatedTime == null) ||
            updatedTime.isBefore(_lastPromptUpdateTime);

        if (!isOutdated) {
          logCatchySummary('cache_hit', 'mailId=$mailId using Firestore summary');
          setState(() {
            _summarizedContent[mailId] = data['result'];
            _extractedEventData[mailId] = data['eventData'];
          });
          return;
        }
        logCatchySummary('cache_stale', 'mailId=$mailId prompt changed, refetch');
      }
    }

    logCatchySummary('server_call', 'mailId=$mailId posting to summary API');
    setState(() {
      _summarizedContent.remove(mailId);
    });

    // 메모리에 있는 최신 프롬프트를 즉시 사용 (1초 지연 해결)
    final String activePrompt = (_selectedPromptType == 0)
        ? _customPrompt
        : _galleryPrompt;

    final String finalInstruction = activePrompt.trim().isEmpty
        ? _customPrompt
        : activePrompt;

    try {
      final requestBody = jsonEncode({
        'mailId': mailId,
        'emailContent':
            """
Message-ID: ${email['messageId'] ?? ''} 
Subject: ${email['subject']}
From: ${email['from']}
Body: ${email['body']}
""",
        'promptInstruction': finalInstruction,
      });
      logCatchySummary(
        'http_request',
        'url=${AppConstants.summaryServerUrl} jsonChars=${requestBody.length} promptChars=${finalInstruction.length}',
      );

      final response = await http
          .post(
            Uri.parse(AppConstants.summaryServerUrl),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(const Duration(seconds: 20));

      logCatchySummary(
        'http_response',
        'mailId=$mailId status=${response.statusCode} bodyChars=${response.body.length} body=${_catchySummaryTruncate(response.body, 1200)}',
      );
      if (response.statusCode == 200) {
        try {
          final Map<String, dynamic> parsedJson = jsonDecode(response.body);
          if (parsedJson['status'] == 'error') {
            logCatchySummary(
              'api_error_payload',
              'mailId=$mailId clean_body=${_catchySummaryTruncate(parsedJson['clean_body']?.toString(), 800)} guide=${_catchySummaryTruncate(parsedJson['guide']?.toString(), 400)}',
            );
            _setErrorState(
              mailId,
              reason:
                  'server returned status=error: ${_catchySummaryTruncate(parsedJson['clean_body']?.toString(), 500)}',
            );
            return;
          }

          final dynamic rawEventData = parsedJson['event_info'];
          List<dynamic> eventList = [];

          if (rawEventData is List) {
            eventList = rawEventData
                .where(
                  (e) => e['title'] != null && e['title'].toString().isNotEmpty,
                )
                .toList();
          } else if (rawEventData is Map && rawEventData.isNotEmpty) {
            if (rawEventData['title']?.toString().isNotEmpty ?? false) {
              eventList = [rawEventData];
            }
          }

          final String? finalMessageId = parsedJson['message_id'];

          setState(() {
            _summarizedContent[mailId] = parsedJson;
            _extractedEventData[mailId] = eventList.isEmpty ? null : eventList;
          });

          // 3. Firestore 저장 (updatedAt에 현재 서버 시간 기록)
          await docRef.set({
            'result': parsedJson,
            'eventData': eventList.isEmpty ? null : eventList,
            'messageId': finalMessageId,
            'updatedAt': FieldValue.serverTimestamp(), // 서버 시간 기록
          }, SetOptions(merge: true));

          logCatchySummary(
            'success',
            'mailId=$mailId summaryChars=${(parsedJson['summary']?.toString() ?? '').length} firestore_saved',
          );
        } catch (e) {
          logCatchySummary('json_parse_fail', 'mailId=$mailId', error: e);
          _setErrorState(mailId, reason: 'json_decode_or_parse: $e');
        }
      } else {
        _setErrorState(
          mailId,
          reason:
              'http_status_${response.statusCode}: ${_catchySummaryTruncate(response.body, 600)}',
        );
      }
    } catch (e, st) {
      final isTimeout = e is TimeoutException;
      logCatchySummary(
        isTimeout ? 'timeout' : 'exception',
        'mailId=$mailId type=${e.runtimeType}',
        error: e,
      );
      print('CatchySummary|stack|${_catchySummaryTruncate(st.toString(), 1500)}');
      _setErrorState(
        mailId,
        reason:
            '${isTimeout ? 'timeout_20s' : e.runtimeType.toString()}: $e',
      );
    }
  }

  void _setErrorState(String mailId, {required String reason}) {
    logCatchySummary('ui_error_state', 'mailId=$mailId reason=$reason');
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
    // [1] 로그인 전 화면: 구글 로그인으로 시작하기 부분
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
                await MailCacheManager.initUserBox(user.email ?? "");
                setState(() {
                  _googleUser = AppLogin.googleSignIn.currentUser;
                });

                // 3. 데이터 로드 및 이메일 가져오기
                await _requestLoadInitialData();
                _fetchEmails();
              }
            },
          ),
        ),
      );
    }

    // [2] 로그인 후 화면 (반응형 레이아웃)
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        // 💡 수정: 현재 포커스를 완전히 해제
        FocusManager.instance.primaryFocus?.unfocus();

        if (_isSearchFocused) {
          setState(() {
            _isSearchFocused = false;
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          // 1. [Leading 영역] 선택 모드일 때만 'X' 취소 버튼 표시
          leading: _selectedMailIds.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.keyboard_backspace_outlined, size: 32),
                  onPressed: () {
                    setState(() {
                      _selectedMailIds.clear();
                      _isSelectionMode = false;
                    });
                  },
                )
              : null, // 평소에는 기본값(뒤로가기 등) 유지
          // 2. [Title 영역] 선택 모드일 때는 개수 표시, 평소에는 검색창 표시
          title: _selectedMailIds.isNotEmpty
              ? Text("${_selectedMailIds.length}개 선택됨")
              : Container(
                  // 기존 검색창 로직 그대로 유지
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
                    focusNode: _searchFocusNode,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                        _displayEmails = _applyAdvancedFilter();
                      });
                    },
                    style: const TextStyle(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: _searchQuery.isEmpty
                          ? "전체 ${_filteredEmails.length}건의 메일 검색"
                          : "검색 결과 ${_displayEmails.length}건",
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[400],
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.blueAccent[700],
                        size: 22,
                      ),
                      suffixIcon:
                          (_searchQuery.isNotEmpty || _searchFocusNode.hasFocus)
                          ? IconButton(
                              icon: const Icon(
                                Icons.close,
                                size: 28,
                                color: Colors.grey,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _searchFocusNode.unfocus();
                                setState(() {
                                  _searchQuery = "";
                                  _displayEmails = _applyAdvancedFilter();
                                  _isSearchFocused =
                                      false; // 검색 칩 영역을 닫기 위해 false 처리
                                });

                                // 3. 💡 핵심: 포커스 해제 (키보드 내리기)
                                _searchFocusNode.unfocus();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
          centerTitle: true,

          // 3. [Actions 영역] 선택 모드일 때는 삭제 버튼, 평소에는 프로필 버튼
          actions: [
            if (_selectedMailIds.isNotEmpty)
              // 선택 모드일 때 나타나는 삭제 버튼
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 32),
                onPressed: () => _showBulkDeleteDialog(), // 삭제 확인 팝업 호출
              )
            else
              // 평소에 나타나는 프로필 버튼 (기존 로직 그대로 유지)
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.account_circle, size: 30),
                  onPressed: () {
                    print("GOOGLE USER: $_googleUser");
                    print("USER MODEL: $_currentUserModel");
                    Scaffold.of(context).openEndDrawer();
                  },
                ),
              ),
          ],
        ),
        drawer: FilterDrawer(
          // 1. 일반 인자들
          whiteList: _whiteList,
          isFilterEnabled: _isFilterEnabled,
          isProfileRegistered:
              _currentUserModel != null && _currentUserModel!.name.isNotEmpty,
          onFilterModeChanged: (val) => setState(() => _isFilterEnabled = val),
          customPrompt: _customPrompt, // ✅ 여기에 위치해야 합니다
          galleryPrompt: _galleryPrompt,
          selectedPromptType: _selectedPromptType,
          selectedDateRange: _selectedDateRange,
          nickname: _currentUserModel?.nickname,

          // 2. 콜백 인자 (onSave)
          onSave:
              (
                newList,
                newPrompt,
                newGalleryPrompt,
                newRange,
                selectedTab,
                newFilterOn, // ✅ 6번째 인자
              ) async {
                setState(() {
                  _selectedEmail = null;
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
                    'filterOn': newFilterOn,
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
                    _isFilterEnabled = newFilterOn;
                  });

                  _fetchEmails();
                }
              }, // ✅ onSave 끝
        ), // ✅ FilterDrawer 끝
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
            Widget filterChipsSection = AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: _isSearchFocused ? 40 : 0, // 컴팩트한 칩 높이
              curve: Curves.easeInOut,
              child: _isSearchFocused
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          _buildFilterChip("Google", MailSource.gmail),
                          _buildFilterChip("Naver", MailSource.naver),
                          _buildFilterChip("Daum", MailSource.daum),
                          _buildUnreadFilterChip(),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            );
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
                            filterChipsSection,
                            _buildNewMailIndicator(),
                            _buildDateHeader(),

                            Expanded(
                              child: _buildListWithHUD(context, isWeb: true),
                            ),
                          ],
                        ),
                        // [왼쪽 리스트 영역의 우측 하단 버튼들]
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. Refresh 버튼 (기존 유지)
                              GestureDetector(
                                onLongPress: () => _showForceResyncDialog(),
                                child: FloatingActionButton(
                                  heroTag: "web_refresh_btn",
                                  mini: true,
                                  backgroundColor: Colors.white.withOpacity(
                                    0.9,
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : () => _fetchEmails(isBackground: false),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh,
                                          color: Colors.blueAccent,
                                        ),
                                ),
                              ),

                              const SizedBox(height: 12), // 버튼 사이 간격
                              // 2. AI 프롬프트 버튼 (기존 파일의 위젯 호출)
                              // ai_prompt_button.dart에 정의된 위젯을 그대로 사용합니다.
                              AIPromptButton(
                                customPrompt: _customPrompt,
                                galleryPrompt: _galleryPrompt,
                                selectedPromptType: _selectedPromptType,
                                onPromptSaved:
                                    (newPrompt, newGallery, newType) {
                                      setState(() {
                                        _customPrompt = newPrompt;
                                        _galleryPrompt = newGallery;
                                        _selectedPromptType = newType;
                                      });
                                    },
                              ),
                            ],
                          ),
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
                      cursor:
                          SystemMouseCursors.resizeLeftRight, // 마우스 커서 모양 변경
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
                            summarizedContent: _summarizedContent,
                            extractedEventData: _extractedEventData,
                            onRefresh: () async {
                              // async/await를 추가하여 작업 완료 후 UI가 갱신되도록 합니다.
                              await _summarizeEmail(
                                _selectedEmail!,
                                forceRefresh: true,
                              );
                              if (mounted) setState(() {});
                            },
                            onAddToCalendar: (event) =>
                                _addToGoogleCalendar(event),
                            onDelete: () {
                              setState(() {
                                _selectedEmail = null;
                                _isMobileDetailOpen = false;
                              });
                              _updateUI();
                            },
                          ),
                  ),
                ],
              );
            }

            // 모바일 레이아웃 (기존 동일)
            return Column(
              children: [
                filterChipsSection,
                _buildNewMailIndicator(),
                _buildDateHeader(),
                Expanded(child: _buildListWithHUD(context, isWeb: false)),
              ],
            );
          },
        ),
        // Scaffold의 마지막 부분입니다.
        floatingActionButton: LayoutBuilder(
          builder: (context, constraints) {
            // 1. 공통 버튼 위젯 정의 (중복 코드를 줄이기 위해 변수로 선언)
            final aiButton = AIPromptButton(
              customPrompt: _customPrompt, // 사용자 1 내용
              galleryPrompt: _galleryPrompt, // 사용자 2 (갤러리) 내용
              selectedPromptType:
                  _selectedPromptType, // 현재 어떤 탭이 활성화인지 (0 or 1)
              nickname: _currentUserModel?.nickname,
              onPromptSaved: (newCustom, newGallery, newType) {
                _customPrompt = newCustom;
                _galleryPrompt = newGallery;
                _selectedPromptType = newType;
                _lastPromptUpdateTime = DateTime.now();
                _summarizedContent.clear();

                setState(() {
                  // UI 업데이트
                });

                // 2. 현재 선택된 메일이 있다면 즉시 다시 요약 실행 (Gemini 2.5-flash)
                if (_selectedEmail != null) {
                  _summarizeEmail(_selectedEmail!, forceRefresh: true);
                }
              },
            );

            // 2. 모바일 환경 처리
            if (constraints.maxWidth <= 700) {
              if (_isMobileDetailOpen) return const SizedBox.shrink();
              return aiButton;
            }
            // 3. 웹 환경 처리
            else {
              return const SizedBox.shrink();
            }
          },
        ),
      ),
    );
  }

  static const EdgeInsets _filterChipLabelPadding = EdgeInsets.symmetric(
    horizontal: 6,
    vertical: 0,
  );

  Widget _buildFilterChip(String label, MailSource source) {
    final bool isSelected = _selectedSources.contains(source);
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: _filterChipLabelPadding,
        padding: EdgeInsets.zero,
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        onSelected: (bool selected) {
          setState(() {
            // 1. 선택 상태 업데이트
            if (selected) {
              _selectedSources.add(source);
            } else {
              if (_selectedSources.length > 1) _selectedSources.remove(source);
            }

            // 💡 핵심 수정: 필터링된 리스트를 _displayEmails에 대입하여 화면을 갱신합니다.
            _displayEmails = _applyAdvancedFilter();
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.blueAccent.withOpacity(0.2),
        checkmarkColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildUnreadFilterChip() {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: FilterChip(
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        labelPadding: _filterChipLabelPadding,
        padding: EdgeInsets.zero,
        label: const Text("안읽음", style: TextStyle(fontSize: 11)),
        selected: _filterUnreadOnly,
        onSelected: (bool selected) {
          setState(() {
            _filterUnreadOnly = selected;
            _displayEmails = _applyAdvancedFilter();
          });
        },
        backgroundColor: Colors.grey[100],
        selectedColor: Colors.blueAccent.withOpacity(0.2),
        checkmarkColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
  // --- 아래는 가독성을 위해 build 함수에서 로직을 분리한 보조 위젯들입니다 ---

  // 1. 상단 날짜 표시 바
  Widget _buildDateHeader() {
    // ✅ 함수 내부에서 직접 변수를 선언합니다. (Undefined name 'range' 에러 해결)
    final DateTime now = DateTime.now();
    final DateTimeRange range =
        _selectedDateRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);

    return GestureDetector(
      onTap: () => _showMobileDateSyncDialog(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        color: Colors.blueAccent.withOpacity(0.08),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.calendar_today,
              size: 14,
              color: Colors.blueAccent,
            ),
            const SizedBox(width: 8),
            Text(
              // 이제 'range'가 정의되었으므로 에러가 사라집니다.
              "${range.start.year}/${range.start.month.toString().padLeft(2, '0')}/${range.start.day.toString().padLeft(2, '0')} ~ "
              "${range.end.year}/${range.end.month.toString().padLeft(2, '0')}/${range.end.day.toString().padLeft(2, '0')}",
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down,
              size: 16,
              color: Colors.blueAccent,
            ),
          ],
        ),
      ),
    );
  }

  // 2. 메일 리스트 수정 버전
  Widget _buildMainEmailList() {
    // 1. [중앙 로딩] 로딩 중인데 화면에 표시할 메일이 아직 하나도 없는 경우 (최초 로딩 시에만)
    if (_isLoading && _displayEmails.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "메일을 불러오는 중입니다...",
                style: TextStyle(
                  color: Colors.blueGrey,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 25),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: _loadingProgress,
                  minHeight: 12,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Colors.blueAccent,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "${(_loadingProgress * 100).toInt()}% 완료",
                style: const TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. [데이터 없음 처리] 로딩이 끝났는데 메일이 없는 경우
    if (!_isLoading && _isInitialized && _displayEmails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mail_outline, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text(
              "조건에 맞는 메일이 없습니다.",
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      );
    }

    // 3. [데이터 리스트 표시] 메일이 있거나, 이미 메일이 있는 상태에서 새로고침 중일 때
    // Stack을 그대로 유지하면서 Column으로 감싸 상단 바를 추가합니다.
    return Column(
      children: [
        // ✅ [추가] 가느다란 로딩 가로바 (이미 리스트가 있는 상태에서 로딩할 때 노출)
        if (_isLoading)
          const SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ),

        Expanded(
          child: Stack(
            children: [
              RefreshIndicator(
                onRefresh: () async => await _fetchEmails(isBackground: false),
                child: ListView.builder(
                  controller: _scrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _displayEmails.length,
                  itemBuilder: (context, index) {
                    final email = _displayEmails[index];
                    final bool isWeb = MediaQuery.of(context).size.width > 700;
                    final bool isSelectedForDelete = _selectedMailIds.contains(
                      email.id,
                    );
                    final bool isCurrentSelected =
                        _selectedEmail != null &&
                        _selectedEmail!['id'] == email.id;

                    return ListTile(
                      tileColor: isSelectedForDelete
                          ? Colors.red[50]
                          : (isCurrentSelected
                                ? Colors.blue[50]
                                : Colors.white),

                      // --- 아이콘 영역 (생략, 기존 코드 그대로 유지) ---
                      leading: (isWeb || _isSelectionMode)
                          ? Checkbox(
                              value: isSelectedForDelete,
                              onChanged: (bool? value) {
                                setState(() {
                                  if (value == true) {
                                    _selectedMailIds.add(email.id);
                                  } else {
                                    _selectedMailIds.remove(email.id);
                                    if (_selectedMailIds.isEmpty && !isWeb)
                                      _isSelectionMode = false;
                                  }
                                });
                              },
                            )
                          : GestureDetector(
                              onLongPress: () {
                                if (!isWeb) {
                                  setState(() {
                                    _isSelectionMode = true;
                                    _selectedMailIds.add(email.id);
                                  });
                                }
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: () {
                                  if (email.source == MailSource.naver) {
                                    return BoxDecoration(
                                      color: const Color(0xFF03C75A),
                                      borderRadius: BorderRadius.circular(10),
                                    );
                                  } else if (email.source == MailSource.daum) {
                                    return BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                      border: Border.all(
                                        color: const Color(
                                          0xFF3866E6,
                                        ).withOpacity(0.3),
                                      ),
                                    );
                                  } else {
                                    // return const BoxDecoration(
                                    //   color: Color(0xFF4285F4),
                                    //   shape: BoxShape.circle,
                                    return BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.withOpacity(
                                          0.2,
                                        ), // 테두리 색상
                                        width: 1,
                                      ),
                                    );
                                  }
                                }(),
                                child: Center(
                                  child: () {
                                    if (email.source == MailSource.naver) {
                                      return const Text(
                                        "N",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                        ),
                                      );
                                    } else if (email.source ==
                                        MailSource.daum) {
                                      return const Text(
                                        "D",
                                        style: TextStyle(
                                          color: Color(0xFF3866E6),
                                          fontWeight: FontWeight.w900,
                                          fontSize: 20,
                                        ),
                                      );
                                    } else {
                                      // return const FaIcon(
                                      //   FontAwesomeIcons.google,
                                      //   // color: Colors.white,
                                      //   color: Color(0xFF4285F4),
                                      //   size: 18,
                                      return Padding(
                                        padding: const EdgeInsets.all(
                                          7.0,
                                        ), // 테두리와 로고 사이의 여백 (기호에 맞게 조절)
                                        child: Image.asset(
                                          'assets/images/google_logo.png',
                                          fit: BoxFit.contain,
                                        ),
                                      );
                                    }
                                  }(),
                                ),
                              ),
                            ),

                      title: Text(
                        email.subject,
                        style: TextStyle(
                          fontWeight: _readIds.contains(email.id)
                              ? FontWeight.normal
                              : FontWeight.bold,
                          color: _readIds.contains(email.id)
                              ? Colors.grey
                              : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        "${email.sender}\n${_formatDate(email.dateTime)}",
                        style: TextStyle(
                          fontSize: 12,
                          color: _summarizedIds.contains(email.id)
                              ? Colors.grey[400]
                              : Colors.grey[600],
                        ),
                      ),

                      // --- 탭/롱프레스 로직 (생략, 기존 코드 그대로 유지) ---
                      onTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        if (_isSelectionMode ||
                            (isWeb && _selectedMailIds.isNotEmpty)) {
                          setState(() {
                            if (_selectedMailIds.contains(email.id)) {
                              _selectedMailIds.remove(email.id);
                              if (_selectedMailIds.isEmpty && !isWeb)
                                _isSelectionMode = false;
                            } else {
                              _selectedMailIds.add(email.id);
                            }
                          });
                        } else {
                          // ... 상세 페이지 이동 로직 생략 (기존 코드 유지) ...
                          final bool isMobile =
                              MediaQuery.of(context).size.width <= 700;
                          final selectedEmailMap = {
                            'id': email.id,
                            'threadId': email.threadId,
                            'subject': email.subject,
                            'from': email.sender,
                            'timestamp': email.dateTime,
                            'body': email.body,
                          };

                          if (isMobile) {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (context) => const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                            );
                          }

                          setState(() {
                            _selectedEmail = selectedEmailMap;
                            _isMobileDetailOpen = true;
                            if (!_readIds.contains(email.id))
                              _readIds.add(email.id);
                          });

                          _markAsRead(email.id);

                          if (isMobile) {
                            await _summarizeEmail(selectedEmailMap);
                            if (!mounted) return;
                            Navigator.of(context, rootNavigator: true).pop();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmailDetailScreen(
                                  email: selectedEmailMap,
                                  summarizedContent: _summarizedContent,
                                  calendarCard: _buildCalendarEventCard(
                                    _extractedEventData[selectedEmailMap['id']], // email.id 대신 실제 Map의 id 사용
                                  ),
                                  customPrompt: _customPrompt,
                                  galleryPrompt: _galleryPrompt,
                                  selectedPromptType: _selectedPromptType,
                                  nickname: _currentUserModel?.nickname,

                                  // ✅ [추가] 상세창에서 프롬프트 저장 시 실행될 로직
                                  onSave: (newCustom, newGallery, newType) {
                                    setState(() {
                                      _customPrompt = newCustom;
                                      _galleryPrompt = newGallery;
                                      _selectedPromptType = newType;
                                      _lastPromptUpdateTime =
                                          DateTime.now(); // 시간차 오류 방지용
                                      _summarizedContent.clear(); // 캐시 초기화
                                    });
                                  },

                                  onRefresh: () async {
                                    await _summarizeEmail(
                                      selectedEmailMap,
                                      forceRefresh: true,
                                    );
                                    if (mounted) setState(() {});
                                  },
                                ),
                              ),
                            ).then((result) {
                              if (mounted) {
                                setState(() {
                                  _isMobileDetailOpen = false;
                                });
                                if (result == "deleted") _updateUI();
                              }
                            });
                          } else {
                            _summarizeEmail(selectedEmailMap);
                          }
                        }
                      },
                      onLongPress: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        _showWhiteListDialog(context, email.sender);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
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
    if (_whiteList.length >= 30) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            "알림",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: const Text("발신 주소를 최대 30개까지 등록 가능합니다. 🐱"),
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

  // [1] 삭제 확인 팝업창
  void _showBulkDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("메일 삭제"),
        content: Text("선택한 ${_selectedMailIds.length}개의 메일을 삭제하시겠습니까?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // 취소
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // 확인 팝업 닫기
              await _performBulkDelete(); // 실제 삭제 로직 실행
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // [2] 실제 삭제 처리 로직
  Future<void> _performBulkDelete() async {
    // 1. 로딩 인디케이터 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
    );

    try {
      debugPrint("🗑️ 로컬 저장소 삭제 시작: $_selectedMailIds");

      // 2. ⭐ 핵심: 선택된 모든 ID를 로컬 저장소(MailCacheManager)에서 삭제
      for (String id in _selectedMailIds) {
        await MailCacheManager.deleteMail(id);
      }

      // 3. UI 업데이트
      setState(() {
        // 전체 메일 리스트에서 제거
        _displayEmails.removeWhere(
          (email) => _selectedMailIds.contains(email.id),
        );

        // 필터링된 리스트에서도 제거
        _filteredEmails.removeWhere(
          (email) => _selectedMailIds.contains(email.id),
        );

        // 선택 상태 초기화 및 모드 종료
        _selectedMailIds.clear();
        _isSelectionMode = false;
      });

      if (mounted) {
        Navigator.pop(context); // 로딩 창 닫기
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("선택한 메일이 캐시에서 삭제되었습니다."),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.pop(context); // 로딩 창 닫기
      debugPrint("삭제 실패: $e");

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("삭제 중 오류가 발생했습니다: $e")));
      }
    }
  }

  // 헬퍼 함수 수정

  String _formatDate(DateTime dt) {
    String month = dt.month.toString().padLeft(2, '0');
    String day = dt.day.toString().padLeft(2, '0');
    String hour = dt.hour.toString().padLeft(2, '0');
    String minute = dt.minute.toString().padLeft(2, '0');
    return "${dt.year}/$month/$day $hour:$minute";
  }

  Widget _buildListWithHUD(BuildContext context, {required bool isWeb}) {
    return Stack(
      alignment: Alignment.center, // 중앙 정렬을 위해 추가
      children: [
        // 1. 실제 이메일 리스트
        _buildMainEmailList(),

        // 2. 공통 스크롤 버튼과 사용안내 버튼을 묶어서 표시
        if (_showScrollHUD)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 상하 화살표 HUD
              _buildCommonScrollHUD(isWeb: isWeb, scroll: _scrollController),

              // 모바일에서만 화살표 아래에 '사용안내' 버튼 표시
              if (!isWeb) ...[
                const SizedBox(height: 16),
                _buildManualButton(context),
              ],
            ],
          ),
      ],
    );
  }

  Widget _buildCommonScrollHUD({
    required bool isWeb,
    required ScrollController scroll,
  }) {
    // 1. Center를 Align으로 변경합니다.
    return Align(
      alignment: Alignment.centerRight, // ✅ 우측 중앙으로 배치
      child: Padding(
        padding: const EdgeInsets.only(right: 8), // ✅ 벽에 너무 붙지 않게 살짝 띄움
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: isWeb ? 10 : 8,
            horizontal: 6,
          ),
          decoration: BoxDecoration(
            // 투명도를 조금 낮춰서 배경이 살짝 비치게 하면 더 세련되어 보입니다.
            color: Colors.white.withOpacity(isWeb ? 0.7 : 0.85),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.vertical_align_top,
                  color: Colors.blueAccent,
                  size: 28,
                ),
                onPressed: () => scroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                ),
              ),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(
                  Icons.vertical_align_bottom,
                  color: Colors.blueAccent,
                  size: 28,
                ),
                onPressed: () => scroll.animateTo(
                  scroll.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualButton(BuildContext context) {
    return GestureDetector(
      onTap: () => ManualManager.showUserManual(context),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.indigoAccent, Colors.blueAccent.shade700],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.indigoAccent.withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.help_outline_rounded, color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              "사용안내",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
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
