import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/features/admin/presentation/providers/admin_actions.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// The seller review queue.
///
/// This is the screen the marketplace cannot open without. A woman submits her
/// commercial registration, her identity document and her bank details, and
/// until someone reads them and decides, she cannot sell — the application sat
/// in `seller_verifications` with a `PENDING` status and no screen in the
/// console that listed it, let alone one that could approve it.
///
/// It is deliberately not the generic section screen: the decision is made by
/// reading documents, and a JSON dump is not reading documents.
class AdminSellerApplicationsScreen extends ConsumerStatefulWidget {
  const AdminSellerApplicationsScreen({super.key});

  @override
  ConsumerState<AdminSellerApplicationsScreen> createState() =>
      _AdminSellerApplicationsScreenState();
}

class _AdminSellerApplicationsScreenState
    extends ConsumerState<AdminSellerApplicationsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  static final _config = adminSectionConfigs['sellerApplications']!;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      unawaited(
        ref.read(adminSectionNotifierProvider(_config).notifier).search(value),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.console;
    final state = ref.watch(adminSectionNotifierProvider(_config));
    final notifier = ref.read(adminSectionNotifierProvider(_config).notifier);
    final permissions = ref.watch(currentPermissionsProvider);
    final canReview = permissions.contains(_config.writePermission);
    final pending = state.section?.summary['pending'];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminSellerApplications,
            subtitle: l10n.adminSellerApplicationsSubtitle,
            actions: [
              IconButton(
                tooltip: l10n.refresh,
                onPressed: () => unawaited(notifier.load()),
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (pending != null)
                  AdminMetricPill(
                    label: l10n.adminAwaitingReview(pending),
                    color: palette.caution,
                  ),
                const SizedBox(height: DsSpacing.md),
                TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    hintText: l10n.adminSearchApplications,
                  ),
                ),
                const SizedBox(height: DsSpacing.md),
                Wrap(
                  spacing: DsSpacing.xs,
                  runSpacing: DsSpacing.xs,
                  children: [
                    ChoiceChip(
                      label: Text(l10n.adminFilterAll),
                      selected: state.status == null,
                      onSelected: (_) =>
                          unawaited(notifier.filterByStatus(null)),
                    ),
                    for (final status in _config.statusFilters)
                      ChoiceChip(
                        label: Text(adminStatusLabel(l10n, status)),
                        selected: state.status == status,
                        onSelected: (selected) => unawaited(
                          notifier.filterByStatus(selected ? status : null),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: DsSpacing.lg),
                if (state.error != null)
                  _Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.error!,
                          style: context.dsText.body.tint(context.dsColors.error),
                        ),
                        const SizedBox(height: DsSpacing.md),
                        SecondaryButton(
                          label: l10n.retry,
                          icon: Icons.refresh_rounded,
                          isExpanded: false,
                          onPressed: () => unawaited(notifier.load()),
                        ),
                      ],
                    ),
                  )
                else if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(DsSpacing.xl),
                    child: Center(child: DsLoadingIndicator()),
                  )
                else if (state.records.isEmpty)
                  _Panel(
                    child: Text(
                      l10n.adminNoApplications,
                      style: context.dsText.body.tint(context.dsColors.onSurfaceVariant),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: DsRadius.borderSm,
                      border: Border.all(color: palette.line),
                    ),
                    child: Column(
                      children: [
                        for (final entry in state.records.asMap().entries) ...[
                          _ApplicationTile(
                            record: entry.value,
                            onOpen: () => unawaited(
                              _openApplication(entry.value, canReview),
                            ),
                          ),
                          if (entry.key < state.records.length - 1)
                            Divider(height: 1, color: palette.line),
                        ],
                      ],
                    ),
                  ),
                if (state.hasMore) ...[
                  const SizedBox(height: DsSpacing.md),
                  Center(
                    child: SecondaryButton(
                      label: l10n.adminLoadMore,
                      isExpanded: false,
                      isLoading: state.isLoadingMore,
                      onPressed: () => unawaited(notifier.loadMore()),
                    ),
                  ),
                ],
                const SizedBox(height: DsSpacing.xxxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fetches the full application before showing it.
  ///
  /// The list row carries a summary; the decision needs the documents and the
  /// review history, which only the single-application route returns.
  Future<void> _openApplication(AdminRecord record, bool canReview) async {
    final result = await ref
        .read(adminRepositoryProvider)
        .getSellerApplication(record.id);
    if (!mounted) return;

    result.when(
      success: (application) => unawaited(
        showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          builder: (sheetContext) => _ApplicationSheet(
            application: application,
            canReview: canReview,
            onDecide: (payload) => _decide(record.id, payload),
          ),
        ),
      ),
      error: (failure) => _showSnack(failure.message, isError: true),
    );
  }

  Future<void> _decide(String id, Map<String, dynamic> payload) async {
    final result = await ref
        .read(adminRepositoryProvider)
        .reviewSellerApplication(id, payload);
    if (!mounted) return;

    result.when(
      success: (_) {
        unawaited(
          ref.read(adminSectionNotifierProvider(_config).notifier).load(),
        );
        _showSnack(context.l10n.adminActionDone);
      },
      error: (failure) => _showSnack(failure.message, isError: true),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    final colors = context.dsColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : colors.success,
      ),
    );
  }
}

class _ApplicationTile extends StatelessWidget {
  const _ApplicationTile({required this.record, required this.onOpen});

  final AdminRecord record;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.console;
    final status = record.status.toUpperCase();

    return ListTile(
      onTap: onOpen,
      leading: CircleAvatar(
        backgroundColor: palette.primary.withValues(alpha: 0.1),
        child: Icon(
          Icons.assignment_ind_outlined,
          color: palette.primary,
          size: 20,
        ),
      ),
      title: Text(
        record.field('business_name') ?? record.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          record.field('legal_name'),
          record.field('contact_phone') ?? record.field('contact_email'),
        ].whereType<String>().join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: AdminMetricPill(
        label: adminStatusLabel(l10n, status),
        color: switch (status) {
          'APPROVED' => palette.positive,
          'REJECTED' || 'SUSPENDED' => palette.critical,
          'PENDING' => palette.caution,
          _ => palette.primary,
        },
      ),
    );
  }
}

class _ApplicationSheet extends StatefulWidget {
  const _ApplicationSheet({
    required this.application,
    required this.canReview,
    required this.onDecide,
  });

  final Map<String, dynamic> application;
  final bool canReview;
  final Future<void> Function(Map<String, dynamic> payload) onDecide;

  @override
  State<_ApplicationSheet> createState() => _ApplicationSheetState();
}

class _ApplicationSheetState extends State<_ApplicationSheet> {
  final _reason = TextEditingController();
  String _decision = 'APPROVED';
  bool _isSubmitting = false;
  String? _error;

  Map<String, dynamic> get application => widget.application;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String? _value(String key) {
    final value = application[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.xl,
            DsSpacing.sm,
            DsSpacing.xl,
            DsSpacing.xxl,
          ),
          children: [
            Text(
              _value('business_name') ?? l10n.adminSellerApplications,
              style: context.dsText.sectionTitle.bold.tint(colors.onSurface),
            ),
            const SizedBox(height: DsSpacing.xs),
            AdminMetricPill(
              label: adminStatusLabel(l10n, _value('status') ?? 'PENDING'),
              color: context.console.primary,
            ),
            const SizedBox(height: DsSpacing.lg),

            _Section(
              title: l10n.adminBusinessDetails,
              rows: {
                l10n.adminFieldLegalName: _value('legal_name'),
                l10n.adminFieldCategory: _value('business_category'),
                l10n.adminFieldCommercialRegistration: _value(
                  'commercial_registration',
                ),
                l10n.adminFieldTaxId: _value('tax_id'),
                l10n.adminFieldYearsExperience: _value('years_experience'),
                l10n.adminFieldWebsite: _value('website'),
              },
            ),
            _Section(
              title: l10n.adminContactDetails,
              rows: {
                l10n.contactPhone: _value('contact_phone'),
                l10n.email: _value('contact_email'),
                l10n.adminFieldBusinessAddress: _value('business_address'),
                l10n.adminFieldWarehouseAddress: _value('warehouse_address'),
              },
            ),
            _Section(
              title: l10n.adminBankDetails,
              rows: {
                l10n.adminFieldBankName: _value('bank_name'),
                l10n.adminFieldAccountHolder: _value('account_holder'),
                l10n.adminFieldIban: _value('iban'),
              },
            ),
            _Documents(application: application),
            _History(application: application),

            if (widget.canReview) ...[
              const SizedBox(height: DsSpacing.lg),
              Text(
                l10n.adminDecision,
                style: context.dsText.body.semibold.tint(colors.onSurface),
              ),
              const SizedBox(height: DsSpacing.sm),
              DropdownButtonFormField<String>(
                initialValue: _decision,
                decoration: InputDecoration(labelText: l10n.formStatus),
                items: [
                  for (final choice in sellerReviewDecisions)
                    DropdownMenuItem(
                      value: choice.value,
                      child: Text(choice.label(l10n)),
                    ),
                ],
                onChanged: _isSubmitting
                    ? null
                    : (value) =>
                          setState(() => _decision = value ?? _decision),
              ),
              const SizedBox(height: DsSpacing.sm),
              TextField(
                controller: _reason,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: l10n.adminFieldReason,
                  // The API refuses a decision with no reason, and rightly:
                  // the applicant is told what it said.
                  helperText: l10n.adminReasonReachesApplicant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: DsSpacing.sm),
                Text(_error!, style: context.dsText.body.tint(colors.error)),
              ],
              const SizedBox(height: DsSpacing.md),
              PrimaryButton(
                label: l10n.adminSubmitDecision,
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ] else ...[
              const SizedBox(height: DsSpacing.lg),
              Text(
                l10n.adminReviewNotPermitted,
                style: context.dsText.body.tint(colors.onSurfaceVariant),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _submit() async {
    final l10n = context.l10n;
    final reason = _reason.text.trim();
    if (reason.length < 3) {
      setState(() => _error = l10n.adminReasonRequired);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    await widget.onDecide({
      'status': _decision,
      'reason': reason,
      if (_decision == 'REJECTED') 'rejection_reason': reason,
    });
    if (!mounted) return;
    Navigator.pop(context);
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});

  final String title;
  final Map<String, String?> rows;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final present = {
      for (final entry in rows.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    if (present.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.dsText.body.semibold.tint(colors.onSurface),
          ),
          const SizedBox(height: DsSpacing.xs),
          for (final entry in present.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 170,
                    child: Text(
                      entry.key,
                      style: context.dsText.body.tint(colors.onSurfaceVariant),
                    ),
                  ),
                  Expanded(
                    child: SelectableText(
                      entry.value,
                      style: context.dsText.body.tint(colors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Documents extends StatelessWidget {
  const _Documents({required this.application});

  final Map<String, dynamic> application;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final documents = <String, String>{
      if (application['government_id_url'] is String)
        l10n.adminDocGovernmentId: application['government_id_url'] as String,
      if (application['business_license_url'] is String)
        l10n.adminDocBusinessLicense:
            application['business_license_url'] as String,
      if (application['store_logo_url'] is String)
        l10n.adminDocStoreLogo: application['store_logo_url'] as String,
    };
    final extras = application['document_urls'];
    if (extras is List) {
      for (final (index, url) in extras.indexed) {
        if (url is String && url.isNotEmpty) {
          documents['${l10n.adminDocAttachment} ${index + 1}'] = url;
        }
      }
    }
    if (documents.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminDocuments,
            style: context.dsText.body.semibold.tint(context.dsColors.onSurface),
          ),
          const SizedBox(height: DsSpacing.xs),
          Wrap(
            spacing: DsSpacing.sm,
            runSpacing: DsSpacing.sm,
            children: [
              for (final entry in documents.entries)
                SecondaryButton(
                  label: entry.key,
                  icon: Icons.open_in_new_rounded,
                  isExpanded: false,
                  onPressed: () => unawaited(_open(entry.value)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class _History extends StatelessWidget {
  const _History({required this.application});

  final Map<String, dynamic> application;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final history = application['history'];
    if (history is! List || history.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminReviewHistory,
            style: context.dsText.body.semibold.tint(colors.onSurface),
          ),
          const SizedBox(height: DsSpacing.xs),
          for (final entry in history.whereType<Map>())
            Padding(
              padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxs),
              child: Text(
                [
                  adminStatusLabel(l10n, '${entry['status']}'),
                  if (entry['admin_name'] != null) '${entry['admin_name']}',
                  if (entry['reason'] != null) '${entry['reason']}',
                ].join(' · '),
                style: context.dsText.body.tint(colors.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border),
      ),
      child: child,
    );
  }
}
