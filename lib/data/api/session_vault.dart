import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api_client.dart';

/// What the app needs to reopen signed in: the backend session, the
/// restaurant/branch it was working in, and the last `me` payload (so a
/// restart without internet still opens the right restaurant).
class SavedLogin {
  const SavedLogin({
    required this.session,
    this.organizationId,
    this.locationId,
    this.me,
    this.verifiedAt,
  });

  /// How long the app may run from this saved login without reaching the
  /// server (the offline session grant).
  static const offlineGrant = Duration(hours: 24);

  final ApiSession session;
  final String? organizationId;
  final String? locationId;
  final Map<String, dynamic>? me;

  /// When the server last confirmed this login (sign-in or a successful
  /// call). Offline use is allowed for [offlineGrant] after it.
  final DateTime? verifiedAt;

  bool offlineExpired(DateTime now) =>
      verifiedAt == null || now.difference(verifiedAt!) > offlineGrant;

  SavedLogin copyWith(
          {ApiSession? session,
          Map<String, dynamic>? me,
          DateTime? verifiedAt}) =>
      SavedLogin(
        session: session ?? this.session,
        organizationId: organizationId,
        locationId: locationId,
        me: me ?? this.me,
        verifiedAt: verifiedAt ?? this.verifiedAt,
      );

  Map<String, Object?> toJson() => {
        'session': session.toJson(),
        'organization_id': organizationId,
        'location_id': locationId,
        'me': me,
        'verified_at': verifiedAt?.toUtc().toIso8601String(),
      };

  factory SavedLogin.fromJson(Map<String, dynamic> j) => SavedLogin(
        session:
            ApiSession.fromJson((j['session'] as Map).cast<String, dynamic>()),
        organizationId: j['organization_id'] as String?,
        locationId: j['location_id'] as String?,
        me: (j['me'] as Map?)?.cast<String, dynamic>(),
        verifiedAt: DateTime.tryParse('${j['verified_at'] ?? ''}'),
      );
}

abstract class SessionVault {
  Future<SavedLogin?> read();

  /// null forgets the saved login (sign-out, revoked token).
  Future<void> write(SavedLogin? login);
}

/// Keeps the login in the OS keystore (Windows Credential Manager, Keychain,
/// Android Keystore, libsecret). Failures never block the app — the user
/// just signs in again.
class SecureSessionVault implements SessionVault {
  SecureSessionVault([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  static const _key = 'proviyaa.login.v1';
  final FlutterSecureStorage _storage;

  @override
  Future<SavedLogin?> read() async {
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return null;
      return SavedLogin.fromJson(
          (jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (e) {
      debugPrint('Saved login unreadable: $e');
      return null;
    }
  }

  @override
  Future<void> write(SavedLogin? login) async {
    try {
      if (login == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: jsonEncode(login.toJson()));
      }
    } catch (e) {
      debugPrint('Could not save login: $e');
    }
  }
}

class MemorySessionVault implements SessionVault {
  MemorySessionVault([this.saved]);
  SavedLogin? saved;

  @override
  Future<SavedLogin?> read() async => saved;

  @override
  Future<void> write(SavedLogin? login) async => saved = login;
}
