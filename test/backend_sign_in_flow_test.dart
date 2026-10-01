import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:proviyaa_pos/config/app_config.dart';
import 'package:proviyaa_pos/data/api/api_client.dart';
import 'package:proviyaa_pos/data/api/session_vault.dart';
import 'package:proviyaa_pos/data/app_database.dart';
import 'package:proviyaa_pos/main.dart';
import 'package:proviyaa_pos/presentation/franchise/franchise_vendor_shell.dart';

/// The app's sign-in flow against a scripted backend: master-admin platform
/// admins pick a restaurant, and a saved login reopens the app — online,
/// offline, or not at all once the backend revokes it.
void main() {
  const base = 'http://backend.test';
  const config = AppConfig(
    appEnv: 'local',
    dataMode: 'backend',
    apiBaseUrl: base,
    syncEnabled: false,
  );

  const spicy = {'id': 'org-1', 'name': 'Spicy Bistro', 'status': 'Active'};
  const latur = {
    'id': 'org-2',
    'name': 'Latur Tiffin House',
    'status': 'Active'
  };

  Map<String, Object?> session(String email) => {
        'access_token': 'token-$email',
        'refresh_token': 'token-$email',
        'expires_at': 4102444800,
        'user': {'id': 'user-1', 'email': email},
      };

  Map<String, Object?> me(String email,
          {Map<String, Object?>? org, bool platform = false}) =>
      {
        'user': {'id': 'user-1', 'email': email},
        'platform_admin': platform,
        'organization': org,
        'member': {
          'full_name': 'Test User',
          'email': email,
          'role': org == null ? null : 'org_owner',
          'role_name': org == null ? null : 'Owner',
        },
        'panel': 'vendor',
        'capabilities': org == null
            ? {}
            : {
                'franchise': ['read', 'write'],
                'master': ['read', 'write'],
                'operations': ['read', 'write'],
              },
        'locations': [
          {'id': 'loc-1', 'name': 'Main Branch', 'code': 'MAIN'},
        ],
        'location': {'id': 'loc-1', 'name': 'Main Branch'},
        if (platform) 'organizations': [spicy, latur],
      };

  http.Response json(int status, Object body) =>
      http.Response(jsonEncode(body), status,
          headers: {'content-type': 'application/json'});

  // Everything the tests don't script (sync, franchise, inbox) is simply
  // unavailable — the app must cope.
  http.Response unavailable() => json(503, {
        'error': {'code': 'unavailable', 'message': 'not scripted'}
      });

  // A desktop-sized window, as the vendor panel expects. As in
  // master_navigation_test: the test binding blocks network images and
  // renders with the Ahem font (small overflows), so both are ignored.
  Future<AppDatabase> memoryDb(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final oldOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.library == 'image resource service') return;
      if (details.exceptionAsString().contains('RenderFlex overflowed')) return;
      oldOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = oldOnError);
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    return db;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  }

  testWidgets('a platform admin signs in and picks the restaurant to open',
      (tester) async {
    const email = 'superadmin@proviyaa.test';
    final meCalls = <String?>[];
    final client = MockClient((req) async {
      final path = req.url.path;
      if (path == '/v1/auth/login') {
        return json(200, {
          'data': {
            'session': session(email),
            'me': me(email, platform: true),
          }
        });
      }
      if (path == '/v1/auth/me') {
        final org = req.headers['X-Organization-Id'];
        meCalls.add(org);
        return json(200, {
          'data': me(email, org: org == 'org-2' ? latur : null, platform: true),
        });
      }
      return unavailable();
    });
    final vault = MemorySessionVault();

    await tester.pumpWidget(ProviyaaPosApp(
      config: config,
      database: await memoryDb(tester),
      apiClient: ProviyaaApiClient(baseUrl: base, httpClient: client),
      sessionVault: vault,
    ));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), 'Test-Password-2026');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Open which restaurant?'), findsOneWidget);
    expect(find.text('Spicy Bistro'), findsOneWidget);
    await tester.tap(find.text('Latur Tiffin House'));
    await tester.pumpAndSettle();

    expect(find.byType(FranchiseVendorShell), findsOneWidget);
    expect(meCalls, contains('org-2'));
    // The choice is remembered for the next start.
    expect(vault.saved?.organizationId, 'org-2');
    expect(vault.saved?.session.accessToken, 'token-$email');

    await unmount(tester);
  });

  testWidgets('a restaurant account without a restaurant is turned away',
      (tester) async {
    const email = 'orphan@proviyaa.test';
    final client = MockClient((req) async {
      if (req.url.path == '/v1/auth/login') {
        return json(200, {
          'data': {'session': session(email), 'me': me(email)}
        });
      }
      if (req.url.path == '/v1/auth/logout') return http.Response('', 204);
      return unavailable();
    });
    final vault = MemorySessionVault();

    await tester.pumpWidget(ProviyaaPosApp(
      config: config,
      database: await memoryDb(tester),
      apiClient: ProviyaaApiClient(baseUrl: base, httpClient: client),
      sessionVault: vault,
    ));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), email);
    await tester.enterText(find.byType(TextField).at(1), 'Test-Password-2026');
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not linked to a restaurant'), findsOneWidget);
    expect(find.byType(FranchiseVendorShell), findsNothing);
    expect(vault.saved, isNull);

    await unmount(tester);
  });

  SavedLogin saved(String email, {Duration since = const Duration(hours: 1)}) =>
      SavedLogin(
        session: ApiSession.fromJson(session(email)),
        locationId: 'loc-1',
        me: me(email, org: spicy),
        verifiedAt: DateTime.now().subtract(since),
      );

  testWidgets('a saved login reopens the restaurant without signing in',
      (tester) async {
    const email = 'owner@spicybistro.test';
    String? auth;
    final client = MockClient((req) async {
      if (req.url.path == '/v1/auth/me') {
        auth = req.headers['Authorization'];
        return json(200, {'data': me(email, org: spicy)});
      }
      return unavailable();
    });

    await tester.pumpWidget(ProviyaaPosApp(
      config: config,
      database: await memoryDb(tester),
      apiClient: ProviyaaApiClient(baseUrl: base, httpClient: client),
      sessionVault: MemorySessionVault(saved(email)),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FranchiseVendorShell), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
    expect(auth, 'Bearer token-$email');

    await unmount(tester);
  });

  testWidgets('offline, the saved login still opens the POS', (tester) async {
    const email = 'owner@spicybistro.test';
    final client = MockClient(
        (req) async => throw const SocketLikeException('no route to host'));

    await tester.pumpWidget(ProviyaaPosApp(
      config: config,
      database: await memoryDb(tester),
      apiClient: ProviyaaApiClient(baseUrl: base, httpClient: client),
      sessionVault: MemorySessionVault(saved(email)),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FranchiseVendorShell), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('offline for more than 24 hours: sign in again, with a reason',
      (tester) async {
    const email = 'owner@spicybistro.test';
    final client = MockClient(
        (req) async => throw const SocketLikeException('no route to host'));
    final vault =
        MemorySessionVault(saved(email, since: const Duration(hours: 25)));

    await tester.pumpWidget(ProviyaaPosApp(
      config: config,
      database: await memoryDb(tester),
      apiClient: ProviyaaApiClient(baseUrl: base, httpClient: client),
      sessionVault: vault,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FranchiseVendorShell), findsNothing);
    expect(find.byKey(const Key('login-notice')), findsOneWidget);
    expect(find.textContaining('more than 24 hours'), findsOneWidget);

    await unmount(tester);
  });

  testWidgets('a revoked login goes back to the sign-in screen',
      (tester) async {
    const email = 'suspended@spicybistro.test';
    final client = MockClient((req) async => json(401, {
          'error': {'code': 'unauthorized', 'message': 'Session expired.'}
        }));
    final vault = MemorySessionVault(saved(email));

    await tester.pumpWidget(ProviyaaPosApp(
      config: config,
      database: await memoryDb(tester),
      apiClient: ProviyaaApiClient(baseUrl: base, httpClient: client),
      sessionVault: vault,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(FranchiseVendorShell), findsNothing);
    expect(find.text('Sign In'), findsWidgets);
    expect(vault.saved, isNull);

    await unmount(tester);
  });
}

class SocketLikeException implements Exception {
  const SocketLikeException(this.message);
  final String message;
  @override
  String toString() => message;
}
