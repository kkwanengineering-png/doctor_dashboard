import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum BackgroundType { home, list, session }

class AppBackground extends StatelessWidget {
  final BackgroundType type;

  const AppBackground({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(color: AppColors.backgroundLight);
  }
}
