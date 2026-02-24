import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'prompt_gallery_sheet.dart';

class AIPromptButton extends StatefulWidget {
  final String customPrompt; // 사용자 프롬프트 1 (통일)
  final String galleryPrompt; // 사용자 프롬프트 2 (통일)
  final int selectedPromptType; // 선택된 타입 (통일)
  final String? nickname;
  final Function(String, String, int) onPromptSaved;

  const AIPromptButton({
    super.key,
    required this.customPrompt,
    required this.galleryPrompt,
    required this.selectedPromptType,
    this.nickname,
    required this.onPromptSaved,
  });

  @override
  State<AIPromptButton> createState() => _AIPromptButtonState();
}

class _AIPromptButtonState extends State<AIPromptButton> {
  // filter_drawer.dart와 동일한 내부 변수명 사용
  late TextEditingController _promptController;
  late String _galleryPrompt;
  late int _selectedPromptTab;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.customPrompt);
    _galleryPrompt = widget.galleryPrompt;
    _selectedPromptTab = widget.selectedPromptType;
  }

  @override
  void didUpdateWidget(covariant AIPromptButton oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 1. 프롬프트 및 탭 정보 동기화
    if (oldWidget.customPrompt != widget.customPrompt ||
        oldWidget.galleryPrompt != widget.galleryPrompt ||
        oldWidget.selectedPromptType != widget.selectedPromptType ||
        oldWidget.nickname != widget.nickname) {
      setState(() {
        _promptController.text = widget.customPrompt;
        _galleryPrompt = widget.galleryPrompt;
        _selectedPromptTab = widget.selectedPromptType;
      });
    }

    if (oldWidget.nickname != widget.nickname) {
      setState(() {});
      debugPrint("🚩 AIPromptButton: 닉네임 업데이트됨 -> ${widget.nickname}");
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

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

  // 갤러리 공유 로직 (사용자 1 탭)
  Future<void> _sharePromptToGallery() async {
    final String content = _promptController.text.trim();
    if (content.isEmpty) {
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

      Map<String, dynamic> dataToSave = {
        'content': content,
        'authorNickname': nickname,
        'authorUid': user.uid,
        'authorEmail': user.email,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!docSnapshot.exists) {
        dataToSave['createdAt'] = FieldValue.serverTimestamp();
        dataToSave['usedCount'] = 0;
      }

      await docRef.set(dataToSave, SetOptions(merge: true));
      if (mounted) _showSimpleAlert("공유 완료", "프롬프트가 갤러리에 등록되었습니다.");
    } catch (e) {
      if (mounted) _showSimpleAlert("오류", "공유 중 오류 발생: $e");
    }
  }

  void _openPromptGallery(StateSetter setSheetState) async {
    final user = FirebaseAuth.instance.currentUser;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PromptGallerySheet(currentUserUid: user?.uid),
    );

    if (selected != null) {
      setSheetState(() {
        _galleryPrompt = selected;
        _selectedPromptTab = 1; // 갤러리 선택 시 자동으로 탭 전환
      });
    }
  }

  void _showPromptSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.65,
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 25,
            bottom: MediaQuery.of(context).viewInsets.bottom + 25,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // 탭 선택 영역
              Row(
                children: [
                  _tabButton("사용자 프롬프트 1", 0, setSheetState),
                  const SizedBox(width: 10),
                  _tabButton("사용자 프롬프트 2", 1, setSheetState),
                ],
              ),
              const SizedBox(height: 20),

              // 텍스트 박스 영역
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: _selectedPromptTab == 0
                      ? Stack(
                          children: [
                            TextField(
                              controller: _promptController, // 변수명 통일
                              maxLines: null,
                              keyboardType: TextInputType.multiline,
                              style: const TextStyle(fontSize: 15, height: 1.5),
                              decoration: const InputDecoration(
                                hintText: "나만의 요약을 지시해보세요...",
                                border: InputBorder.none,
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: FloatingActionButton.small(
                                heroTag: "share_fab",
                                onPressed: _sharePromptToGallery,
                                backgroundColor: Colors.indigo.withOpacity(0.1),
                                elevation: 0,
                                child: const Icon(
                                  Icons.cloud_upload,
                                  color: Colors.indigo,
                                ),
                              ),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: TextButton.icon(
                                onPressed: () =>
                                    _openPromptGallery(setSheetState),
                                icon: const Icon(Icons.auto_awesome, size: 18),
                                label: const Text("갤러리에서 새로 가져오기"),
                                style: TextButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 45),
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.indigo,
                                  side: BorderSide(
                                    color: Colors.indigo.withOpacity(0.2),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const BouncingScrollPhysics(),
                                child: Container(
                                  width: double.infinity,
                                  alignment: Alignment.topLeft,
                                  child: Text(
                                    _galleryPrompt.isEmpty
                                        ? "선택된 갤러리 프롬프트가 없습니다."
                                        : _galleryPrompt,
                                    style: const TextStyle(
                                      color: Colors.black87,
                                      fontSize: 15,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // 저장 버튼
              Padding(
                padding: const EdgeInsets.only(top: 8.0), // 상단 여백 약간 추가
                child: Row(
                  children: [
                    // --- 취소 버튼 ---
                    Expanded(
                      flex: 1,
                      child: SizedBox(
                        height: 60,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(
                              color: Colors.grey[300]!,
                            ), // 연한 테두리
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "취소",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12), // 버튼 사이 간격
                    // --- 적용 버튼 ---
                    Expanded(
                      flex: 2, // 적용 버튼을 조금 더 크게 강조
                      child: SizedBox(
                        height: 60,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent, // 기존 강조 색상 유지
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          onPressed: () async {
                            final user = FirebaseAuth.instance.currentUser;
                            if (user != null) {
                              // Firestore 업데이트
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({
                                    'customPrompt': _promptController.text,
                                    'galleryPrompt': _galleryPrompt,
                                    'selectedPromptType': _selectedPromptTab,
                                  });
                              // 콜백 실행 (이때 main.dart의 시간 갱신 로직이 돌아갑니다)
                              widget.onPromptSaved(
                                _promptController.text,
                                _galleryPrompt,
                                _selectedPromptTab,
                              );
                            }
                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text(
                            "적용",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(String label, int index, StateSetter setSheetState) {
    bool isSelected = _selectedPromptTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setSheetState(() => _selectedPromptTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.indigo : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey[600],
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: "mainAIPromptBtn",
      onPressed: () => _showPromptSheet(context),
      backgroundColor: Colors.blueAccent,
      icon: const Icon(Icons.auto_awesome, color: Colors.white),
      label: const Text(
        "AI 프롬프트",
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
    );
  }
}
