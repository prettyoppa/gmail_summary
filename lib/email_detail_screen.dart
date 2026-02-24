import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'services/email_link_manager.dart';
import 'widgets/analysis_guide_card.dart';
import 'services/mail_cache_manager.dart';
import 'widgets/ai_prompt_button.dart';

class EmailDetailScreen extends StatefulWidget {
  final Map<String, dynamic> email;
  // final dynamic summary;
  final Map<String, dynamic> summarizedContent;
  final String? cleanBody;
  final String? messageIdFromGemini;
  final Widget calendarCard;
  final String customPrompt;
  final String galleryPrompt;
  final int selectedPromptType;
  final String? nickname;

  final Function(String, String, int) onSave;
  // final VoidCallback onRefresh;
  final Future<void> Function() onRefresh;

  const EmailDetailScreen({
    super.key,
    required this.email,
    // this.summary,
    required this.summarizedContent,
    this.cleanBody,
    this.messageIdFromGemini,
    required this.calendarCard,
    required this.customPrompt,
    required this.galleryPrompt,
    required this.selectedPromptType,
    this.nickname,
    required this.onSave,
    required this.onRefresh,
  });

  @override
  State<EmailDetailScreen> createState() => _EmailDetailScreenState();
}

class _EmailDetailScreenState extends State<EmailDetailScreen> {
  bool _isLoading = false;
  // 수정된 함수 정의 (파라미터 추가)
  void _shareSummary(dynamic currentSummary, Map currentEmail) {
    debugPrint("🚀 공유 실행 시점 데이터 확인");
    debugPrint("제목: ${currentEmail['subject']}");

    String textToShare = "";

    // 1. 전달받은 인자(currentSummary)를 직접 파싱
    if (currentSummary is Map) {
      textToShare =
          currentSummary['summary'] ??
          currentSummary['result'] ??
          currentSummary['content'] ??
          "";
      if (textToShare.isEmpty && currentSummary.values.isNotEmpty) {
        textToShare = currentSummary.values.first.toString();
      }
    } else {
      textToShare = currentSummary?.toString() ?? "";
    }

    if (textToShare.trim().isEmpty) {
      textToShare = "요약 정보를 가져오지 못했습니다.";
    }

    final String subject = currentEmail['subject'] ?? '제목 없음';
    final String sender =
        currentEmail['sender'] ?? currentEmail['from'] ?? '알 수 없음';

    final String shareText =
        """
[메일 요약 비서]
제목: $subject
발신: $sender

📌 AI 요약 내용:
$textToShare

""";

    // 2. 최신 Share API 호출
    Share.share(shareText, subject: '메일 요약 공유');
  }

  // ✅ 삭제 확인 및 실행 함수 추가
  void _showDeleteConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("메일 삭제"),
        content: const Text(
          "이 메일을 Catchy 앱에서 삭제하시겠습니까?\n(메일 서버에서는 삭제되지 않습니다.)",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("취소", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () async {
              // StatefulWidget이므로 widget.email['id']로 접근합니다.
              final String? mailId = widget.email['id'];

              if (mailId != null) {
                await MailCacheManager.deleteMail(mailId);
              }

              if (mounted) {
                Navigator.pop(context); // 다이얼로그 닫기
                Navigator.pop(
                  context,
                  "deleted",
                ); // 리스트 화면으로 "deleted" 신호를 보내며 돌아가기
              }
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mailId = widget.email['id'];
    final currentSummaryData = widget.summarizedContent[mailId];
    print("DEBUG: 현재 위젯이 가진 제목: ${widget.email['subject']}");
    print(
      "DEBUG: 현재 데이터 상태: ${currentSummaryData != null ? '데이터 있음' : '데이터 없음'}",
    );
    // print(
    //   "DEBUG: 현재 위젯이 가진 요약(내용): ${widget.summary.toString().substring(0, 20)}...",
    // );
    return Scaffold(
      appBar: AppBar(
        title: const Text("메일 분석 결과"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => _showDeleteConfirmDialog(context),
            tooltip: '메일 삭제',
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareSummary(currentSummaryData, widget.email),
            tooltip: '요약 내용 공유',
          ),
        ],
      ),
      body: SelectionArea(
        child: InteractiveViewer(
          constrained: false,
          scaleEnabled: true,
          panEnabled: true,
          minScale: 1.0,
          maxScale: 4.0,
          boundaryMargin: EdgeInsets.zero,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                // 기기 화면의 최소 높이만큼 공간을 확보합니다.
                minHeight: MediaQuery.of(context).size.height,
              ),
              child: Container(
                width: MediaQuery.of(context).size.width,
                padding: const EdgeInsets.all(20),
                color: Colors.white, // 이제 바닥까지 흰색으로 채워집니다.
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max, // min에서 max로 변경하여 공간 확보
                  children: [
                    Text(
                      widget.email['subject'] ?? '제목 없음',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "From: ${widget.email['sender'] ?? widget.email['from'] ?? '알 수 없음'}",
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const Divider(height: 30),

                    // AI 요약 타이틀
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_awesome,
                          color: Colors.purple,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          "AI 요약",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const Spacer(), // 왼쪽 타이틀과 오른쪽 버튼 사이를 띄워줌
                        // ✅ AI 프롬프트 버튼 추가
                        AIPromptButton(
                          customPrompt: widget.customPrompt,
                          galleryPrompt: widget.galleryPrompt,
                          selectedPromptType: widget.selectedPromptType,
                          nickname: widget.nickname,
                          onPromptSaved: (newCustom, newGallery, newType) {
                            // 1. 메인 화면의 프롬프트 변수와 '업데이트 시간'을 갱신합니다.
                            widget.onSave(newCustom, newGallery, newType);

                            // 2. 즉시 새로고침을 실행합니다.
                            // 생성자에서 required로 받았으므로 ! 없이 바로 호출 가능합니다.
                            widget.onRefresh();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 요약 영역
                    _buildSummarySection(context),

                    // 캘린더 카드
                    widget.calendarCard,

                    const SizedBox(height: 200), // 하단 버튼 여유 공간
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'view_original_gmail',
            // onPressed: () {
            //   EmailLinkManager.openOriginalEmail(email: widget.email);
            // },
            onPressed: () {
              // 1. 데이터 전체 구조 파악 (본문 제외하고 모든 키값 출력)
              final Map<String, dynamic> fullData = Map.from(widget.email);
              fullData.remove('body'); // 로그 가독성을 위해 본문은 제거

              EmailLinkManager.openOriginalEmail(
                context: context,
                email: widget.email,
              );
            },
            icon: const Icon(Icons.open_in_new, color: Colors.blue),
            label: const Text(
              "원문링크",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'share_button',
            onPressed: () => _shareSummary(currentSummaryData, widget.email),
            child: const Icon(Icons.share),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'refresh_button',
            onPressed: _isLoading
                ? null
                : () async {
                    // 🔴 로딩 중엔 버튼 클릭 방지
                    setState(() {
                      _isLoading = true; // 1. 로딩 시작
                    });

                    try {
                      await widget.onRefresh(); // 2. 부모의 요약 로직 실행
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isLoading = false; // 3. 로딩 종료 (성공/실패 상관없이)
                        });
                      }
                    }
                  },
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  // 🔴 [추가] 에러 가이드 및 요약 표시 위젯
  Widget _buildSummarySection(BuildContext context) {
    if (_isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: const [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 16),
            Text(
              "Gemini가 메일을 분석하고 있습니다...",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    // 1. widget.summary가 Map 전체라면 ID로 꺼내고, 아니라면 값 자체를 사용
    // final dynamic currentSummary =
    //     (widget.summary is Map &&
    //         widget.summary.containsKey(widget.email['id']))
    //     ? widget.summary[widget.email['id']]
    //     : widget.summary;
    final mailId = widget.email['id'];
    final dynamic currentSummary = widget.summarizedContent[mailId];
    // 2. 에러 상황 처리 (onRefresh 규격 문제 해결)
    if (currentSummary is Map && currentSummary['status'] == 'error') {
      return AnalysisGuideCard(
        onRefresh: () {
          widget.onRefresh(); // 함수를 감싸서 VoidCallback 타입을 맞춤
        },
      );
    }

    // 3. 일반 결과 표시 (로딩/성공)
    String displaySummary = "";
    if (currentSummary is Map) {
      displaySummary = currentSummary['summary'] ?? "요약 정보가 없습니다.";
    } else if (currentSummary is String) {
      displaySummary = currentSummary;
    } else {
      displaySummary = "Gemini가 분석 중입니다. 잠시만 기다려주세요...";
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        displaySummary,
        style: const TextStyle(fontSize: 16, height: 1.6),
      ),
    );
  }
}
