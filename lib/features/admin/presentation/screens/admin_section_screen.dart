import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/utils/relative_time.dart';
import 'package:ohara/features/admin/domain/entities/admin_console_entity.dart';
import 'package:ohara/features/admin/presentation/providers/admin_actions.dart';
import 'package:ohara/features/admin/presentation/providers/admin_provider.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_action_dialog.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_labels.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_page_header.dart';
import 'package:ohara/features/admin/presentation/widgets/admin_record_details.dart';
import 'package:ohara/features/experience/presentation/providers/role_experience_provider.dart';

/// One screen, twelve consoles.
///
/// Every admin section is the same shape — a filtered, searchable queue of
/// records, each of which a permitted operator can act on — so it is one
/// screen reading a [AdminSectionConfig] rather than twelve near-copies. What
/// differs between sections lives in data: the endpoint, the queue filters,
/// and the action catalogue in `admin_actions.dart`.
class AdminSectionScreen extends ConsumerStatefulWidget {
  const AdminSectionScreen({super.key, required this.config});

  final AdminSectionConfig config;

  @override
  ConsumerState<AdminSectionScreen> createState() => _AdminSectionScreenState();
}

class _AdminSectionScreenState extends ConsumerState<AdminSectionScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  AdminSectionConfig get config => widget.config;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// Search runs on the server, so it is debounced: a keystroke per request
  /// would put a query on the users table for every letter of a name.
  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      unawaited(ref.read(_notifier.notifier).search(value));
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 400) {
      unawaited(ref.read(_notifier.notifier).loadMore());
    }
  }

  late final _notifier = adminSectionNotifierProvider(widget.config);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(_notifier);
    final permissions = ref.watch(currentPermissionsProvider);
    final canWrite =
        config.writePermission == null ||
        permissions.contains(config.writePermission);
    final createAction = config.createAction;

    return SingleChildScrollView(
      controller: _scrollController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: config.titleOf(l10n),
            subtitle: l10n.adminSectionSubtitle,
            icon: _iconFor(config.key),
            // The queue's own figures — «١١ مفتوحة» — lit on the sky, where
            // they are read first, rather than in a pill under the title.
            highlights: [
              for (final entry
                  in state.section?.summary.entries ??
                      const <MapEntry<String, String>>[])
                CourtHighlight(
                  value: entry.value,
                  label: adminSummaryLabel(l10n, entry.key),
                ),
            ],
            actions: [
              IconButton(
                tooltip: l10n.refresh,
                onPressed: () => unawaited(ref.read(_notifier.notifier).load()),
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (config.key == 'campaigns')
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: DsSpacing.sm,
                  ),
                  child: PrimaryButton(
                    label: l10n.adminNewCampaign,
                    icon: Icons.add_rounded,
                    isExpanded: false,
                    onPressed: _showCampaignDialog,
                  ),
                ),
              if (createAction != null &&
                  permissions.contains(createAction.permission))
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: DsSpacing.sm,
                  ),
                  child: PrimaryButton(
                    label: createAction.label(l10n),
                    icon: createAction.icon,
                    isExpanded: false,
                    onPressed: () => unawaited(_runCreate(createAction)),
                  ),
                ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.sizeOf(context).width < 600
                  ? DsSpacing.md
                  : DsSpacing.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The threshold: what to look for, and which part of the
                // queue to look at, on one plate above the list.
                CourtPanel(
                  padding: DsSpacing.paddingMd,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsInputField.search(
                        controller: _searchController,
                        hint: l10n.search,
                        onChanged: _onSearchChanged,
                        onSubmitted: (value) => unawaited(
                          ref.read(_notifier.notifier).search(value),
                        ),
                        onClear: () =>
                            unawaited(ref.read(_notifier.notifier).search('')),
                      ),
                      if (config.statusFilters.isNotEmpty) ...[
                        DsGaps.vMd,
                        _StatusFilters(
                          filters: config.statusFilters,
                          selected: state.status,
                          onSelected: (status) => unawaited(
                            ref.read(_notifier.notifier).filterByStatus(status),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                DsGaps.vLg,
                if (state.error != null)
                  _SectionError(
                    message: state.error!,
                    onRetry: () =>
                        unawaited(ref.read(_notifier.notifier).load()),
                  )
                else if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(DsSpacing.xl),
                    child: Center(child: DsLoadingIndicator()),
                  )
                else if (state.records.isEmpty)
                  _EmptyRecords(
                    searched:
                        state.query.trim().isNotEmpty || state.status != null,
                    title: config.titleOf(l10n),
                  )
                else ...[
                  _CountLine(shown: state.records.length, total: state.total),
                  const SizedBox(height: DsSpacing.sm),
                  _RecordsList(
                    keyName: config.key,
                    records: state.records,
                    actions: canWrite ? config.actions : const [],
                    permissions: permissions,
                    onOpen: _showRecordSheet,
                    onAction: (action, record) =>
                        unawaited(_runAction(action, record)),
                    onRunCampaign: config.key == 'campaigns'
                        ? (id) => unawaited(_runCampaign(id))
                        : null,
                  ),
                  if (state.isLoadingMore)
                    const Padding(
                      padding: EdgeInsets.all(DsSpacing.lg),
                      child: Center(child: DsLoadingIndicator()),
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

  Future<void> _runAction(AdminRecordAction action, AdminRecord record) async {
    final payload = await showAdminActionDialog(
      context: context,
      action: action,
      record: record,
    );
    if (payload == null || !mounted) return;

    final result = await ref
        .read(adminMutationProvider)
        .submit(sectionKey: config.key, recordId: record.id, payload: payload);
    if (!mounted) return;

    result.when(
      success: (_) {
        unawaited(ref.read(_notifier.notifier).load());
        _showSnack(context.l10n.adminActionDone);
      },
      error: (failure) => _showSnack(_failureText(failure), isError: true),
    );
  }

  /// Server messages arrive already in her language; the two failures this
  /// feature raises itself arrive as codes, because the notifier that raised
  /// them had no context to localise with.
  String _failureText(Failure failure) => switch (failure.code) {
    AdminFailureCodes.sectionHasNoActions => context.l10n.adminSectionNoActions,
    AdminFailureCodes.sectionHasNoCreate => context.l10n.adminSectionNoCreate,
    _ => failure.message,
  };

  Future<void> _runCreate(AdminRecordAction action) async {
    final payload = await showAdminActionDialog(
      context: context,
      action: action,
    );
    if (payload == null || !mounted) return;

    final result = await ref
        .read(adminMutationProvider)
        .create(sectionKey: config.key, payload: payload);
    if (!mounted) return;

    result.when(
      success: (_) {
        unawaited(ref.read(_notifier.notifier).load());
        _showSnack(context.l10n.adminActionDone);
      },
      error: (failure) => _showSnack(_failureText(failure), isError: true),
    );
  }

  Future<void> _showCampaignDialog() async {
    final l10n = context.l10n;
    final name = TextEditingController();
    final title = TextEditingController();
    final body = TextEditingController();
    final role = TextEditingController();
    final scheduledAt = TextEditingController();
    final channels = <String, bool>{
      'IN_APP': true,
      'PUSH': true,
      'EMAIL': false,
      'SMS': false,
    };
    var verifiedSellers = false;
    var isSubmitting = false;

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (dialogContext, setDialogState) {
              return AlertDialog(
                title: Text(l10n.adminNewCampaignTitle),
                // A width, not *the* width. Pinned at 560 the campaign form
                // was wider than any phone the console is opened on, and the
                // dialog overflowed off both sides of the screen.
                content: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AdminTextField(
                          controller: name,
                          label: l10n.adminCampaignName,
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        _AdminTextField(
                          controller: title,
                          label: l10n.adminNotificationTitle,
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        _AdminTextField(
                          controller: body,
                          label: l10n.adminMessageBody,
                          maxLines: 4,
                        ),
                        const SizedBox(height: DsSpacing.md),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            l10n.adminChannels,
                            style: context.dsText.labelLarge.tint(
                              context.dsColors.onSurface,
                            ),
                          ),
                        ),
                        Wrap(
                          spacing: DsSpacing.xs,
                          runSpacing: DsSpacing.xs,
                          children: [
                            for (final entry in channels.entries)
                              FilterChip(
                                label: Text(entry.key),
                                selected: entry.value,
                                onSelected: isSubmitting
                                    ? null
                                    : (selected) => setDialogState(
                                        () => channels[entry.key] = selected,
                                      ),
                              ),
                          ],
                        ),
                        const SizedBox(height: DsSpacing.md),
                        _AdminTextField(
                          controller: role,
                          label: l10n.adminRoleSegment,
                          hint: l10n.adminRoleFilterHint,
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        SwitchListTile.adaptive(
                          value: verifiedSellers,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.adminVerifiedSellersOnly),
                          onChanged: isSubmitting
                              ? null
                              : (value) => setDialogState(
                                  () => verifiedSellers = value,
                                ),
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        _AdminTextField(
                          controller: scheduledAt,
                          label: l10n.adminScheduleTime,
                          hint: '2026-06-16T14:30:00Z',
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.pop(dialogContext),
                    child: Text(context.l10n.cancel),
                  ),
                  PrimaryButton(
                    label: l10n.create,
                    isLoading: isSubmitting,
                    isExpanded: false,
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            final payload = _campaignPayload(
                              name: name.text,
                              title: title.text,
                              body: body.text,
                              role: role.text,
                              scheduledAt: scheduledAt.text,
                              channels: channels,
                              verifiedSellers: verifiedSellers,
                            );
                            if (payload == null) return;

                            setDialogState(() => isSubmitting = true);
                            final result = await ref
                                .read(adminRepositoryProvider)
                                .createNotificationCampaign(payload);
                            if (!dialogContext.mounted) return;

                            result.when(
                              success: (_) {
                                Navigator.pop(dialogContext);
                                unawaited(ref.read(_notifier.notifier).load());
                                _showSnack(l10n.adminCampaignCreated);
                              },
                              error: (failure) {
                                setDialogState(() => isSubmitting = false);
                                _showSnack(
                                  _failureText(failure),
                                  isError: true,
                                );
                              },
                            );
                          },
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      name.dispose();
      title.dispose();
      body.dispose();
      role.dispose();
      scheduledAt.dispose();
    }
  }

  Map<String, dynamic>? _campaignPayload({
    required String name,
    required String title,
    required String body,
    required String role,
    required String scheduledAt,
    required Map<String, bool> channels,
    required bool verifiedSellers,
  }) {
    final l10n = context.l10n;
    final selectedChannels = channels.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    if (name.trim().isEmpty || title.trim().isEmpty || body.trim().isEmpty) {
      _showSnack(l10n.adminCampaignFieldsRequired, isError: true);
      return null;
    }
    if (selectedChannels.isEmpty) {
      _showSnack(l10n.adminSelectChannel, isError: true);
      return null;
    }

    final payload = <String, dynamic>{
      'name': name.trim(),
      'title': title.trim(),
      'body': body.trim(),
      'channels': selectedChannels,
      'segment': <String, dynamic>{},
    };
    final segment = payload['segment'] as Map<String, dynamic>;
    if (role.trim().isNotEmpty) {
      segment['roles'] = [role.trim().toUpperCase()];
    }
    if (verifiedSellers) segment['verified_sellers'] = true;
    if (segment.isEmpty) payload.remove('segment');

    if (scheduledAt.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(scheduledAt.trim());
      if (parsed == null) {
        _showSnack(l10n.adminScheduleIsoHint, isError: true);
        return null;
      }
      payload['scheduled_at'] = parsed.toUtc().toIso8601String();
    }

    return payload;
  }

  Future<void> _runCampaign(String id) async {
    final l10n = context.l10n;
    if (id.isEmpty) return;
    final result = await ref
        .read(adminRepositoryProvider)
        .runNotificationCampaign(id);
    if (!mounted) return;

    result.when(
      success: (_) {
        unawaited(ref.read(_notifier.notifier).load());
        final analyticsConfig = adminSectionConfigs['notificationAnalytics'];
        if (analyticsConfig != null) {
          ref.invalidate(adminSectionNotifierProvider(analyticsConfig));
        }
        _showSnack(l10n.adminCampaignQueued);
      },
      error: (failure) => _showSnack(_failureText(failure), isError: true),
    );
  }

  void _showRecordSheet(AdminRecord record) {
    final l10n = context.l10n;
    final colors = context.dsColors;
    final permissions = ref.read(currentPermissionsProvider);
    final canWrite =
        config.writePermission == null ||
        permissions.contains(config.writePermission);
    final actions = canWrite
        ? config.actions
              .where(
                (action) =>
                    permissions.contains(action.permission) &&
                    action.appliesTo(record),
              )
              .toList()
        : const <AdminRecordAction>[];
    final pretty = const JsonEncoder.withIndent('  ').convert(record.raw);

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (sheetContext, scrollController) {
            return ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                DsSpacing.xl,
                DsSpacing.sm,
                DsSpacing.xl,
                DsSpacing.xl,
              ),
              children: [
                Text(
                  adminRecordTitle(l10n, config.key, record),
                  style: context.dsText.sectionTitle.bold.tint(
                    colors.onSurface,
                  ),
                ),
                const SizedBox(height: DsSpacing.xs),
                Text(
                  adminRecordSubtitle(l10n, config.key, record),
                  style: context.dsText.body.tint(colors.onSurfaceVariant),
                ),
                const SizedBox(height: DsSpacing.md),
                Wrap(
                  spacing: DsSpacing.xs,
                  runSpacing: DsSpacing.xs,
                  children: [
                    AdminMetricPill(
                      label: adminStatusLabel(l10n, record.status),
                      color: context.console.positive,
                    ),
                    for (final entry in record.metrics.entries)
                      AdminMetricPill(
                        label:
                            '${adminFieldLabel(context, entry.key)}: '
                            '${entry.value}',
                      ),
                  ],
                ),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: DsSpacing.lg),
                  Wrap(
                    spacing: DsSpacing.sm,
                    runSpacing: DsSpacing.sm,
                    children: [
                      for (final action in actions)
                        SecondaryButton(
                          label: action.label(l10n),
                          icon: action.icon,
                          isExpanded: false,
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            unawaited(_runAction(action, record));
                          },
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: DsSpacing.lg),
                // The record itself, read as a record: labelled lines in her
                // language, money as money and timestamps as dates. What used
                // to be here was `JsonEncoder.withIndent('  ')` over the same
                // map — the API's language on a screen whose job is helping a
                // person decide something.
                AdminRecordDetails(raw: record.raw),
                const SizedBox(height: DsSpacing.md),
                // Kept, and folded away. Support occasionally needs the literal
                // payload to answer "what did the server actually send"; an
                // operator deciding about a woman's account never does.
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      l10n.adminRawRecord,
                      style: context.dsText.bodySmall.tint(
                        colors.onSurfaceVariant,
                      ),
                    ),
                    children: [
                      SelectableText(
                        pretty,
                        // ds-ignore: no-hand-rolled-text-styles -- a raw JSON
                        // dump needs a monospaced family the type scale does
                        // not carry.
                        style: TextStyle(
                          fontFamily: 'monospace',
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    DsSnackbar.show(
      context,
      message: message,
      type: isError ? DsSnackbarType.error : DsSnackbarType.success,
    );
  }
}

class _StatusFilters extends StatelessWidget {
  const _StatusFilters({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<String> filters;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CourtFilterBeads<String>(
      selected: selected,
      onSelected: onSelected,
      options: [
        CourtFilterOption(value: null, label: l10n.adminFilterAll),
        for (final filter in filters)
          CourtFilterOption(
            value: filter,
            label: adminStatusLabel(l10n, filter),
          ),
      ],
    );
  }
}

class _CountLine extends StatelessWidget {
  const _CountLine({required this.shown, required this.total});

  final int shown;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: DsSpacing.xs),
      child: Text(
        context.l10n.adminShowingCount(shown, total),
        style: context.dsText.overline.tint(context.console.muted),
      ),
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({
    required this.keyName,
    required this.records,
    required this.actions,
    required this.permissions,
    required this.onOpen,
    required this.onAction,
    this.onRunCampaign,
  });

  final String keyName;
  final List<AdminRecord> records;
  final List<AdminRecordAction> actions;
  final Set<String> permissions;
  final ValueChanged<AdminRecord> onOpen;
  final void Function(AdminRecordAction action, AdminRecord record) onAction;
  final ValueChanged<String>? onRunCampaign;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 780;

    return Column(
        children: [
          for (final entry in records.asMap().entries) ...[
            DsStaggerAnimations.item(
              index: entry.key,
              child: _RecordTile(
              keyName: keyName,
              record: entry.value,
              compact: compact,
              actions: actions
                  .where(
                    (action) =>
                        permissions.contains(action.permission) &&
                        action.appliesTo(entry.value),
                  )
                  .toList(),
              onOpen: () => onOpen(entry.value),
              onAction: (action) => onAction(action, entry.value),
              onRunCampaign: onRunCampaign == null
                  ? null
                  : () => onRunCampaign!(entry.value.id),
              ),
            ),
            if (entry.key < records.length - 1) DsGaps.vSm,
          ],
        ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.keyName,
    required this.record,
    required this.compact,
    required this.actions,
    required this.onOpen,
    required this.onAction,
    this.onRunCampaign,
  });

  final String keyName;
  final AdminRecord record;
  final bool compact;
  final List<AdminRecordAction> actions;
  final VoidCallback onOpen;
  final ValueChanged<AdminRecordAction> onAction;
  final VoidCallback? onRunCampaign;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    final tone = context.toneColor(adminStatusTone(record.status));
    final badges = _RecordBadges(
      record: record,
      actions: actions,
      onAction: onAction,
      onRunCampaign: onRunCampaign,
    );
    final title = adminRecordTitle(l10n, keyName, record);

    // Each record is its own small room: an arch in the colour of its
    // status, the name, what it is, and what can be done with it.
    return Semantics(
      button: true,
      label: title,
      child: Material(
        color: palette.surface,
        borderRadius: DsRadius.borderXl,
        child: InkWell(
          borderRadius: DsRadius.borderXl,
          onTap: onOpen,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: DsSpacing.md,
              vertical: DsSpacing.sm,
            ),
            decoration: BoxDecoration(
              borderRadius: DsRadius.borderXl,
              border: Border.all(color: palette.line),
            ),
            child: Row(
              children: [
                CourtArchMedallion(
                  icon: _iconFor(keyName),
                  color: tone,
                  size: DsSizes.controlSm,
                ),
                DsGaps.hMd,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.dsText.bodyStrong.tint(palette.ink),
                      ),
                      // A row with nothing to say underneath its title says
                      // nothing, rather than repeating the name of the screen.
                      if (record.subtitle.isNotEmpty) ...[
                        DsGaps.vXxxs,
                        Text(
                          adminRecordSubtitle(l10n, keyName, record),
                          maxLines: compact ? 2 : 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.dsText.caption.tint(palette.muted),
                        ),
                      ],
                      if (compact) ...[DsGaps.vXs, badges],
                    ],
                  ),
                ),
                if (!compact) ...[DsGaps.hMd, badges],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordBadges extends StatelessWidget {
  const _RecordBadges({
    required this.record,
    required this.actions,
    required this.onAction,
    this.onRunCampaign,
  });

  final AdminRecord record;
  final List<AdminRecordAction> actions;
  final ValueChanged<AdminRecordAction> onAction;
  final VoidCallback? onRunCampaign;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.console;
    final isDisabled = record.flag('is_disabled') ?? false;

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final metric in record.metrics.entries.take(2))
          AdminMetricPill(label: metric.value),
        // «قبل ٣ أيام» rather than `2026-09-10T01:53:18.694Z`, which is what
        // every row in the console used to carry.
        if (record.createdAt != null)
          AdminMetricPill(label: formatRelativeTime(l10n, record.createdAt!)),
        CourtStatusPill(
          label: adminStatusLabel(l10n, record.status),
          color: context.toneColor(adminStatusTone(record.status)),
        ),
        // A suspended account reads as "customer" like any other unless the
        // suspension is said out loud, which is the one fact an operator
        // scanning this list most needs.
        if (isDisabled)
          CourtStatusPill(
            label: l10n.adminStatusSuspended,
            color: palette.critical,
          ),
        if (onRunCampaign != null)
          IconButton(
            tooltip: l10n.adminRunCampaign,
            onPressed: onRunCampaign,
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        if (actions.isNotEmpty)
          PopupMenuButton<AdminRecordAction>(
            tooltip: l10n.adminActions,
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: onAction,
            itemBuilder: (context) => [
              for (final action in actions)
                PopupMenuItem(
                  value: action,
                  child: Row(
                    children: [
                      Icon(
                        action.icon,
                        size: 18,
                        color: action.destructive
                            ? context.dsColors.error
                            : context.dsColors.onSurfaceVariant,
                      ),
                      const SizedBox(width: DsSpacing.sm),
                      Text(action.label(l10n)),
                    ],
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    final l10n = context.l10n;
    return CourtPanel(
      accent: palette.critical,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CourtArchMedallion(
            icon: Icons.cloud_off_rounded,
            color: palette.critical,
          ),
          DsGaps.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.adminSectionUnavailable,
                  style: context.dsText.bodyStrong.tint(palette.criticalInk),
                ),
                DsGaps.vXs,
                Text(message, style: context.dsText.body.tint(palette.muted)),
                DsGaps.vMd,
                SecondaryButton(
                  label: l10n.retry,
                  icon: Icons.refresh_rounded,
                  isExpanded: false,
                  onPressed: onRetry,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords({required this.searched, required this.title});

  final bool searched;
  final String title;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return CourtQuietNote(
      icon: searched ? Icons.search_off_rounded : Icons.spa_outlined,
      color: searched ? context.console.muted : null,
      message: searched
          ? l10n.adminNoMatchingRecords
          : l10n.adminNoRecordsYet(title),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return DsInputField(
      controller: controller,
      label: label,
      hint: hint,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : null,
    );
  }
}

IconData _iconFor(String key) => switch (key) {
  'users' => Icons.people_outline,
  'sellers' => Icons.storefront_outlined,
  'sellerApplications' => Icons.assignment_ind_outlined,
  'products' => Icons.inventory_2_outlined,
  'orders' => Icons.receipt_long_outlined,
  'financials' => Icons.account_balance_outlined,
  'commissions' => Icons.percent_outlined,
  'reports' => Icons.assessment_outlined,
  'moderation' => Icons.gavel_outlined,
  'support' => Icons.support_agent_outlined,
  'audit' => Icons.manage_search_outlined,
  'settings' => Icons.tune_outlined,
  'campaigns' => Icons.campaign_outlined,
  _ => Icons.analytics_outlined,
};
