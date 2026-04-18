import 'dart:async';
import 'package:flutter/material.dart';
import '../exercise_session_screen.dart';
import '../../theme/app_theme.dart';
import '../../services/ble_service.dart';
import '../../widgets/glass_card.dart';

// ============================================================================
// Marching Screen
// ============================================================================
// Exercise: Patient marches in place, alternately lifting each knee.
// An animated "foot" icon pulses left/right to cue which leg to lift.
// ============================================================================
class MarchingScreen extends StatelessWidget {
  const MarchingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExerciseShell(
      exerciseName: 'Marching',
      sensorBuilder: (onRepPassed, _, isStarted, __) =>
          _MarchingPanel(onRepPassed: onRepPassed, isStarted: isStarted),
    );
  }
}

class _MarchingPanel extends StatefulWidget {
  final VoidCallback onRepPassed;
  final bool isStarted;
  const _MarchingPanel({required this.onRepPassed, required this.isStarted});

  @override
  State<_MarchingPanel> createState() => _MarchingPanelState();
}

class _MarchingPanelState extends State<_MarchingPanel>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _lift;

  bool _rightActive = false;

  // Rep counting logic
  StreamSubscription<double>? _angleSub;
  bool _wasStanding = true;

  void _checkRep(double angle) {
    if (!widget.isStarted) return;

    // 90 = standing, 0 = thigh parallel to floor (lifted)
    final bool isStanding = angle > 65;
    final bool isLifted = angle < 25;

    if (_wasStanding && isLifted) {
      _wasStanding = false;
    } else if (!_wasStanding && isStanding) {
      _wasStanding = true;
      // Defer so we never call setState during a build frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onRepPassed();
      });
    }
  }

  @override
  void initState() {
    super.initState();

    _angleSub = BleService.instance.angleStream.listen((angle) {
      _checkRep(angle);
    });
    _ctrl =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 700),
        )..addStatusListener((status) {
          if (status == AnimationStatus.completed) {
            // Auto-switch leg after each up-down cycle
            setState(() => _rightActive = !_rightActive);
            _ctrl.forward(from: 0);
          }
        });

    _lift = Tween<double>(
      begin: 0,
      end: -28,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    _ctrl.forward();
  }

  @override
  void dispose() {
    _angleSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ExercisePanelCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Animated feet ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: _lift,
            builder: (_, __) {
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // Left foot
                  Transform.translate(
                    offset: Offset(0, _rightActive ? 0 : _lift.value),
                    child: _FootIcon(active: !_rightActive, flipped: false),
                  ),
                  const SizedBox(width: 32),
                  // Right foot
                  Transform.translate(
                    offset: Offset(0, _rightActive ? _lift.value : 0),
                    child: _FootIcon(active: _rightActive, flipped: true),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          // ── Active side label ──────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              _rightActive ? 'Right Leg' : 'Left Leg',
              key: ValueKey(_rightActive),
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: AppColors.slate900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lift your knee, then step down',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 16),
          _InstructionChip(
            text: 'March in place, alternating legs',
            icon: Icons.directions_walk,
          ),
        ],
      ),
    );
  }
}

class _FootIcon extends StatelessWidget {
  final bool active;
  final bool flipped;
  const _FootIcon({required this.active, required this.flipped});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: active
            ? AppColors.primary.withValues(alpha: 0.15)
            : AppColors.slate200.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? AppColors.primary : Colors.transparent,
          width: 2.5,
        ),
      ),
      child: Transform(
        alignment: Alignment.center,
        transform: flipped
            ? (Matrix4.identity()..scale(-1.0, 1.0))
            : Matrix4.identity(),
        child: Icon(
          Icons.directions_walk,
          size: 44,
          color: active ? AppColors.primary : AppColors.slate400,
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _ExercisePanelCard extends StatelessWidget {
  final Widget child;
  const _ExercisePanelCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return GlassCard(child: child);
  }
}

class _InstructionChip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _InstructionChip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
