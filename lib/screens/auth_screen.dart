import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../services/account_rules.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

enum AuthMode { setup, login, signup }

/// First-run root setup, sign-in, and sign-up in one form.
class AuthScreen extends StatefulWidget {
  final AuthMode mode;
  final bool allowSignups;
  final VoidCallback onSignedIn;

  const AuthScreen({
    super.key,
    required this.mode,
    required this.onSignedIn,
    this.allowSignups = false,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  late AuthMode _mode = widget.mode;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  bool get _creatingAccount => _mode != AuthMode.login;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _switchMode(AuthMode mode) {
    setState(() {
      _mode = mode;
      _error = null;
      _confirm.clear();
    });
    _formKey.currentState?.reset();
  }

  Future<void> _submit() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final username = _username.text.trim();
    final password = _password.text;
    final auth = AuthService.instance;
    try {
      switch (_mode) {
        case AuthMode.setup:
          await auth.setup(username, password);
        case AuthMode.login:
          await auth.login(username, password);
        case AuthMode.signup:
          await auth.signup(username, password);
      }
      TextInput.finishAutofillContext();
      if (mounted) widget.onSignedIn();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _title => switch (_mode) {
        AuthMode.setup => 'Welcome to Bokses',
        AuthMode.login => 'Sign in',
        AuthMode.signup => 'Create an account',
      };

  String get _subtitle => switch (_mode) {
        AuthMode.setup =>
          'Create the root account. It manages everyone else\'s accounts on this Bokses container.',
        AuthMode.login => 'Tidy up your life. Just put it in a box.',
        AuthMode.signup => 'Everyone on this local Bokses application shares the same boxes.',
      };

  String get _submitLabel => switch (_mode) {
        AuthMode.setup => 'Create root account',
        AuthMode.login => 'Sign in',
        AuthMode.signup => 'Create account',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Image.asset('assets/icons/app_icon_light.png',
                            width: 88, height: 88),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: kFontFamily,
                          fontSize: 14,
                          height: 1.4,
                          color: AppTheme.textMid,
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextFormField(
                        key: const Key('auth-username'),
                        controller: _username,
                        enabled: !_busy,
                        autocorrect: false,
                        textInputAction: TextInputAction.next,
                        autofillHints: [
                          _creatingAccount ? AutofillHints.newUsername : AutofillHints.username
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Username',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        // Sign-in accepts anything; the server decides.
                        validator: _creatingAccount
                            ? AccountRules.validateUsername
                            : (v) => (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('auth-password'),
                        controller: _password,
                        enabled: !_busy,
                        obscureText: _obscure,
                        textInputAction:
                            _creatingAccount ? TextInputAction.next : TextInputAction.done,
                        onFieldSubmitted: _creatingAccount ? null : (_) => _submit(),
                        autofillHints: [
                          _creatingAccount ? AutofillHints.newPassword : AutofillHints.password
                        ],
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          helperText: _creatingAccount
                              ? 'At least ${AccountRules.minPasswordLength} characters'
                              : null,
                          suffixIcon: IconButton(
                            tooltip: _obscure ? 'Show password' : 'Hide password',
                            icon: Icon(_obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        validator: _creatingAccount
                            ? AccountRules.validatePassword
                            : (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                      ),
                      if (_creatingAccount) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          key: const Key('auth-confirm'),
                          controller: _confirm,
                          enabled: !_busy,
                          obscureText: _obscure,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: Icon(Icons.lock_outline_rounded),
                          ),
                          validator: (v) =>
                              v != _password.text ? 'Passwords don\'t match' : null,
                        ),
                      ],
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline_rounded,
                                color: Color(0xFFE53935), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                key: const Key('auth-error'),
                                style: TextStyle(
                                    fontFamily: kFontFamily, color: AppTheme.textDark),
                              ),
                            ),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          key: const Key('auth-submit'),
                          onPressed: _busy ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2.5),
                                )
                              : Text(_submitLabel),
                        ),
                      ),
                      if (_mode == AuthMode.login && widget.allowSignups) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy ? null : () => _switchMode(AuthMode.signup),
                          child: const Text('New here? Create an account'),
                        ),
                      ],
                      if (_mode == AuthMode.signup) ...[
                        const SizedBox(height: 12),
                        TextButton(
                          onPressed: _busy ? null : () => _switchMode(AuthMode.login),
                          child: const Text('Already have an account? Sign in'),
                        ),
                      ],
                      if (_mode == AuthMode.login && !widget.allowSignups) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Need an account? Ask whoever runs your local Bokses!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontFamily: kFontFamily, fontSize: 13, color: AppTheme.textMid),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
