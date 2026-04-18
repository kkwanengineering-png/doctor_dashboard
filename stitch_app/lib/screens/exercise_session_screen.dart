import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/firebase_service.dart';
import '../services/ble_service.dart';
import '../services/fall_detection_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/app_background.dart';

// ============================================================================
// ExerciseShell — reusable scaffold used by every per-exercise screen.
//
// Provides:
//   • Blob gradient background
//   • Glassmorphism header (back button + exercise name)
//   • BLE status bar (auto-connects by calling BleService.instance.startScan)
//   • Rep tracking (20 reps), segmented progress bar, Pass / Fail buttons
//   • Finish button → saves result via FirebaseService and pops true
//
// The caller supplies [sensorPanel] — a widget that appears above the rep
// section and is responsible for any exercise-specific sensor visualisation.
// ============================================================================
class ExerciseShell extends StatefulWidget {
  final String exerciseName;

  /// Builder placed between the header/BLE bar and the rep section.
  /// Typically a card containing a sensor visualisation, which can call
  /// [onRepPassed] or [onRepFailed] when the exercise's target is reached or failed.
  final Widget Function(
    VoidCallback onRepPassed,
    VoidCallback onRepFailed,
    bool isStarted,
    ValueChanged<bool> onReadyChanged,
  )?
  sensorBuilder;

  const ExerciseShell({
    super.key,
    required this.exerciseName,
    this.sensorBuilder,
  });

  @override
  State<ExerciseShell> createState() => _ExerciseShellState();
}

class _ExerciseShellState extends State<ExerciseShell> {
  bool _isStarted = false;
  bool _isReady = true;
  bool _isFallAlertShowing = false;
  StreamSubscription<FallDetectionResult>? _fallSubscription;
  StreamSubscription? _firebaseFellSub;
  FallDetectionResult? _latestFallResult;
  bool _hasFell = false;
  bool _didFall = false; // "Forever" flag for the session history
  bool _showDebugPanel = false;
  double _maxFallProbability = 0.0;

  // ── Angle sample collection (sent to Firestore for AI analysis) ──────────
  // Sampled from the BLE stream at ~5 Hz while the exercise is running.
  final List<double> _anglesSampled = [];
  DateTime _lastAngleSample = DateTime.fromMillisecondsSinceEpoch(0);

  // ── Timer ─────────────────────────────────────────────────────────────────
  Timer? _timer;
  final ValueNotifier<int> _secondsElapsed = ValueNotifier<int>(0);
  DateTime? _startTime;

  void _startTimer() {
    _timer?.cancel();
    _startTime = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _secondsElapsed.value++;
      _syncFirebase();
    });
  }

  void _onReadyChanged(bool ready) {
    if (_isReady != ready && mounted) {
      // Must schedule setState in case it's called during build by child
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isReady = ready);
      });
    }
  }

  // ── Rep tracking ──────────────────────────────────────────────────────────
  final List<bool> _repResults = [];
  static const int _totalReps = 20;

  int get _completedReps => _repResults.length;
  bool get _isComplete => _completedReps >= _totalReps;

  void _passRep() {
    if (!_isComplete) {
      setState(() => _repResults.add(true));
      _syncFirebase();
      if (_isComplete) _timer?.cancel();
    }
  }

  void _failRep() {
    if (!_isComplete) {
      setState(() => _repResults.add(false));
      _syncFirebase();
      if (_isComplete) _timer?.cancel();
    }
  }

  void _syncFirebase() {
    FirebaseService.saveExerciseResult(
      userId: 'User123',
      userName: 'Stitch User',
      exerciseName: widget.exerciseName,
      repResults: _repResults,
      startTime: _startTime ?? DateTime.now(),
      durationSeconds: _secondsElapsed.value,
      fell: _hasFell,
      didFall: _didFall,
      fallProbability: _maxFallProbability,
      angles: List<double>.from(_anglesSampled),
    );
  }

  // ── BLE ───────────────────────────────────────────────────────────────────
  BleConnectionState _bleState = BleConnectionState.idle;
  StreamSubscription<BleConnectionState>? _stateSub;

  @override
  void initState() {
    super.initState();
    _stateSub = BleService.instance.connectionStateStream.listen((s) {
      if (mounted) {
        setState(() => _bleState = s);
        // Sync connection status to Firebase
        FirebaseService.updateSensorStatus(
          exerciseName: widget.exerciseName,
          isConnected: s == BleConnectionState.connected,
        );
      }
    });

    // Sample angle data while exercise is running (~5 Hz) for Firestore history.
    BleService.instance.angleStream.listen((angle) {
      if (!_isStarted) return;
      final now = DateTime.now();
      if (now.difference(_lastAngleSample).inMilliseconds >= 200) {
        _lastAngleSample = now;
        _anglesSampled.add(double.parse(angle.toStringAsFixed(1)));
      }
    });

    _firebaseFellSub = FirebaseService.getFellStream(widget.exerciseName).listen((isFell) {
      if (mounted && !isFell && _hasFell) {
        setState(() {
          _hasFell = false;
          _maxFallProbability = 0.0;
        });
        debugPrint('Fall status reset by external source (Firebase)');
      }
    });

    _fallSubscription = BleService.instance.fallStream.listen((result) {
      setState(() {
        _latestFallResult = result;
        // Keep track of maximum probability seen in the current session
        if (result.probability > _maxFallProbability) {
          _maxFallProbability = result.probability;
        }
      });

      // ONLY trigger the Alert UI if this event was caused by an impact > 15
      if (result.isImpactTriggered && 
          result.probability > 0.8 && 
          mounted && 
          !_isFallAlertShowing) {
        _isFallAlertShowing = true;
        _hasFell = true;
        _didFall = true;

        FallDetectionService.analyzeFallData(
          context,
          BleService.instance.recentAccel,
          BleService.instance.recentGyro,
          BleService.instance.recentLinearAccel,
        ).then((_) {
          // After dismissal, we might want to keep the flag true for a few seconds
          // to prevent immediate re-triggering while the data is still in the window.
          Future.delayed(const Duration(seconds: 4), () {
            if (mounted) _isFallAlertShowing = false;
          });
        });
      }
    });

    // Defer scan to after the first frame so permission dialogs don't block
    // the initial layout/paint pass.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) BleService.instance.startScan();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _secondsElapsed.dispose();
    _stateSub?.cancel();
    _fallSubscription?.cancel();
    _firebaseFellSub?.cancel();
    // Mark as disconnected in Firebase before leaving
    FirebaseService.updateSensorStatus(
      exerciseName: widget.exerciseName,
      isConnected: false,
    );
    BleService.instance.disconnect();
    super.dispose();
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      body: Stack(
        children: [
          const AppBackground(type: BackgroundType.session),
          Column(
            children: [
              _buildGlassHeader(),
              _BleStatusBar(
                state: _bleState,
                secondsElapsed: _secondsElapsed,
                isStarted: _isStarted,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      // ── Scrollable: sensor panel + rep info ────────────
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(top: 16, bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (widget.sensorBuilder != null)
                                Stack(
                                  children: [
                                    widget.sensorBuilder!(
                                      _passRep,
                                      _failRep,
                                      _isStarted,
                                      _onReadyChanged,
                                    ),
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withValues(alpha: 0.05),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Text(
                                            '!',
                                            style: TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: AppColors.slate500,
                                            ),
                                          ),
                                          onPressed: () {
                                            setState(() => _showDebugPanel = true);
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 20),
                              const Text(
                                'Repetition',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.slate900,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _buildProgressBar(),
                              const SizedBox(height: 10),
                              Text(
                                '$_completedReps of $_totalReps',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.slate900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const SizedBox(height: 8),
                            ],
                          ),
                        ),
                      ),
                      // ── Buttons pinned at bottom ────────────────────────
                      if (!_isStarted)
                        _buildStartButton()
                      else if (_isComplete)
                        _buildFinishButton()
                      else
                        const SizedBox(
                          height: 68,
                        ), // Spacer to maintain bottom layout and avoid jumping
                      const SafeArea(top: false, child: SizedBox(height: 24)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_showDebugPanel && _latestFallResult != null) _buildFallDetectionDebugPanel(),
        ],
      ),
    );
  }

  Widget _buildFallDetectionDebugPanel() {
    final features = _latestFallResult!.features;
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'FALL MONITOR (Real-time)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        setState(() => _showDebugPanel = false);
                      },
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      'PROBABILITY: ',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    Text(
                      '${(_latestFallResult!.probability * 100).toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: _latestFallResult!.probability > 0.8 ? Colors.redAccent : Colors.greenAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const Divider(color: Colors.white24, height: 24),
                Wrap(
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    _debugItem('accMax', features['accMax']),
                    _debugItem('gyroMax', features['gyroMax']),
                    _debugItem('linMax', features['linMax']),
                    _debugItem('accKurt', features['accKurt']),
                    _debugItem('gyroKurt', features['gyroKurt']),
                    _debugItem('accSkew', features['accSkew']),
                    _debugItem('gyroSkew', features['gyroSkew']),
                    _debugItem('postLin', features['postLinMax']),
                    _debugItem('postGyro', features['postGyroMax']),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _debugItem(String label, double? value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey, fontSize: 8)),
        Text(
          value?.toStringAsFixed(2) ?? '0.00',
          style: TextStyle(color: Colors.white, fontSize: 10, fontFamily: 'monospace'),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildGlassHeader() {
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
          padding: const EdgeInsets.fromLTRB(16, 12, 24, 12),
          child: Row(
            children: [
              GlassButton(
                onPressed: () => Navigator.pop(context),
                width: 100,
                height: 48,
                borderRadius: 12,
                color: Colors.white.withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_ios_new,
                      size: 16,
                      color: AppColors.slate600,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Back',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.exerciseName.replaceAll('\n', ' '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress bar ──────────────────────────────────────────────────────────
  Widget _buildProgressBar() {
    return Container(
      width: double.infinity,
      height: 24,
      decoration: BoxDecoration(
        color: AppColors.slate200.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CustomPaint(
          painter: SegmentPainter(
            repResults: List.unmodifiable(_repResults),
            totalReps: _totalReps,
          ),
        ),
      ),
    );
  }

  // ── Start button ──────────────────────────────────────────────────────────
  Widget _buildStartButton() {
    final bool canStart = _isReady && _bleState == BleConnectionState.connected;

    return GlassButton(
      onPressed: canStart
          ? () {
              setState(() {
                _isStarted = true;
                _startTimer();
              });
            }
          : null,
      borderRadius: 16,
      height: 68,
      color: canStart
          ? AppColors.primary.withValues(alpha: 0.8)
          : AppColors.slate200.withValues(alpha: 0.5),
      boxShadow: canStart
          ? [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ]
          : null,
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.play_arrow, size: 28, color: Colors.white),
          SizedBox(width: 10),
          Text(
            'Start Exercise',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // ── Finish button ─────────────────────────────────────────────────────────
  Widget _buildFinishButton() {
    return GlassButton(
      onPressed: () async {
        // Final save with full session data — writes to both RTDB (live monitor)
        // and Firestore (session_history for AI clinical note generation).
        await FirebaseService.saveExerciseResult(
          userId: 'User123',
          userName: 'Stitch User',
          exerciseName: widget.exerciseName,
          repResults: _repResults,
          startTime: _startTime ?? DateTime.now(),
          durationSeconds: _secondsElapsed.value,
          fell: _hasFell,
          didFall: _didFall,
          fallProbability: _maxFallProbability,
          angles: List<double>.from(_anglesSampled),
        );
        if (mounted) Navigator.pop(context, true);
      },
      borderRadius: 16,
      height: 68,
      color: const Color(0xFFEAB308).withValues(alpha: 0.8),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFFEAB308).withValues(alpha: 0.3),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 28, color: Color(0xFF422006)),
          SizedBox(width: 10),
          Text(
            'Finish',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF422006),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BLE Status Bar
// ============================================================================
class _BleStatusBar extends StatelessWidget {
  final BleConnectionState state;
  final ValueNotifier<int> secondsElapsed;
  final bool isStarted;

  const _BleStatusBar({
    required this.state,
    required this.secondsElapsed,
    required this.isStarted,
  });

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      BleConnectionState.scanning => (
        'Scanning for sensor…',
        const Color(0xFFF59E0B),
      ),
      BleConnectionState.connecting => ('Connecting…', const Color(0xFF3B82F6)),
      BleConnectionState.connected => (
        'Sensor connected',
        const Color(0xFF16A34A),
      ),
      BleConnectionState.disconnected => (
        'Sensor disconnected',
        const Color(0xFFDC2626),
      ),
      BleConnectionState.error => (
        'BLE error — tap to retry',
        const Color(0xFFDC2626),
      ),
      BleConnectionState.idle => ('No sensor', const Color(0xFF94A3B8)),
    };

    return GestureDetector(
      onTap:
          (state == BleConnectionState.error ||
              state == BleConnectionState.disconnected ||
              state == BleConnectionState.idle)
          ? () => BleService.instance.startScan()
          : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        color: color.withValues(alpha: 0.1),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
            if (state == BleConnectionState.scanning ||
                state == BleConnectionState.connecting) ...[
              const SizedBox(width: 10),
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              ),
            ],
            // ── Timer Display ──────────────────────────────────────────────
            if (isStarted) ...[
              const Spacer(),
              ValueListenableBuilder<int>(
                valueListenable: secondsElapsed,
                builder: (_, secs, __) {
                  final minutes = secs ~/ 60;
                  final seconds = secs % 60;
                  final formatted =
                      '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatted,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ] else if (state == BleConnectionState.error ||
                state == BleConnectionState.disconnected) ...[
              const Spacer(),
              Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// LiveLegVisualizer — widget-based 2-D leg using Transform.rotate
// ============================================================================
/// Displays a vertical 2-D representation of a human leg.
///
/// * **Thigh** — static grey rounded rectangle (upper leg).
/// * **Knee joint** — small circular widget acting as a visual hinge.
/// * **Shank** — blue-gradient rounded rectangle wrapped in [Transform.rotate]
///   with [Alignment.topCenter] so it pivots from the knee, pendulum-style.
///
/// [angleDeg] is the live pitch angle in **degrees** from the IMU sensor.
class LiveLegVisualizer extends StatelessWidget {
  final double angleDeg;

  const LiveLegVisualizer({super.key, required this.angleDeg});

  static const double _thighWidth = 28;
  static const double _thighHeight = 110;
  static const double _kneeSize = 22;
  static const double _shankWidth = 26;
  static const double _shankHeight = 110;

  @override
  Widget build(BuildContext context) {
    final double angleRad = angleDeg * math.pi / 180;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Thigh (static) ───────────────────────────────────────────────
        Container(
          width: _thighWidth,
          height: _thighHeight,
          decoration: BoxDecoration(
            color: AppColors.slate400,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(2, 3),
              ),
            ],
          ),
        ),

        // ── Knee joint (hinge) ───────────────────────────────────────────
        Container(
          width: _kneeSize,
          height: _kneeSize,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.primary, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.30),
                blurRadius: 8,
              ),
            ],
          ),
        ),

        // ── Shank (rotates from top-centre pivot = knee joint) ───────────
        Transform.rotate(
          angle: angleRad,
          alignment: Alignment.topCenter,
          child: Container(
            width: _shankWidth,
            height: _shankHeight,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.70),
                ],
              ),
              borderRadius: BorderRadius.circular(13),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(2, 4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// Segment painter for rep progress bar  (now public so screens can reuse)
// ============================================================================
class SegmentPainter extends CustomPainter {
  final List<bool> repResults;
  final int totalReps;

  const SegmentPainter({required this.repResults, required this.totalReps});

  static const _green = Color(0xFF16A34A);
  static const _red = Color(0xFFDC2626);
  static const _gap = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (totalReps == 0) return;
    final segW = size.width / totalReps;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < repResults.length; i++) {
      paint.color = repResults[i] ? _green : _red;
      final left = i * segW + (i == 0 ? 0 : _gap / 2);
      final right = (i + 1) * segW - (i == totalReps - 1 ? 0 : _gap / 2);
      canvas.drawRect(Rect.fromLTRB(left, 0, right, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant SegmentPainter old) =>
      old.repResults.length != repResults.length;
}

// ============================================================================
// Blob background
// ============================================================================
// End of file. Local blob background removed.
