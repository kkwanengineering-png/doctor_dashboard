import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double blur; // kept for API compat, no longer used for BackdropFilter
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double? height;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(24),
    this.color,
    this.blur = 12,
    this.border,
    this.boxShadow,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: color ?? Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(borderRadius),
          border:
              border ??
              Border.all(
                color: Colors.white.withValues(alpha: 0.2),
                width: 1.5,
              ),
          boxShadow: boxShadow,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
