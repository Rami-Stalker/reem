import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/l10n/app_localizations.dart';

/// Localized titles for the admin sections.
///
/// [AdminSectionConfig.title] stays an English constant on purpose: it travels
/// to the repository and on to the API, where it identifies the section rather
/// than greeting anyone. What the operator reads is resolved here, at display
/// time, from the section's stable `key` — so translating the console never
/// risks changing a value the backend matches on.
extension AdminSectionTitle on AdminSectionConfig {
  String titleOf(AppLocalizations l10n) => switch (key) {
    'users' => l10n.adminUserManagement,
    'sellers' => l10n.adminSellerManagement,
    'sellerApplications' => l10n.adminSellerApplications,
    'products' => l10n.adminProductManagement,
    'orders' => l10n.adminOrderManagement,
    'financials' => l10n.adminFinancialManagement,
    'commissions' => l10n.adminCommissionManagement,
    'analytics' => l10n.adminReportsAndAnalytics,
    'reports' => l10n.adminReports,
    'moderation' => l10n.adminModerationTools,
    'support' => l10n.adminSupportManagement,
    'audit' => l10n.adminAuditLogs,
    'settings' => l10n.adminSystemSettings,
    'campaigns' => l10n.adminNotificationCampaigns,
    'notificationAnalytics' => l10n.adminNotificationAnalytics,
    // A section added to the API before it is added here still renders — with
    // its English name — rather than throwing at the operator.
    _ => title,
  };
}
