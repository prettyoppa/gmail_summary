import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../constants.dart';

class AppLogin {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: AppConstants.googleClientId,
    scopes: [
      'https://www.googleapis.com/auth/gmail.readonly',
      'https://www.googleapis.com/auth/calendar.events',
      'email',
    ],
  );

  static GoogleSignIn get googleSignIn => _googleSignIn;

  // 🎯 [핵심] 로그인 및 사용자 정보 저장 (이름 초기화 방지)
  static Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);
      final User? user = userCredential.user;

      if (user != null) {
        await _saveUserInfoSafe(user, googleUser);
      }
      return user;
    } catch (e) {
      debugPrint("Login Error: $e");
      return null;
    }
  }

  // 🎯 [수정] Firestore 저장 로직: 이름이 이미 있으면 덮어쓰지 않음
  static Future<void> _saveUserInfoSafe(
    User user,
    GoogleSignInAccount googleUser,
  ) async {
    final userDocRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid);
    final doc = await userDocRef.get();

    Map<String, dynamic> updateData = {
      'email': googleUser.email,
      'lastLogin': FieldValue.serverTimestamp(),
    };

    if (!doc.exists) {
      // 신규 유저일 때만 구글 정보를 기본값으로 저장
      updateData['name'] = googleUser.displayName ?? '이름없음';
      updateData['createdAt'] = FieldValue.serverTimestamp();
      await userDocRef.set(updateData);
    } else {
      // 기존 유저라면 이름(name) 필드가 있는지 확인
      final existingData = doc.data()!;
      if (existingData['name'] == null ||
          existingData['name'].toString().isEmpty) {
        // 이름 필드가 비어있을 때만 구글 이름으로 채워줌
        await userDocRef.update({'name': googleUser.displayName ?? '이름없음'});
      }
      // 이름이 이미 있다면 updateData(이메일, 마지막 로그인)만 업데이트
      await userDocRef.update(updateData);
    }
  }

  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
