import 'package:reem/core/shared/entities/user.dart';

/// Capability checks derived from the current user's role. These mirror the
/// server-side RBAC for UX purposes only — the backend is the source of truth
/// and independently rejects unauthorized requests.
class Permissions {
  const Permissions(this.role);

  final UserRole role;

  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;
  bool get isSupport => role == UserRole.support;
  bool get isSeller => role == UserRole.seller || isAdmin;
  bool get isCustomer => role == UserRole.customer;

  // Seller-only content management.
  bool get canManageProducts => isSeller;
  bool get canPublishPosts => isSeller;
  bool get canCreateStories => isSeller;
  bool get canViewStoryAnalytics => isSeller;

  bool get canReviewSellers => isAdmin || isSupport;
  bool get canManageUsers => isAdmin || isSupport;

  // Customer interactions are open to any authenticated user.
  bool get canInteract => true;
}
