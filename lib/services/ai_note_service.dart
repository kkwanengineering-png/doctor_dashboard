import 'package:firebase_ai/firebase_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Service that generates a professional clinical note for a rehabilitation
/// session by calling Gemini Flash via Firebase AI Logic.
class AiNoteService {
  AiNoteService._();

  static final AiNoteService instance = AiNoteService._();

  /// Fetches the last [historyLimit] sessions of [exerciseName] from Firestore
  /// (excluding the current session if present) and calls Gemini to produce a
  /// clinical paragraph.
  ///
  /// [currentSession] is the full Firestore document for the session being
  /// reviewed.  It must contain at least the keys that [_buildPrompt] uses.
  Future<String> generateClinicalNote({
    required Map<String, dynamic> currentSession,
    int historyLimit = 10,
  }) async {
    final exerciseName =
        (currentSession['exerciseName'] as String?) ?? 'Unknown Exercise';

    // --- 1. Fetch historical sessions from Firestore ---
    List<Map<String, dynamic>> previousSessions = [];
    try {
      final currentTs = currentSession['timestamp'] as Timestamp?;
      final query = FirebaseFirestore.instance
          .collection('session_history')
          .where('exerciseName', isEqualTo: exerciseName)
          .orderBy('timestamp', descending: true)
          .limit(historyLimit + 1); // +1 so we can exclude current if present

      final snap = await query.get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final docTs = data['timestamp'] as Timestamp?;
        // Skip the current session if it appears in history
        if (currentTs != null && docTs != null && docTs == currentTs) continue;
        previousSessions.add(data);
        if (previousSessions.length >= historyLimit) break;
      }
    } catch (e) {
      debugPrint('[AiNoteService] Error fetching history: $e');
      // Proceed with empty history if fetch fails
    }

    // --- 2. Build the prompt ---
    final prompt = _buildPrompt(
      currentSession: currentSession,
      previousSessions: previousSessions,
    );

    // --- 3. Call Gemini Flash via Firebase AI Logic ---
    try {
      final model = FirebaseAI.googleAI().generativeModel(
        model: 'gemini-2.5-flash',
      );
      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text;
      if (text == null || text.trim().isEmpty) {
        throw Exception('Empty response from AI model.');
      }
      return text.trim();
    } catch (e) {
      debugPrint('[AiNoteService] Error calling Gemini: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _buildPrompt({
    required Map<String, dynamic> currentSession,
    required List<Map<String, dynamic>> previousSessions,
  }) {
    final buf = StringBuffer();

    buf.writeln(
      'You are a clinical physiotherapy assistant generating a formal progress '
      'note for a doctor. Based on the rehabilitation session data below, write '
      'ONE concise, professional paragraph (4–6 sentences) summarising the '
      "patient's performance and progress trend. Use objective, third-person "
      'clinical language (e.g., "The patient demonstrated…"). '
      'IMPORTANT: You MUST explicitly comment on the patient\'s movement SPEED '
      '(the "Speed" field provided for each session). '
      'If speed is SLOW (>8 s/rep), note that the patient performed repetitions '
      'at a slower-than-expected pace and suggest the clinician consider whether '
      'this reflects fatigue, pain avoidance, or excessive caution. '
      'If speed is FAST (<3 s/rep), note that the patient completed repetitions '
      'at a faster-than-recommended pace and advise the clinician to assess '
      'whether controlled movement quality was maintained throughout. '
      'If speed is NORMAL (3–8 s/rep), briefly acknowledge appropriate pacing. '
      'CRITICAL: Monitor the "Angle range" field. Most rehabilitation exercises '
      'should typically stay within 0° to 100°. If you observe angles reaching '
      'extreme values (e.g., >120° or nearing +/- 180°), you MUST flag this as '
      '"abnormal" or "potentially indicative of sensor tracking anomalies or extreme compensation" '
      'and advise the clinician to verify the movement quality. '
      'CRITICAL: Monitor the "Fall Detected" field. If a fall was detected, you MUST '
      'PRIORITIZE this information over all other metrics. Explicitly mention the fall in '
      'your opening sentence, suggest potential reasons (e.g., loss of balance, '
      'environmental obstacle) based on the exercise context, and strongly advise the '
      'clinician to conduct an immediate physical assessment for injury. '
      'Do NOT add disclaimers. Do NOT invent data not provided. If data is '
      'limited, note that this is an early session.',
    );
    buf.writeln();
    buf.writeln('EXERCISE: ${currentSession['exerciseName'] ?? 'Unknown'}');
    buf.writeln();
    buf.writeln('CURRENT SESSION:');
    buf.writeln(_formatSession(currentSession, label: 'Current'));
    buf.writeln();

    if (previousSessions.isEmpty) {
      buf.writeln(
        'PREVIOUS SESSIONS: None recorded (this appears to be the first session).',
      );
    } else {
      buf.writeln('PREVIOUS SESSIONS (most recent first):');
      for (int i = 0; i < previousSessions.length; i++) {
        buf.writeln(
          _formatSession(previousSessions[i], label: 'Session ${i + 1}'),
        );
      }
    }

    buf.writeln();
    buf.writeln('Write the clinical note now:');
    return buf.toString();
  }

  String _formatSession(
    Map<String, dynamic> session, {
    required String label,
  }) {
    final ts = session['timestamp'] as Timestamp?;
    final dateStr = ts != null
        ? DateFormat('yyyy-MM-dd').format(ts.toDate())
        : 'Unknown date';

    final passCount = (session['passCount'] ?? 0) as int;
    final failCount = (session['failCount'] ?? 0) as int;
    final duration = (session['durationSeconds'] ?? 0) as int;
    final totalReps = passCount + failCount;
    final successRate = totalReps > 0
        ? ((passCount / totalReps) * 100).toStringAsFixed(0)
        : 'N/A';

    // Angle range derived from the stored angle list
    final angles = (session['angles'] as List<dynamic>?)
        ?.map((e) => (e as num).toDouble())
        .toList();
    String angleRange = 'N/A';
    if (angles != null && angles.isNotEmpty) {
      final minA = angles.reduce((a, b) => a < b ? a : b).toStringAsFixed(1);
      final maxA = angles.reduce((a, b) => a > b ? a : b).toStringAsFixed(1);
      angleRange = '${minA}° – ${maxA}°';
    }

    // Speed / pace analysis
    final speedInfo = _computeSpeedInfo(
      durationSeconds: duration,
      totalReps: totalReps,
    );

    final fell = session['didFall'] == true || session['fell'] == true;
    final fallProb = (session['fallProbability'] as num?)?.toDouble() ?? 0.0;

    return '  [$label | $dateStr] Duration: ${duration}s | '
        'Pass: $passCount | Fail: $failCount | '
        'Success rate: $successRate% | Angle range: $angleRange | '
        'Speed: $speedInfo | Fall Detected: $fell | Fall Probability: ${(fallProb * 100).toStringAsFixed(1)}%';
  }

  /// Computes a human-readable speed descriptor for the Gemini prompt.
  ///
  /// Reference norms for lower-limb rehabilitation exercises:
  ///   < 3 s/rep  → FAST   (rushed, potential quality concern)
  ///   3–8 s/rep  → NORMAL (controlled, therapeutic range)
  ///   > 8 s/rep  → SLOW   (could indicate fatigue, pain, or excessive caution)
  ///
  /// Returns 'N/A' if there are no reps or zero duration.
  String _computeSpeedInfo({
    required int durationSeconds,
    required int totalReps,
  }) {
    if (totalReps <= 0 || durationSeconds <= 0) {
      return 'N/A (insufficient data)';
    }

    final secsPerRep = durationSeconds / totalReps;
    final repsPerMin = totalReps / durationSeconds * 60;

    final String classification;
    if (secsPerRep < 3.0) {
      classification = 'FAST';
    } else if (secsPerRep <= 8.0) {
      classification = 'NORMAL';
    } else {
      classification = 'SLOW';
    }

    return '$classification (${secsPerRep.toStringAsFixed(1)} s/rep, '
        '${repsPerMin.toStringAsFixed(1)} reps/min)';
  }
}
