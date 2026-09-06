import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:reem/core/auth/app_permissions.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/presentation/providers/core_providers.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/admin/data/datasources/admin_remote_datasource.dart';
import 'package:reem/features/admin/data/datasources/impl/admin_remote_datasource_impl.dart';
import 'package:reem/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/features/admin/domain/entities/analytics_dashboard_entity.dart';
import 'package:reem/features/admin/domain/repositories/admin_repository.dart';
import 'package:reem/features/admin/domain/usecases/get_admin_stats_usecase.dart';
import 'package:reem/features/admin/presentation/providers/admin_actions.dart';
import 'package:reem/features/admin/presentation/providers/admin_dashboard_notifier.dart';
import 'package:reem/features/admin/presentation/providers/admin_state.dart';

final adminRemoteDataSourceProvider = Provider<AdminRemoteDataSource>(
  (ref) => AdminRemoteDataSourceImpl(ref.watch(dioProvider)),
);

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepositoryImpl(remote: ref.watch(adminRemoteDataSourceProvider)),
);

final getAdminStatsUseCaseProvider = Provider(
  (ref) => GetAdminStatsUseCase(ref.watch(adminRepositoryProvider)),
);

final adminDashboardNotifierProvider =
    StateNotifierProvider<AdminDashboardNotifier, AdminDashboardState>((ref) {
      return AdminDashboardNotifier(
        getAdminStatsUseCase: ref.watch(getAdminStatsUseCaseProvider),
      );
    });

class AnalyticsDateRange {
  const AnalyticsDateRange({this.start, this.end});

  final DateTime? start;
  final DateTime? end;
}

final analyticsDateRangeProvider = StateProvider<AnalyticsDateRange>((ref) {
  final end = DateTime.now();
  return AnalyticsDateRange(
    start: end.subtract(const Duration(days: 30)),
    end: end,
  );
});

final analyticsDashboardProvider = FutureProvider<AnalyticsDashboardEntity>((
  ref,
) async {
  final range = ref.watch(analyticsDateRangeProvider);
  final result = await ref
      .watch(adminRepositoryProvider)
      .getAnalyticsDashboard(start: range.start, end: range.end);
  return switch (result) {
    Success(:final data) => data,
    Error(:final failure) => throw Exception(failure.message),
  };
});

/// One screen of the console.
///
/// [permission] is what the API demands to *read* the section and
/// [writePermission] what it demands to change anything in it. Both live here
/// rather than in the shell so the navigation, the screen, and the row actions
/// all answer the same question from one source.
@immutable
class AdminSectionConfig {
  const AdminSectionConfig({
    required this.key,
    required this.title,
    required this.endpoint,
    required this.permission,
    this.writePermission,
    this.statusFilters = const [],
    this.defaultStatus,
  });

  final String key;
  final String title;
  final String endpoint;
  final String permission;
  final String? writePermission;

  /// Queue filters offered above the list, sent to the server as `status`.
  final List<String> statusFilters;

  /// The filter the screen opens on.
  ///
  /// A review queue should open on the work, not on the archive — the seller
  /// applications screen is useless if the six approved stores from last month
  /// are what an operator sees first.
  final String? defaultStatus;

  List<AdminRecordAction> get actions => adminSectionActions[key] ?? const [];

  AdminRecordAction? get createAction => adminSectionCreateActions[key];

  @override
  bool operator ==(Object other) =>
      other is AdminSectionConfig && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Failures this layer raises itself, named so the screen can localise them.
abstract final class AdminFailureCodes {
  static const sectionHasNoActions = 'admin.section_has_no_actions';
  static const sectionHasNoCreate = 'admin.section_has_no_create';
}

const adminSectionConfigs = {
  'users': AdminSectionConfig(
    key: 'users',
    title: 'User management',
    endpoint: ApiEndpoints.adminUsers,
    permission: AppPermissions.userManage,
    writePermission: AppPermissions.userManage,
  ),
  'sellers': AdminSectionConfig(
    key: 'sellers',
    title: 'Seller management',
    endpoint: ApiEndpoints.adminSellers,
    permission: AppPermissions.sellerVerificationReview,
  ),
  'sellerApplications': AdminSectionConfig(
    key: 'sellerApplications',
    title: 'Seller applications',
    endpoint: ApiEndpoints.adminSellerApplications,
    permission: AppPermissions.sellerVerificationReview,
    writePermission: AppPermissions.sellerVerificationReview,
    statusFilters: [
      'PENDING',
      'UNDER_REVIEW',
      'NEEDS_MORE_DOCUMENTS',
      'APPROVED',
      'REJECTED',
    ],
    defaultStatus: 'PENDING',
  ),
  'products': AdminSectionConfig(
    key: 'products',
    title: 'Product management',
    endpoint: ApiEndpoints.adminProducts,
    permission: AppPermissions.productManage,
    writePermission: AppPermissions.productManage,
    statusFilters: ['ACTIVE', 'DRAFT', 'OUT_OF_STOCK', 'ARCHIVED'],
  ),
  'orders': AdminSectionConfig(
    key: 'orders',
    title: 'Order management',
    endpoint: ApiEndpoints.adminOrders,
    permission: AppPermissions.orderRead,
  ),
  'financials': AdminSectionConfig(
    key: 'financials',
    title: 'Financial management',
    endpoint: ApiEndpoints.adminFinancials,
    permission: AppPermissions.financeRead,
  ),
  'commissions': AdminSectionConfig(
    key: 'commissions',
    title: 'Commission management',
    endpoint: ApiEndpoints.adminCommissions,
    permission: AppPermissions.financeRead,
    writePermission: AppPermissions.financeWrite,
    statusFilters: ['PENDING', 'EARNED', 'PAID', 'REVERSED'],
  ),
  'analytics': AdminSectionConfig(
    key: 'analytics',
    title: 'Reports and analytics',
    endpoint: ApiEndpoints.adminAnalytics,
    permission: AppPermissions.analyticsRead,
  ),
  'reports': AdminSectionConfig(
    key: 'reports',
    title: 'Reports',
    endpoint: ApiEndpoints.adminReports,
    permission: AppPermissions.supportRead,
    writePermission: AppPermissions.supportWrite,
    statusFilters: ['OPEN', 'REVIEWING', 'RESOLVED', 'DISMISSED'],
  ),
  'moderation': AdminSectionConfig(
    key: 'moderation',
    title: 'Moderation tools',
    endpoint: ApiEndpoints.adminModeration,
    permission: AppPermissions.contentModerate,
    writePermission: AppPermissions.contentModerate,
    statusFilters: ['OPEN', 'APPROVED', 'REJECTED', 'ESCALATED'],
  ),
  'support': AdminSectionConfig(
    key: 'support',
    title: 'Support management',
    endpoint: ApiEndpoints.adminSupport,
    permission: AppPermissions.supportRead,
    writePermission: AppPermissions.supportWrite,
    statusFilters: ['OPEN', 'PENDING', 'RESOLVED', 'CLOSED'],
  ),
  'audit': AdminSectionConfig(
    key: 'audit',
    title: 'Audit logs',
    endpoint: ApiEndpoints.adminAuditLogs,
    permission: AppPermissions.auditRead,
  ),
  'settings': AdminSectionConfig(
    key: 'settings',
    title: 'System settings',
    endpoint: ApiEndpoints.adminSystemSettings,
    permission: AppPermissions.authorizationManage,
    writePermission: AppPermissions.authorizationManage,
  ),
  'campaigns': AdminSectionConfig(
    key: 'campaigns',
    title: 'Notification campaigns',
    endpoint: ApiEndpoints.notificationAdminCampaigns,
    permission: AppPermissions.adminDashboard,
    writePermission: AppPermissions.adminDashboard,
  ),
  'notificationAnalytics': AdminSectionConfig(
    key: 'notificationAnalytics',
    title: 'Notification analytics',
    endpoint: ApiEndpoints.notificationAdminAnalytics,
    permission: AppPermissions.adminDashboard,
  ),
};

/// What one section screen is showing, including how it got there.
@immutable
class AdminSectionState {
  const AdminSectionState({
    this.section,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.query = '',
    this.status,
  });

  final AdminConsoleSection? section;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String query;
  final String? status;

  List<AdminRecord> get records => section?.records ?? const [];
  bool get hasMore => section?.hasMore ?? false;
  int get total => section?.total ?? 0;

  AdminSectionState copyWith({
    AdminConsoleSection? section,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? query,
    String? status,
    bool clearStatus = false,
  }) {
    return AdminSectionState(
      section: section ?? this.section,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      query: query ?? this.query,
      status: clearStatus ? null : (status ?? this.status),
    );
  }
}

class AdminSectionNotifier extends StateNotifier<AdminSectionState> {
  AdminSectionNotifier({required this.repository, required this.config})
    : super(AdminSectionState(status: config.defaultStatus)) {
    load();
  }

  final AdminRepository repository;
  final AdminSectionConfig config;

  static const _pageSize = 25;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _fetch(page: 1);
    if (!mounted) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
        section: data,
        isLoading: false,
        clearError: true,
      ),
      Error(:final failure) => state.copyWith(
        isLoading: false,
        error: failure.message,
      ),
    };
  }

  /// Asks the server for the next page and appends it.
  ///
  /// Guarded on `isLoadingMore` because a long list can fire the trigger twice
  /// before the first response lands, and the second call would ask for the
  /// same page and duplicate every row in it.
  Future<void> loadMore() async {
    final current = state.section;
    if (current == null || !current.hasMore || state.isLoadingMore) return;
    state = state.copyWith(isLoadingMore: true);
    final result = await _fetch(page: current.page + 1);
    if (!mounted) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
        section: current.appending(data),
        isLoadingMore: false,
      ),
      Error(:final failure) => state.copyWith(
        isLoadingMore: false,
        error: failure.message,
      ),
    };
  }

  Future<void> search(String query) {
    if (query == state.query) return Future<void>.value();
    state = state.copyWith(query: query);
    return load();
  }

  Future<void> filterByStatus(String? status) {
    if (status == state.status) return Future<void>.value();
    state = status == null
        ? state.copyWith(clearStatus: true)
        : state.copyWith(status: status);
    return load();
  }

  Future<Result<AdminConsoleSection>> _fetch({required int page}) {
    return repository.getSection(
      key: config.key,
      title: config.title,
      endpoint: config.endpoint,
      page: page,
      limit: _pageSize,
      query: state.query,
      status: state.status,
    );
  }
}

final adminSectionNotifierProvider = StateNotifierProvider.autoDispose
    .family<AdminSectionNotifier, AdminSectionState, AdminSectionConfig>((
      ref,
      config,
    ) {
      return AdminSectionNotifier(
        repository: ref.watch(adminRepositoryProvider),
        config: config,
      );
    });

/// Sends one record action to the route that owns it.
///
/// The section screen is generic; the API is not. This is the single place
/// that knows a moderation decision goes to `/admin/moderation/:id` and a
/// settings edit goes to a `POST` with no id at all, which keeps that mapping
/// out of the widget tree entirely.
final adminMutationProvider = Provider<AdminMutations>(
  (ref) => AdminMutations(ref.watch(adminRepositoryProvider)),
);

class AdminMutations {
  const AdminMutations(this._repository);

  final AdminRepository _repository;

  Future<Result<void>> submit({
    required String sectionKey,
    required String recordId,
    required Map<String, dynamic> payload,
  }) {
    return switch (sectionKey) {
      'users' => _repository.updateUser(recordId, payload),
      'products' => _repository.updateProduct(recordId, payload),
      'support' => _repository.updateSupportTicket(recordId, payload),
      'moderation' => _repository.updateModerationCase(recordId, payload),
      'reports' => _repository.updateReport(recordId, payload),
      'commissions' => _repository.updateCommissionLedger(recordId, payload),
      'settings' => _repository.upsertSystemSetting(payload),
      'sellerApplications' => _repository.reviewSellerApplication(
        recordId,
        payload,
      ),
      // A code, not a sentence: this notifier has no `BuildContext`, and a
      // section with no handler is a gap in the console rather than something
      // the operator did wrong. The screen turns the code into her language.
      _ => Future.value(
        const Error<void>(
          ValidationFailure('', code: AdminFailureCodes.sectionHasNoActions),
        ),
      ),
    };
  }

  Future<Result<void>> create({
    required String sectionKey,
    required Map<String, dynamic> payload,
  }) {
    return switch (sectionKey) {
      'commissions' => _repository.createCommissionRule(payload),
      'settings' => _repository.upsertSystemSetting(payload),
      _ => Future.value(
        const Error<void>(
          ValidationFailure('', code: AdminFailureCodes.sectionHasNoCreate),
        ),
      ),
    };
  }
}
