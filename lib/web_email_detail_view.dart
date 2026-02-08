import 'package:flutter/material.dart';
import 'services/email_link_manager.dart';
import '/manual_manager.dart';
import 'widgets/analysis_guide_card.dart';

class WebEmailDetailView extends StatelessWidget {
  final Map<String, dynamic> email;
  final dynamic rawData;
  final dynamic analysisMap;
  final dynamic eventData; // ✅ 일정 데이터를 직접 받기 위해 추가
  final VoidCallback onRefresh;
  final Function(Map<String, dynamic>) onAddToCalendar; // ✅ 캘린더 추가 함수 연결

  const WebEmailDetailView({
    super.key,
    required this.email,
    required this.rawData,
    required this.analysisMap,
    required this.eventData, // main.dart의 _extractedEventData[_selectedEmail!['id']]
    required this.onRefresh,
    required this.onAddToCalendar,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: SelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 제목 및 발신자
                Text(
                  email['subject'] ?? '',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "발신: ${email['from']}",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const Divider(height: 40),

                // AI 요약 정보 타이틀
                const Text(
                  "AI 요약 정보",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 20),

                _buildSummarySection(),

                // ✅ 일정 위젯 추가 (이 부분이 누락되어 보이지 않았던 것입니다)
                if (eventData != null) ...[
                  const SizedBox(height: 30),
                  _buildWebCalendarSection(eventData),
                ],

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),

        // 우측 하단 버튼 그룹 (기존 UI 유지)
        _buildBottomButtons(context),
      ],
    );
  }

  Widget _buildSummarySection() {
    final content = rawData;

    // 1. 로딩 중 (main.dart에서 remove하여 null이 된 경우)
    if (content == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // 2. 에러가 발생한 경우 (Map 형태이고 status가 error인 경우)
    if (content is Map && content['status'] == 'error') {
      return AnalysisGuideCard(onRefresh: onRefresh);
    }

    // 3. 정상 결과 표시
    String displaySummary = "";
    if (analysisMap != null && analysisMap is Map) {
      displaySummary = analysisMap['summary'] ?? "요약 정보가 없습니다.";
    } else {
      displaySummary = rawData.toString();
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

  Widget _buildBottomButtons(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: "web_manual",
            onPressed: () => ManualManager.showUserManual(context),
            backgroundColor: Colors.indigoAccent,
            label: const Text("사용안내", style: TextStyle(color: Colors.white)),
            icon: const Icon(Icons.help_outline, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              FloatingActionButton.extended(
                heroTag: "web_link",
                onPressed: () =>
                    EmailLinkManager.openOriginalEmail(email: email),
                backgroundColor: Colors.white,
                label: const Text("원문 링크"),
                icon: const Icon(Icons.open_in_new),
              ),
              const SizedBox(width: 8),
              FloatingActionButton(
                heroTag: "web_refresh",
                onPressed: onRefresh,
                backgroundColor: Colors.white,
                child: const Icon(Icons.refresh, color: Colors.blue),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
