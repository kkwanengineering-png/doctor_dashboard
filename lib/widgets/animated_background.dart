import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../theme/app_theme.dart';

class AnimatedBackground extends StatefulWidget {
  final Widget child;
  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 10),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Base Background
        Container(color: AppTheme.brandCream),
        // Animated Blobs
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final size = MediaQuery.of(context).size;
              return IgnorePointer(
                child: Stack(
                  children: [
                    _buildBlob(
                      top: -100,
                      right: -50,
                      size: 400,
                      scaleOffset:
                          math.sin(_controller.value * 2 * math.pi) * 0.1,
                    ),
                    _buildBlob(
                      bottom: -50,
                      left: -100,
                      size: 400,
                      scaleOffset:
                          math.cos(_controller.value * 2 * math.pi) * 0.1,
                      reverse: true,
                    ),
                    _buildBlob(
                      top: size.height * 0.4,
                      left: size.width * 0.3,
                      size: 300,
                      scaleOffset: 0.0, // Static size for the middle one
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        // Foreground Content
        widget.child,
      ],
    );
  }

  Widget _buildBlob({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    double scaleOffset = 0.0,
    bool reverse = false,
  }) {
    final scale = 1.0 + scaleOffset;
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.brandOrange.withValues(alpha: 0.15),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandOrange.withValues(alpha: 0.15),
                blurRadius: 80,
                spreadRadius: 80,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
