import 'package:flutter/material.dart';

class AnalysisGuideCard extends StatelessWidget {
  final VoidCallback onRefresh;

  const AnalysisGuideCard({super.key, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blueGrey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blueGrey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blueGrey[700], size: 22),
              const SizedBox(width: 8),
              const Text(
                "분석 오류 안내",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 🎯 요청하신 색상 강조가 적용된 RichText
          Text.rich(
            TextSpan(
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: Colors.blueGrey[900],
              ),
              children: [
                const TextSpan(text: "여러 번의 회신이 겹친 "),
                const TextSpan(
                  text: "**스레드 메일**",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const TextSpan(text: "의 경우, 프롬프트에 복잡한 "),
                const TextSpan(
                  text: "가정",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(
                  text: "이나 모호한 지시가 포함되면 AI가 분석 중 오류가 발생할 수 있습니다.\n\n",
                ),
                const TextSpan(text: "프롬프트에서 AI가 "),
                const TextSpan(
                  text: "판단",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: " 또는 "),
                const TextSpan(
                  text: "가정",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: "을 하도록 지시하는 내용 대신 "),
                const TextSpan(
                  text: "단순",
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(text: "하고 "),
                const TextSpan(
                  text: "명확",
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const TextSpan(
                  text: "하게 지시해 주시면, 훨씬 빠르고 정확한 요약 결과를 얻으실 수 있습니다.",
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text("다시 분석하기"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey[700],
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
