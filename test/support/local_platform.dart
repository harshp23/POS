import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

/// The whole Proviyaa platform on this machine, for end-to-end tests: the
/// POS backend (backend/, `npm run start:local` — a real Postgres via
/// PGlite with master-admin's migrations, the live-schema snapshot and the
/// POS migration) and master-admin's own Express backend on the same
/// database and JWT secret. Nothing here touches Supabase.
class LocalPlatform {
  LocalPlatform({
    this.platformEmail = 'superadmin@proviyaa.test',
    this.platformPassword = 'E2e-Platform-2026',
    this.vendorEmail = 'admin@spicybistro.com',
    this.vendorPassword = 'E2e-Password-2026',
    this.jwtSecret = 'e2e-shared-jwt-secret-for-both-backends-0123456789',
  });

  final String platformEmail;
  final String platformPassword;
  final String vendorEmail;
  final String vendorPassword;
  final String jwtSecret;

  static bool get posBackendInstalled =>
      File('backend/node_modules/tsx/package.json').existsSync();
  static bool get masterAdminInstalled =>
      File('master-admin/backend/node_modules/ts-node/package.json')
          .existsSync();

  late final String posUrl;
  late final String masterUrl;
  late final Directory _dataDir;
  Process? _pos;
  Process? _master;
  final posLog = StringBuffer();
  final masterLog = StringBuffer();

  Future<void> start({bool withMasterAdmin = true}) async {
    _dataDir = Directory.systemTemp.createTempSync('proviyaa_e2e_');
    final random = Random();
    final port = 20000 + random.nextInt(10000);
    final dbPort = 30000 + random.nextInt(10000);
    final masterPort = 40000 + random.nextInt(10000);
    posUrl = 'http://127.0.0.1:$port';
    masterUrl = 'http://127.0.0.1:$masterPort/api';
    _pos = await Process.start(
      'node',
      ['--import', 'tsx', 'src/local-server.ts'],
      workingDirectory: 'backend',
      environment: {
        'PORT': '$port',
        'LOCAL_DB_PORT': '$dbPort',
        'LOCAL_DATA_DIR': _dataDir.path,
        'LOCAL_SEED_EMAIL': vendorEmail,
        'LOCAL_SEED_PASSWORD': vendorPassword,
        'LOCAL_PLATFORM_EMAIL': platformEmail,
        'LOCAL_PLATFORM_PASSWORD': platformPassword,
        'JWT_SECRET': jwtSecret,
      },
      runInShell: Platform.isWindows,
    );
    await _waitFor(_pos!, posLog, 'listening', 'POS backend');
    if (!withMasterAdmin) return;
    _master = await Process.start(
      'node',
      ['-r', 'ts-node/register/transpile-only', 'src/index.ts'],
      workingDirectory: 'master-admin/backend',
      environment: {
        'PORT': '$masterPort',
        'NODE_ENV': 'development',
        'DATABASE_URL':
            'postgresql://postgres:postgres@127.0.0.1:$dbPort/postgres',
        'JWT_SECRET': jwtSecret,
      },
      runInShell: Platform.isWindows,
    );
    await _waitFor(_master!, masterLog, 'Server running', 'master-admin');
  }

  Future<void> stop() async {
    for (final p in [_master, _pos]) {
      if (p == null) continue;
      // On Windows the process is a cmd.exe wrapper: kill its whole tree
      // first — killing the wrapper alone orphans the node server.
      if (Platform.isWindows) {
        await Process.run('taskkill', ['/F', '/T', '/PID', '${p.pid}']);
      }
      p.kill();
      await p.exitCode
          .timeout(const Duration(seconds: 10), onTimeout: () => -1);
    }
    try {
      _dataDir.deleteSync(recursive: true);
    } catch (_) {}
  }

  static Future<void> _waitFor(
      Process p, StringBuffer log, String marker, String name) {
    final up = Completer<void>();
    p.stdout.transform(utf8.decoder).listen((s) {
      log.write(s);
      if (s.contains(marker) && !up.isCompleted) up.complete();
    });
    p.stderr.transform(utf8.decoder).listen(log.write);
    return up.future.timeout(const Duration(seconds: 120),
        onTimeout: () => throw StateError('$name did not start:\n$log'));
  }

  /// A call to master-admin's REST API (/api/...), as its React panel
  /// makes it. Uses a real dart:io client even inside widget tests.
  Future<Map<String, dynamic>> master(String method, String path,
      {String? token, Object? body}) async {
    final client = realHttpClient();
    try {
      final req = await client.openUrl(method, Uri.parse('$masterUrl$path'));
      req.headers.contentType = ContentType.json;
      if (token != null) req.headers.set('Authorization', 'Bearer $token');
      if (body != null) req.write(jsonEncode(body));
      final res = await req.close();
      final text = await res.transform(utf8.decoder).join();
      if (res.statusCode < 200 || res.statusCode > 201) {
        throw StateError(
            'master-admin $method $path → ${res.statusCode} $text\n$masterLog');
      }
      return (jsonDecode(text) as Map).cast<String, dynamic>();
    } finally {
      client.close();
    }
  }
}

/// flutter_test replaces dart:io HTTP with a fake that answers 400 inside
/// widget tests; these end-to-end tests talk to real local servers.
HttpClient realHttpClient() =>
    HttpOverrides.runWithHttpOverrides(HttpClient.new, _RealHttp());

class _RealHttp extends HttpOverrides {}
