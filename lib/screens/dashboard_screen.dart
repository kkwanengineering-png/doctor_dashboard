import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../theme/app_theme.dart';
import '../services/ai_note_service.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ValueNotifier<String?> _selectedExerciseNotifier = ValueNotifier(null);
  final ValueNotifier<Map<String, bool>> _sensorStatusNotifier = ValueNotifier(
    {},
  );
  final List<StreamSubscription> _sidebarSubs = [];
  Timer? _throttleTimer;
  final Map<String, bool> _currentStatuses = {};

  // We define this here to set up targeted listeners that IGNORE high-frequency 'currentAngle'
  static const List<String> _trackedExercises = [
    "Sit and Stand",
    "Seated Leg Extension",
    "Marching",
    "Single-Leg Stance",
  ];

  @override
  void initState() {
    super.initState();
    final rootRef = FirebaseDatabase.instance.ref('exercise_sessions');

    for (final exercise in _trackedExercises) {
      final sub = rootRef
          .child(exercise)
          .child('sensorConnected')
          .onValue
          .listen((event) {
            final isConnected = event.snapshot.value == true;
            _updateThrottledStatus(exercise, isConnected);
          });
      _sidebarSubs.add(sub);
    }
  }

  void _updateThrottledStatus(String exercise, bool isConnected) {
    _currentStatuses[exercise] = isConnected;

    if (_throttleTimer == null) {
      _throttleTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted) {
          _sensorStatusNotifier.value = Map.from(_currentStatuses);
        }
        _throttleTimer = null;
      });
    }
  }

  @override
  void dispose() {
    _selectedExerciseNotifier.dispose();
    _sensorStatusNotifier.dispose();
    for (final sub in _sidebarSubs) {
      sub.cancel();
    }
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _DashboardHeader(),
                    const SizedBox(height: 32),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 1024) {
                          return _DesktopLayout(
                            selectedExerciseNotifier: _selectedExerciseNotifier,
                            sensorStatusNotifier: _sensorStatusNotifier,
                          );
                        } else {
                          return _MobileTabletLayout(
                            selectedExerciseNotifier: _selectedExerciseNotifier,
                            sensorStatusNotifier: _sensorStatusNotifier,
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    final today = DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now());
    return GlassCard(
      padding: const EdgeInsets.all(32.0),
      child: Stack(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Welcome, Dr. Smith',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B), // slate-800
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    today,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B), // slate-500
                    ),
                  ),
                ],
              ),
              PopupMenuButton<String>(
                offset: const Offset(0, 56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (value) async {
                  if (value == 'logout') {
                    await FirebaseAuth.instance.signOut();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, color: Colors.redAccent, size: 20),
                        SizedBox(width: 12),
                        Text(
                          'Logout',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.5),
                    border: Border.all(color: AppTheme.brandOrange, width: 2),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.person_outline,
                      color: AppTheme.brandOrange,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DesktopLayout extends StatelessWidget {
  final ValueNotifier<String?> selectedExerciseNotifier;
  final ValueNotifier<Map<String, bool>> sensorStatusNotifier;
  const _DesktopLayout({
    required this.selectedExerciseNotifier,
    required this.sensorStatusNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 8,
              child: _LiveSessionCard(
                selectedExerciseNotifier: selectedExerciseNotifier,
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              flex: 4,
              child: _ProgramCard(
                selectedExerciseNotifier: selectedExerciseNotifier,
                sensorStatusNotifier: sensorStatusNotifier,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SizedBox(height: 24),
        const _SystemStatusCard(),
        const SizedBox(height: 24),
        const _SessionHistoryCard(),
      ],
    );
  }
}

class _MobileTabletLayout extends StatelessWidget {
  final ValueNotifier<String?> selectedExerciseNotifier;
  final ValueNotifier<Map<String, bool>> sensorStatusNotifier;
  const _MobileTabletLayout({
    required this.selectedExerciseNotifier,
    required this.sensorStatusNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _LiveSessionCard(selectedExerciseNotifier: selectedExerciseNotifier),
        const SizedBox(height: 24),
        _ProgramCard(
          selectedExerciseNotifier: selectedExerciseNotifier,
          sensorStatusNotifier: sensorStatusNotifier,
        ),
        const SizedBox(height: 24),
        const _SystemStatusCard(),
        const SizedBox(height: 24),
        const _SessionHistoryCard(),
      ],
    );
  }
}

class _LiveSessionCard extends StatefulWidget {
  final ValueNotifier<String?> selectedExerciseNotifier;
  const _LiveSessionCard({required this.selectedExerciseNotifier});

  @override
  State<_LiveSessionCard> createState() => _LiveSessionCardState();
}

class _LiveSessionCardState extends State<_LiveSessionCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Tween<double> _angleTween;
  late Animation<double> _smoothAngle;
  String? _lastExercise;

  // Performance-optimized notifiers
  final ValueNotifier<bool> _isLiveNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int> _passRepsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _failRepsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> _durationNotifier = ValueNotifier<int>(0);
  final ValueNotifier<String> _exerciseNameNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _sensorConnectedNotifier = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<String?> _startTimeNotifier = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<String?> _endTimeNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<bool> _fellNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _didFallNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<double> _fallProbNotifier = ValueNotifier<double>(0.0);

  StreamSubscription? _subscription;
  StreamSubscription? _passRepsSub;
  StreamSubscription? _failRepsSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _sensorSub;
  StreamSubscription? _startTimeSub;
  StreamSubscription? _endTimeSub;
  StreamSubscription? _fellSub;
  StreamSubscription? _didFallSub;
  StreamSubscription? _fallProbSub;

  // Capture movement for history replay
  final List<double> _angleCapture = [];
  DateTime? _lastCaptureTime;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 150,
      ), // Smooth follow-through for live sensor data
    );
    _angleTween = Tween<double>(begin: 0.0, end: 0.0);
    _smoothAngle = _angleTween.animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ), // easeOut for natural deceleration
    );

    // Initial setup
    _setupSubscription(widget.selectedExerciseNotifier.value);

    // Listen for exercise changes
    widget.selectedExerciseNotifier.addListener(_onExerciseChanged);
  }

  void _onExerciseChanged() {
    _setupSubscription(widget.selectedExerciseNotifier.value);
  }

  void _setupSubscription(String? exercise) {
    _subscription?.cancel();
    _passRepsSub?.cancel();
    _failRepsSub?.cancel();
    _durationSub?.cancel();
    _sensorSub?.cancel();
    _startTimeSub?.cancel();
    _endTimeSub?.cancel();
    _fellSub?.cancel();
    _didFallSub?.cancel();
    _fallProbSub?.cancel();
    _exerciseNameNotifier.value = exercise ?? '';

    // Reset state for new session
    _angleCapture.clear();
    _lastCaptureTime = null;
    _startTimeNotifier.value = null;
    _endTimeNotifier.value = null;
    _fellNotifier.value = false;
    _didFallNotifier.value = false;
    _fallProbNotifier.value = 0.0;

    if (exercise == null) {
      _isLiveNotifier.value = false;
      return;
    }
    final baseRef = FirebaseDatabase.instance.ref(
      'exercise_sessions/$exercise',
    );

    // 1. Availability & Sensor Listener (Combined)
    // We listen to a grandchild to AVOID 50Hz rebuilds from 'currentAngle' sibling.
    _sensorSub = baseRef.child('sensorConnected').onValue.listen((event) {
      final snapshot = event.snapshot;
      final exists = snapshot.exists;
      final isConnected = snapshot.value == true;

      if (_isLiveNotifier.value != exists) {
        _isLiveNotifier.value = exists;
      }
      _sensorConnectedNotifier.value = isConnected;
    });

    // 2. Slow Metrics Listeners (Reps, Duration)
    // We listen to children individually to AVOID 50Hz rebuilds from 'currentAngle'
    _passRepsSub = baseRef.child('passCount').onValue.listen((event) {
      _passRepsNotifier.value = (event.snapshot.value as num?)?.toInt() ?? 0;
    });
    _failRepsSub = baseRef.child('failCount').onValue.listen((event) {
      _failRepsNotifier.value = (event.snapshot.value as num?)?.toInt() ?? 0;
    });
    _durationSub = baseRef.child('durationSeconds').onValue.listen((event) {
      _durationNotifier.value = (event.snapshot.value as num?)?.toInt() ?? 0;
    });

    _startTimeSub = baseRef.child('startTime').onValue.listen((event) {
      _startTimeNotifier.value = event.snapshot.value?.toString();
    });

    _endTimeSub = baseRef.child('endTime').onValue.listen((event) {
      _endTimeNotifier.value = event.snapshot.value?.toString();
    });

    _fellSub = baseRef.child('fell').onValue.listen((event) {
      _fellNotifier.value = event.snapshot.value == true;
    });

    _didFallSub = baseRef.child('didFall').onValue.listen((event) {
      _didFallNotifier.value = event.snapshot.value == true;
    });

    _fallProbSub = baseRef.child('fallProbability').onValue.listen((event) {
      final val = event.snapshot.value;
      if (val is num) {
        _fallProbNotifier.value = val.toDouble();
      } else {
        _fallProbNotifier.value = 0.0;
      }
    });

    // 4. High-Frequency Angle Listener (Exclusively Angle)
    _subscription = baseRef.child('currentAngle').onValue.listen((event) {
      final angleRaw = event.snapshot.value;
      if (angleRaw != null) {
        final double currentAngle = (angleRaw as num).toDouble();
        _updateSmoothing(currentAngle, _exerciseNameNotifier.value);

        // Record movement as soon as the timer is counting (durationSeconds > 0)
        if (_durationNotifier.value > 0) {
          final now = DateTime.now();
          if (_lastCaptureTime == null ||
              now.difference(_lastCaptureTime!).inMilliseconds >= 100) {
            _angleCapture.add(double.parse(currentAngle.toStringAsFixed(1)));
            _lastCaptureTime = now;
          }
        }
      }
    });
  }

  @override
  void dispose() {
    widget.selectedExerciseNotifier.removeListener(_onExerciseChanged);
    _subscription?.cancel();
    _passRepsSub?.cancel();
    _failRepsSub?.cancel();
    _durationSub?.cancel();
    _sensorSub?.cancel();
    _controller.dispose();
    _isLiveNotifier.dispose();
    _sensorConnectedNotifier.dispose();
    _passRepsNotifier.dispose();
    _failRepsNotifier.dispose();
    _durationNotifier.dispose();
    _exerciseNameNotifier.dispose();
    _startTimeNotifier.dispose();
    _endTimeNotifier.dispose();
    _fellNotifier.dispose();
    _didFallNotifier.dispose();
    _fallProbNotifier.dispose();
    super.dispose();
  }

  void _updateSmoothing(double newAngle, String? exercise) {
    if (_lastExercise != exercise) {
      _lastExercise = exercise;
      _angleTween.begin = newAngle;
      _angleTween.end = newAngle;
      _controller.value = 1.0;
    } else {
      if (_angleTween.end == newAngle && _controller.isAnimating) return;
      // Smooth interpolation to new target
      _angleTween.begin = _smoothAngle.value;
      _angleTween.end = newAngle;
      _controller.forward(from: 0.0);
    }
  }

  String _formatTime(int totalSeconds) {
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _archiveSession() async {
    final exercise = _exerciseNameNotifier.value;
    if (exercise.isEmpty) return;

    final data = {
      'exerciseName': exercise,
      'passCount': _passRepsNotifier.value,
      'failCount': _failRepsNotifier.value,
      'durationSeconds': _durationNotifier.value,
      'startTime': _startTimeNotifier.value,
      'endTime': _endTimeNotifier.value ?? DateTime.now().toIso8601String(),
      'timestamp': FieldValue.serverTimestamp(),
      'angles': List<double>.from(_angleCapture), // Copy the captured list
      'fell': _fellNotifier.value,
      'didFall': _didFallNotifier.value,
      'fallProbability': _fallProbNotifier.value,
    };

    try {
      debugPrint('Archiving session to Firestore: $data');
      await FirebaseFirestore.instance.collection('session_history').add(data);
      debugPrint('Session archived successfully');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Session for $exercise archived successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF059669), // Emerald-600
          ),
        );
      }
    } catch (e) {
      debugPrint('Error archiving session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to archive session: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _fellNotifier,
      builder: (context, hasFell, _) {
        return GlassCard(
          color: hasFell ? Colors.red.withValues(alpha: 0.15) : null,
          borderColor: hasFell ? Colors.redAccent : null,
          child: ValueListenableBuilder<String?>(
            valueListenable: widget.selectedExerciseNotifier,
        builder: (context, selectedExercise, _) {
          if (selectedExercise == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    size: 48,
                    color: Colors.grey.withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please Select Program',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _sensorConnectedNotifier,
                        builder: (context, isConnected, _) {
                          return Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: isConnected ? Colors.red : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      ValueListenableBuilder<bool>(
                        valueListenable: _sensorConnectedNotifier,
                        builder: (context, isConnected, _) {
                          return Text(
                            'LIVE',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: isConnected
                                  ? const Color(0xFF1E293B)
                                  : Colors.grey,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  OutlinedButton(
                    onPressed: _archiveSession,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.brandOrange,
                      side: BorderSide(
                        color: AppTheme.brandOrange.withValues(alpha: 0.3),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text(
                      'End Session',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 500;
                  return Flex(
                    direction: isWide ? Axis.horizontal : Axis.vertical,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isWide)
                        Expanded(flex: 1, child: _buildAnimatedFeed(isWide))
                      else
                        _buildAnimatedFeed(isWide),
                      SizedBox(width: isWide ? 24 : 0, height: isWide ? 0 : 24),
                      if (isWide)
                        Expanded(flex: 1, child: _buildSessionDataView())
                      else
                        _buildSessionDataView(),
                    ],
                  );
                },
              ),
              ],
            );
          },
        ),
        );
      },
    );
  }

  Widget _buildAnimatedFeed(bool isWide) {
    return _buildCameraFeed(isWide);
  }

  Widget _buildSessionDataView() {
    return ValueListenableBuilder<bool>(
      valueListenable: _fellNotifier,
      builder: (context, hasFell, _) {
        return _buildSessionData(
          exerciseNameNotifier: _exerciseNameNotifier,
          passRepsNotifier: _passRepsNotifier,
          failRepsNotifier: _failRepsNotifier,
          durationNotifier: _durationNotifier,
          patientName: 'Lee Kwan Huai',
          hasFell: hasFell,
        );
      },
    );
  }

  Widget _buildCameraFeed(bool isWide) {
    return Container(
      height: isWide ? 400 : 350,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Stack(
        children: [
          // The Visualizer (Passes the animation directly)
          ValueListenableBuilder<String>(
            valueListenable: _exerciseNameNotifier,
            builder: (context, name, _) {
              return Positioned.fill(
                child: RepaintBoundary(
                  child: _getVisualizerForExercise(name, _smoothAngle),
                ),
              );
            },
          ),

          // Top Overlay (Angle & Live)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Angle Text - Minimal rebuild scope
                AnimatedBuilder(
                  animation: _smoothAngle,
                  builder: (context, _) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Angle: ${_smoothAngle.value.toStringAsFixed(1)}°",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getVisualizerForExercise(
    String name,
    Animation<double> angleAnimation,
  ) {
    if (name == 'Sit and Stand') {
      return SitToStandVisualizer(angleAnimation: angleAnimation);
    } else if (name == 'Seated Leg Extension') {
      return SeatedLegExtensionVisualizer(angleAnimation: angleAnimation);
    } else {
      return Center(
        child: Text(
          "Visualization for $name\nComing Soon",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }
  }

  Widget _buildSessionData({
    required ValueNotifier<String> exerciseNameNotifier,
    required ValueNotifier<int> passRepsNotifier,
    required ValueNotifier<int> failRepsNotifier,
    required ValueNotifier<int> durationNotifier,
    required String patientName,
    bool hasFell = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'PATIENT',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
            letterSpacing: 1.5,
          ),
        ),
        Text(
          patientName,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: exerciseNameNotifier,
              builder: (context, name, _) => Text(
                name,
                style: const TextStyle(
                  color: AppTheme.brandOrange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<int>(
              valueListenable: durationNotifier,
              builder: (context, seconds, _) => Text(
                _formatTime(seconds),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: passRepsNotifier,
                builder: (context, reps, _) => _StatBox(
                  label: 'Pass Reps',
                  value: reps.toString(),
                  valueColor: Colors.green,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: failRepsNotifier,
                builder: (context, reps, _) => _StatBox(
                  label: 'Fail Reps',
                  value: reps.toString(),
                  valueColor: Colors.red,
                ),
              ),
            ),
          ],
        ),
        if (hasFell) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                    SizedBox(width: 8),
                    Text(
                      'FALL DETECTED!',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Contact the patient immediately to ensure patient is ok.',
                  style: TextStyle(color: Colors.redAccent, fontSize: 14),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    final exercise = exerciseNameNotifier.value;
                    if (exercise.isNotEmpty) {
                      FirebaseDatabase.instance
                          .ref('exercise_sessions/$exercise/fell')
                          .set(false);
                      FirebaseDatabase.instance
                          .ref('exercise_sessions/$exercise/fallProbability')
                          .set(0.0);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Okay'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _StatBox({
    required this.label,
    required this.value,
    this.valueColor = AppTheme.brandOrange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends StatelessWidget {
  final ValueNotifier<String?> selectedExerciseNotifier;
  final ValueNotifier<Map<String, bool>> sensorStatusNotifier;
  const _ProgramCard({
    required this.selectedExerciseNotifier,
    required this.sensorStatusNotifier,
  });

  static const List<String> _programExercises = [
    "Sit and Stand",
    "Seated Leg Extension",
    "Marching",
    "Single-Leg Stance",
  ];

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.assignment_outlined, color: AppTheme.brandOrange),
              SizedBox(width: 8),
              Text(
                'Program',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<String?>(
            valueListenable: selectedExerciseNotifier,
            builder: (context, selectedExercise, _) {
              return ValueListenableBuilder<Map<String, bool>>(
                valueListenable: sensorStatusNotifier,
                builder: (context, sensorStatusMap, _) {
                  return RepaintBoundary(
                    child: Column(
                      children: _programExercises.map((exercise) {
                        final bool isLive = sensorStatusMap[exercise] ?? false;
                        final bool isSelected = (exercise == selectedExercise);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildProgramItem(
                            exercise,
                            isLive,
                            isSelected,
                          ),
                        );
                      }).toList(),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProgramItem(String name, bool isLive, bool isSelected) {
    return InkWell(
      onTap: () {
        selectedExerciseNotifier.value = name;
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.brandOrange.withValues(alpha: 0.1)
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.brandOrange.withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isSelected
                    ? AppTheme.brandOrange
                    : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isLive ? Colors.red : Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'LIVE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isLive
                        ? Colors.red.withValues(alpha: 0.8)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SystemStatusCard extends StatelessWidget {
  const _SystemStatusCard();
  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 600;
          return Flex(
            direction: isMobile ? Axis.vertical : Axis.horizontal,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: isMobile
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.wifi,
                      color: Colors.green,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BLE Sensor Status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Connected - IMU Sensor 01',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (isMobile) const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                mainAxisSize: isMobile ? MainAxisSize.max : MainAxisSize.min,
                children: [
                  _buildStatusMetric('BATTERY', '98%', true),
                  const SizedBox(width: 32),
                  _buildStatusMetric(
                    'SIGNAL',
                    'Strong',
                    false,
                  ), // Could build bars here
                  const SizedBox(width: 32),
                  if (!isMobile) _buildStatusMetric('LATENCY', '12ms', false),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatusMetric(String label, String value, bool isBattery) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF94A3B8),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            if (isBattery) ...[
              const SizedBox(width: 8),
              Container(
                width: 24,
                height: 12,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF94A3B8)),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.98,
                  child: Container(color: Colors.green),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// --- Exercise Visualization Components ---
// ============================================================================

class SeatedLegExtensionVisualizer extends StatelessWidget {
  final ValueListenable<double> angleAnimation;
  const SeatedLegExtensionVisualizer({super.key, required this.angleAnimation});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _LegExtensionPainter(angleAnimation: angleAnimation),
              size: Size.infinite,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20, top: 40, bottom: 40),
          child: AnimatedBuilder(
            animation: angleAnimation,
            builder: (context, _) {
              final double progress =
                  (angleAnimation.value.clamp(0.0, 90.0)) / 90.0;
              return _MeterPainterWidget(
                label: "Extension",
                progress: progress,
                meterHeight: 200,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MeterPainterWidget extends StatelessWidget {
  final String label;
  final double progress;
  final double meterHeight;

  const _MeterPainterWidget({
    required this.label,
    required this.progress,
    required this.meterHeight,
  });

  @override
  Widget build(BuildContext context) {
    final Color fillColor = Color.lerp(
      const Color(0xFFF25C19),
      const Color(0xFF16A34A),
      progress,
    )!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Color(0xFF64748B),
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        RepaintBoundary(
          child: CustomPaint(
            size: Size(24, meterHeight),
            painter: _MeterPainter(progress: progress, fillColor: fillColor),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "${(progress * 100).round()}%",
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: fillColor,
          ),
        ),
      ],
    );
  }
}

class _MeterPainter extends CustomPainter {
  final double progress;
  final Color fillColor;

  _MeterPainter({required this.progress, required this.fillColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.1);
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(rrect, paint);

    final fillPaint = Paint()..color = fillColor;
    final fillHeight = size.height * progress.clamp(0.0, 1.0);
    final fillRect = Rect.fromLTWH(
      0,
      size.height - fillHeight,
      size.width,
      fillHeight,
    );
    final fillRRect = RRect.fromRectAndRadius(
      fillRect,
      const Radius.circular(12),
    );
    canvas.drawRRect(fillRRect, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _MeterPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.fillColor != fillColor;
}

class _LegExtensionPainter extends CustomPainter {
  final ValueListenable<double> angleAnimation;
  _LegExtensionPainter({required this.angleAnimation})
    : _jointPaint = Paint()..color = const Color(0xFF94A3B8),
      _bodyPaint = Paint()..color = const Color(0xFF475569),
      _kneeFillPaint = Paint()..color = Colors.white,
      _kneeBorderPaint = Paint()
        ..color = const Color(0xFFF25C19)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
      _shinePaint = Paint()..color = const Color(0xFFF25C19),
      _shadowPaint = Paint()..color = const Color(0x2694A3B8),
      super(repaint: angleAnimation);

  final Paint _jointPaint;
  final Paint _bodyPaint;
  final Paint _kneeFillPaint;
  final Paint _kneeBorderPaint;
  final Paint _shinePaint;
  final Paint _shadowPaint;

  static const double _kneeX = 120.0;
  static const double _kneeY = 240.0;
  static const double _thighLen = 70.0;
  static const double _shankLen = 75.0;
  static const double _torsoLen = 80.0;
  static const double _headR = 15.0;
  static const double _limbW = 18.0;
  static const double _kneeR = 10.0;
  static const double _hipX = _kneeX - _thighLen;
  static const double _hipY = _kneeY;

  double get _shankRad =>
      -(90.0 - angleAnimation.value.clamp(-5.0, 100.0)) * math.pi / 180.0;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Centering logic: Figure center X is ~85, center Y is ~220.5
    canvas.translate(size.width / 2 + 85, size.height / 2 - 220.5);
    canvas.scale(-1, 1);

    // Chair represention
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_hipX - 20, _hipY + 8, _thighLen + 40, 8),
        const Radius.circular(4),
      ),
      _shadowPaint,
    );

    // Torso
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_hipX - _limbW / 2, _hipY - _torsoLen, _limbW, _torsoLen),
        const Radius.circular(10),
      ),
      _bodyPaint,
    );

    // Head
    canvas.drawCircle(
      Offset(_hipX, _hipY - _torsoLen - _headR - 4),
      _headR,
      _bodyPaint,
    );

    // Thigh (horizontal)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(_hipX, _kneeY - _limbW / 2, _thighLen, _limbW),
        const Radius.circular(10),
      ),
      _jointPaint,
    );

    // Shank — rotate around knee pivot
    canvas.save();
    canvas.translate(_kneeX, _kneeY);
    canvas.rotate(_shankRad);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(-_limbW / 2, 0, _limbW, _shankLen),
        bottomLeft: const Radius.circular(10),
        bottomRight: const Radius.circular(10),
      ),
      _shinePaint,
    );
    canvas.restore();

    // Knee cap (on top)
    canvas.drawCircle(Offset(_kneeX, _kneeY), _kneeR, _kneeFillPaint);
    canvas.drawCircle(Offset(_kneeX, _kneeY), _kneeR, _kneeBorderPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LegExtensionPainter old) =>
      old.angleAnimation.value != angleAnimation.value;
}

class SitToStandVisualizer extends StatelessWidget {
  final ValueListenable<double> angleAnimation;
  const SitToStandVisualizer({super.key, required this.angleAnimation});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _SitToStandPainter(angleAnimation: angleAnimation),
              size: Size.infinite,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 20, top: 40, bottom: 40),
          child: AnimatedBuilder(
            animation: angleAnimation,
            builder: (context, _) {
              final double progress =
                  (angleAnimation.value.clamp(0.0, 90.0)) / 90.0;
              return _MeterPainterWidget(
                label: "Stand",
                progress: progress,
                meterHeight: 200,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SitToStandPainter extends CustomPainter {
  final ValueListenable<double> angleAnimation;

  _SitToStandPainter({required this.angleAnimation})
    : _jointPaint = Paint()..color = const Color(0xFF94A3B8),
      _bodyPaint = Paint()..color = const Color(0xFF475569),
      _kneeFillPaint = Paint()..color = Colors.white,
      _kneeBorderPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0,
      _thighPaint = Paint(),
      _floorPaint = Paint()
        ..color = const Color(0x3394A3B8), // 0xFF94A3B8 at ~20% alpha
      super(repaint: angleAnimation);

  final Paint _jointPaint;
  final Paint _bodyPaint;
  final Paint _kneeFillPaint;
  final Paint _kneeBorderPaint;
  final Paint _thighPaint;
  final Paint _floorPaint;
  Shader? _cachedShader;

  static const double _kneeY = 240.0;
  static const double _cx = 100.0;
  static const double _thighLen = 70.0;
  static const double _shankLen = 70.0;
  static const double _torsoLen = 85.0;
  static const double _headR = 15.0;
  static const double _limbW = 18.0;
  static const double _kneeR = 10.0;

  @override
  void paint(Canvas canvas, Size size) {
    final double angleDeg = angleAnimation.value;
    final double thighRad =
        -(90.0 - angleDeg.clamp(0.0, 95.0)) * math.pi / 180.0;
    final double hipX = _cx + _thighLen * math.sin(thighRad);
    final double hipY = _kneeY - _thighLen * math.cos(thighRad);

    canvas.save();
    // Centering logic: Figure center X is ~65, center Y is ~187.5
    canvas.translate(size.width / 2 + 65, size.height / 2 - 187.5);
    canvas.scale(-1, 1);

    _cachedShader ??=
        const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF25C19), Color(0xFFB45309)],
        ).createShader(
          Rect.fromLTWH(
            _cx - _limbW / 2,
            _kneeY - _thighLen,
            _limbW,
            _thighLen,
          ),
        );

    _thighPaint.shader = _cachedShader;

    // Floor line
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, _kneeY + _shankLen + 2, 160, 4),
        const Radius.circular(2),
      ),
      _floorPaint,
    );

    // Shank (static vertical)
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(_cx - _limbW / 2, _kneeY, _limbW, _shankLen),
        bottomLeft: const Radius.circular(10),
        bottomRight: const Radius.circular(10),
      ),
      _jointPaint,
    );

    // Thigh — rotate around knee pivot
    canvas.save();
    canvas.translate(_cx, _kneeY);
    canvas.rotate(thighRad);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(-_limbW / 2, -_thighLen, _limbW, _thighLen),
        topLeft: const Radius.circular(10),
        topRight: const Radius.circular(10),
      ),
      _thighPaint,
    );
    canvas.restore();

    // Knee cap
    canvas.drawCircle(Offset(_cx, _kneeY), _kneeR, _kneeFillPaint);
    canvas.drawCircle(Offset(_cx, _kneeY), _kneeR, _kneeBorderPaint);

    // Torso — follows hip position
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(hipX - _limbW / 2, hipY - _torsoLen, _limbW, _torsoLen),
        const Radius.circular(10),
      ),
      _bodyPaint,
    );

    // Head
    canvas.drawCircle(
      Offset(hipX, hipY - _torsoLen - _headR - 4),
      _headR,
      _bodyPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SitToStandPainter old) =>
      old.angleAnimation.value != angleAnimation.value;
}

class _SessionHistoryCard extends StatelessWidget {
  const _SessionHistoryCard();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Recent Session History',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.history, size: 18),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.brandOrange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('session_history')
                .orderBy('timestamp', descending: true)
                .limit(5)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint('Firestore Stream Error: ${snapshot.error}');
                return Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Unable to load history: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              final docs = snapshot.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32.0),
                    child: Text(
                      'No session history found.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 32),
                itemBuilder: (context, index) {
                  final session = docs[index].data() as Map<String, dynamic>;
                  final timestamp = session['timestamp'] as Timestamp?;
                  final dateStr = timestamp != null
                      ? DateFormat('MMM d, h:mm a').format(timestamp.toDate())
                      : 'Unknown Date';

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              SessionDetailScreen(session: session),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.brandOrange.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              _getExerciseIcon(session['exerciseName'] as String?),
                              color: AppTheme.brandOrange,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session['exerciseName'] ?? 'Exercise',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.black.withValues(alpha: 0.4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildStatItem(
                            'Pass',
                            '${session['passCount'] ?? 0}',
                            const Color(0xFF059669), // Emerald-600
                          ),
                          const SizedBox(width: 24),
                          _buildStatItem(
                            'Fail',
                            '${session['failCount'] ?? 0}',
                            Colors.redAccent,
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right,
                            color: Colors.black.withValues(alpha: 0.2),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.black.withValues(alpha: 0.3),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  IconData _getExerciseIcon(String? exerciseName) {
    if (exerciseName == 'Sit and Stand') {
      return Icons.accessibility_new;
    } else if (exerciseName == 'Seated Leg Extension') {
      return Icons.airline_seat_legroom_extra;
    }
    return Icons.fitness_center;
  }
}

class SessionDetailScreen extends StatefulWidget {
  final Map<String, dynamic> session;

  const SessionDetailScreen({super.key, required this.session});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen>
    with SingleTickerProviderStateMixin {
  late final List<double> _angles;
  final ValueNotifier<int> _currentFrameNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isPlayingNotifier = ValueNotifier<bool>(false);

  late final AnimationController _animationController;
  late final ValueNotifier<double> _playbackAngleNotifier;

  List<Map<String, dynamic>> _pastSessions = [];
  Map<String, dynamic>? _selectedCompareSession;
  List<double>? _compareAngles;
  late final ValueNotifier<double> _comparePlaybackAngleNotifier;

  @override
  void initState() {
    super.initState();
    _angles =
        (widget.session['angles'] as List<dynamic>?)
            ?.map((e) => (e as num).toDouble())
            .toList() ??
        [];

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _playbackAngleNotifier = ValueNotifier<double>(
      _angles.isNotEmpty ? _angles[0] : 0.0,
    );

    _comparePlaybackAngleNotifier = ValueNotifier<double>(0.0);

    final exerciseName = widget.session['exerciseName'] as String?;
    if (exerciseName != null) {
      _fetchCompareOptions(exerciseName);
    }

    // Add listener to update the playback angle during animation
    _animationController.addListener(() {
      if (_currentFrameNotifier.value < _angles.length - 1) {
        final double startAngle = _angles[_currentFrameNotifier.value];
        final double endAngle = _angles[_currentFrameNotifier.value + 1];
        _playbackAngleNotifier.value =
            ui.lerpDouble(startAngle, endAngle, _animationController.value) ??
            startAngle;
      } else if (_angles.isNotEmpty) {
        _playbackAngleNotifier.value = _angles.last;
      }

      if (_compareAngles != null && _compareAngles!.isNotEmpty) {
        if (_currentFrameNotifier.value < _compareAngles!.length - 1) {
          final double cStartAngle =
              _compareAngles![_currentFrameNotifier.value];
          final double cEndAngle =
              _compareAngles![_currentFrameNotifier.value + 1];
          _comparePlaybackAngleNotifier.value =
              ui.lerpDouble(
                cStartAngle,
                cEndAngle,
                _animationController.value,
              ) ??
              cStartAngle;
        } else {
          _comparePlaybackAngleNotifier.value = _compareAngles!.last;
        }
      }
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isPlayingNotifier.value) {
        if (_currentFrameNotifier.value < _maxFrames - 1) {
          _currentFrameNotifier.value++;
          if (_currentFrameNotifier.value < _maxFrames - 1) {
            _animationController.forward(from: 0.0);
          } else {
            _isPlayingNotifier.value = false;
          }
        }
      }
    });
  }

  Future<void> _fetchCompareOptions(String exercise) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('session_history')
          .where('exerciseName', isEqualTo: exercise)
          .orderBy('timestamp', descending: true)
          .limit(6)
          .get();

      if (mounted) {
        setState(() {
          final currentTimestamp = widget.session['timestamp'] as Timestamp?;
          _pastSessions = querySnapshot.docs
              .map((doc) => doc.data())
              .where((data) {
                final t = data['timestamp'] as Timestamp?;
                if (currentTimestamp != null && t != null) {
                  return t.microsecondsSinceEpoch !=
                      currentTimestamp.microsecondsSinceEpoch;
                }
                return true;
              })
              .take(5)
              .toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching compare options: $e');
    }
  }

  @override
  void dispose() {
    _currentFrameNotifier.dispose();
    _isPlayingNotifier.dispose();
    _animationController.dispose();
    _playbackAngleNotifier.dispose();
    _comparePlaybackAngleNotifier.dispose();
    super.dispose();
  }

  void _togglePlayback() {
    if (_isPlayingNotifier.value) {
      _animationController.stop();
      _isPlayingNotifier.value = false;
    } else {
      if (_currentFrameNotifier.value >= _maxFrames - 1) {
        _currentFrameNotifier.value = 0;
        _animationController.reset();
      }
      _isPlayingNotifier.value = true;
      _animationController.forward(
        from: _animationController.value == 1.0
            ? 0.0
            : _animationController.value,
      );
    }
  }

  int get _maxFrames {
    final caLen = _compareAngles?.length ?? 0;
    return _angles.length > caLen ? _angles.length : caLen;
  }

  void _resetPlayback() {
    _animationController.stop();
    _animationController.reset();
    _isPlayingNotifier.value = false;
    _currentFrameNotifier.value = 0;
    if (_angles.isNotEmpty) {
      _playbackAngleNotifier.value = _angles[0];
    }
    if (_compareAngles != null && _compareAngles!.isNotEmpty) {
      _comparePlaybackAngleNotifier.value = _compareAngles![0];
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final timestamp = session['timestamp'] as Timestamp?;
    final dateStr = timestamp != null
        ? DateFormat('EEEE, MMMM d, y • h:mm a').format(timestamp.toDate())
        : 'Unknown Date';

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Back Button & Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () => Navigator.pop(context),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_ios_new,
                                size: 20,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  session['exerciseName'] ?? 'Session Details',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_pastSessions.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Compare with:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black.withValues(alpha: 0.4),
                              ),
                            ),
                            DropdownButton<Map<String, dynamic>>(
                              value: _selectedCompareSession,
                              hint: const Text(
                                'Select historical session',
                                style: TextStyle(fontSize: 14),
                              ),
                              isDense: true,
                              underline: const SizedBox(),
                              items: _pastSessions.map((pastSession) {
                                final pTimestamp =
                                    pastSession['timestamp'] as Timestamp?;
                                final pDateStr = pTimestamp != null
                                    ? DateFormat(
                                        'MMM d, h:mm a',
                                      ).format(pTimestamp.toDate())
                                    : 'Unknown';
                                return DropdownMenuItem(
                                  value: pastSession,
                                  child: Text(
                                    '$pDateStr (Pass: ${pastSession['passCount']})',
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCompareSession = val;
                                  if (val != null && val['angles'] != null) {
                                    _compareAngles = (val['angles'] as List)
                                        .map((e) => (e as num).toDouble())
                                        .toList();
                                  } else {
                                    _compareAngles = null;
                                  }
                                  _resetPlayback(); // Reset to sync ghost playback
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 48),

                // Stats Overview
                Row(
                  children: [
                    Expanded(
                      child: _buildDetailStat(
                        'Total Duration',
                        session['durationSeconds'] != null
                            ? '${session['durationSeconds']}s'
                            : '0s',
                        Icons.timer_outlined,
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDetailStat(
                        'Successful Reps',
                        '${session['passCount'] ?? 0}',
                        Icons.check_circle_outline,
                        color: const Color(0xFF059669),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildDetailStat(
                        'Failed Reps',
                        '${session['failCount'] ?? 0}',
                        Icons.cancel_outlined,
                        color: Colors.redAccent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 48),

                // Visualizer and Graph Section
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isLargeSource = constraints.maxWidth > 1000;
                    return Column(
                      children: [
                        if (isLargeSource)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 5, child: _buildPlaybackCard()),
                              const SizedBox(width: 32),
                              Expanded(flex: 7, child: _buildGraphCard()),
                            ],
                          )
                        else ...[
                          _buildPlaybackCard(),
                          const SizedBox(height: 32),
                          _buildGraphCard(),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 32),

                // AI Clinical Summary
                _ClinicalNoteCard(session: session),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackCard() {
    final exerciseName = widget.session['exerciseName'] ?? '';
    Widget primaryVisualizer;
    Widget? ghostVisualizer;

    if (exerciseName == "Seated Leg Extension") {
      primaryVisualizer = SeatedLegExtensionVisualizer(
        angleAnimation: _playbackAngleNotifier,
      );
      if (_compareAngles != null) {
        ghostVisualizer = SeatedLegExtensionVisualizer(
          angleAnimation: _comparePlaybackAngleNotifier,
        );
      }
    } else if (exerciseName == "Sit and Stand") {
      primaryVisualizer = SitToStandVisualizer(
        angleAnimation: _playbackAngleNotifier,
      );
      if (_compareAngles != null) {
        ghostVisualizer = SitToStandVisualizer(
          angleAnimation: _comparePlaybackAngleNotifier,
        );
      }
    } else {
      primaryVisualizer = Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 48,
              color: Colors.black.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 16),
            const Text('No visualizer for this exercise'),
          ],
        ),
      );
    }

    Widget visualizerStack = primaryVisualizer;
    if (ghostVisualizer != null) {
      visualizerStack = Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.4,
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  Colors.grey,
                  BlendMode.srcIn,
                ),
                child: ghostVisualizer,
              ),
            ),
          ),
          Positioned.fill(child: primaryVisualizer),
        ],
      );
    }

    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Performance Playback',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              Row(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _isPlayingNotifier,
                    builder: (context, isPlaying, _) {
                      return InkWell(
                        onTap: _togglePlayback,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.brandOrange.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isPlaying ? Icons.pause : Icons.play_arrow,
                            color: AppTheme.brandOrange,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),
                  InkWell(
                    onTap: _resetPlayback,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.refresh, size: 20),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          Container(
            height: 380,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: visualizerStack,
          ),
          const SizedBox(height: 24),
          ValueListenableBuilder<int>(
            valueListenable: _currentFrameNotifier,
            builder: (context, frame, _) {
              return Column(
                children: [
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: AppTheme.brandOrange,
                      inactiveTrackColor: Colors.black.withValues(alpha: 0.05),
                      thumbColor: AppTheme.brandOrange,
                      overlayColor: AppTheme.brandOrange.withValues(alpha: 0.1),
                    ),
                    child: Slider(
                      value: frame.toDouble(),
                      min: 0,
                      max: (_maxFrames - 1).toDouble().clamp(
                        1.0,
                        double.infinity,
                      ),
                      onChanged: (value) {
                        // Pause playback while scrubbing to prevent conflicts
                        if (_isPlayingNotifier.value) {
                          _togglePlayback();
                        }
                        _animationController.reset();
                        _currentFrameNotifier.value = value.toInt();
                        if (_angles.isNotEmpty) {
                          if (value.toInt() < _angles.length) {
                            _playbackAngleNotifier.value =
                                _angles[value.toInt()];
                          } else {
                            _playbackAngleNotifier.value = _angles.last;
                          }
                        }
                        if (_compareAngles != null &&
                            _compareAngles!.isNotEmpty) {
                          if (value.toInt() < _compareAngles!.length) {
                            _comparePlaybackAngleNotifier.value =
                                _compareAngles![value.toInt()];
                          } else {
                            _comparePlaybackAngleNotifier.value =
                                _compareAngles!.last;
                          }
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Time: ${(frame * 0.1).toStringAsFixed(1)}s',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Angle: ${_angles.isEmpty ? 0 : _angles[frame.clamp(0, _angles.length - 1)].toInt()}°',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.brandOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGraphCard() {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Movement Angle Analysis',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visualizing real-time sensor and angle tracking data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 48),
          SizedBox(
            height: 380,
            child: _angles.isEmpty
                ? const Center(
                    child: Text('No angle data recorded for this session.'),
                  )
                : _AngleTrendChart(
                    angles: _angles,
                    compareAngles: _compareAngles,
                    currentFrame: _currentFrameNotifier,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailStat(
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (color ?? AppTheme.brandOrange).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: color ?? AppTheme.brandOrange),
          ),
          const SizedBox(width: 20),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color ?? const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AngleTrendChart extends StatelessWidget {
  final List<double> angles;
  final List<double>? compareAngles;
  final ValueListenable<int>? currentFrame;

  const _AngleTrendChart({
    required this.angles,
    this.compareAngles,
    this.currentFrame,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // Layer 1: Static Background Graph
                RepaintBoundary(
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _StaticTrendPainter(
                      angles: angles,
                      compareAngles: compareAngles,
                    ),
                  ),
                ),
                // Layer 2: Dynamic Playback Indicator
                ValueListenableBuilder<int>(
                  valueListenable: currentFrame ?? ValueNotifier<int>(0),
                  builder: (context, frame, _) {
                    return RepaintBoundary(
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: _PlaybackIndicatorPainter(
                          angles: angles,
                          compareAngles: compareAngles,
                          currentFrame: frame,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Start',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
              Text(
                'Time (Session Duration)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
              Text(
                'End',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaticTrendPainter extends CustomPainter {
  final List<double> angles;
  final List<double>? compareAngles;

  _StaticTrendPainter({required this.angles, this.compareAngles});

  @override
  void paint(Canvas canvas, Size size) {
    if (angles.isEmpty) return;

    final int caLen = compareAngles?.length ?? 0;
    final int maxFrames = angles.length > caLen ? angles.length : caLen;
    if (maxFrames <= 1) return;

    const double minAngle = -45.0;
    const double maxAngle = 135.0;
    final double range = maxAngle - minAngle;
    final double chartWidth = size.width;
    final double chartHeight = size.height;
    final double stepX = chartWidth / (maxFrames - 1);

    double getY(double angle) =>
        chartHeight - ((angle - minAngle) / range * chartHeight);

    final Path path = Path();
    final Path fillPath = Path();

    path.moveTo(0, getY(angles[0]));
    fillPath.moveTo(0, chartHeight);
    fillPath.lineTo(0, getY(angles[0]));

    for (int i = 1; i < angles.length; i++) {
      final double x = i * stepX;
      final double y = getY(angles[i]);
      final double prevX = (i - 1) * stepX;
      final double prevY = getY(angles[i - 1]);
      final double midX = (prevX + x) / 2;

      path.cubicTo(midX, prevY, midX, y, x, y);
      fillPath.cubicTo(midX, prevY, midX, y, x, y);
    }

    fillPath.lineTo(chartWidth, chartHeight);
    fillPath.close();

    // Fill
    final Paint fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppTheme.brandOrange.withValues(alpha: 0.3),
          AppTheme.brandOrange.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, chartWidth, chartHeight));
    canvas.drawPath(fillPath, fillPaint);

    // Grid lines
    final Paint gridPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (int i = 0; i <= 4; i++) {
      final double y = chartHeight * (i / 4);
      canvas.drawLine(Offset(0, y), Offset(chartWidth, y), gridPaint);

      final double angleLabel = maxAngle - (i / 4) * range;
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: '${angleLabel.toInt()}°',
          style: TextStyle(
            color: Colors.black.withValues(alpha: 0.2),
            fontSize: 10,
          ),
        ),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width - 8, y - tp.height / 2));
    }

    // Draw compare line
    if (compareAngles != null && compareAngles!.isNotEmpty) {
      final Path comparePath = Path();

      comparePath.moveTo(0, getY(compareAngles![0]));
      for (int i = 1; i < compareAngles!.length; i++) {
        final double x = i * stepX;
        final double y = getY(compareAngles![i]);
        final double prevX = (i - 1) * stepX;
        final double prevY = getY(compareAngles![i - 1]);
        final double midX = (prevX + x) / 2;

        comparePath.cubicTo(midX, prevY, midX, y, x, y);
      }

      final Paint comparePaint = Paint()
        ..color = Colors.grey.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      canvas.drawPath(comparePath, comparePaint);
    }

    // Shadow line for main path
    canvas.drawPath(
      path,
      Paint()
        ..color = AppTheme.brandOrange.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Main line
    final Paint linePaint = Paint()
      ..color = AppTheme.brandOrange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _StaticTrendPainter old) =>
      old.angles != angles || old.compareAngles != compareAngles;
}

class _PlaybackIndicatorPainter extends CustomPainter {
  final List<double> angles;
  final List<double>? compareAngles;
  final int currentFrame;

  _PlaybackIndicatorPainter({
    required this.angles,
    this.compareAngles,
    required this.currentFrame,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (angles.isEmpty) return;

    final int caLen = compareAngles?.length ?? 0;
    final int maxFrames = angles.length > caLen ? angles.length : caLen;
    if (maxFrames <= 1) return;

    const double minAngle = -45.0;
    const double maxAngle = 135.0;
    final double range = maxAngle - minAngle;
    final double stepX = size.width / (maxFrames - 1);
    final double headX = currentFrame * stepX;
    final double chartHeight = size.height;

    double getY(double angle) =>
        chartHeight - ((angle - minAngle) / range * chartHeight);

    // Playback Head (Vertical Line)
    final Paint headPaint = Paint()
      ..color = AppTheme.brandOrange
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(headX, 0), Offset(headX, chartHeight), headPaint);

    // Glow for playback head
    canvas.drawLine(
      Offset(headX, 0),
      Offset(headX, chartHeight),
      Paint()
        ..color = AppTheme.brandOrange.withValues(alpha: 0.2)
        ..strokeWidth = 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );

    // Indicator dot on the line
    final double headY = getY(angles[currentFrame.clamp(0, angles.length - 1)]);
    canvas.drawCircle(
      Offset(headX, headY),
      6,
      headPaint..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(headX, headY),
      10,
      Paint()
        ..color = AppTheme.brandOrange.withValues(alpha: 0.2)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(covariant _PlaybackIndicatorPainter old) =>
      old.currentFrame != currentFrame;
}

// ─────────────────────────────────────────────────────────────────────────────
// AI Clinical Note Card
// ─────────────────────────────────────────────────────────────────────────────

enum _NoteState { idle, loading, success, error }

class _ClinicalNoteCard extends StatefulWidget {
  final Map<String, dynamic> session;
  const _ClinicalNoteCard({required this.session});

  @override
  State<_ClinicalNoteCard> createState() => _ClinicalNoteCardState();
}

class _ClinicalNoteCardState extends State<_ClinicalNoteCard> {
  _NoteState _noteState = _NoteState.idle;
  String _noteText = '';
  String _errorText = '';
  bool _copied = false;

  Future<void> _generate() async {
    setState(() {
      _noteState = _NoteState.loading;
      _noteText = '';
      _errorText = '';
      _copied = false;
    });

    try {
      final note = await AiNoteService.instance.generateClinicalNote(
        currentSession: widget.session,
      );
      if (mounted) {
        setState(() {
          _noteText = note;
          _noteState = _NoteState.success;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorText = e.toString();
          _noteState = _NoteState.error;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _noteText));
    if (mounted) {
      setState(() => _copied = true);
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) setState(() => _copied = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.brandOrange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.brandOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Clinical Summary',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Powered by Gemini via Firebase AI Logic',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Copy button — only visible when note is ready
              if (_noteState == _NoteState.success)
                Tooltip(
                  message: _copied ? 'Copied!' : 'Copy to clipboard',
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: InkWell(
                      key: ValueKey(_copied),
                      onTap: _copyToClipboard,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _copied
                              ? const Color(0xFF059669).withValues(alpha: 0.1)
                              : Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _copied ? Icons.check : Icons.copy_outlined,
                          size: 18,
                          color: _copied
                              ? const Color(0xFF059669)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 28),

          // ── Body ─────────────────────────────────────────────────────────
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_noteState) {
      // ── Idle: show generate button ──────────────────────────────────────
      case _NoteState.idle:
        return Center(
          key: const ValueKey('idle'),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.brandOrange.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.description_outlined,
                  size: 40,
                  color: AppTheme.brandOrange.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Generate a professional clinical note',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'The AI will analyse this session alongside previous sessions\n'
                'of the same exercise and write a concise progress note.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.black.withValues(alpha: 0.35),
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: _generate,
                icon: const Icon(Icons.auto_awesome, size: 18),
                label: const Text(
                  'Generate Clinical Note',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
            ],
          ),
        );

      // ── Loading ──────────────────────────────────────────────────────────
      case _NoteState.loading:
        return Center(
          key: const ValueKey('loading'),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: AppTheme.brandOrange,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Analysing patient data…',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Gemini is reviewing session history and generating\na clinical summary. This may take a few seconds.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.3),
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        );

      // ── Success: display note ─────────────────────────────────────────────
      case _NoteState.success:
        return Column(
          key: const ValueKey('success'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.brandOrange.withValues(alpha: 0.15),
                ),
              ),
              child: Text(
                _noteText,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.75,
                  color: Color(0xFF1E293B),
                  fontStyle: FontStyle.normal,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.black.withValues(alpha: 0.25),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'AI-generated — always verify with clinical judgement',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withValues(alpha: 0.25),
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.refresh, size: 15),
                  label: const Text('Regenerate'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.brandOrange,
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );

      // ── Error ─────────────────────────────────────────────────────────────
      case _NoteState.error:
        return Center(
          key: const ValueKey('error'),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: Colors.redAccent,
                  size: 36,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Could not generate clinical note',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Make sure Firebase AI Logic is enabled in your project and '
                  'the app has network access.\n\n'
                  'Error: $_errorText',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withValues(alpha: 0.4),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: _generate,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Try Again'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }
}
