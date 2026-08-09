/// Centralized environment configuration.
///
/// In development, defaults point to localhost.
/// For production, pass values at build time:
///   flutter build web --dart-define=DIRECTUS_URL=https://cms.edumynt.org \
///                     --dart-define=POWERSYNC_URL=https://powersync.edumynt.org
class AppConfig {
  static const String directusUrl = String.fromEnvironment(
    'DIRECTUS_URL',
    defaultValue: 'http://localhost:8056',
  );

  static const String powersyncUrl = String.fromEnvironment(
    'POWERSYNC_URL',
    defaultValue: 'http://localhost:8080',
  );

  /// Build the Directus asset URL for a given file UUID.
  static String? assetUrl(String? fileId) {
    if (fileId == null || fileId.isEmpty) return null;
    return '$directusUrl/assets/$fileId';
  }
}
