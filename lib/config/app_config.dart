/// Runtime configuration from --dart-define (see tool/run_local.*).
///
/// The app holds no Supabase URL or key: every central read/write goes
/// through the Proviyaa backend at [apiBaseUrl], which owns database
/// access. With no [apiBaseUrl] the app runs fully local (demo sign-in,
/// device database only).
class AppConfig {
  const AppConfig(
      {required this.appEnv,
      required this.dataMode,
      required this.apiBaseUrl,
      required this.syncEnabled});
  final String appEnv, dataMode, apiBaseUrl;
  final bool syncEnabled;
  bool get isLocalDemo => dataMode == 'local_demo';

  /// Signed-in accounts and cloud sync need the backend.
  bool get usesBackend => apiBaseUrl.isNotEmpty;

  factory AppConfig.fromDartDefines() => AppConfig(
      appEnv: const String.fromEnvironment('APP_ENV', defaultValue: 'local'),
      dataMode:
          const String.fromEnvironment('DATA_MODE', defaultValue: 'local_demo'),
      apiBaseUrl: const String.fromEnvironment('PROVIYAA_API_BASE_URL'),
      syncEnabled:
          const bool.fromEnvironment('SYNC_ENABLED', defaultValue: false));
}
