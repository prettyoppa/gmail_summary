import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; //
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart'; // ✅ 링크 실행용

class ManualManager {
  // 1. Firebase에서 매뉴얼 텍스트 가져오기 (이 부분이 사라져서 에러가 났던 것입니다)
  static Future<String> _fetchManualFromFirebase() async {
    try {
      print("LOG: 매뉴얼 불러오기 시작...");
      var doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc('guide')
          .get();

      if (doc.exists) {
        print("LOG: 데이터 확인됨 -> ${doc.data()}");
        return doc.data()?['manual_content'] ?? "필드(manual_content)가 비어있습니다.";
      } else {
        print("LOG: 문서를 찾을 수 없습니다 (admin/guide)");
        return "관리자가 작성한 매뉴얼 문서가 없습니다.";
      }
    } catch (e) {
      print("LOG: 에러 발생 -> $e");
      return "데이터를 가져오는 중 에러가 발생했습니다: $e";
    }
  }

  // 2. 바텀 시트 실행 함수
  static void showUserManual(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return FutureBuilder<String>(
          future: _fetchManualFromFirebase(), // ✅ 이제 이 메서드를 정상적으로 찾을 수 있습니다.
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return Container(
              padding: const EdgeInsets.all(20),
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  // 상단 디자인 바
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.only(bottom: 20, top: 10),
                  ),

                  const Row(
                    children: [
                      Icon(Icons.help_rounded, color: Colors.indigoAccent),
                      SizedBox(width: 8),
                      Text(
                        "AI 고양이 Catchy",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // 마크다운 본문 영역
                  Expanded(
                    child: Markdown(
                      data: snapshot.data ?? "내용을 불러올 수 없습니다.",
                      extensionSet: md.ExtensionSet.gitHubWeb,

                      // ✅ 링크 클릭 시 브라우저나 유튜브 앱으로 연결
                      onTapLink: (text, href, title) async {
                        if (href != null) {
                          final Uri url = Uri.parse(href);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(
                              url,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }
                      },

                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 16, height: 1.5),
                        // ✅ 링크 스타일: 파란색 + 밑줄로 클릭 가능함을 표시
                        a: const TextStyle(
                          color: Colors.blueAccent,
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  // 닫기 버튼
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        "확인했습니다",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
