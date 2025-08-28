// lib/widgets/app_background.dart

import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({Key? key, required this.child}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          // --- UPDATED COLORS ---
          colors: [
            // A richer, more vibrant aqua color
            Color(0xFF4DB6AC), // This is similar to Teal 300
            // A richer, more vibrant coral color
            Color(0xFFFF8A65), // This is similar to Deep Orange 300
          ],
        ),
      ),
      child: child,
    );
  }
}
