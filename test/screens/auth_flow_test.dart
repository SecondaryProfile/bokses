// Widget tests for first-run setup, sign-in, sign-up, and the Account
// screen. The server is FakeApi (test/helpers/fake_api.dart), a small
// in-memory stand-in for server/lib/src/api.dart driving a MockClient, so
// these exercise the real AuthService/ApiClient/AuthGate/AuthScreen wiring
// without a network.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bokses/screens/account_screen.dart';
import 'package:bokses/screens/auth_gate.dart';
import 'package:bokses/screens/home_screen.dart';
import 'package:bokses/services/api_client.dart';
import 'package:bokses/services/auth_service.dart';
import 'package:bokses/services/database_service.dart';
import 'package:bokses/theme/app_theme.dart';

import '../helpers/fake_api.dart';
import '../helpers/fake_database_service.dart';

late FakeApi server;

Future<void> pumpGate(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(800, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.theme,
    home: const AuthGate(),
  ));
  await tester.pumpAndSettle();
}

Finder field(String key) => find.byKey(Key(key));

Future<void> fillAndSubmit(WidgetTester tester,
    {required String username, required String password, String? confirm}) async {
  await tester.enterText(field('auth-username'), username);
  await tester.enterText(field('auth-password'), password);
  if (confirm != null) await tester.enterText(field('auth-confirm'), confirm);
  await tester.tap(field('auth-submit'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    server = FakeApi();
    AuthService.instance = AuthService.forTesting(ApiClient(client: server.client));
    DatabaseService.instance = FakeDatabaseService();
    SharedPreferences.setMockInitialValues({});
    AppTheme.setMode(true);
    AppTheme.setPreset(0);
  });

  group('first launch', () {
    testWidgets('shows root account setup', (t) async {
      await pumpGate(t);
      expect(find.text('Welcome to Bokses'), findsOneWidget);
      expect(find.text('Create root account'), findsWidgets);
      expect(field('auth-confirm'), findsOneWidget);
    });

    testWidgets('validates before sending anything', (t) async {
      await pumpGate(t);
      await fillAndSubmit(t, username: 'ad', password: 'short', confirm: 'different');
      expect(find.text('At least 3 characters'), findsOneWidget);
      expect(find.text('At least 8 characters'), findsWidgets);
      expect(find.text('Passwords don\'t match'), findsOneWidget);
      expect(server.requests.where((r) => r.method == 'POST'), isEmpty);
    });

    testWidgets('creating root opens the app as root', (t) async {
      await pumpGate(t);
      await fillAndSubmit(t,
          username: 'admin', password: 'root-password', confirm: 'root-password');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(server.users['admin']!.isRoot, isTrue);
      expect(AuthService.instance.currentAccount.value?.isRoot, isTrue);
    });
  });

  group('sign in', () {
    setUp(() => server.addUser('admin', 'root-password', isRoot: true));

    testWidgets('an existing session skips straight to the app', (t) async {
      server.signedInAs = 'admin';
      await pumpGate(t);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('shows sign-in with a sign-up link when sign-ups are on', (t) async {
      await pumpGate(t);
      expect(find.text('Sign in'), findsWidgets);
      expect(field('auth-confirm'), findsNothing);
      expect(find.text('New here? Create an account'), findsOneWidget);
    });

    testWidgets('hides the sign-up link when sign-ups are off', (t) async {
      server.allowSignups = false;
      await pumpGate(t);
      expect(find.text('New here? Create an account'), findsNothing);
      expect(find.text('Need an account? Ask whoever runs your local Bokses!'), findsOneWidget);
    });

    testWidgets('a wrong password shows the server\'s message', (t) async {
      await pumpGate(t);
      await fillAndSubmit(t, username: 'admin', password: 'wrong-password');
      expect(find.text('Invalid username or password'), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
    });

    testWidgets('the right password opens the app', (t) async {
      await pumpGate(t);
      await fillAndSubmit(t, username: 'admin', password: 'root-password');
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('signing up creates a regular account', (t) async {
      await pumpGate(t);
      await t.tap(find.text('New here? Create an account'));
      await t.pumpAndSettle();
      expect(find.text('Create an account'), findsWidgets);

      await fillAndSubmit(t, username: 'amy', password: 'amy-password', confirm: 'amy-password');
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(server.users['amy']!.isRoot, isFalse);
    });

    testWidgets('a taken username shows the server\'s message', (t) async {
      await pumpGate(t);
      await t.tap(find.text('New here? Create an account'));
      await t.pumpAndSettle();
      await fillAndSubmit(t, username: 'admin', password: 'another-pass', confirm: 'another-pass');
      expect(find.text('That username is already taken'), findsOneWidget);
    });

    testWidgets('the password visibility toggle works', (t) async {
      await pumpGate(t);
      EditableText password() =>
          t.widget<EditableText>(find.descendant(of: field('auth-password'), matching: find.byType(EditableText)));
      expect(password().obscureText, isTrue);
      await t.tap(find.byTooltip('Show password'));
      await t.pump();
      expect(password().obscureText, isFalse);
    });
  });

  group('server problems', () {
    testWidgets('an unreachable server shows a retry screen', (t) async {
      server.offline = true;
      await pumpGate(t);
      expect(find.textContaining("Couldn't reach the Bokses server."), findsOneWidget);

      server
        ..offline = false
        ..addUser('admin', 'root-password', isRoot: true);
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(find.text('Sign in'), findsWidgets);
    });
  });

  group('Account screen', () {
    Future<void> pumpAccount(WidgetTester t) async {
      await pumpGate(t);
      Navigator.of(t.element(find.byType(HomeScreen))).push(
        MaterialPageRoute(builder: (_) => const AccountScreen()),
      );
      await t.pumpAndSettle();
    }

    testWidgets('a regular account sees no admin controls', (t) async {
      server
        ..addUser('admin', 'root-password', isRoot: true)
        ..addUser('joe', 'joe-password')
        ..signedInAs = 'joe';
      await pumpAccount(t);
      expect(find.text('joe'), findsOneWidget);
      expect(find.text('Change password'), findsOneWidget);
      expect(find.text('MANAGE ACCOUNTS'), findsNothing);
    });

    testWidgets('root sees every account and the sign-up switch', (t) async {
      server
        ..addUser('admin', 'root-password', isRoot: true)
        ..addUser('joe', 'joe-password')
        ..signedInAs = 'admin';
      await pumpAccount(t);
      expect(find.text('MANAGE ACCOUNTS'), findsOneWidget);
      expect(find.text('joe'), findsOneWidget);

      await t.tap(find.byType(SwitchListTile));
      await t.pumpAndSettle();
      expect(server.allowSignups, isFalse);
    });

    testWidgets('root adds an account', (t) async {
      server
        ..addUser('admin', 'root-password', isRoot: true)
        ..signedInAs = 'admin';
      await pumpAccount(t);

      await t.tap(find.text('Add account'));
      await t.pumpAndSettle();
      final dialog = find.byType(AlertDialog);
      await t.enterText(find.descendant(of: dialog, matching: find.byType(TextFormField)).at(0), 'amy');
      await t.enterText(
          find.descendant(of: dialog, matching: find.byType(TextFormField)).at(1), 'amy-password');
      await t.tap(find.text('Add'));
      await t.pumpAndSettle();

      expect(server.users['amy']?.password, 'amy-password');
      expect(find.text('amy'), findsOneWidget);
    });

    testWidgets('root deletes an account after confirming', (t) async {
      server
        ..addUser('admin', 'root-password', isRoot: true)
        ..addUser('joe', 'joe-password')
        ..signedInAs = 'admin';
      await pumpAccount(t);

      await t.tap(find.byTooltip('Delete account'));
      await t.pumpAndSettle();
      expect(find.text('Delete account?'), findsOneWidget);
      await t.tap(find.widgetWithText(TextButton, 'Delete'));
      await t.pumpAndSettle();

      expect(server.users.containsKey('joe'), isFalse);
      expect(find.text('joe'), findsNothing);
    });

    testWidgets('changing password requires the minimum length', (t) async {
      server
        ..addUser('joe', 'joe-password')
        ..signedInAs = 'joe';
      await pumpAccount(t);

      await t.tap(find.text('Change password'));
      await t.pumpAndSettle();
      final fields = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextFormField));
      await t.enterText(fields.at(0), 'joe-password');
      await t.enterText(fields.at(1), 'short');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(find.text('At least 8 characters'), findsOneWidget);

      await t.enterText(fields.at(1), 'brand-new-pass');
      await t.tap(find.text('Save'));
      await t.pumpAndSettle();
      expect(server.users['joe']!.password, 'brand-new-pass');
    });

    testWidgets('sign out returns to sign-in', (t) async {
      server
        ..addUser('joe', 'joe-password')
        ..signedInAs = 'joe';
      await pumpAccount(t);

      await t.tap(find.text('Sign out'));
      await t.pumpAndSettle();

      expect(server.signedInAs, isNull);
      expect(find.byType(AccountScreen), findsNothing);
      expect(find.text('Sign in'), findsWidgets);
    });
  });
}
