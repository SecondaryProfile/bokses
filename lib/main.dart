import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? true;
  final preset = prefs.getInt('theme_preset') ?? 0;
  AppTheme.setMode(isDark);
  AppTheme.setPreset(preset);
  runApp(const BoksesApp());
}

class BoksesApp extends StatefulWidget {
  const BoksesApp({super.key});

  @override
  State<BoksesApp> createState() => _BoksesAppState();
}

class _BoksesAppState extends State<BoksesApp> {
  @override
  void initState() {
    super.initState();
    AppTheme.modeNotifier.addListener(_rebuild);
    AppTheme.presetNotifier.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppTheme.modeNotifier.removeListener(_rebuild);
    AppTheme.presetNotifier.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bokses',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}
