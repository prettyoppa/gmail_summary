import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // 날짜 변환 함수 (시간 제외, 날짜만 yyyy-MM-dd)
  String _formatDateOnly(dynamic timestamp) {
    if (timestamp == null) return '기록 없음';

    DateTime? date;

    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is String) {
      // 문자열로 들어올 경우를 대비해 파싱 시도
      date = DateTime.tryParse(timestamp);
    }

    if (date != null) {
      // ✨ yyyy-MM-dd 포맷으로 시간은 원천 봉쇄
      return DateFormat('yyyy-MM-dd').format(date);
    }

    return '날짜 형식 오류';
  }

  // 분석 상세 날짜를 보여주는 바텀 시트
  void _showAnalysisDetails(String userId, String userName) async {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "$userName님의 분석 기록",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('read_mails')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("분석 기록이 없습니다."));
                    }

                    // 🎯 [정렬 로직] 가져온 문서를 readAt 기준으로 내림차순 정렬
                    List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
                    docs.sort((a, b) {
                      final aTime =
                          (a.data() as Map<String, dynamic>)['readAt']
                              as Timestamp?;
                      final bTime =
                          (b.data() as Map<String, dynamic>)['readAt']
                              as Timestamp?;
                      if (aTime == null || bTime == null) return 0;
                      return bTime.compareTo(aTime); // 최신순(내림차순)
                    });

                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final mailData =
                            docs[index].data() as Map<String, dynamic>;
                        final dynamic readAtValue = mailData['readAt'];

                        String detailDate = '날짜 정보 없음';
                        if (readAtValue is Timestamp) {
                          // 상세 내역에서는 분석 시각까지 표시
                          detailDate = DateFormat(
                            'yyyy-MM-dd HH:mm:ss',
                          ).format(readAtValue.toDate());
                        }

                        return ListTile(
                          dense: true,
                          // 🎯 타이틀 제거: 날짜 정보를 타이틀 위치로 올림
                          title: Text(
                            "분석 일시: $detailDate",
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          leading: const Icon(
                            Icons.history,
                            color: Colors.indigo,
                            size: 20,
                          ),
                          // 필요한 경우 아래에 메일 ID 등을 살짝 표시 가능 (현재는 공백)
                          subtitle: mailData['subject'] != null
                              ? Text(mailData['subject'])
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("관리자 모니터링"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text("데이터 오류"));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final userDocs = snapshot.data!.docs;

          return ListView.separated(
            itemCount: userDocs.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final userData = userDocs[index].data() as Map<String, dynamic>;
              final String userId = userDocs[index].id;

              // 🎯 닉네임 대신 이름(name) 필드를 우선적으로 사용
              String displayName =
                  userData['name'] ?? userData['displayName'] ?? '이름 없음';
              String email = userData['email'] ?? '계정 정보 없음';
              String createdAt = _formatDateOnly(userData['createdAt']);

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                // 아이콘 제거로 인해 바로 title 시작
                title: Text(
                  displayName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "가입일: $createdAt", // 시간 정보 제외됨
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                trailing: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('read_mails')
                      .get(),
                  builder: (context, mailSnapshot) {
                    int count = 0;
                    if (mailSnapshot.hasData) {
                      count = mailSnapshot.data!.docs.length;
                    }

                    return GestureDetector(
                      onTap: () => _showAnalysisDetails(userId, displayName),
                      child: Container(
                        // 1. 패딩을 더 타이트하게 조정 (수직 패딩을 8 -> 4로 줄임)
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.indigo.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.indigo.shade100),
                        ),
                        child: Column(
                          // 2. Column이 차지하는 세로 공간을 최소화
                          mainAxisSize: MainAxisSize.min,
                          // 3. 중앙 정렬
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "분석건수",
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.indigo,
                                height: 1.0,
                              ), // height 조절로 간격 축소
                            ),
                            const SizedBox(height: 2), // 텍스트 사이 간격 미세 조정
                            Text(
                              "$count",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16, // 크기를 18 -> 16으로 살짝 조절
                                color: Colors.indigo,
                                height: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
