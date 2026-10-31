/// Semua path endpoint API — satu-satunya tempat mendefinisikan string endpoint.
class Endpoints {
  Endpoints._();

  // Auth
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String emailVerify = '/auth/email/verify';
  static const String emailResend = '/auth/email/resend';
  static const String deleteAccount = '/account';
  static const String fcmToken = '/auth/fcm-token';

  // Merchant — self
  static const String merchantProfile = '/merchant/profile';
  static const String merchantProfilePhoto = '/merchant/profile/photo';
  static const String sellingStart = '/merchant/selling/start';
  static const String sellingStop = '/merchant/selling/stop';
  static const String merchantLocation = '/merchant/location';
  static const String merchantMenus = '/merchant/menus';
  static String merchantMenuById(String id) => '/merchant/menus/$id';
  static String merchantMenuPhotos(String menuId) =>
      '/merchant/menus/$menuId/photos';
  static String deleteMenuPhoto(String photoId) =>
      '/merchant/menu-photos/$photoId';

  // Merchant — public (buyer)
  static String merchantPublicProfile(String id) => '/merchants/$id';
  static String merchantMenusPublic(String id) => '/merchants/$id/menus';
  static String merchantRating(String id) => '/merchants/$id/rating';

  // Radar
  static const String radarMerchants = '/radar/merchants';

  // Calls
  static const String calls = '/calls';
  static String callById(String id) => '/calls/$id';
  static String callAnswer(String id) => '/calls/$id/answer';
  static String callUnanswered(String id) => '/calls/$id/unanswered';
  static String callCancel(String id) => '/calls/$id/cancel';

  // Reviews
  static String callReview(String callId) => '/calls/$callId/review';
  static String reviewReport(String reviewId) => '/reviews/$reviewId/reports';

  // Admin
  static const String adminReviewReports = '/admin/review-reports';
  static String adminHideReview(String id) => '/admin/reviews/$id/hide';
}
