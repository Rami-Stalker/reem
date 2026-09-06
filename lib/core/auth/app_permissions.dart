/// The permission keys the API speaks, mirrored for the client.
///
/// These strings are a contract with `backend/src/common/permissions.ts`. The
/// console uses them for one purpose only — deciding what to *offer* — so a
/// key that drifts out of sync degrades a menu, never a guard. Keeping them in
/// one file rather than sprinkled as literals is what makes that drift
/// findable; a literal `'finance:read'` typed into a widget is not.
abstract final class AppPermissions {
  static const adminDashboard = 'admin:dashboard';
  static const userManage = 'user:manage';
  static const sellerVerificationReview = 'seller_verification:review';
  static const productManage = 'product:manage';
  static const contentModerate = 'content:moderate';
  static const orderRead = 'order:read';
  static const orderManage = 'order:manage';
  static const supportRead = 'support:read';
  static const supportWrite = 'support:write';
  static const financeRead = 'finance:read';
  static const financeWrite = 'finance:write';
  static const analyticsRead = 'analytics:read';
  static const auditRead = 'audit:read';
  static const authorizationManage = 'authorization:manage';
  static const securityForensicsRead = 'security_forensics:read';
  static const accountRecoveryReview = 'account_recovery:review';
}
