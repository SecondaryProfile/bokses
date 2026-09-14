import 'package:shelf/shelf_io.dart' as io;

import 'package:bokses_server/src/api.dart';
import 'package:bokses_server/src/config.dart';
import 'package:bokses_server/src/store.dart';

Future<void> main() async {
  final config = Config.fromEnvironment();

  if (config.dbPassword == 'change-me') {
    // ignore: avoid_print
    print('bokses-server: DB_PASSWORD is still the placeholder from .env.example. '
        'Set a real password in .env.');
    return;
  }

  final store = await Store.connect(config);
  // ignore: avoid_print
  print('bokses-server: connected to Postgres at ${config.dbHost}:${config.dbPort}, '
      'schema up to date');

  final handler = buildHandler(store);
  await io.serve(handler, config.bindHost, config.bindPort);
  // ignore: avoid_print
  print('bokses-server: listening on ${config.bindHost}:${config.bindPort}');
}
