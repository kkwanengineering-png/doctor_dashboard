import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../exercise_session_screen.dart';
import '../../services/firebase_service.dart';
import '../../services/ble_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

// ============================================================================
// Sit and Stand Screen
// ============================================================================
class SitAndStandScreen extends StatelessWidget {
  const SitAndStandScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExerciseShell(
      exerciseName: 'Sit and Stand',
      sensorBuilder: (onRepPassed, onRepFailed, isStarted, onReadyChanged) =>
          _SitAndStandPanel(
            onRepPassed: onRepPassed,
            onRepFailed: onRepFailed,
            isStarted: isStarted,
            onReadyChanged: onReadyChanged,
          ),
    );
  }
}

// Panel: observes angle and fires onRepPassed/onRepFailed when a rep cycle completes/fails.
class _SitAndStandPanel extends StatefulWidget {
  final VoidCallback onRepPassed;
  final VoidCallback onRepFailed;
  final bool isStarted;
  final ValueChanged<bool> onReadyChanged;
  const _SitAndStandPanel({
    required this.onRepPassed,
    required this.onRepFailed,
    required this.isStarted,
    required this.onReadyChanged,
  });

  @override
  State<_SitAndStandPanel> createState() => _SitAndStandPanelState();
}

enum _RepState { idle, returning, cooldown }

class _SitAndStandPanelState extends State<_SitAndStandPanel>
    with SingleTickerProviderStateMixin {
  _RepState _state = _RepState.idle;
  DateTime? _repStartTime;
  double _maxAngleDuringRep = 0;

  // ── Smooth animation ────────────────────────────────────────────────────
  late final AnimationController _controller;
  late Tween<double> _angleTween;
  late Animation<double> _smoothAngle;

  StreamSubscription<double>? _angleSub;

  // postFrameCallback storm guards
  bool _pendingRepCallback = false;
  bool _pendingReadyCallback = false;
  bool _lastReadyValue = true;

  // Firebase Angle Sync throttle: only sync the angle to the database
  // at most once every 100ms (10 Hz).
  DateTime _lastFirebaseAngleUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _angleTween = Tween<double>(begin: 0.0, end: 0.0);
    _smoothAngle = _angleTween.animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _angleSub = BleService.instance.angleStream.listen(_onAngle);
  }

  @override
  void dispose() {
    _angleSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onAngle(double angle) {
    _checkRep(angle);
    _angleTween.begin = _smoothAngle.value;
    _angleTween.end = angle;
    _controller.forward(from: 0.0);

    // Sync to Firebase if exercise is started and ≥100ms passed.
    if (widget.isStarted) {
      final now = DateTime.now();
      if (now.difference(_lastFirebaseAngleUpdate).inMilliseconds >= 20) {
        _lastFirebaseAngleUpdate = now;
        FirebaseService.updateLiveAngle(
          exerciseName: 'Sit and Stand',
          angle: angle,
        );
      }
    }
  }

  void _checkRep(double angle) {
    // 0 = seated, 90 = standing
    // angle > 65 is "standing"; angle < 25 is "sitting".
    final bool isSitting = angle < 25;

    if (!widget.isStarted) {
      // Only notify parent when ready state actually changes.
      if (_lastReadyValue != isSitting) {
        _lastReadyValue = isSitting;
        if (!_pendingReadyCallback) {
          _pendingReadyCallback = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _pendingReadyCallback = false;
            if (mounted) widget.onReadyChanged(_lastReadyValue);
          });
        }
      }
      _state = _RepState.idle;
      _repStartTime = null;
      return;
    }

    final now = DateTime.now();

    if (_state == _RepState.idle) {
      if (!isSitting && angle > 30) {
        _state = _RepState.returning;
        _repStartTime = now;
        _maxAngleDuringRep = angle;
      }
    } else if (_state == _RepState.returning) {
      _maxAngleDuringRep = math.max(_maxAngleDuringRep, angle);

      if (_repStartTime != null &&
          now.difference(_repStartTime!).inSeconds >= 5) {
        _failRep();
        return;
      }

      if (isSitting) {
        if (_maxAngleDuringRep > 65) {
          _passRep();
        } else {
          _failRep();
        }
      }
    } else if (_state == _RepState.cooldown) {
      if (isSitting) {
        _state = _RepState.idle;
      }
    }
  }

  void _passRep() {
    _state = _RepState.cooldown;
    _repStartTime = null;
    if (_pendingRepCallback) return;
    _pendingRepCallback = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingRepCallback = false;
      if (mounted) widget.onRepPassed();
    });
  }

  void _failRep() {
    _state = _RepState.cooldown;
    _repStartTime = null;
    if (_pendingRepCallback) return;
    _pendingRepCallback = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _pendingRepCallback = false;
      if (mounted) widget.onRepFailed();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _smoothAngle,
      builder: (context, _) {
        return SitToStandVisualizer(angleDeg: _smoothAngle.value);
      },
    );
  }
}

// ============================================================================
// SitToStandVisualizer — CustomPaint based (no Positioned widget churn)
// ============================================================================
/// Real-time sit-to-stand visualizer driven by an IMU pitch angle on the THIGH.
///
/// * Seated    ≈  0° (thigh horizontal)
/// * Standing  ≈ 90° (thigh vertical)
class SitToStandVisualizer extends StatelessWidget {
  final double angleDeg;

  const SitToStandVisualizer({super.key, required this.angleDeg});

  // Geometry (kept here for computations passed to painter)
  static const double _cx = 38.0;
  static const double _kneeY = 200.0;
  static const double _thighLen = 62.0;

  double get _clampedAngle => angleDeg.clamp(-10.0, 105.0);
  double get _thighRad => (90.0 - _clampedAngle) * math.pi / 180.0;
  double get _hipX => _cx + _thighLen * math.sin(_thighRad);
  double get _hipY => _kneeY - _thighLen * math.cos(_thighRad);
  double get _progress => (angleDeg.clamp(0.0, 90.0) / 90.0).clamp(0.0, 1.0);

  String get _statusLabel {
    if (angleDeg < 25) return 'Sitting';
    if (angleDeg < 65) return 'Rising…';
    return 'Standing';
  }

  Color get _statusColor {
    if (angleDeg < 25) return AppColors.slate600;
    if (angleDeg < 65) return AppColors.primary;
    return const Color(0xFF16A34A);
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Angle + status ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                angleDeg.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slate900,
                  letterSpacing: -2,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '°',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate600,
                  height: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _statusLabel,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _statusColor,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),

          // ── Avatar + Stand Meter ──────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildAvatar(),
              const SizedBox(width: 20),
              _buildStandMeter(),
            ],
          ),
        ],
      ),
    );
  }

  // ── Avatar ─────────────────────────────────────────────────────────────────
  Widget _buildAvatar() {
    return RepaintBoundary(
      child: CustomPaint(
        size: const Size(140, 290),
        painter: _SitToStandPainter(
          angleDeg: angleDeg,
          thighRad: _thighRad,
          hipX: _hipX,
          hipY: _hipY,
        ),
      ),
    );
  }

  // ── Stand Meter ────────────────────────────────────────────────────────────
  Widget _buildStandMeter() {
    const double barH = 200.0;
    const double barW = 30.0;
    final Color fillColor = Color.lerp(
      const Color.from(alpha: 1, red: 0.949, green: 0.361, blue: 0.098),
      AppColors.green600,
      _progress,
    )!;
    final double filledH = barH * _progress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Stand\nMeter',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.slate600,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: barW,
          height: barH,
          decoration: BoxDecoration(
            color: AppColors.slate200,
            borderRadius: BorderRadius.circular(barW / 2),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                width: barW,
                height: filledH,
                decoration: BoxDecoration(
                  color: fillColor,
                  borderRadius: BorderRadius.circular(barW / 2),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${(_progress * 100).round()}%',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: fillColor,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// _SitToStandPainter — single canvas draw call per sensor packet
// ============================================================================
class _SitToStandPainter extends CustomPainter {
  final double angleDeg;
  final double thighRad;
  final double hipX;
  final double hipY;

  static const double _cx = 38.0;
  static const double _kneeY = 200.0;
  static const double _thighLen = 62.0;
  static const double _shankLen = 62.0;
  static const double _torsoLen = 70.0;
  static const double _headR = 13.0;
  static const double _limbW = 16.0;
  static const double _kneeR = 9.0;

  const _SitToStandPainter({
    required this.angleDeg,
    required this.thighRad,
    required this.hipX,
    required this.hipY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()..color = AppColors.slate400;
    final bodyPaint = Paint()..color = AppColors.slate600;
    final thighPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: 0.85),
              AppColors.primary,
            ],
          ).createShader(
            Rect.fromLTWH(
              _cx - _limbW / 2,
              _kneeY - _thighLen,
              _limbW,
              _thighLen,
            ),
          );
    final kneeFillPaint = Paint()..color = Colors.white;
    final kneeBorderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Floor line
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, _kneeY + _shankLen + 2, size.width, 3),
        const Radius.circular(2),
      ),
      Paint()..color = AppColors.slate400.withValues(alpha: 0.4),
    );

    // Shank (static vertical)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(_cx - _limbW / 2, _kneeY, _limbW, _shankLen),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      ),
      jointPaint,
    );

    // Thigh — rotate around bottom-center (knee pivot)
    canvas.save();
    canvas.translate(_cx, _kneeY);
    canvas.rotate(thighRad);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(-_limbW / 2, -_thighLen, _limbW, _thighLen),
        topLeft: const Radius.circular(8),
        topRight: const Radius.circular(8),
      ),
      thighPaint,
    );
    canvas.restore();

    // Knee cap (on top)
    canvas.drawCircle(Offset(_cx, _kneeY), _kneeR, kneeFillPaint);
    canvas.drawCircle(Offset(_cx, _kneeY), _kneeR, kneeBorderPaint);

    // Torso — follows hip position
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hipX - _limbW / 2, hipY - _torsoLen, _limbW, _torsoLen),
        const Radius.circular(8),
      ),
      bodyPaint,
    );

    // Head
    canvas.drawCircle(
      Offset(hipX, hipY - _torsoLen - _headR - 2),
      _headR,
      bodyPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SitToStandPainter old) =>
      old.angleDeg != angleDeg;
}
