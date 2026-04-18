import 'package:flutter/material.dart';

class GlassButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final double borderRadius;
  final Color? color;
  final double blur; // kept for API compat, no longer drives BackdropFilter
  final Border? border;
  final List<BoxShadow>? boxShadow;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.borderRadius = 16,
    this.color,
    this.blur = 15,
    this.border,
    this.boxShadow,
    this.width,
    this.height = 68,
    this.padding = const EdgeInsets.symmetric(horizontal: 24),
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onPressed != null;

    return RepaintBoundary(
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: boxShadow,
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(borderRadius),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(borderRadius),
              splashColor: Colors.white.withValues(alpha: 0.1),
              highlightColor: Colors.white.withValues(alpha: 0.05),
              child: Container(
                padding: padding,
                decoration: BoxDecoration(
                  color: color ?? Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border:
                      border ??
                      Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                ),
                child: Center(child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
