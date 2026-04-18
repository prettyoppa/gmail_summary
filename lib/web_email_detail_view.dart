import 'package:flutter/material.dart';
import 'services/email_link_manager.dart';
import 'services/mail_cache_manager.dart';
import '/manual_manager.dart';
import 'widgets/analysis_guide_card.dart';
import 'email_received_at_format.dart';

class WebEmailDetailView extends StatelessWidget {
  final Map<String, dynamic> email;
  // final dynamic rawData;
  // final dynamic analysisMap;
  // final dynamic eventData; // ✅ 일정 데이터를 직접 받기 위해 추가
  final Map<String, dynamic> summarizedContent;
  final Map<String, dynamic> extractedEventData;
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic>) onAddToCalendar; // ✅ 캘린더 추가 함수 연결
  final VoidCallback? onDelete;

  const WebEmailDetailView({
    super.key,
    required this.email,
    // required this.rawData,
    // required this.analysisMap,
    // required this.eventData,
    required this.summarizedContent,
    required this.extractedEventData,
    required this.onRefresh,
    required this.onAddToCalendar,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final String receivedAt = formatEmailReceivedAt(email);
    final String mailId = email['id'] ?? '';
    final dynamic currentAnalysis = summarizedContent[mailId];
    final dynamic currentEvent = extractedEventData[mailId];

    return Container(
      color: Colors.white, // 배경색을 흰색으로 고정
      child: Column(
        children: [
          // 1. 본문 영역 (위에서부터 시작하고, 남은 공간을 다 차지함)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40), // 여백을 조금 더 줌
              child: SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제목
                    Text(
                      email['subject'] ?? '',
                      style: const TextStyle(
                        fontSize: 28, // 웹에 맞춰 폰트 키움
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 발신자
                    Text(
                      "발신: ${email['sender'] ?? email['from'] ?? '알 수 없음'}",
                      style: const TextStyle(color: Colors.grey, fontSize: 15),
                    ),
                    if (receivedAt.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        receivedAt,
                        style: const TextStyle(color: Colors.grey, fontSize: 15),
                      ),
                    ],
                    const Divider(height: 50, thickness: 1),

                    // AI 요약 정보 타이틀
                    const Row(
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          color: Colors.blueAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "AI 요약 정보",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // 요약 내용 섹션
                    _buildSummarySection(currentAnalysis),

                    // 일정 위젯
                    if (currentEvent != null) ...[
                      const SizedBox(height: 40),
                      _buildWebCalendarSection(currentEvent),
                    ],

                    // 하단 버튼과 겹치지 않게 충분한 여백 추가
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),

          // 2. 하단 버튼 영역 (화면 하단에 고정)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                top: BorderSide(color: Colors.grey[200]!),
              ), // 경계선 추가
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end, // 오른쪽 정렬
              children: [
                // 기존 FloatingActionButton들을 Row 안에 배치하기 위해 스타일 조정
                _buildActionButtons(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 버튼 그룹을 별도 함수로 분리하여 가독성 높임
  Widget _buildActionButtons(BuildContext context) {
    return Wrap(
      spacing: 12, // 가로 간격
      runSpacing: 12, // 세로 간격 (창이 작아질 경우)
      children: [
        // 이 메일 삭제
        OutlinedButton.icon(
          onPressed: () => _showDeleteConfirmDialog(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.delete_outline, size: 20),
          label: const Text(
            "이 메일 삭제",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        // 사용안내
        ElevatedButton.icon(
          onPressed: () => ManualManager.showUserManual(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigoAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.help_outline, size: 20),
          label: const Text("사용안내"),
        ),
        // 원문링크
        ElevatedButton.icon(
          onPressed: () => EmailLinkManager.openOriginalEmail(
            context: context,
            email: email,
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.open_in_new, size: 20),
          label: const Text("원문링크"),
        ),
        // 새로고침
        IconButton.filled(
          onPressed: onRefresh,
          style: IconButton.styleFrom(
            backgroundColor: Colors.blue[50],
            foregroundColor: Colors.blue,
            padding: const EdgeInsets.all(15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.refresh),
        ),
      ],
    );
  }

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
              final String? mailId = email['id'];
              if (mailId != null) {
                await MailCacheManager.deleteMail(mailId);
                if (context.mounted) {
                  Navigator.pop(context); // 다이얼로그 닫기
                  onDelete?.call(); // ✅ 삭제 후 부모 위젯(main.dart)에 알림
                }
              }
            },
            child: const Text("삭제", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(dynamic content) {
    // 1. 로딩 중
    if (content == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 2. 에러 발생
    if (content is Map && content['status'] == 'error') {
      return AnalysisGuideCard(onRefresh: onRefresh);
    }

    // 3. 정상 결과 표시
    String displaySummary = "";
    if (content is Map) {
      displaySummary = content['summary'] ?? "요약 정보가 없습니다.";
    } else {
      displaySummary = content.toString();
    }

    return Text(
      displaySummary,
      style: const TextStyle(fontSize: 16, height: 1.8),
    );
  }

  // ✅ main.dart의 일직 카드 로직을 웹 버전에 맞게 이식
  Widget _buildWebCalendarSection(dynamic data) {
    List<dynamic> events = data is List ? data : [data];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              "감지된 일정 (${events.length}개)",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...events
            .map((e) => _buildSingleEventCard(e as Map<String, dynamic>))
            .toList(),
      ],
    );
  }

  Widget _buildSingleEventCard(Map<String, dynamic> event) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "📌 제목: ${event['title']}",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text("⏰ 일시: ${event['start']}"),
          if (event['location']?.isNotEmpty == true)
            Text("📍 장소: ${event['location']}"),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => onAddToCalendar(event),
            icon: const Icon(Icons.add, size: 16),
            label: const Text("내 캘린더에 추가"),
          ),
        ],
      ),
    );
  }
}
