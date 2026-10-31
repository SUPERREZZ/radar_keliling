/// Semua konstanta konfigurasi aplikasi.
/// Ganti nilai placeholder setelah dapat info dari tim backend.
class AppConfig {
  AppConfig._();

  // ── REST API ──────────────────────────────────────────────
  /// Base URL tanpa trailing slash.
  static const String baseUrl = 'https://YOUR_DOMAIN/api/v1';

  // ── WebSocket (Laravel Reverb) ────────────────────────────
  /// Host Reverb — minta ke tim backend.
  static const String wsHost = 'YOUR_DOMAIN';

  /// Key Reverb — harus sama persis dengan nilai di .env backend.
  static const String reverbAppKey = 'YOUR_REVERB_APP_KEY';

  /// Port Reverb (default: 6001 untuk non-TLS, 443 untuk TLS).
  static const int wsPort = 6001;

  /// Gunakan TLS (wss://) di production.
  static const bool wsTls = false;

  // ── Aturan bisnis ─────────────────────────────────────────
  static const int radarRadiusMeters = 3000;
  static const int callRadiusMeters = 200;
  static const double callGpsAccuracyMaxMeters = 50.0;
  static const int gpsUpdateIntervalSeconds = 10;
  static const int locationStaleThresholdSeconds = 30;
  static const int maxMenuPhotos = 5;
  static const int maxPhotoSizeBytes = 2 * 1024 * 1024; // 2 MB
}
