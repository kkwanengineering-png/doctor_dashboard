import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Sign in anonymously so Firebase security rules (auth != null) are satisfied.
  // This runs silently in the background — no login screen is needed.
  // The same anonymous UID is reused across sessions on the same device.
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    await auth.signInAnonymously();
  }

  // Prevent screen from sleeping during exercise sessions.
  WakelockPlus.enable();

  runApp(const StitchApp());
}

class StitchApp extends StatelessWidget {
  const StitchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stitch Telerehabilitation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      scrollBehavior: const NoGlowScrollBehavior(),
      home: const HomeScreen(),
    );
  }
}

class NoGlowScrollBehavior extends ScrollBehavior {
  const NoGlowScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}
