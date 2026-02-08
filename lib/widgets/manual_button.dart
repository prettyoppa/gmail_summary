import 'package:flutter/material.dart';
// ManualManager가 정의된 파일을 import 하세요 (예: import '../services/manual_manager.dart';)
import '../manual_manager.dart';

class ManualButton extends StatelessWidget {
  const ManualButton({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      heroTag: "mainManualBtn",
      onPressed: () => ManualManager.showUserManual(context),
      backgroundColor: Colors.indigoAccent,
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.help_outline_rounded,
          color: Colors.indigoAccent,
          size: 18,
        ),
      ),
      label: const Text(
        "사용안내",
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
  }
}
