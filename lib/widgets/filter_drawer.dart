import 'package:flutter/material.dart';
import 'package:gmail_summary/widgets/prompt_gallery_sheet.dart'; // 경로 확인 필요
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FilterDrawer extends StatefulWidget {
  final List<String> whiteList;
  final String customPrompt;
  final String? galleryPrompt;
  final DateTimeRange? selectedDateRange;
  final int selectedPromptType;
  final Function(List<String>, String, String?, DateTimeRange?, int) onSave;
  final bool isFilterEnabled;
  final Function(bool) onFilterModeChanged;
  final bool isProfileRegistered;
  final String? nickname;

  const FilterDrawer({
    super.key,
    required this.whiteList,
    required this.isFilterEnabled, // 이 줄을 추가 (변수와 생성자 연결)
    required this.onFilterModeChanged, // 이 줄을 추가 (변수와 생성자 연결)
    required this.customPrompt,
    this.galleryPrompt,
    this.selectedDateRange,
    required this.selectedPromptType,
    required this.onSave,
    required this.isProfileRegistered,
    this.nickname,
  });

  @override
  State<FilterDrawer> createState() => _FilterDrawerState();
}

class _FilterDrawerState extends State<FilterDrawer> {
  DateTimeRange? _localDateRange;
  late TextEditingController _controller;
  late TextEditingController _promptController;
  late List<String> _localWhiteList;

  late bool _localFilterEnabled;
  bool _isSearchVisible = false;
  String _searchQuery = "";

  late String _galleryPrompt; // 갤러리에서 가져온 프롬프트 저장용
  int _selectedPromptTab = 0; // 기본값을 0(사용자 프롬프트 1)으로 설정

  @override
  void initState() {
    super.initState();
    _localFilterEnabled = widget.isFilterEnabled;
    _controller = TextEditingController();
    _promptController = TextEditingController(text: widget.customPrompt);
    // _promptController = TextEditingController();
    _localWhiteList = List.from(widget.whiteList);
    _galleryPrompt = widget.galleryPrompt ?? "";
    _selectedPromptTab = widget.selectedPromptType;

    // --- 초기 날짜 로직 적용 ---
    // From은 전달받은 값(없으면 7일 전), To는 무조건 오늘(현재 시각)
    DateTime now = DateTime.now();
    // 오늘로부터 딱 3개월 전 (제한선)
    DateTime threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    // From 기본값 설정 (전달받은 값 없으면 7일 전)
    DateTime fromDate =
        widget.selectedDateRange?.start ??
        now.subtract(const Duration(days: 7));

    // [중요] 혹시라도 전달받은 날짜가 3개월보다 더 이전이면 3개월 전으로 맞춤 (에러 방지)
    if (fromDate.isBefore(threeMonthsAgo)) {
      fromDate = threeMonthsAgo;
    }

    _localDateRange = DateTimeRange(start: fromDate, end: now);
  }

  @override
  void dispose() {
    _controller.dispose();
    _promptController.dispose();
    super.dispose();
  }

  // 날짜 포맷팅 함수
  String _formatDate(DateTime? date) {
    if (date == null) return "";
    return "${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}";
  }

  // 텍스트 필드 디자인
  InputDecoration _getInputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      // 1. 힌트 글자 크기를 12로 더 줄여서 전체가 다 보이게 합니다.
      hintStyle: const TextStyle(
        fontSize: 13,
        color: Colors.grey,
        overflow: TextOverflow.visible, // 텍스트가 넘쳐도 잘리지 않게 설정
      ),
      filled: true,
      fillColor: Colors.white,
      isDense: true, // 다시 true로 설정하되 패딩으로 조절합니다.
      // 2. 좌우 패딩을 줄여서 텍스트가 들어갈 공간을 더 확보합니다.
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 8, // 12에서 8로 줄임
        vertical: 12,
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  void _showEditDialog(int index, String oldEmail, bool currentStatus) {
    TextEditingController editController = TextEditingController(
      text: oldEmail,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          "항목 수정",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: "이메일 또는 도메인 입력",
            helperText: "도메인은 @없이 입력해도 자동 추가됩니다.",
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소"),
          ),
          ElevatedButton(
            onPressed: () {
              // 1. 입력값 정리
              String inputText = editController.text.trim();

              if (inputText.isNotEmpty) {
                // 2. 도메인 처리 로직: @가 포함되어 있지 않으면 앞에 @를 추가
                if (!inputText.contains('@')) {
                  inputText = "@$inputText";
                }

                setState(() {
                  // 3. 수정된 텍스트와 기존 활성 상태를 결합하여 저장
                  _localWhiteList[index] = "$inputText:$currentStatus";
                });
              }

              Navigator.pop(context);
            },
            child: const Text("저장"),
          ),
        ],
      ),
    );
  }

  // 1. 추천 갤러리 열기 (바텀 시트)
  void _openPromptGallery() async {
    // 1. 갤러리 창 열기 (onApply 에러를 피하기 위해 빈 함수 전달)
    final String? selectedContent = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PromptGallerySheet(
        onApply: (content) {}, // 일단 빈 함수를 전달하여 에러 방지
        currentUserUid: FirebaseAuth.instance.currentUser?.uid,
      ),
    );

    // 2. 결과값이 넘어온 경우 처리
    if (selectedContent != null && mounted) {
      setState(() {
        _galleryPrompt = selectedContent; // 변수 업데이트

        _selectedPromptTab = 1; // 탭 인덱스 변수만 변경 (UI가 이를 참조한다면)
      });
    }
  }

  // 2. 최종 저장 로직 (필드 분리 저장)
  Future<void> _finalSaveWithBackup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String finalCustom = (_selectedPromptTab == 0)
        ? _promptController.text
        : widget.customPrompt;

    String finalGallery = _galleryPrompt;

    try {
      // 2. Firestore 업데이트
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
            'customPrompt': finalCustom,
            'galleryPrompt': finalGallery,
            'selectedPromptType': _selectedPromptTab,
          });

      // 3. main.dart 메모리 동기화
      widget.onSave(
        _localWhiteList,
        finalCustom,
        finalGallery,
        _localDateRange,
        _selectedPromptTab,
      );
    } catch (e) {
      print("저장 오류: $e");
    }
  }

  Future<void> _sharePromptToGallery() async {
    final String content = _promptController.text.trim();

    if (content.isEmpty) {
      // 입력창이 비었을 때는 간단한 경고창
      _showSimpleAlert("알림", "공유할 프롬프트 내용을 입력해주세요.");
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("갤러리 공유"),
        content: const Text(
          "내 프롬프트를 닉네임으로 갤러리에 공유합니다.\n모든 사용자가 내 프롬프트를 보고 적용할 수 있습니다.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("취소"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              "공유하기",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String nickname =
          widget.nickname ??
          user.displayName ??
          (user.email?.split('@')[0] ?? "익명");

      final docRef = FirebaseFirestore.instance
          .collection('shared_prompts')
          .doc(user.uid);
      final docSnapshot = await docRef.get();

      // 🔥 Firestore 저장
      Map<String, dynamic> dataToSave = {
        'content': content,
        'authorNickname': nickname,
        'authorUid': user.uid,
        'authorEmail': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // 3. 문서가 없을 때만 createdAt을 추가합니다.
      if (!docSnapshot.exists) {
        dataToSave['createdAt'] = FieldValue.serverTimestamp();
        dataToSave['usedCount'] = 0; // 최초 생성 시에만 0으로 초기화
      }

      // 4. 저장 (merge: true를 사용해 기존 데이터와 병합)
      await docRef.set(dataToSave, SetOptions(merge: true));

      if (mounted) {
        // ✅ 해결: 스낵바 대신 사용자에게 확실히 보이는 Alert 사용
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Text("공유 완료"),
              ],
            ),
            content: const Text("프롬프트가 갤러리에 성공적으로 등록되었습니다."),
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
      debugPrint("🚩 [프롬프트 공유 오류]: $e");
      if (mounted) {
        _showSimpleAlert("오류", "공유 중 오류가 발생했습니다: $e");
      }
    }
  }

  // 공통으로 쓸 간단한 알림창 함수 (State 클래스 내부에 추가)
  void _showSimpleAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("확인"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 1. 화면 너비를 계산하여 웹/모바일 여부를 판별합니다.
    double screenWidth = MediaQuery.of(context).size.width;
    final double drawerWidth = screenWidth > 600 ? 500 : screenWidth;
    // bool isMobile = screenWidth < 600;

    // 기존 SizedBox(width: screenWidth)를 제거하고 바로 Drawer를 리턴합니다.
    return Drawer(
      // 2. 너비를 모바일일 때는 전체, 웹일 때는 400으로 설정 (ProfileDrawer와 동일)
      width: drawerWidth,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(""),
          centerTitle: true,
          // 3. 닫기 버튼 스타일을 ProfileDrawer와 동일하게 맞춤 (선택사항)
          leading: Container(), // 왼쪽 비움
          actions: [
            IconButton(
              icon: const Icon(Icons.close, size: 32, color: Colors.black),
              onPressed: () => Navigator.pop(context),
              padding: const EdgeInsets.only(right: 20, top: 10),
            ),
          ],
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 조회 기간 섹션 ---
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_month,
                      color: Colors.blue,
                    ),
                    title: const Text(
                      "조회 기간",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      _localDateRange == null
                          ? "전체 기간 (제한 없음)"
                          : "${_formatDate(_localDateRange!.start)} ~ ${_formatDate(_localDateRange!.end)}",
                    ),
                    onTap: () => _selectDateRange(context),
                  ),

                  // 퀵 선택 버튼들
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildQuickDateButton("1주일", const Duration(days: 7)),
                      _buildQuickDateButton("1개월", const Duration(days: 30)),
                      _buildQuickDateButton("3개월", const Duration(days: 90)),
                      _buildDirectInputButton("직접입력"),
                    ],
                  ),
                  const Divider(height: 32),

                  // --- 발신 주소 섹션 ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Text(
                            "발신 주소",
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _isSearchVisible
                                  ? Icons.search_off
                                  : Icons.search,
                              size: 20,
                              color: _isSearchVisible
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                            onPressed: () => setState(() {
                              _isSearchVisible = !_isSearchVisible;
                              if (!_isSearchVisible) _searchQuery = "";
                            }),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            _localFilterEnabled ? "필터 ON" : "필터 OFF",
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _localFilterEnabled
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Switch(
                            value: _localFilterEnabled,
                            activeColor: Colors.blue,
                            onChanged: (bool value) {
                              setState(() => _localFilterEnabled = value);
                              widget.onFilterModeChanged(value);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (_isSearchVisible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        autofocus: true,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: "리스트 내 검색...",
                          prefixIcon: const Icon(Icons.search, size: 18),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.blue.withOpacity(0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: _getInputDecoration(
                            "이메일 주소 또는 도메인(gmail.com)",
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          String input = _controller.text.trim();
                          if (input.isNotEmpty) {
                            // --- [추가된 로직: 개수 제한 체크] ---
                            if (_localWhiteList.length >= 10) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text(
                                    "알림",
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: const Text(
                                    "베타 테스트 기간에는 발신 주소를 최대 10개까지 등록 가능합니다. 🐱",
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text("확인"),
                                    ),
                                  ],
                                ),
                              );
                              return; // 10개가 넘으면 더 이상 아래 로직을 실행하지 않고 나갑니다.
                            }
                            // ------------------------------------

                            if (!input.contains('@')) input = "@$input";
                            setState(() {
                              bool exists = _localWhiteList.any(
                                (item) => item.startsWith('$input:'),
                              );
                              if (exists) {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    content: const Text("이미 리스트에 존재하는 주소입니다."),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context),
                                        child: const Text("확인"),
                                      ),
                                    ],
                                  ),
                                );
                              } else {
                                _localWhiteList.add("$input:true");
                                _controller.clear();
                              }
                            });
                          }
                        },
                        child: const Text("추가"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 발신자 리스트 (Expanded 제거하고 Container로 고정)
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.builder(
                      itemCount: _localWhiteList
                          .where(
                            (item) => item
                                .split(':')[0]
                                .toLowerCase()
                                .contains(_searchQuery.toLowerCase()),
                          )
                          .length,
                      itemBuilder: (context, index) {
                        final filteredList = _localWhiteList
                            .where(
                              (item) => item
                                  .split(':')[0]
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()),
                            )
                            .toList();
                        final item = filteredList[index];
                        final actualIndex = _localWhiteList.indexOf(item);
                        final parts = item.split(':');
                        String emailOrDomain = parts[0];
                        bool isActive = parts.length > 1
                            ? parts[1] == 'true'
                            : true;

                        return GestureDetector(
                          onLongPress: () => _showEditDialog(
                            actualIndex,
                            emailOrDomain,
                            isActive,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? Colors.blue.withOpacity(0.03)
                                  : Colors.white,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade100),
                              ),
                            ),
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: Colors.redAccent,
                                  ),
                                  onPressed: () => setState(
                                    () => _localWhiteList.removeAt(actualIndex),
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    emailOrDomain,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: isActive
                                          ? Colors.black87
                                          : Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Checkbox(
                                  value: isActive,
                                  onChanged: (val) {
                                    setState(
                                      () => _localWhiteList[actualIndex] =
                                          "$emailOrDomain:$val",
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(height: 32),

                  // --- AI 프롬프트 섹션 ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "AI 프롬프트",
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // ✨ 갤러리 이동 버튼 (이제 복구 버튼은 필요 없으므로 삭제하거나 조건부 처리)
                      Row(
                        children: [
                          // 1. 프롬프트 갤러리 버튼
                          InkWell(
                            onTap: _openPromptGallery,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.indigo.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Icon(
                                    Icons.auto_awesome,
                                    size: 14,
                                    color: Colors.indigo,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    "프롬프트 갤러리",
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // --- 탭 선택 버튼 (사용자 프롬프트 1 / 2) ---
                  Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        _buildTabButton("사용자 프롬프트 1", 0),
                        _buildTabButton("사용자 프롬프트 2", 1),
                      ],
                    ),
                  ),

                  // --- 프롬프트 내용 입력/조회 영역 ---
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    child: Column(
                      children: [
                        const SizedBox(height: 10),
                        Container(
                          height: 150,
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            // 사용자 2번 탭일 때는 조회 모드임을 알리기 위해 배경색을 살짝 다르게 함
                            color: _selectedPromptTab == 1
                                ? Colors.grey[50]
                                : Colors.white,
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _selectedPromptTab == 0
                              ? Stack(
                                  children: [
                                    TextField(
                                      controller: _promptController,
                                      maxLines: null,
                                      expands: true,
                                      textAlignVertical: TextAlignVertical.top,
                                      style: const TextStyle(fontSize: 14),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        hintText: "나만의 요약 스타일을 입력하세요",
                                        // 버튼과 겹치지 않게 하단 여백 확보
                                        contentPadding: EdgeInsets.only(
                                          bottom: 30,
                                        ),
                                      ),
                                    ),
                                    // 우측 하단에 클라우드 공유 버튼 배치
                                    Positioned(
                                      right: -8, // 아이콘 버튼 자체의 여백 때문에 약간 마이너스 조정
                                      bottom: -8,
                                      child: IconButton(
                                        icon: const Icon(
                                          Icons.cloud_upload_rounded,
                                          color: Colors.indigo,
                                          size: 30,
                                        ),
                                        tooltip: '갤러리에 공유',
                                        onPressed: _sharePromptToGallery,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ),
                                  ],
                                )
                              : Stack(
                                  // ✅ SingleChildScrollView를 Stack으로 감싸서 버튼 배치를 가능하게 함
                                  children: [
                                    SingleChildScrollView(
                                      padding: const EdgeInsets.only(
                                        bottom: 30,
                                      ), // 버튼과 겹치지 않게 하단 여백 추가
                                      child: Text(
                                        _galleryPrompt.isEmpty
                                            ? "갤러리에서 선택한 프롬프트가 없습니다."
                                            : _galleryPrompt,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                          fontSize: 14,
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                    // 🔥 우측 하단에 초기화 버튼 배치
                                    if (_galleryPrompt
                                        .isNotEmpty) // 내용이 있을 때만 버튼 표시
                                      Positioned(
                                        right: -8,
                                        bottom: -8,
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons
                                                .delete_sweep_rounded, // 초기화 느낌의 아이콘
                                            color: Color.fromARGB(
                                              255,
                                              123,
                                              122,
                                              120,
                                            ), // 클라우드 버튼(indigo)과 구분되는 색상 권장
                                            size: 30,
                                          ),
                                          tooltip: '프롬프트 초기화',
                                          onPressed: () {
                                            // 초기화 확인 다이얼로그
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text("프롬프트 초기화"),
                                                content: const Text(
                                                  "이 프롬프트를 리셋합니다.",
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text("취소"),
                                                  ),
                                                  TextButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        _galleryPrompt =
                                                            ""; // 내용 비우기
                                                      });
                                                      Navigator.pop(context);
                                                    },
                                                    child: const Text(
                                                      "초기화",
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          constraints: const BoxConstraints(),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // --- 설정 저장 및 적용 버튼 ---
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        if (!widget.isProfileRegistered) {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text("알림"),
                              content: const Text("사용자 프로파일을 먼저 등록해 주시기 바랍니다."),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text("확인"),
                                ),
                              ],
                            ),
                          );
                          return;
                        }

                        // ✅ 우리가 새로 만든 저장 함수 호출
                        _finalSaveWithBackup();
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "설정 저장 및 적용",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- 도움 함수 구역 ---

  Widget _buildQuickDateButton(String label, Duration duration) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: Colors.grey),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () {
            setState(() {
              _localDateRange = DateTimeRange(
                start: DateTime.now().subtract(duration),
                end: DateTime.now(),
              );
            });
          },
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectInputButton(String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Container(
          height: 40, // 다른 버튼들과 높이 통일
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              isExpanded: true,
              hint: Center(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ),
              icon: const Icon(
                Icons.arrow_drop_down,
                size: 18,
                color: Colors.grey,
              ),
              items: List.generate(30, (index) => index + 1).map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Center(
                    child: Text(
                      "$value일",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (int? newValue) {
                if (newValue != null) {
                  // 핵심: 다른 버튼들과 똑같이 _localDateRange를 업데이트합니다.
                  setState(() {
                    _localDateRange = DateTimeRange(
                      start: DateTime.now().subtract(Duration(days: newValue)),
                      end: DateTime.now(),
                    );
                  });
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDateRange(BuildContext context) async {
    // 내부 상태 관리를 위한 임시 변수
    DateTime? start = _localDateRange?.start;
    DateTime? end = _localDateRange?.end;
    // --- 3개월 제한 날짜 계산 ---
    DateTime now = DateTime.now();
    DateTime threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);

    await showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. 상단 헤더: 작고 얇은 날짜 (사용자님 선호 스타일)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: const Icon(
                            Icons.close,
                            size: 22,
                            color: Colors.black54,
                          ),
                        ),
                        Text(
                          start == null || end == null
                              ? "조회 기간을 선택하세요"
                              : "${_formatDate(start)} ~ ${_formatDate(end)}",
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400, // 얇은 굵기
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(width: 22),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // 2. 달력 본체: 검정색 날짜 보장 (좌우 이동 방식)
                  Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: Colors.blue, // 선택 시 동그라미 색상
                        onSurface: Colors.black87, // ★ 날짜 숫자 검정색 강제
                      ),
                    ),
                    child: SizedBox(
                      height: 320,
                      child: CalendarDatePicker(
                        initialDate: start ?? DateTime.now(),
                        // -------------------------------------------------------
                        // ★ 수정: 3개월 전까지만 달력 이동 가능하도록 제한
                        firstDate: threeMonthsAgo,
                        // ★ 수정: 오늘 이후의 미래 날짜는 선택 불가
                        lastDate: now,
                        // -------------------------------------------------------
                        onDateChanged: (date) {
                          setDialogState(() {
                            // 시작일/종료일 선택 로직
                            if (start == null ||
                                (start != null && end != null)) {
                              start = date;
                              end = null;
                            } else if (date.isBefore(start!)) {
                              start = date;
                            } else {
                              end = date;
                            }
                          });
                        },
                      ),
                    ),
                  ),

                  // 3. 하단 버튼
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        // ★ 베타 기간 안내 텍스트 추가
                        const Text(
                          "베타 테스트 기간에는 최근 3개월 내 메일만 조회 가능합니다. 🐱",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blueAccent,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "시작일과 종료일을 각각 클릭하세요",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: (start != null && end != null)
                                  ? () {
                                      setState(() {
                                        _localDateRange = DateTimeRange(
                                          start: start!,
                                          end: end!,
                                        );
                                      });
                                      Navigator.pop(context);
                                    }
                                  : null,
                              child: const Text("확인"),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTabButton(String label, int index) {
    bool isSelected = _selectedPromptTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPromptTab = index;
          });
        },
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}
