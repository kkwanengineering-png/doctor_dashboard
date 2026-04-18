import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../services/firebase_service.dart';
import '../exercise_session_screen.dart';
import '../../services/ble_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

// ============================================================================
// Seated Leg Extension Screen
// ============================================================================
class SeatedLegExtensionScreen extends StatelessWidget {
  const SeatedLegExtensionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExerciseShell(
      exerciseName: 'Seated Leg Extension',
      sensorBuilder: (onRepPassed, onRepFailed, isStarted, onReadyChanged) =>
          _LegExtensionPanel(
            onRepPassed: onRepPassed,
            onRepFailed: onRepFailed,
            isStarted: isStarted,
            onReadyChanged: onReadyChanged,
          ),
    );
  }
}

class _LegExtensionPanel extends StatefulWidget {
  final VoidCallback onRepPassed;
  final VoidCallback onRepFailed;
  final bool isStarted;
  final ValueChanged<bool> onReadyChanged;
  const _LegExtensionPanel({
    required this.onRepPassed,
    required this.onRepFailed,
    required this.isStarted,
    required this.onReadyChanged,
  });

  @override
  State<_LegExtensionPanel> createState() => _LegExtensionPanelState();
}

enum _RepState { idle, returning, cooldown }

class _LegExtensionPanelState extends State<_LegExtensionPanel>
    with SingleTickerProviderStateMixin {
  _RepState _state = _RepState.idle;
  DateTime? _repStartTime;
  double _minAngleDuringRep = 90.0;

  // ── Smooth animation ────────────────────────────────────────────────────
  // AnimationController runs at vsync (60-120 fps) and interpolates between
  // successive sensor readings. This produces butter-smooth motion even if
  // the BLE sensor only sends 60-100 packets/sec.
  late final AnimationController _controller;
  late Tween<double> _angleTween;
  late Animation<double> _smoothAngle;

  StreamSubscription<double>? _angleSub;

  // postFrameCallback storm guards
  bool _pendingRepCallback = false;
  bool _pendingReadyCallback = false;
  // last known ready state to avoid duplicate callbacks
  bool _lastReadyValue = true;

  // Firebase Angle Sync throttle: only sync the angle to the database
  // at most once every 100ms (10 Hz) to avoid flooding the network.
  DateTime _lastFirebaseAngleUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    );
    _angleTween = Tween<double>(begin: 90.0, end: 90.0);
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

  /// Called on every BLE packet. Rep logic runs at full sensor rate.
  /// The AnimationController handles vsync-driven interpolation to the display.
  void _onAngle(double angle) {
    _checkRep(angle);
    // Animate from current displayed value → new sensor reading.
    _angleTween.begin = _smoothAngle.value;
    _angleTween.end = angle;
    _controller.forward(from: 0.0);

    // Sync to Firebase if exercise is started and ≥100ms passed.
    if (widget.isStarted) {
      final now = DateTime.now();
      if (now.difference(_lastFirebaseAngleUpdate).inMilliseconds >= 20) {
        _lastFirebaseAngleUpdate = now;
        FirebaseService.updateLiveAngle(
          exerciseName: 'Seated Leg Extension',
          angle: angle,
        );
      }
    }
  }

  void _checkRep(double angle) {
    // 90 = resting (bent), 0 = fully extended
    // "Extended" is < 25, "Resting" is > 65.
    final bool isResting = angle > 65;

    if (!widget.isStarted) {
      // Only notify parent when ready state actually changes — not every packet.
      if (_lastReadyValue != isResting) {
        _lastReadyValue = isResting;
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
      if (!isResting && angle < 60) {
        // Started rep.
        _state = _RepState.returning;
        _repStartTime = now;
        _minAngleDuringRep = angle;
      }
    } else if (_state == _RepState.returning) {
      _minAngleDuringRep = math.min(_minAngleDuringRep, angle);

      // Check for timeout.
      if (_repStartTime != null &&
          now.difference(_repStartTime!).inSeconds >= 5) {
        _failRep();
        return;
      }

      if (isResting) {
        // Returned to resting. Did we reach extended target?
        if (_minAngleDuringRep < 25) {
          _passRep();
        } else {
          // Reversing direction mid-way (didn't reach target).
          _failRep();
        }
      }
    } else if (_state == _RepState.cooldown) {
      if (isResting) {
        _state = _RepState.idle;
      }
    }
  }

  void _passRep() {
    _state = _RepState.cooldown;
    _repStartTime = null;
    // Guard: if a callback is already queued, do NOT queue another one.
    // Without this, rapid oscillation causes a storm of stacked callbacks
    // that floods the scheduler and freezes the app.
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
    // AnimatedBuilder re-runs only on vsync ticks while the animation plays,
    // then goes idle — zero overhead between sensor updates.
    return AnimatedBuilder(
      animation: _smoothAngle,
      builder: (context, _) {
        return SeatedLegExtensionVisualizer(angleDeg: _smoothAngle.value);
      },
    );
  }
}

// ============================================================================
// SeatedLegExtensionVisualizer — CustomPaint based (no Positioned widget churn)
// ============================================================================
/// Real-time visualizer for seated knee extension.
/// Uses a single CustomPaint for the stick figure to eliminate widget-tree
/// churn at sensor frequency (~50 Hz).
class SeatedLegExtensionVisualizer extends StatelessWidget {
  final double angleDeg;

  const SeatedLegExtensionVisualizer({super.key, required this.angleDeg});

  // Extension progress: 0 % resting (90°) → 100 % extended (0°)
  double get _progress =>
      ((90.0 - angleDeg.clamp(0.0, 90.0)) / 90.0).clamp(0.0, 1.0);

  String get _statusLabel {
    if (angleDeg > 65) return 'Resting';
    if (angleDeg > 25) return 'Extending…';
    return 'Extended!';
  }

  Color get _statusColor {
    if (angleDeg > 65) return AppColors.slate600;
    if (angleDeg > 25) return AppColors.primary;
    return AppColors.green600;
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Angle + status ──────────────────────────────────────────────
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

          // ── CustomPaint figure + Extension Meter ────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RepaintBoundary(
                child: CustomPaint(
                  size: const Size(168, 212),
                  painter: _LegExtensionPainter(angleDeg: angleDeg),
                ),
              ),
              const SizedBox(width: 20),
              _buildExtensionMeter(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExtensionMeter() {
    const double barH = 200.0;
    const double barW = 30.0;
    final Color fillColor = Color.lerp(
      AppColors.primary,
      AppColors.green600,
      _progress,
    )!;
    final double filledH = barH * _progress;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Extension\nMeter',
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
// _LegExtensionPainter — draws the entire stick figure in one canvas pass
// ============================================================================
/// CustomPainter for the seated leg extension stick figure.
/// Single canvas draw call per frame — eliminates widget-tree diffing at 50 Hz.
class _LegExtensionPainter extends CustomPainter {
  final double angleDeg;

  _LegExtensionPainter({required this.angleDeg});

  static const double _kneeX = 90.0;
  static const double _kneeY = 128.0;
  static const double _thighLen = 60.0;
  static const double _shankLen = 65.0;
  static const double _torsoLen = 68.0;
  static const double _headR = 13.0;
  static const double _limbW = 16.0;
  static const double _kneeR = 9.0;
  static const double _hipX = _kneeX - _thighLen;
  static const double _hipY = _kneeY;

  double get _shankRad =>
      -(90.0 - angleDeg.clamp(-5.0, 100.0)) * math.pi / 180.0;

  RRect _rr(double l, double t, double w, double h, double r) =>
      RRect.fromRectAndRadius(Rect.fromLTWH(l, t, w, h), Radius.circular(r));

  @override
  void paint(Canvas canvas, Size size) {
    final jointPaint = Paint()..color = AppColors.slate400;
    final bodyPaint = Paint()..color = AppColors.slate600;
    final shinePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.primary, Color(0xFFB45309)],
      ).createShader(Rect.fromLTWH(_kneeX - _limbW / 2, _kneeY, _limbW, _shankLen));
    final kneeFillPaint = Paint()..color = Colors.white;
    final kneeBorderPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Chair seat
    canvas.drawRRect(
      _rr(_hipX - 10, _hipY + _limbW / 2, _thighLen + 20, 6, 3),
      Paint()..color = AppColors.slate400.withValues(alpha: 0.45),
    );

    // Chair back
    canvas.drawRRect(
      _rr(_hipX - 14, _hipY - _torsoLen - 10, 6, _torsoLen + 10, 3),
      Paint()..color = AppColors.slate400.withValues(alpha: 0.35),
    );

    // Torso
    canvas.drawRRect(
      _rr(_hipX - _limbW / 2, _hipY - _torsoLen, _limbW, _torsoLen, 8),
      bodyPaint,
    );

    // Head
    canvas.drawCircle(
      Offset(_hipX, _hipY - _torsoLen - _headR - 2),
      _headR,
      bodyPaint,
    );

    // Thigh (horizontal)
    canvas.drawRRect(
      _rr(_hipX, _kneeY - _limbW / 2, _thighLen, _limbW, 8),
      jointPaint,
    );

    // Shank — rotate around knee pivot
    canvas.save();
    canvas.translate(_kneeX, _kneeY);
    canvas.rotate(_shankRad);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(-_limbW / 2, 0, _limbW, _shankLen),
        bottomLeft: const Radius.circular(8),
        bottomRight: const Radius.circular(8),
      ),
      shinePaint,
    );
    canvas.restore();

    // Knee cap (drawn last so it's on top)
    canvas.drawCircle(Offset(_kneeX, _kneeY), _kneeR, kneeFillPaint);
    canvas.drawCircle(Offset(_kneeX, _kneeY), _kneeR, kneeBorderPaint);
  }

  @override
  bool shouldRepaint(covariant _LegExtensionPainter old) =>
      old.angleDeg != angleDeg;
}
