import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/app_background.dart';
import 'exercises_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final Set<String> _completedExercises = {};
  static const int _totalExercises = 4;

  double get _progress => _completedExercises.length / _totalExercises;
  int get _progressPercent => (_progress * 100).round();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          // Animated Glassmorphism Background
          const AppBackground(type: BackgroundType.home),
          // Main content
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      const Spacer(flex: 1),
                      _buildGlassProgressCard(),
                      const Spacer(flex: 1),
                      _buildStartSessionButton(context),
                      const SafeArea(top: false, child: SizedBox(height: 16)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return GlassCard(
      padding: EdgeInsets.zero,
      borderRadius: 0,
      blur: 15,
      color: Colors.white.withValues(alpha: 0.1),
      border: Border(
        bottom: BorderSide(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
          child: Row(
            children: [
              // Avatar — cached after first load
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuBAbI_ksBSyrvtEx0YnLJOOjXBiQoCjMBjB64bEip0vGDyO9LCbOJLzujKKN4My-AsgRERQCe5zpbl-kFSpOVo9yodonPBktv2sDCOxsNTgn9tThJG0jJTrfjgBzkppkHeWi_RGyd4zHYHOX4P9sw_9TFydyIKAXR9R1VoGIS6OBhutdYKhdRuAgsWprw6HOqh_Ql130uMr02GCv3DTodmJnCT7d-go3niSIBaBN7FiZlKqVaGzT2OQPDVM2LV_7cExP1CGcZXRhy74',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 20),
              // Greeting
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good Morning',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Welcome back!',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate900,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassProgressCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      borderRadius: 40,
      blur: 20,
      color: Colors.white.withValues(alpha: 0.15),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.15),
          blurRadius: 32,
          offset: const Offset(0, 8),
        ),
      ],
      child: Column(
        children: [
          Text(
            'Your Progress',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.slate900,
            ),
          ),
          const SizedBox(height: 24),
          // Circular Progress (orange)
          SizedBox(
            width: 240,
            height: 240,
            child: CustomPaint(
              painter: _CircularProgressPainter(
                progress: _progress,
                strokeWidth: 14,
                backgroundColor: Colors.white.withValues(alpha: 0.5),
                progressColor: AppColors.primary,
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$_progressPercent%',
                      style: TextStyle(
                        fontSize: 64,
                        fontWeight: FontWeight.w900,
                        color: AppColors.slate900,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'Completed',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),
          // Status text with pill badge — Wrap prevents overflow on narrow screens
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            runSpacing: 4,
            children: [
              Text(
                'You have completed',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  '${_completedExercises.length} of $_totalExercises exercises',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartSessionButton(BuildContext context) {
    return GlassButton(
      onPressed: () async {
        final result = await Navigator.push<Set<String>>(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ExercisesScreen(completedExercises: _completedExercises),
          ),
        );
        if (result != null) {
          setState(() {
            _completedExercises
              ..clear()
              ..addAll(result);
          });
        }
      },
      borderRadius: 24,
      height: 88,
      color: AppColors.primary.withValues(alpha: 0.8),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
      ],
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 20),
          const Text(
            'Start Session',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// Circular progress painter — optimized Paint creation
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  final Paint _bgPaint;
  final Paint _progressPaint;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  }) : _bgPaint = Paint()
         ..color = backgroundColor
         ..style = PaintingStyle.stroke
         ..strokeWidth = strokeWidth
         ..strokeCap = StrokeCap.round,
       _progressPaint = Paint()
         ..color = progressColor
         ..style = PaintingStyle.stroke
         ..strokeWidth = strokeWidth
         ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    canvas.drawCircle(center, radius, _bgPaint);

    // Progress arc
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        _progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
