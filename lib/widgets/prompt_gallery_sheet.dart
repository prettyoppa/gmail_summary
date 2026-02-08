import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PromptGallerySheet extends StatefulWidget {
  final Function(String)? onApply;
  final String? currentUserUid;

  const PromptGallerySheet({super.key, this.onApply, this.currentUserUid});

  @override
  State<PromptGallerySheet> createState() => _PromptGallerySheetState();
}

class _PromptGallerySheetState extends State<PromptGallerySheet> {
  late Future<List<Map<String, dynamic>>> _allPromptsFuture;

  @override
  void initState() {
    super.initState();
    _allPromptsFuture = _fetchAllPrompts();
  }

  Future<List<Map<String, dynamic>>> _fetchAllPrompts() async {
    final adminQuery = FirebaseFirestore.instance
        .collection('admin_settings')
        .doc('prompts')
        .collection('items')
        .orderBy('order', descending: false)
        .get();

    final sharedQuery = FirebaseFirestore.instance
        .collection('shared_prompts')
        .orderBy('updatedAt', descending: true)
        .orderBy('usedCount', descending: true)
        .get();

    final results = await Future.wait([adminQuery, sharedQuery]);
    List<Map<String, dynamic>> combined = [];

    // 1. Admin 프롬프트 처리
    for (var doc in results[0].docs) {
      final data = doc.data();
      combined.add({
        'docId': doc.id, // ID 저장
        'type': 'admin',
        'author': 'Admin',
        'title': data['title'] ?? '추천 프롬프트',
        'content': data['content'] ?? '',
        // 'usedCount': data['usedCount'] ?? 0,
        'usedBy': data['usedBy'] ?? [],
        'usedCount': (data['usedBy'] as List?)?.length ?? 0,
      });
    }

    // 2. 사용자 프롬프트 처리
    for (var doc in results[1].docs) {
      final data = doc.data();
      String authorNickname = data['authorNickname'] ?? '익명';
      if (authorNickname.trim().isEmpty) authorNickname = '익명';

      combined.add({
        'docId': doc.id, // ID 저장
        'type': 'user',
        'author': authorNickname,
        'title': data['title'] ?? '사용자 프롬프트',
        'content': data['content'] ?? '',
        'updatedAt': data['updatedAt'],
        // 'usedCount': data['usedCount'] ?? 0,
        'usedBy': data['usedBy'] ?? [],
        'usedCount': (data['usedBy'] as List?)?.length ?? 0,
      });
    }
    return combined;
  }

  // usedCount 증가 함수
  void _incrementUsedCount(Map<String, dynamic> p) async {
    // 로그 1: 함수 호출 확인
    print("==== [로그 1] _incrementUsedCount 함수 진입 ====");
    print("현재 문서 ID: ${p['docId']}");
    print("현재 사용자 UID: ${widget.currentUserUid}");
    // 1. UID가 없으면 중단
    if (widget.currentUserUid == null || p['docId'] == null) {
      print("UID 또는 DocID가 없어 업데이트를 중단합니다.");
      return;
    }

    final uid = widget.currentUserUid!;

    // 2. 이미 적용한 사용자인지 메모리 상에서 1차 체크 (불필요한 네트워크 요청 방지)
    final List usedBy = p['usedBy'] is List ? p['usedBy'] : [];
    if (usedBy.contains(uid)) {
      print("이미 명단에 존재하는 사용자입니다.");
      return;
    }

    // 3. 경로 설정
    DocumentReference docRef;
    if (p['type'] == 'admin') {
      docRef = FirebaseFirestore.instance
          .collection('admin_settings')
          .doc('prompts')
          .collection('items')
          .doc(p['docId']);
    } else {
      docRef = FirebaseFirestore.instance
          .collection('shared_prompts')
          .doc(p['docId']);
    }

    print("🚀 [로그 2] Firestore 업데이트 시도 중... 경로: ${docRef.path}");
    // 4. DB 업데이트 (핵심: 사용자가 명단에 없을 때만 실행됨)
    await docRef.update({
      'usedBy': FieldValue.arrayUnion([uid]), // 명단에 추가 (없으면 생성됨)
      'usedCount': FieldValue.increment(1), // 숫자 증가
    });
    print("✅ [로그 3] Firestore 업데이트 성공!");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "✨ 프롬프트 갤러리",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _allPromptsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("에러: ${snapshot.error}"));
                }
                final allData = snapshot.data ?? [];
                final adminList = allData
                    .where((p) => p['type'] == 'admin')
                    .toList();
                final userList = allData
                    .where((p) => p['type'] == 'user')
                    .toList();

                return ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    if (adminList.isNotEmpty) ...[
                      _buildSectionTitle("🎯 Admin 추천"),
                      ...adminList.map((p) => _buildExpandablePrompt(p)),
                    ],
                    if (userList.isNotEmpty) ...[
                      const Divider(height: 40),
                      _buildSectionTitle("👥 사용자 공유"),
                      ...userList.map((p) => _buildExpandablePrompt(p)),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          color: Colors.blueAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildExpandablePrompt(Map<String, dynamic> p) {
    bool isExpanded = false;

    return StatefulBuilder(
      builder: (context, setItemState) {
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.grey[200]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            onTap: () {
              setItemState(() {
                isExpanded = !isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        "작성자: ${p['author']}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.person_add, size: 18, color: Colors.blue[400]),
                      const SizedBox(width: 4),
                      Text(
                        "${p['usedCount'] ?? 0}",
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.fastOutSlowIn,
                    child: Text(
                      p['content'],
                      style: const TextStyle(
                        height: 1.5,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                      maxLines: isExpanded ? null : 2,
                      overflow: isExpanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                    ),
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _incrementUsedCount(p); // 카운트 증가 실행

                          if (widget.onApply != null) {
                            widget.onApply!(p['content']);
                          }
                          Navigator.pop(context, p['content']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("이 프롬프트 적용하기"),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
