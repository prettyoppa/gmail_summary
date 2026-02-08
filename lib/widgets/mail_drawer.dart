import 'package:flutter/material.dart';
// import '../constants.dart';

class MailDrawer extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final List<String> whiteList;
  final Set<String> selectedSenders;
  final int selectedPromptIndex;
  final List<TextEditingController> promptControllers;
  final TextEditingController senderController;
  final Function(DateTimeRange) onDateRangeSelected;
  final Function(String) onAddSender;
  final Function(String, bool) onSenderToggled;
  final Function(String) onDeleteSender;
  final Function(int) onPromptSelected;
  final Function() onSave;

  const MailDrawer({
    super.key,
    required this.startDate,
    required this.endDate,
    required this.whiteList,
    required this.selectedSenders,
    required this.selectedPromptIndex,
    required this.promptControllers,
    required this.senderController,
    required this.onDateRangeSelected,
    required this.onAddSender,
    required this.onSenderToggled,
    required this.onDeleteSender,
    required this.onPromptSelected,
    required this.onSave,
  });

  // 날짜 포맷 함수 (yyyy/mm/dd)
  String _formatDate(DateTime dt) =>
      "${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // 상단 타이틀 영역 제거 및 여백 확보 (요청사항 4-3)
          const SizedBox(height: 60),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const Text(
                  "1. 필터 설정",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ListTile(
                  dense: true,
                  tileColor: Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: const Icon(Icons.calendar_today, size: 18),
                  title: Text(
                    "${_formatDate(startDate)} ~ ${_formatDate(endDate)}",
                    style: const TextStyle(fontSize: 13),
                  ),
                  onTap: () async {
                    final picked = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      helpText: '', // Date Range 문구 제거 (요청사항 4-2)
                    );
                    if (picked != null) onDateRangeSelected(picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: senderController,
                  decoration: InputDecoration(
                    hintText: "발신자 이메일 추가",
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.add_circle),
                      onPressed: () => onAddSender(senderController.text),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                ...whiteList.map(
                  (email) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(email, style: const TextStyle(fontSize: 12)),
                    value: selectedSenders.contains(email),
                    onChanged: (val) => onSenderToggled(email, val ?? false),
                    secondary: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 20,
                        color: Colors.redAccent,
                      ),
                      onPressed: () => onDeleteSender(email),
                    ),
                  ),
                ),
                const Divider(height: 32),
                const Text(
                  "2. AI 프롬프트",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ), // 명칭 변경 (4-1)
                const SizedBox(height: 12),
                for (int i = 0; i < 3; i++) ...[
                  Row(
                    children: [
                      Radio<int>(
                        value: i,
                        groupValue: selectedPromptIndex,
                        onChanged: (val) => onPromptSelected(val!),
                      ),
                      Text(
                        "프리셋 ${i + 1}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  TextField(
                    controller: promptControllers[i],
                    maxLines: 2,
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: selectedPromptIndex == i
                          ? Colors.amber[50]
                          : Colors.grey[50],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) => onSave(),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
