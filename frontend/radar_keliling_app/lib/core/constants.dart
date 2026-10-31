/// Konstanta string yang digunakan di seluruh aplikasi.
/// Hindari string literal hardcoded — pakai konstanta ini.
class AppConstants {
  AppConstants._();

  // ── Role strings ──────────────────────────────────────────
  static const String roleBuyer = 'buyer';
  static const String roleMerchant = 'merchant';
  static const String roleAdmin = 'admin';

  // ── Call status strings ───────────────────────────────────
  static const String callStatusPending = 'pending';
  static const String callStatusAccept = 'accept';
  static const String callStatusUnanswered = 'unanswered';
  static const String callStatusCancelled = 'cancelled';
  static const String callStatusExpired = 'expired';

  // ── Review report status ──────────────────────────────────
  static const String reportStatusPending = 'pending';
  static const String reportStatusReviewed = 'reviewed';
  static const String reportStatusResolved = 'resolved';

  // ── Foto format ───────────────────────────────────────────
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];
  static const List<String> allowedImageMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];
}
