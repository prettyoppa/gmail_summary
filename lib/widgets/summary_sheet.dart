import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SummarySheet extends StatelessWidget {
  final Map<String, String> email;
  final String aiResult;
  final bool isProcessing;
  final Future<void> Function() onRunAI;

  const SummarySheet({
    super.key,
    required this.email,
    required this.aiResult,
    required this.isProcessing,
    required this.onRunAI,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          Text(
            email['subject'] ?? "제목 없음",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Divider(),

          // 메일 본문 영역
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              child: SelectableText(
                email['body'] ?? "",
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[800],
                  height: 1.6,
                ),
              ),
            ),
          ),

          const Divider(height: 32),

          // 중앙 AI 실행 버튼 또는 결과 표시 (요청사항 4-4)
          Expanded(
            flex: 3,
            child: Center(
              child: aiResult.isEmpty
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 20,
                            ),
                            backgroundColor: const Color(0xFF000099),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: isProcessing ? null : onRunAI,
                          icon: isProcessing
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.auto_awesome),
                          label: const Text(
                            "AI 프롬프트 실행",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "선택한 프리셋으로 분석을 시작합니다.",
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    )
                  : Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "AI 분석 결과",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.copy,
                                size: 20,
                                color: Colors.blue,
                              ),
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: aiResult),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("클립보드에 복사되었습니다."),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            child: SelectableText(
                              aiResult,
                              style: const TextStyle(fontSize: 15, height: 1.6),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("닫기", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}
