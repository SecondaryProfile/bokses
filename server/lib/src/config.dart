import 'dart:io' show Platform;

/// Server configuration, read entirely from the environment. See
/// docker-compose.yml for the variables this expects.
class Config {
  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUser;
  final String dbPassword;

  /// The API server binds only to loopback — nginx is the only thing that
  /// talks to it, proxying /api/ from the outside (see docker/nginx.conf).
  final String bindHost;
  final int bindPort;

  Config({
    required this.dbHost,
    required this.dbPort,
    required this.dbName,
    required this.dbUser,
    required this.dbPassword,
    this.bindHost = '127.0.0.1',
    this.bindPort = 8081,
  });

  factory Config.fromEnvironment() {
    final env = Platform.environment;
    return Config(
      dbHost: env['DB_HOST'] ?? 'postgres',
      dbPort: int.tryParse(env['DB_PORT'] ?? '') ?? 5432,
      dbName: env['DB_NAME'] ?? 'bokses',
      dbUser: env['DB_USER'] ?? 'bokses',
      dbPassword: env['DB_PASSWORD'] ?? '',
    );
  }
}
