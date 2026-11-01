/// Semua konstanta konfigurasi aplikasi.
/// Ganti nilai placeholder setelah dapat info dari tim backend.
class AppConfig {
  AppConfig._();

  // ── DEMO MODE ─────────────────────────────────────────────
  /// Set true untuk testing tanpa backend (gunakan dummy data)
  static const bool isDemoMode = false;

  // ── REST API ──────────────────────────────────────────────
  /// Base URL tanpa trailing slash. Path endpoint sudah mengandung `/v1`.
  static const String baseUrl = 'http://backend.jh-beon.cloud/api';

  /// Origin backend untuk file statis (mis. foto profil/menu).
  static String get _mediaOrigin {
    final uri = Uri.parse(baseUrl);
    return '${uri.scheme}://${uri.authority}';
  }

  /// Memperbaiki URL media yang masih menunjuk ke localhost atau relatif.
  static String resolveMediaUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return raw;

    final uri = Uri.tryParse(raw);
    if (uri != null && uri.hasScheme) {
      final isLocalHost =
          uri.host == 'localhost' ||
          uri.host == '127.0.0.1' ||
          uri.host == '0.0.0.0';
      if (!isLocalHost) return raw;

      final path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
      final query = uri.hasQuery ? '?${uri.query}' : '';
      return '$_mediaOrigin$path$query';
    }

    final path = raw.startsWith('/') ? raw : '/$raw';
    return '$_mediaOrigin$path';
  }

  // ── WebSocket (Laravel Reverb) ────────────────────────────
  /// Host Reverb — dari Jelastic Endpoint Access URL.
  static const String wsHost = 'node37310-backend.jh-beon.cloud';

  /// Key Reverb — harus sama persis dengan nilai di .env backend.
  static const String reverbAppKey = 'radarkelilingkey';

  /// Port Reverb (Public Port dari Jelastic Endpoint).
  static const int wsPort = 11046;

  /// Gunakan TLS (wss://) di production.
  static const bool wsTls = false;

  // ── Aturan bisnis ─────────────────────────────────────────
  static const int radarRadiusMeters = 3000;
  static const int callRadiusMeters = 200;
  static const double callGpsAccuracyMaxMeters = 50.0;
  static const int gpsUpdateIntervalSeconds = 10;
  static const int locationStaleThresholdSeconds = 60;
  static const int maxMenuPhotos = 5;
  static const int maxPhotoSizeBytes = 2 * 1024 * 1024; // 2 MB
}
