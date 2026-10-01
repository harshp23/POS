import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// An error the Proviyaa backend returned (or a network failure, with
/// [status] 0). [code] is the backend's machine-readable error code.
class ApiException implements Exception {
  const ApiException(this.status, this.code, this.message, {this.details});
  final int status;
  final String code;
  final String message;
  final Object? details;

  /// No response at all — offline, DNS, timeout. Always worth retrying.
  bool get isNetwork => status == 0;
  bool get isUnauthorized => status == 401;

  @override
  String toString() => message;
}

class ApiSession {
  const ApiSession({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresAt,
    required this.userId,
    required this.email,
  });

  final String accessToken;
  final String refreshToken;

  /// Epoch seconds.
  final int expiresAt;
  final String userId;
  final String email;

  factory ApiSession.fromJson(Map<String, dynamic> j) => ApiSession(
        accessToken: j['access_token'] as String,
        refreshToken: j['refresh_token'] as String,
        expiresAt: (j['expires_at'] as num).toInt(),
        userId: (j['user'] as Map)['id'] as String,
        email: ((j['user'] as Map)['email'] ?? '') as String,
      );

  Map<String, Object> toJson() => {
        'access_token': accessToken,
        'refresh_token': refreshToken,
        'expires_at': expiresAt,
        'user': {'id': userId, 'email': email},
      };
}

/// The app's only way to reach central data: the Proviyaa backend
/// (backend/, PROVIYAA_API_BASE_URL). There is deliberately no Supabase
/// client in this app — the backend signs users in (master-admin accounts),
/// applies role and tenancy checks and is the only thing that talks to the
/// database.
class ProviyaaApiClient {
  ProviyaaApiClient({
    required String baseUrl,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 20),
    this.onSessionChanged,
  })  : _base = Uri.parse(baseUrl.endsWith('/') ? baseUrl : '$baseUrl/'),
        _http = httpClient ?? http.Client();

  final Uri _base;
  final http.Client _http;
  final Duration timeout;

  /// Called whenever the session is set, refreshed or cleared, so it can be
  /// persisted for the next app start.
  void Function(ApiSession? session)? onSessionChanged;

  ApiSession? _session;
  ApiSession? get session => _session;
  bool get isSignedIn => _session != null;

  /// The branch (org_locations id) requests act for; null = the backend's
  /// default (the organization's first active branch).
  String? locationId;

  /// The restaurant (organizations id) a platform admin is working in, sent
  /// as X-Organization-Id. Restaurant accounts leave it null — the backend
  /// uses the account's own organization.
  String? organizationId;

  Future<ApiSession>? _refreshing;

  /// When the server last answered a signed-in request successfully.
  DateTime? lastServerContact;

  set session(ApiSession? s) {
    _session = s;
    onSessionChanged?.call(s);
  }

  // ── auth ────────────────────────────────────────────────────────────

  /// Signs in; returns the backend's `me` payload (organization, role,
  /// panel, branches).
  Future<Map<String, dynamic>> login(String email, String password) async {
    final data = await _send('POST', 'v1/auth/login',
        body: {'email': email, 'password': password}, authenticated: false);
    session = ApiSession.fromJson(data['session'] as Map<String, dynamic>);
    return (data['me'] as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> me() async =>
      (await get('v1/auth/me') as Map).cast<String, dynamic>();

  /// Changes the password. The server ends every earlier session (this
  /// token included) and returns a new one, which replaces it here.
  Future<void> changePassword(String current, String next) async {
    final data = await _send('POST', 'v1/auth/change-password',
        body: {'current_password': current, 'new_password': next});
    final fresh = data is Map ? data['session'] : null;
    if (fresh is Map) {
      session = ApiSession.fromJson(fresh.cast<String, dynamic>());
    }
  }

  Future<void> logout() async {
    try {
      if (_session != null) await _send('POST', 'v1/auth/logout');
    } on ApiException {
      // Signing out locally matters more than telling the server.
    } finally {
      session = null;
      organizationId = null;
      locationId = null;
    }
  }

  /// Restores a session saved by a previous run; returns the fresh `me`
  /// (the token is refreshed on the way if it expired).
  Future<Map<String, dynamic>> resume(ApiSession saved,
      {String? organizationId, String? locationId}) async {
    _session = saved;
    this.organizationId = organizationId;
    this.locationId = locationId;
    return me();
  }

  Future<ApiSession> _refresh() {
    return _refreshing ??= () async {
      try {
        final s = _session;
        if (s == null) {
          throw const ApiException(401, 'unauthorized', 'Sign in required.');
        }
        final data = await _send('POST', 'v1/auth/refresh',
            body: {'refresh_token': s.refreshToken}, authenticated: false);
        final next =
            ApiSession.fromJson(data['session'] as Map<String, dynamic>);
        session = next;
        return next;
      } finally {
        _refreshing = null;
      }
    }();
  }

  // ── verbs ───────────────────────────────────────────────────────────

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body: body);
  Future<dynamic> put(String path, Object? body) =>
      _send('PUT', path, body: body);
  Future<dynamic> patch(String path, Object? body) =>
      _send('PATCH', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// The whole response body ({data, summary, total, message …}) instead
  /// of just its data — for endpoints that send more than data.
  Future<Map<String, dynamic>> getEnvelope(String path,
          {Map<String, String>? query}) async =>
      ((await _send('GET', path, query: query, envelope: true)) as Map)
          .cast<String, dynamic>();
  Future<Map<String, dynamic>> postEnvelope(String path,
          [Object? body]) async =>
      ((await _send('POST', path, body: body, envelope: true)) as Map? ??
              const {})
          .cast<String, dynamic>();

  Future<dynamic> _send(String method, String path,
      {Object? body,
      Map<String, String>? query,
      bool authenticated = true,
      bool retried = false,
      bool networkRetried = false,
      bool envelope = false,
      Duration? timeoutOverride}) async {
    final uri = _base.resolve(path).replace(queryParameters: query);
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (organizationId != null) {
      request.headers['X-Organization-Id'] = organizationId!;
    }
    if (authenticated) {
      final s = _session;
      if (s == null) {
        throw const ApiException(401, 'unauthorized', 'Sign in required.');
      }
      request.headers['Authorization'] = 'Bearer ${s.accessToken}';
      if (locationId != null) request.headers['X-Location-Id'] = locationId!;
    }

    http.Response res;
    try {
      res = await http.Response.fromStream(
          await _http.send(request).timeout(timeoutOverride ?? timeout));
    } on TimeoutException {
      throw const ApiException(
          0, 'timeout', 'The Proviyaa server did not answer in time.');
    } catch (e) {
      // A kept-alive connection the server has just closed fails at once;
      // a read is safe to repeat on a fresh connection.
      if (method == 'GET' && !networkRetried) {
        return _send(method, path,
            body: body,
            query: query,
            authenticated: authenticated,
            retried: retried,
            networkRetried: true,
            envelope: envelope,
            timeoutOverride: timeoutOverride);
      }
      throw ApiException(0, 'network', 'Cannot reach the Proviyaa server: $e');
    }

    if (res.statusCode == 401 && authenticated && !retried) {
      await _refresh();
      return _send(method, path,
          body: body,
          query: query,
          retried: true,
          envelope: envelope,
          timeoutOverride: timeoutOverride);
    }
    if (authenticated && res.statusCode < 400) {
      lastServerContact = DateTime.now();
    }
    if (res.statusCode == 204 || res.body.isEmpty) return null;

    Object? decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw ApiException(res.statusCode, 'bad_response',
          'Unexpected response from the Proviyaa server.');
    }
    if (res.statusCode >= 400) {
      final err = decoded is Map ? decoded['error'] : null;
      if (err is Map) {
        throw ApiException(res.statusCode, '${err['code'] ?? 'error'}',
            '${err['message'] ?? 'Request failed.'}',
            details: err['details']);
      }
      throw ApiException(res.statusCode, 'error', 'Request failed.');
    }
    if (envelope) return decoded;
    return decoded is Map ? decoded['data'] : decoded;
  }

  /// Longer timeout for sync batches.
  Future<dynamic> postLong(String path, Object? body) => _send('POST', path,
      body: body, timeoutOverride: const Duration(seconds: 90));

  void close() => _http.close();
}
