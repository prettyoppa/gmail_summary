import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:markdown/markdown.dart' as md;

class ManualManager {
  // 1. Firebase에서 매뉴얼 텍스트 가져오기
  static Future<String> _fetchManualFromFirebase() async {
    try {
      print("LOG: 매뉴얼 불러오기 시작...");
      var doc = await FirebaseFirestore.instance
          .collection('admin')
          .doc('guide')
          .get();

      if (doc.exists) {
        print("LOG: 데이터 확인됨 -> ${doc.data()}");
        // 콘솔에 입력하신 필드명이 'manual_content'가 맞는지 여기서 꼭 확인하세요!
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
        // FutureBuilder를 사용하여 데이터를 비동기로 기다립니다.
        // 이렇게 해야 데이터가 오지 않아도 다른 UI가 멈추지 않습니다.
        return FutureBuilder<String>(
          future: _fetchManualFromFirebase(),
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

                  Row(
                    children: [
                      Icon(
                        Icons.help_rounded,
                        color: Colors.indigoAccent,
                      ), // 버튼 아이콘과 통일감
                      SizedBox(width: 8),
                      Text(
                        "Catchy 사용 가이드",
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
                      // 💡 이 부분을 수정했습니다.
                      // gitHubWeb 설정은 HTML 태그 인라인 해석을 기본으로 포함합니다.
                      extensionSet: md.ExtensionSet.gitHubWeb,
                      styleSheet: MarkdownStyleSheet(
                        p: const TextStyle(fontSize: 16, height: 1.5),
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
