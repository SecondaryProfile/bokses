import 'package:flutter/material.dart';

import '../constants.dart';
import '../models/account.dart';
import '../services/account_rules.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Reachable from Settings. Everyone can change their own password and sign
/// out here; root additionally sees the account list, can add or delete
/// accounts, reset anyone's password, and toggle self-service sign-ups.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  List<Account>? _accounts;
  bool _signupsEnabled = false;
  bool _loadingAccounts = false;

  Account? get _me => AuthService.instance.currentAccount.value;

  @override
  void initState() {
    super.initState();
    if (_me?.isRoot ?? false) _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final results = await Future.wait([
        AuthService.instance.listAccounts(),
        AuthService.instance.checkSetup(),
      ]);
      if (!mounted) return;
      setState(() {
        _accounts = results[0] as List<Account>;
        _signupsEnabled = (results[1] as ({bool needsSetup, bool signupsEnabled})).signupsEnabled;
      });
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  void _showError(Object e) {
    final message = e is ApiException ? e.message : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _signOut() async {
    await AuthService.instance.logout();
    // AuthGate listens for this and swaps back to the sign-in screen itself.
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  Future<void> _changePassword() async {
    final result = await showDialog<({String current, String next})>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (result == null) return;
    try {
      await AuthService.instance.changePassword(result.current, result.next);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Password changed. Other devices were signed out.')));
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _addAccount() async {
    final result = await showDialog<({String username, String password})>(
      context: context,
      builder: (_) => const _NewAccountDialog(),
    );
    if (result == null) return;
    try {
      await AuthService.instance.createAccount(result.username, result.password);
      _loadAccounts();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _resetPassword(Account account) async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _ResetPasswordDialog(username: account.username),
    );
    if (result == null) return;
    try {
      await AuthService.instance.resetPassword(account.id, result);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("${account.username}'s password was reset and they were signed out.")));
      }
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _deleteAccount(Account account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete account?'),
        content: Text('This permanently deletes ${account.username}\'s account. They will be signed out.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AuthService.instance.deleteAccount(account.id);
      _loadAccounts();
    } catch (e) {
      if (mounted) _showError(e);
    }
  }

  Future<void> _toggleSignups(bool enabled) async {
    setState(() => _signupsEnabled = enabled);
    try {
      await AuthService.instance.setSignupsEnabled(enabled);
    } catch (e) {
      if (mounted) {
        setState(() => _signupsEnabled = !enabled);
        _showError(e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = _me;
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Account'), backgroundColor: Colors.transparent),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppTheme.cardBg,
            child: ListTile(
              leading: const Icon(Icons.person_rounded),
              title: Text(me?.username ?? '', style: const TextStyle(fontFamily: kFontFamily)),
              subtitle: Text(me?.isRoot ?? false ? 'Root account' : 'Account'),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.lock_reset_rounded),
            title: const Text('Change password'),
            subtitle: const Text('Signs out your other devices'),
            onTap: _changePassword,
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Sign out'),
            onTap: _signOut,
          ),
          if (me?.isRoot ?? false) ...[
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text('MANAGE ACCOUNTS',
                  style: TextStyle(
                      fontFamily: kFontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMid)),
            ),
            SwitchListTile(
              title: const Text('Allow sign-ups'),
              subtitle: const Text('Let people create their own account from the sign-in screen'),
              value: _signupsEnabled,
              onChanged: _toggleSignups,
            ),
            if (_loadingAccounts) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
            for (final account in _accounts ?? [])
              ListTile(
                leading: Icon(account.isRoot ? Icons.shield_rounded : Icons.person_outline_rounded),
                title: Text(account.username),
                subtitle: account.isRoot ? const Text('Root') : null,
                trailing: account.isRoot
                    ? null
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.lock_reset_rounded),
                            tooltip: 'Reset password',
                            onPressed: () => _resetPassword(account),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            tooltip: 'Delete account',
                            onPressed: () => _deleteAccount(account),
                          ),
                        ],
                      ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _addAccount,
              icon: const Icon(Icons.person_add_alt_rounded),
              label: const Text('Add account'),
            ),
          ],
        ],
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
              validator: AccountRules.validatePassword,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, (current: _current.text, next: _next.text));
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _NewAccountDialog extends StatefulWidget {
  const _NewAccountDialog();

  @override
  State<_NewAccountDialog> createState() => _NewAccountDialogState();
}

class _NewAccountDialogState extends State<_NewAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add account'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _username,
              decoration: const InputDecoration(labelText: 'Username'),
              validator: AccountRules.validateUsername,
            ),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: AccountRules.validatePassword,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, (username: _username.text.trim(), password: _password.text));
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  final String username;
  const _ResetPasswordDialog({required this.username});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text("Reset ${widget.username}'s password"),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _password,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'New password'),
          validator: AccountRules.validatePassword,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (!(_formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, _password.text);
          },
          child: const Text('Reset'),
        ),
      ],
    );
  }
}
