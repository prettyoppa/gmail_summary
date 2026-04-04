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
      isScrollControlled: true, // 키보드 대응 필수
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        // [중요] 키보드 높이만큼 시트 전체를 위로 밀어 올립니다.
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: StatefulBuilder(
          builder: (context, setSheetState) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            // Column의 mainAxisSize를 min으로 설정하여 내용물만큼만 높이를 차지하게 함
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 상단 핸들 바
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 탭 버튼
                Row(
                  children: [
                    _tabButton("사용자 프롬프트 1", 0, setSheetState),
                    const SizedBox(width: 10),
                    _tabButton("사용자 프롬프트 2", 1, setSheetState),
                  ],
                ),
                const SizedBox(height: 15),

                // [핵심] 텍스트 입력 영역 (최대 높이를 제한하여 버튼을 가리지 않게 함)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: _selectedPromptTab == 0
                        ? TextField(
                            controller: _promptController,
                            maxLines: 6, // 기본 노출 줄 수 조절
                            minLines: 1,
                            keyboardType: TextInputType.multiline,
                            decoration: const InputDecoration(
                              hintText: "나만의 요약을 지시해보세요...",
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          )
                        : ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight:
                                  MediaQuery.of(context).size.height *
                                  0.3, // 너무 길어지면 내부 스크롤
                            ),
                            child: SingleChildScrollView(
                              child: Text(
                                _galleryPrompt.isEmpty
                                    ? "선택된 프롬프트가 없습니다."
                                    : _galleryPrompt,
                              ),
                            ),
                          ),
                  ),
                ),

                // 갤러리 공유/가져오기 버튼 (텍스트 영역 바로 아래 배치)
                if (_selectedPromptTab == 0)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _sharePromptToGallery,
                      icon: const Icon(Icons.cloud_upload, size: 18),
                      label: const Text("갤러리에 공유"),
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ElevatedButton.icon(
                      onPressed: () => _openPromptGallery(setSheetState),
                      icon: const Icon(Icons.auto_awesome, size: 18),
                      label: const Text("갤러리에서 가져오기"),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 40),
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // 하단 버튼 (항상 최하단에 위치)
                Padding(
                  // 아까 확인하신 것처럼 60 정도를 주면 작은 폰에서도 안정적으로 올라옵니다.
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("취소"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final user = FirebaseAuth.instance.currentUser;

                            if (user != null) {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .update({
                                    'customPrompt': _promptController.text,

                                    'galleryPrompt': _galleryPrompt,

                                    'selectedPromptType': _selectedPromptTab,
                                  });

                              widget.onPromptSaved(
                                _promptController.text,

                                _galleryPrompt,

                                _selectedPromptTab,
                              );
                            }

                            if (context.mounted) Navigator.pop(context);
                          },
                          child: const Text("적용"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
