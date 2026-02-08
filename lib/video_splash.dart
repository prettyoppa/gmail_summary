import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoSplashScreen extends StatefulWidget {
  final Widget nextScreen; // 다음에 이동할 화면을 저장할 변수 추가

  // 생성자에서 nextScreen을 받도록 수정
  const VideoSplashScreen({super.key, required this.nextScreen});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // 비디오 경로 확인 필수!
    _controller = VideoPlayerController.asset("assets/videos/Catchy.mp4")
      ..initialize().then((_) {
        _controller.setVolume(0.0); // ★ 소리를 0으로 설정 (웹 자동재생 허용을 위해)
        setState(() {});
        _controller.play();
      });

    _controller.addListener(() {
      if (_controller.value.position >= _controller.value.duration) {
        // 영상이 끝나면, 위에서 받아온 'nextScreen'으로 이동합니다.
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => widget.nextScreen),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // 영상 배경색과 맞추세요
      body: Center(
        child: _controller.value.isInitialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              )
            : const SizedBox.shrink(), // 로딩 중엔 빈 화면
      ),
    );
  }
}
