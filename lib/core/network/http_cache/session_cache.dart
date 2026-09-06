import 'package:reem/core/network/api_client.dart';
import 'package:reem/core/network/interceptors/cache_interceptor.dart';

/// The one place the session tells the response cache who is using the app.
///
/// Two rules, and they are not the same rule:
///
/// * **Binding** scopes new entries to an account, so two women sharing a
///   handset never read each other's feed even while both sessions are warm.
/// * **Forgetting** empties the disk on sign-out, so a device that changes
///   hands is not still carrying the last account's data in its cache folder.
///
/// Kept behind this seam so the auth layer does not have to know that the
/// cache is an HTTP interceptor at all.
abstract final class SessionCache {
  /// Scopes subsequent cached reads to [userId]. Pass null for a guest.
  static void bind(String? userId) => HttpCacheScope.set(userId);

  /// Drops every cached response and returns to the guest scope.
  static Future<void> forget() async {
    HttpCacheScope.set(null);
    await ApiClient.clearCache();
  }
}
