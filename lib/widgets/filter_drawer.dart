import 'package:flutter/material.dart';
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
  // late TextEditingController _promptController;
  late List<String> _localWhiteList;

  late bool _localFilterEnabled;
  bool _isSearchVisible = false;
  String _searchQuery = "";

  // late String _galleryPrompt; // 갤러리에서 가져온 프롬프트 저장용
  // int _selectedPromptTab = 0; // 기본값을 0(사용자 프롬프트 1)으로 설정

  @override
  void initState() {
    super.initState();
    _localFilterEnabled = widget.isFilterEnabled;
    _controller = TextEditingController();
    // _promptController = TextEditingController(text: widget.customPrompt);
    // _promptController = TextEditingController();
    _localWhiteList = List.from(widget.whiteList);
    // _galleryPrompt = widget.galleryPrompt ?? "";
    // _selectedPromptTab = widget.selectedPromptType;

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
    // _promptController.dispose();
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

  // 2. 최종 저장 로직 (필드 분리 저장)
  Future<void> _finalSaveWithBackup() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // AI 기능을 제거했으므로 Firestore에는 기존 widget에 있던 값을 그대로 유지하거나
    // 기본값을 저장하도록 설정합니다.
    try {
      // 1. Firestore 업데이트 (AI 관련 값은 기존 값을 유지하거나 기본값 0 설정)
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
        {
          'whiteList': _localWhiteList, // 화이트리스트 저장 추가
          'customPrompt': widget.customPrompt, // 기존 값 유지
          'galleryPrompt': widget.galleryPrompt, // 기존 값 유지
          'selectedPromptType': 0, // 기본 타입 0으로 고정
        },
      );

      // 2. main.dart 메모리 동기화 (onSave 호출)
      // 변수가 삭제되었으므로, 해당 자리에는 widget이 가진 기존값이나 기본값을 넣어줍니다.
      widget.onSave(
        _localWhiteList, // 업데이트된 화이트리스트
        widget.customPrompt, // 기존 프롬프트 값 전달
        widget.galleryPrompt, // 기존 갤러리 값 전달
        _localDateRange, // 업데이트된 날짜 범위
        0, // 선택된 탭 (기본값 0)
      );
    } catch (e) {
      debugPrint("저장 오류: $e");
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

    return Drawer(
      width: drawerWidth,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(""),
          centerTitle: true,
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
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- 1. 조회 기간 섹션 ---
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
                            ? "전체 기간"
                            : "${_formatDate(_localDateRange!.start)} ~ ${_formatDate(_localDateRange!.end)}",
                      ),
                      onTap: () => _selectDateRange(context),
                    ),
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

                    // --- 2. 발신 주소 섹션 (AI 탭 제거됨) ---
                    _buildWhiteListHeaderSection(),
                    const SizedBox(height: 12),

                    // 핵심 수정: 제한된 높이(SizedBox) 없이 ListView만 배치하여 전체 스크롤 적용
                    ListView.builder(
                      shrinkWrap: true, // ScrollView 안에서 높이 자동 조절
                      physics:
                          const NeverScrollableScrollPhysics(), // 부모(SingleChildScrollView) 스크롤 사용
                      itemCount: _getFilteredList().length,
                      itemBuilder: (context, index) {
                        final item = _getFilteredList()[index];
                        return _buildWhiteListItem(item);
                      },
                    ),
                    const SizedBox(height: 100), // 하단 버튼 공간 확보용 패딩
                  ],
                ),
              ),
            ),
          ],
        ),
        // --- 3. 하단 저장 버튼 고정 ---
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
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
                  _showSimpleAlert("알림", "사용자 프로파일을 먼저 등록해 주시기 바랍니다.");
                  return;
                }
                _finalSaveWithBackup();
                Navigator.pop(context);
              },
              child: const Text(
                "설정 저장 및 적용",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 1. 발신 주소 헤더 및 필터 부분
  Widget _buildWhiteListHeaderSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Text(
                  "발신 주소",
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                    _isSearchVisible ? Icons.search_off : Icons.search,
                    size: 20,
                    color: _isSearchVisible ? Colors.blue : Colors.grey,
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
                    color: _localFilterEnabled ? Colors.blue : Colors.grey,
                  ),
                ),
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
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: _getInputDecoration("리스트 내 검색..."),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: _getInputDecoration("이메일 주소 또는 도메인"),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(onPressed: _addWhiteList, child: const Text("추가")),
          ],
        ),
      ],
    );
  }

  // 2. 리스트 아이템 (기존 GestureDetector 부분을 분리)
  Widget _buildWhiteListItem(String item) {
    final actualIndex = _localWhiteList.indexOf(item);
    final parts = item.split(':');
    String emailOrDomain = parts[0];
    bool isActive = parts.length > 1 ? parts[1] == 'true' : true;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: IconButton(
          icon: const Icon(
            Icons.delete_outline_rounded,
            color: Colors.redAccent,
          ),
          onPressed: () =>
              setState(() => _localWhiteList.removeAt(actualIndex)),
        ),
        title: Text(
          emailOrDomain,
          style: TextStyle(
            fontSize: 15,
            color: isActive ? Colors.black87 : Colors.grey,
          ),
        ),
        trailing: Checkbox(
          value: isActive,
          onChanged: (val) => setState(
            () => _localWhiteList[actualIndex] = "$emailOrDomain:$val",
          ),
        ),
        onLongPress: () =>
            _showEditDialog(actualIndex, emailOrDomain, isActive),
      ),
    );
  }

  // 3. 필터링된 리스트 가져오기 함수
  List<String> _getFilteredList() {
    return _localWhiteList
        .where(
          (item) => item
              .split(':')[0]
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  // 4. 추가 로직 분리
  void _addWhiteList() {
    String input = _controller.text.trim();
    if (input.isEmpty) return;
    if (_localWhiteList.length >= 30) {
      _showSimpleAlert("알림", "베타 테스트 기간에는 최대 30개까지 등록 가능합니다. 🐱");
      return;
    }
    if (!input.contains('@')) input = "@$input";
    if (_localWhiteList.any((item) => item.startsWith('$input:'))) {
      _showSimpleAlert("알림", "이미 리스트에 존재하는 주소입니다.");
    } else {
      setState(() {
        _localWhiteList.add("$input:true");
        _controller.clear();
      });
    }
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
}
