import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:bokses/services/greeting_service.dart';

void main() {
  final originalFactory = GreetingService.clientFactory;
  tearDown(() => GreetingService.clientFactory = originalFactory);

  test('picks a template from the fetched CSV and fills in the name', () async {
    GreetingService.clientFactory = () => MockClient((_) async => http.Response(
          'greeting\nHi, {name}!\n',
          200,
        ));
    final greeting = await GreetingService.greetingFor('Alice');
    expect(greeting, 'Hi, Alice!');
  });

  test('skips the header row and blank lines', () async {
    GreetingService.clientFactory = () => MockClient((_) async => http.Response(
          'greeting\n\nWelcome, {name}!\n\n',
          200,
        ));
    final greeting = await GreetingService.greetingFor('Bo');
    expect(greeting, 'Welcome, Bo!');
  });

  test('falls back to a built-in template on a non-200 response', () async {
    GreetingService.clientFactory = () => MockClient((_) async => http.Response('', 404));
    final greeting = await GreetingService.greetingFor('Cass');
    expect(greeting, contains('Cass'));
    expect(greeting, isNot(contains('{name}')));
  });

  test('falls back when the response looks like the SPA fallback HTML', () async {
    GreetingService.clientFactory =
        () => MockClient((_) async => http.Response('<!DOCTYPE html><html></html>', 200));
    final greeting = await GreetingService.greetingFor('Dee');
    expect(greeting, contains('Dee'));
  });

  test('falls back when the request throws', () async {
    GreetingService.clientFactory = () => MockClient((_) async => throw Exception('offline'));
    final greeting = await GreetingService.greetingFor('Evan');
    expect(greeting, contains('Evan'));
  });
}
