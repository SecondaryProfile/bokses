import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/account.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'home_screen.dart';

/// The app's root widget once the splash animation finishes. Decides between
/// first-run setup, sign-in, and the home screen — and reacts automatically
/// to sign-out from anywhere in the app via [AuthService.currentAccount].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _needsSetup = false;
  bool _signupsEnabled = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _loadError = null;
    });
    try {
      final setup = await AuthService.instance.checkSetup();
      _needsSetup = setup.needsSetup;
      _signupsEnabled = setup.signupsEnabled;
      if (!_needsSetup) {
        await AuthService.instance.refresh();
      }
    } catch (e) {
      _loadError = e.toString();
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || _loadError != null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(
          child: _loadError == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Couldn't reach the Bokses server.\n$_loadError",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: kFontFamily, color: AppTheme.textDark),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(onPressed: _check, child: const Text('Retry')),
                    ],
                  ),
                ),
        ),
      );
    }

    if (_needsSetup) {
      return AuthScreen(
        mode: AuthMode.setup,
        onSignedIn: () => setState(() => _needsSetup = false),
      );
    }

    return ValueListenableBuilder<Account?>(
      valueListenable: AuthService.instance.currentAccount,
      builder: (context, account, _) {
        if (account == null) {
          return AuthScreen(
            mode: AuthMode.login,
            allowSignups: _signupsEnabled,
            onSignedIn: () {}, // currentAccount already updated; this rebuild handles it
          );
        }
        return const HomeScreen();
      },
    );
  }
}
