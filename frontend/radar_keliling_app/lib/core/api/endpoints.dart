/// Semua path endpoint API — satu-satunya tempat mendefinisikan string endpoint.
class Endpoints {
  Endpoints._();

  // Auth (all start with /v1)
  static const String register = '/v1/auth/register';
  static const String login = '/v1/auth/login';
  static const String logout = '/v1/auth/logout';
  static const String me = '/v1/auth/me';
  static const String emailVerify = '/v1/auth/verify-email';
  static const String emailResend = '/v1/auth/resend-verification';
  static const String deleteAccount = '/v1/account';
  static const String fcmToken = '/v1/auth/fcm-token';

  // Merchant — self (all start with /v1)
  static const String merchantProfile = '/v1/merchant/profile';
  static const String merchantProfilePhoto = '/v1/merchant/profile/photo';
  static const String sellingStart = '/v1/merchant/selling/start';
  static const String sellingStop = '/v1/merchant/selling/stop';
  static const String merchantLocation = '/v1/merchant/location';
  static const String merchantMenus = '/v1/merchant/menus';
  static String merchantMenuById(String id) => '/v1/merchant/menus/$id';
  static String merchantMenuAvailability(String id) =>
      '/v1/merchant/menus/$id/availability';
  static String merchantMenuPhotos(String menuId) =>
      '/v1/merchant/menus/$menuId/photos';
  static String deleteMenuPhoto(String photoId) =>
      '/v1/merchant/menu-photos/$photoId';

  // Merchant — public (buyer) (all start with /v1)
  static String merchantPublicProfile(String id) => '/v1/merchants/$id';
  static String merchantMenusPublic(String id) => '/v1/merchants/$id/menus';
  static String merchantRating(String id) => '/v1/merchants/$id/rating';

  // Radar (all start with /v1)
  static const String radarMerchants = '/v1/radar/merchants';

  // Calls (all start with /v1)
  static const String calls = '/v1/calls';
  static String callById(String id) => '/v1/calls/$id';
  static String callAnswer(String id) => '/v1/calls/$id/accept';
  static String callUnanswered(String id) => '/v1/calls/$id/unanswered';
  static String callCancel(String id) => '/v1/calls/$id/cancel';

  // Reviews (all start with /v1)
  static String callReview(String callId) => '/v1/calls/$callId/review';
  static String reviewReport(String reviewId) =>
      '/v1/reviews/$reviewId/reports';

  // Admin (all start with /v1)
  static const String adminReviewReports = '/v1/admin/review-reports';
  static String adminHideReview(String id) => '/v1/admin/reviews/$id/hide';
}
