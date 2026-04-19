import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    debugPrint('Initializing Firebase...');
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    debugPrint('Firebase initialized successfully');

    // Access Firestore to trigger plugin initialization on web
    FirebaseFirestore.instance;
    debugPrint('Firestore instance accessed');
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  runApp(const DoctorDashboardApp());
}

class DoctorDashboardApp extends StatelessWidget {
  const DoctorDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Telerehab Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.themeData,
      home: const _AuthGate(),
    );
  }
}

/// Listens to Firebase Auth state and routes to the correct screen.
/// - Not signed in → LoginScreen
/// - Signed in     → DashboardScreen
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Still waiting for Firebase to confirm auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is signed in — go to dashboard
        if (snapshot.hasData && snapshot.data != null) {
          return const DashboardScreen();
        }

        // Not signed in — show login
        return const LoginScreen();
      },
    );
  }
}
