import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'services/email_link_manager.dart';
import 'widgets/analysis_guide_card.dart';

class EmailDetailScreen extends StatelessWidget {
  final Map<String, dynamic> email;
  final dynamic summary; // String? 에서 dynamic으로 변경 (에러 Map 대응)
  final String? cleanBody;
  final String? messageIdFromGemini;
  final Widget calendarCard;
  final VoidCallback onRefresh;

  const EmailDetailScreen({
    super.key,
    required this.email,
    this.summary,
    this.cleanBody,
    this.messageIdFromGemini,
    required this.calendarCard,
    required this.onRefresh,
  });

  void _shareSummary() {
    // summary가 에러 Map일 경우를 대비해 처리
    String textToShare = "";
    if (summary is Map) {
      textToShare = summary['summary'] ?? "";
    } else {
      textToShare = summary ?? "";
    }

    if (textToShare.isEmpty) return;

    final String shareText =
        """
[메일 요약 비서]
제목: ${email['subject'] ?? '제목 없음'}
발신: ${email['from'] ?? '알 수 없음'}

📌 AI 요약 내용:
$textToShare

---
본문 확인은 앱에서 해주세요.
""";
    Share.share(shareText, subject: '메일 요약 공유');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("메일 분석 결과"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareSummary,
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
            child: Container(
              width: MediaQuery.of(context).size.width,
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    email['subject'] ?? '제목 없음',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "From: ${email['from']}",
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                  const Divider(height: 30),

                  // AI 요약 타이틀
                  Row(
                    children: const [
                      Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "AI 요약",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // 🔴 [수정 포인트] 요약 영역을 함수로 대체
                  _buildSummarySection(context),

                  // 캘린더 카드
                  calendarCard,

                  const SizedBox(height: 150),
                ],
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
            onPressed: () => EmailLinkManager.openOriginalEmail(email: email),
            icon: const Icon(Icons.open_in_new, color: Colors.blue),
            label: const Text(
              "원문 링크",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'share_button',
            onPressed: _shareSummary,
            child: const Icon(Icons.share),
          ),
          const SizedBox(width: 12),
          FloatingActionButton(
            heroTag: 'refresh_button',
            onPressed: () => onRefresh(),
            child: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  // 🔴 [추가] 에러 가이드 및 요약 표시 위젯
  Widget _buildSummarySection(BuildContext context) {
    // 1. 에러 상황 처리 (Map 형태이고 status가 error인 경우)
    if (summary is Map && summary['status'] == 'error') {
      return AnalysisGuideCard(onRefresh: onRefresh);
    }

    // 2. 일반 결과 표시 (로딩/성공)
    String displaySummary = "";
    if (summary is Map) {
      displaySummary = summary['summary'] ?? "요약 정보가 없습니다.";
    } else {
      displaySummary = summary ?? "Gemini가 다시 분석 중입니다...";
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
