import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class FallDetectionResult {
  final double probability;
  final Map<String, double> features;
  final bool isImpactTriggered;

  FallDetectionResult({
    required this.probability,
    required this.features,
    this.isImpactTriggered = false,
  });
}

class FallDetectionService {
  static Interpreter? _interpreter;

  /// Loads the TFLite model safely.
  static Future<void> _loadModel() async {
    if (_interpreter != null) return;
    try {
      _interpreter = await Interpreter.fromAsset('assets/fall_model.tflite');
      debugPrint("Fall prediction model loaded successfully.");
    } catch (e) {
      debugPrint("Error loading fall_model.tflite: $e");
    }
  }

  // ==========================================================================
  // SCALER VALUES - REPLACE THESE WITH YOUR TRAINED SCALER OUTPUTS
  // ==========================================================================
  // From sklearn: scaler.mean_
  static const List<double> _scalerMean = [
    21.77767288,
    5.09609503,
    10.20577514,
    4.01934793,
    7.97994773,
    1.73596891,
    1.64704187,
    3.31265842,
    5.26873463,
  ];

  // From sklearn: scaler.scale_
  static const List<double> _scalerScale = [
    5.45631658,
    2.98462952,
    12.35178484,
    5.57192706,
    4.25535458,
    1.55359805,
    1.00988539,
    3.45166707,
    5.01364532,
  ];

  /// Normalizes the features using StandardScaling: (x - mean) / scale
  static List<double> _normalizeFeatures(List<double> rawFeatures) {
    if (rawFeatures.length != _scalerMean.length) return rawFeatures;
    final List<double> normalized = [];
    for (int i = 0; i < rawFeatures.length; i++) {
      normalized.add((rawFeatures[i] - _scalerMean[i]) / _scalerScale[i]);
    }
    return normalized;
  }

  /// Calculates the population skewness of a given array.
  static double _calculateSkewness(List<double> data) {
    if (data.isEmpty) return 0.0;
    final n = data.length;
    final mean = data.reduce((a, b) => a + b) / n;
    var sumSq = 0.0;
    for (var x in data) {
      sumSq += math.pow(x - mean, 2);
    }
    final variance = sumSq / n;

    // Noise gate: If movement is extremely tiny (< 0.001), treat it as 0.0
    // to avoid dividing by near-zero variance (which causes 110+ values)
    if (variance < 0.001) return 0.0;

    final stdDev = math.sqrt(variance);

    var sumCubed = 0.0;
    for (var x in data) {
      sumCubed += math.pow((x - mean) / stdDev, 3);
    }
    return sumCubed / n;
  }

  /// Calculates the population excess kurtosis of a given array.
  static double _calculateKurtosis(List<double> data) {
    if (data.isEmpty) return 0.0;
    final n = data.length;
    final mean = data.reduce((a, b) => a + b) / n;
    var sumSq = 0.0;
    for (var x in data) {
      sumSq += math.pow(x - mean, 2);
    }
    final variance = sumSq / n;

    // Noise gate: If movement is extremely tiny (< 0.001), treat it as 0.0
    // to avoid dividing by near-zero variance (which causes 110+ values)
    if (variance < 0.001) return 0.0;

    final stdDev = math.sqrt(variance);

    var sumFourth = 0.0;
    for (var x in data) {
      sumFourth += math.pow((x - mean) / stdDev, 4);
    }
    return (sumFourth / n) - 3.0; // Excess kurtosis
  }

  /// Calculates fall probability and returns all features for debugging.
  static Future<FallDetectionResult?> getFallProbability(
    List<double> accelWindow,
    List<double> gyroWindow,
    List<double> linearAccelWindow, {
    bool isImpactTriggered = false,
  }) async {
    if (accelWindow.length < 120 ||
        gyroWindow.length < 120 ||
        linearAccelWindow.length < 120) {
      return null;
    }

    // Ensure model is loaded once
    await _loadModel();
    if (_interpreter == null) {
      debugPrint("Model interpreter is null.");
      return null;
    }

    try {
      final accMax = accelWindow.reduce(math.max);
      final gyroMax = gyroWindow.reduce(math.max);
      final accKurt = _calculateKurtosis(accelWindow);
      final gyroKurt = _calculateKurtosis(gyroWindow);
      final linMax = linearAccelWindow.reduce(math.max);
      final accSkew = _calculateSkewness(accelWindow);
      final gyroSkew = _calculateSkewness(gyroWindow);

      final gyroLast40 = gyroWindow
          .sublist(gyroWindow.length - 40)
          .reduce(math.max);
      final linLast40 = linearAccelWindow
          .sublist(linearAccelWindow.length - 40)
          .reduce(math.max);

      final Map<String, double> featureMap = {
        'accMax': accMax,
        'gyroMax': gyroMax,
        'accKurt': accKurt,
        'gyroKurt': gyroKurt,
        'linMax': linMax,
        'accSkew': accSkew,
        'gyroSkew': gyroSkew,
        'postGyroMax': gyroLast40,
        'postLinMax': linLast40,
      };

      // Convert map values to a list for normalization
      final List<double> rawFeaturesList = featureMap.values.toList();

      // Normalize features using the scaler means/scales
      final List<double> normalizedFeatures = _normalizeFeatures(
        rawFeaturesList,
      );

      // Format into input tensor [1, 9]
      var input = [normalizedFeatures];
      var output = List.filled(1 * 1, 0.0).reshape([1, 1]);

      // Run Inference
      _interpreter!.run(input, output);

      final prob = output[0][0] as double;

      return FallDetectionResult(
        probability: prob,
        features: featureMap,
        isImpactTriggered: isImpactTriggered,
      );
    } catch (e) {
      debugPrint("Inference Error: $e");
      return null;
    }
  }

  /// Analyzes a 6-second window and triggers UI alert if probability > 0.5.
  static Future<void> analyzeFallData(
    BuildContext context,
    List<double> accelWindow,
    List<double> gyroWindow,
    List<double> linearAccelWindow,
  ) async {
    final result = await getFallProbability(
      accelWindow,
      gyroWindow,
      linearAccelWindow,
    );

    if (result != null && result.probability > 0.8) {
      debugPrint(
        "CRITICAL FALL DETECTED: ${(result.probability * 100).toStringAsFixed(1)}%",
      );
      if (context.mounted) {
        await _triggerFallAlertUI(context, result.probability);
      }
    }
  }

  static Future<void> _triggerFallAlertUI(
    BuildContext context,
    double probability,
  ) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'CRITICAL FALL ALERT',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'A high probability of a fall was detected.\n'
            'Probability: ${(probability * 100).toStringAsFixed(1)}%\n\n'
            'Please verify the patient\'s condition immediately.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Dismiss', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }
}
