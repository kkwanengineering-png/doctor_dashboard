import 'dart:async';
import 'package:flutter/material.dart';
import '../exercise_session_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';

// ============================================================================
// Single-leg Stance Screen
// ============================================================================
// Exercise: Patient stands on one leg for as long as possible.
// The panel shows a stopwatch counting up from 0 s. The patient (or
// therapist) presses Pass when the hold target (~10 s) is reached,
// or Fail if balance is lost. The timer resets automatically between reps.
// ============================================================================
class SingleLegStanceScreen extends StatelessWidget {
  const SingleLegStanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExerciseShell(
      exerciseName: 'Single-leg Stance',
      sensorBuilder: (onRepPassed, _, isStarted, __) =>
          _SingleLegPanel(onRepPassed: onRepPassed, isStarted: isStarted),
    );
  }
}

class _SingleLegPanel extends StatefulWidget {
  final VoidCallback onRepPassed;
  final bool isStarted;
  const _SingleLegPanel({required this.onRepPassed, required this.isStarted});

  @override
  State<_SingleLegPanel> createState() => _SingleLegPanelState();
}

class _SingleLegPanelState extends State<_SingleLegPanel> {
  static const int _targetSeconds = 10;

  Timer? _timer;
  int _elapsed = 0; // seconds
  bool _running = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    if (!widget.isStarted || _running) return;
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        _elapsed++;
        if (_elapsed == _targetSeconds) {
          widget.onRepPassed();
        }
      });
    });
  }

  void _stop() {
    _timer?.cancel();
    if (mounted) setState(() => _running = false);
  }

  void _reset() {
    _stop();
    setState(() => _elapsed = 0);
  }

  double get _progress => (_elapsed / _targetSeconds).clamp(0.0, 1.0);
  bool get _targetReached => _elapsed >= _targetSeconds;

  @override
  Widget build(BuildContext context) {
    return _ExercisePanelCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Which leg row ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegToggle(label: 'Left', selected: true),
              const SizedBox(width: 12),
              _LegToggle(label: 'Right', selected: false),
            ],
          ),
          const SizedBox(height: 20),

          // ── Ring timer ────────────────────────────────────────────────
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Background ring
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 12,
                    color: AppColors.slate200,
                  ),
                ),
                // Progress ring
                SizedBox.expand(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _progress),
                    duration: const Duration(milliseconds: 400),
                    builder: (_, v, __) => CircularProgressIndicator(
                      value: v,
                      strokeWidth: 12,
                      color: _targetReached
                          ? AppColors.green600
                          : AppColors.primary,
                      strokeCap: StrokeCap.round,
                    ),
                  ),
                ),
                // Elapsed time
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$_elapsed',
                      style: TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w900,
                        color: _targetReached
                            ? AppColors.green600
                            : AppColors.slate900,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                    Text(
                      's / ${_targetSeconds}s',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Target reached badge ───────────────────────────────────────
          AnimatedOpacity(
            opacity: _targetReached ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.green600.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: AppColors.green600),
                  SizedBox(width: 6),
                  Text(
                    'Rep passed! Reset to go again.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.green600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Control buttons ────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TimerButton(
                label: _running ? 'Pause' : 'Start',
                icon: _running ? Icons.pause : Icons.play_arrow,
                color: !widget.isStarted
                    ? AppColors.slate200
                    : (_running ? AppColors.slate600 : AppColors.primary),
                onTap: widget.isStarted ? (_running ? _stop : _start) : () {},
              ),
              const SizedBox(width: 12),
              _TimerButton(
                label: 'Reset',
                icon: Icons.refresh,
                color: widget.isStarted
                    ? AppColors.slate400
                    : AppColors.slate200,
                onTap: widget.isStarted ? _reset : () {},
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InstructionChip(
            text: 'Stand on one leg. Hold for 10 s.',
            icon: Icons.nordic_walking,
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _LegToggle extends StatelessWidget {
  final String label;
  final bool selected;
  const _LegToggle({required this.label, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.primary.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.slate200,
          width: 1.5,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: selected ? AppColors.primary : AppColors.slate400,
        ),
      ),
    );
  }
}

class _TimerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _TimerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
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
