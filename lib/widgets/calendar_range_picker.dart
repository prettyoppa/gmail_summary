import 'package:flutter/material.dart';

class CalendarRangePicker extends StatelessWidget {
  final DateTimeRange? initialRange;
  final VoidCallback onReSync;

  const CalendarRangePicker({
    super.key,
    this.initialRange,
    required this.onReSync,
  });

  static Future<DateTimeRange?> show(
    BuildContext context, {
    DateTimeRange? initialRange,
    required VoidCallback onReSync,
    bool showReSync = true,
  }) async {
    final DateTime now = DateTime.now();
    // ✅ 모든 기준을 1개월(30일)로 통일
    final DateTime oneMonthAgo = DateTime(now.year, now.month, now.day - 30);
    final DateTime firstLimit = oneMonthAgo;

    DateTimeRange? safeRange = initialRange;
    // 기존 설정값이 1개월보다 더 과거라면 범위를 1개월 내로 보정
    if (safeRange != null && safeRange.start.isBefore(firstLimit)) {
      safeRange = DateTimeRange(start: firstLimit, end: now);
    }

    return await showDateRangePicker(
      context: context,
      initialDateRange:
          safeRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
      firstDate: firstLimit,
      lastDate: now,
      helpText: "조회 기간 선택",
      saveText: "적용",
      cancelText: "취소",
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blueAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
              secondary: Colors.blueAccent.withAlpha(25),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: Column(
            children: [
              const SizedBox(height: 50),
              Expanded(child: child!),
              // ✅ 버튼 텍스트와 로직을 1개월로 수정
              if (showReSync)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        onReSync();
                      },
                      icon: const Icon(
                        Icons.sync,
                        size: 16,
                        color: Colors.redAccent,
                      ),
                      label: const Text(
                        "최근 1개월치 이메일 서버 재수집",
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: Colors.redAccent.withOpacity(0.05),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
