import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/glass_button.dart';
import '../widgets/app_background.dart';
import 'exercises/sit_and_stand_screen.dart';
import 'exercises/seated_leg_extension_screen.dart';
import 'exercises/marching_screen.dart';
import 'exercises/single_leg_stance_screen.dart';

class ExerciseItem {
  final String name;
  final IconData icon;

  const ExerciseItem({required this.name, required this.icon});
}

class ExercisesScreen extends StatefulWidget {
  final Set<String> completedExercises;

  const ExercisesScreen({super.key, required this.completedExercises});

  static const List<ExerciseItem> exercises = [
    ExerciseItem(name: 'Sit and Stand', icon: Icons.accessibility_new),
    ExerciseItem(
      name: 'Seated Leg\nExtension',
      icon: Icons.airline_seat_legroom_extra,
    ),
    ExerciseItem(name: 'Marching', icon: Icons.directions_walk),
    ExerciseItem(name: 'Single-leg\nStance', icon: Icons.nordic_walking),
  ];

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  late Set<String> _completedExercises;

  @override
  void initState() {
    super.initState();
    _completedExercises = Set<String>.from(widget.completedExercises);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pop(context, _completedExercises);
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.backgroundLight,
        body: Stack(
          children: [
            const AppBackground(type: BackgroundType.list),
            Column(
              children: [
                _buildGlassHeader(context),
                Expanded(
                  child: ListView.builder(
                    cacheExtent: 500,
                    padding: EdgeInsets.fromLTRB(
                      24,
                      24,
                      24,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    itemCount: ExercisesScreen.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = ExercisesScreen.exercises[index];
                      final isCompleted = _completedExercises.contains(
                        exercise.name,
                      );
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: _ExerciseCard(
                          exercise: exercise,
                          isCompleted: isCompleted,
                          onCompleted: () {
                            setState(() {
                              _completedExercises.add(exercise.name);
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassHeader(BuildContext context) {
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
          padding: const EdgeInsets.fromLTRB(8, 16, 24, 20),
          child: Row(
            children: [
              // Back button
              TextButton.icon(
                onPressed: () => Navigator.pop(context, _completedExercises),
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                label: const Text(
                  'Back',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.slate600,
                ),
              ),
              const SizedBox(width: 8),
              // Avatar
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
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
              const SizedBox(width: 16),
              // Greeting
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ready to move?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'John Doe',
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
}

// ---------------------------------------------------------------------------
// Extracted StatelessWidget — only rebuilds when its own props change.
// ---------------------------------------------------------------------------
class _ExerciseCard extends StatelessWidget {
  final ExerciseItem exercise;
  final bool isCompleted;
  final VoidCallback onCompleted;

  const _ExerciseCard({
    required this.exercise,
    required this.isCompleted,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      borderRadius: 24,
      blur: 12,
      color: Colors.white.withValues(alpha: 0.15),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.07),
          blurRadius: 20,
          offset: const Offset(0, 4),
        ),
      ],
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Icon + Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon container
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.orange100.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    exercise.icon,
                    size: 36,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                // Exercise name
                Text(
                  exercise.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.slate900,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          // Start / Exercise Again button
          _ExerciseButton(
            exerciseName: exercise.name,
            isCompleted: isCompleted,
            onCompleted: onCompleted,
          ),
        ],
      ),
    );
  }
}

class _ExerciseButton extends StatelessWidget {
  final String exerciseName;
  final bool isCompleted;
  final VoidCallback onCompleted;

  const _ExerciseButton({
    required this.exerciseName,
    required this.isCompleted,
    required this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final String label = isCompleted ? 'Exercise\nAgain' : 'Start';
    final IconData icon = isCompleted ? Icons.replay : Icons.play_circle;

    // Completed: Glassy Gold
    // Start: Aesthetic Green
    final Color buttonColor = isCompleted
        ? const Color(0xFFEAB308).withValues(alpha: 0.7)
        : AppColors.green600.withValues(alpha: 0.8);

    final Color textColor = isCompleted
        ? const Color(0xFF422006)
        : Colors.white;

    return GlassButton(
      onPressed: () async {
        final Widget destination = switch (exerciseName) {
          'Sit and Stand' => const SitAndStandScreen(),
          'Seated Leg\nExtension' => const SeatedLegExtensionScreen(),
          'Marching' => const MarchingScreen(),
          'Single-leg\nStance' => const SingleLegStanceScreen(),
          _ => const SitAndStandScreen(),
        };
        final result = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
        if (result == true) {
          onCompleted();
        }
      },
      borderRadius: 12,
      height: 56,
      blur: 15,
      color: buttonColor,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isCompleted ? 16 : 20,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 24, color: textColor),
        ],
      ),
    );
  }
}

// End of file. Local blob background classes removed.
