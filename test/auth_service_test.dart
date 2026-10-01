import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proviyaa_pos/application/auth_service.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/data/drift_device_session_store.dart';

/// The real backend (the Proviyaa backend, /v1/auth/login) needs a server and a
/// real staff account this session has neither of — see the header
/// backend end-to-end test (test/backend_end_to_end_test.dart). This fake is what
/// actually gets exercised; it's the offline-grant caching logic below
/// that matters most, and that logic is identical regardless of which
/// AuthBackend is plugged in.
class _FakeBackend implements AuthBackend {
  _FakeBackend(this._result);
  final ({String staffId, String staffName})? _result;

  @override
  Future<({String staffId, String staffName})> signInWithPassword(
      {required String email, required String password}) async {
    final result = _result;
    if (result == null) throw StateError('invalid credentials');
    return result;
  }
}

void main() {
  group('AuthService', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('a successful sign-in saves a 24-hour offline grant by default',
        () async {
      final auth = AuthService(
          _FakeBackend((staffId: 'staff-1', staffName: 'Amit K')),
          DriftDeviceSessionStore(db));

      final session = await auth.signIn(
          email: 'amit@example.com',
          password: 'x',
          deviceId: 'device-1',
          locationId: 'loc-1');

      expect(session.staffId, 'staff-1');
      expect(session.isValid, isTrue);
      expect(session.grantExpiresAt.difference(session.grantedAt),
          const Duration(hours: 24));
    });

    test('currentGrant reads the cached grant with no backend call at all',
        () async {
      final auth = AuthService(
          _FakeBackend((staffId: 'staff-1', staffName: 'Amit K')),
          DriftDeviceSessionStore(db));
      await auth.signIn(
          email: 'amit@example.com',
          password: 'x',
          deviceId: 'device-1',
          locationId: 'loc-1');

      // A backend that always throws proves this path never calls it.
      final offlineAuth =
          AuthService(_FakeBackend(null), DriftDeviceSessionStore(db));
      final grant = await offlineAuth.currentGrant('device-1');

      expect(grant, isNotNull);
      expect(grant!.staffName, 'Amit K');
    });

    test('an expired grant is returned, not hidden, with isValid false',
        () async {
      final auth = AuthService(
          _FakeBackend((staffId: 'staff-1', staffName: 'Amit K')),
          DriftDeviceSessionStore(db),
          offlineGrantDuration: const Duration(milliseconds: 1));

      await auth.signIn(
          email: 'amit@example.com',
          password: 'x',
          deviceId: 'device-1',
          locationId: 'loc-1');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      final grant = await auth.currentGrant('device-1');
      expect(grant, isNotNull,
          reason: 'PRD §11: expired grant data is preserved, not deleted');
      expect(grant!.isValid, isFalse);
    });

    test('no grant on this device returns null, distinct from an expired one',
        () async {
      final auth = AuthService(_FakeBackend(null), DriftDeviceSessionStore(db));
      expect(await auth.currentGrant('never-enrolled-device'), isNull);
    });

    test('signing in again on the same device replaces the previous grant',
        () async {
      final auth = AuthService(
          _FakeBackend((staffId: 'staff-1', staffName: 'Amit K')),
          DriftDeviceSessionStore(db));
      await auth.signIn(
          email: 'amit@example.com',
          password: 'x',
          deviceId: 'device-1',
          locationId: 'loc-1');

      final auth2 = AuthService(
          _FakeBackend((staffId: 'staff-2', staffName: 'Rahul S')),
          DriftDeviceSessionStore(db));
      await auth2.signIn(
          email: 'rahul@example.com',
          password: 'x',
          deviceId: 'device-1',
          locationId: 'loc-1');

      final grant = await auth.currentGrant('device-1');
      expect(grant!.staffId, 'staff-2');
      final rows = await db.select(db.deviceSessions).get();
      expect(rows, hasLength(1),
          reason: 'one device has one current grant, not a history table');
    });

    test('sign-in failure throws and leaves any previous grant untouched',
        () async {
      final auth = AuthService(
          _FakeBackend((staffId: 'staff-1', staffName: 'Amit K')),
          DriftDeviceSessionStore(db));
      await auth.signIn(
          email: 'amit@example.com',
          password: 'x',
          deviceId: 'device-1',
          locationId: 'loc-1');

      final failingAuth =
          AuthService(_FakeBackend(null), DriftDeviceSessionStore(db));
      await expectLater(
          failingAuth.signIn(
              email: 'amit@example.com',
              password: 'wrong',
              deviceId: 'device-1',
              locationId: 'loc-1'),
          throwsStateError);

      final grant = await auth.currentGrant('device-1');
      expect(grant!.staffId, 'staff-1',
          reason: 'a failed re-auth must not clobber the working grant');
    });

    test('signOut clears the grant for that device', () async {
      final auth = AuthService(
          _FakeBackend((staffId: 'staff-1', staffName: 'Amit K')),
          DriftDeviceSessionStore(db));
      await auth.signIn(
          email: 'amit@example.com',
          password: 'x',
          deviceId: 'device-1',
          locationId: 'loc-1');

      await auth.signOut('device-1');

      expect(await auth.currentGrant('device-1'), isNull);
    });
  });
}
