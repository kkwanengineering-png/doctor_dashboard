import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class FirebaseService {
  static final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Save the full exercise result to Firebase.
  ///
  /// * **Realtime Database** (`exercise_sessions/{name}`) — used by the doctor
  ///   dashboard's live-monitoring panel.
  /// * **Firestore** (`session_history` collection) — used by the AI clinical
  ///   note generator (AiNoteService) which queries by exerciseName + timestamp.
  static Future<void> saveExerciseResult({
    required String userId,
    required String userName,
    required String exerciseName,
    required int durationSeconds,
    required List<bool> repResults,
    required DateTime startTime,
    bool fell = false,
    bool didFall = false,
    double fallProbability = 0.0,
    List<double> angles = const [],
  }) async {
    final safeName = exerciseName.replaceAll('\n', ' ');

    // Build per-rep results map: "1" -> "pass", "2" -> "fail", etc.
    final Map<String, String> repsMap = {};
    int passCount = 0;
    int failCount = 0;

    for (int i = 0; i < repResults.length; i++) {
      final result = repResults[i] ? 'pass' : 'fail';
      repsMap['${i + 1}'] = result;
      if (repResults[i]) {
        passCount++;
      } else {
        failCount++;
      }
    }

    // Get the current user's UID (anonymous or authenticated)
    final uid = FirebaseAuth.instance.currentUser?.uid ?? userId;

    // ── 1. Realtime Database ────────────────────────────────────────────────
    // Real-time live monitor panel in the Doctor Dashboard reads from here.
    try {
      final Map<String, dynamic> rtdbData = {
        'userId': uid,
        'userName': userName,
        'exerciseName': safeName,
        'startTime': startTime.toIso8601String(),
        'endTime': DateTime.now().toIso8601String(),
        'durationSeconds': durationSeconds,
        'totalReps': repResults.length,
        'passCount': passCount,
        'failCount': failCount,
        'fell': fell,
        'didFall': didFall,
        'fallProbability': double.parse(fallProbability.toStringAsFixed(3)),
        'reps': repsMap,
      };
      await _dbRef.child('exercise_sessions').child(safeName).update(rtdbData);
      debugPrint('[FirebaseService] RTDB session saved.');
    } catch (e) {
      debugPrint('[FirebaseService] RTDB error: $e');
    }

    // ── 2. Firestore — session_history ──────────────────────────────────────
    // AiNoteService (Doctor Dashboard) queries this collection to generate
    // AI clinical notes. Schema must match what _buildPrompt() expects:
    //   exerciseName, timestamp, passCount, failCount, durationSeconds,
    //   angles (List<double>), didFall, fell, fallProbability
    try {
      final Map<String, dynamic> firestoreData = {
        'userId': uid,
        'userName': userName,
        'exerciseName': safeName,
        'timestamp': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(DateTime.now()),
        'durationSeconds': durationSeconds,
        'totalReps': repResults.length,
        'passCount': passCount,
        'failCount': failCount,
        'fell': fell,
        'didFall': didFall,
        'fallProbability': double.parse(fallProbability.toStringAsFixed(3)),
        'angles': angles,
        'reps': repsMap,
      };
      await _firestore.collection('session_history').add(firestoreData);
      debugPrint('[FirebaseService] Firestore session_history saved.');
    } catch (e) {
      debugPrint('[FirebaseService] Firestore error: $e');
    }
  }

  /// Update ONLY the current angle for real-time tracking (High Frequency).
  static Future<void> updateLiveAngle({
    required String exerciseName,
    required double angle,
  }) async {
    try {
      final safeName = exerciseName.replaceAll('\n', ' ');
      await _dbRef
        .child('exercise_sessions')
        .child(safeName)
        .update({'currentAngle': double.parse(angle.toStringAsFixed(1))});
    } catch (e) {
      debugPrint('[FirebaseService] Live angle error: $e');
    }
  }

  /// Update the sensor connection status in Firebase Realtime Database.
  static Future<void> updateSensorStatus({
    required String exerciseName,
    required bool isConnected,
  }) async {
    try {
      final safeName = exerciseName.replaceAll('\n', ' ');
      await _dbRef
        .child('exercise_sessions')
        .child(safeName)
        .update({'sensorConnected': isConnected});
    } catch (e) {
      debugPrint('[FirebaseService] Sensor status error: $e');
    }
  }

  /// Get a stream of the 'fell' status for a specific exercise session.
  static Stream<bool> getFellStream(String exerciseName) {
    final safeName = exerciseName.replaceAll('\n', ' ');
    return _dbRef
        .child('exercise_sessions')
        .child(safeName)
        .child('fell')
        .onValue
        .map((event) {
          final dynamic val = event.snapshot.value;
          return val == true;
        });
  }
}
