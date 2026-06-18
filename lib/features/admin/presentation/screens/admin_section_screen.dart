import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/admin/domain/entities/admin_console_entity.dart';
import 'package:reem/features/admin/presentation/providers/admin_provider.dart';
import 'package:reem/features/admin/presentation/widgets/admin_page_header.dart';

class AdminSectionScreen extends ConsumerStatefulWidget {
  const AdminSectionScreen({super.key, required this.config});

  final AdminSectionConfig config;

  @override
  ConsumerState<AdminSectionScreen> createState() => _AdminSectionScreenState();
}

class _AdminSectionScreenState extends ConsumerState<AdminSectionScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  AdminSectionConfig get config => widget.config;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sectionProvider = adminSectionProvider(config);
    final section = ref.watch(sectionProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: config.title,
            subtitle: 'Operational controls, review queues, and live records.',
            actions: [
              IconButton(
                tooltip: 'Refresh',
                onPressed: () => ref.invalidate(sectionProvider),
                icon: const Icon(Icons.refresh_rounded),
              ),
              if (config.key == 'campaigns')
                Padding(
                  padding: const EdgeInsets.only(left: DsSpacing.sm),
                  child: PrimaryButton(
                    label: 'New campaign',
                    icon: Icons.add_rounded,
                    isExpanded: false,
                    onPressed: _showCampaignDialog,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
            child: section.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(DsSpacing.xl),
                child: Center(child: DsLoadingIndicator()),
              ),
              error: (error, _) => _SectionError(
                message: error.toString(),
                onRetry: () => ref.invalidate(sectionProvider),
              ),
              data: (data) {
                final records = data.records.where(_matchesSearch).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (data.summary.isNotEmpty) ...[
                      Wrap(
                        spacing: DsSpacing.sm,
                        runSpacing: DsSpacing.sm,
                        children: data.summary.entries
                            .map(
                              (entry) => Chip(
                                label: Text('${entry.key}: ${entry.value}'),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: DsSpacing.lg),
                    ],
                    TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _query = '');
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                        hintText: 'Search ${data.title.toLowerCase()}',
                      ),
                    ),
                    const SizedBox(height: DsSpacing.md),
                    if (records.isEmpty)
                      _EmptyRecords(
                        searched: _query.trim().isNotEmpty,
                        title: data.title,
                      )
                    else
                      _RecordsList(
                        keyName: data.key,
                        records: records,
                        onOpen: _showRecordSheet,
                        onRunCampaign: config.key == 'campaigns'
                            ? _runCampaign
                            : null,
                      ),
                    const SizedBox(height: DsSpacing.xxxl),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearch(AdminRecord record) {
    final needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return [
      record.title,
      record.subtitle,
      record.status,
      record.id,
      ...record.metrics.values,
    ].any((value) => value.toLowerCase().contains(needle));
  }

  Future<void> _showCampaignDialog() async {
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
                title: const Text('New notification campaign'),
                content: SizedBox(
                  width: 560,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _AdminTextField(
                          controller: name,
                          label: 'Campaign name',
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        _AdminTextField(
                          controller: title,
                          label: 'Notification title',
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        _AdminTextField(
                          controller: body,
                          label: 'Message body',
                          maxLines: 4,
                        ),
                        const SizedBox(height: DsSpacing.md),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Channels',
                            style: TextStyle(
                              fontSize: DsTypography.labelLarge,
                              fontWeight: DsTypography.semiBold,
                              color: context.dsColors.onSurface,
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
                          label: 'Role segment (optional)',
                          hint: 'USER, SELLER, ADMIN',
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        SwitchListTile.adaptive(
                          value: verifiedSellers,
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Verified sellers only'),
                          onChanged: isSubmitting
                              ? null
                              : (value) => setDialogState(
                                  () => verifiedSellers = value,
                                ),
                        ),
                        const SizedBox(height: DsSpacing.sm),
                        _AdminTextField(
                          controller: scheduledAt,
                          label: 'Schedule time (optional)',
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
                    child: const Text('Cancel'),
                  ),
                  PrimaryButton(
                    label: 'Create',
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
                                ref.invalidate(adminSectionProvider(config));
                                _showSnack('Campaign created.');
                              },
                              error: (failure) {
                                setDialogState(() => isSubmitting = false);
                                _showSnack(failure.message, isError: true);
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
    final selectedChannels = channels.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
    if (name.trim().isEmpty || title.trim().isEmpty || body.trim().isEmpty) {
      _showSnack('Name, title, and body are required.', isError: true);
      return null;
    }
    if (selectedChannels.isEmpty) {
      _showSnack('Select at least one channel.', isError: true);
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
        _showSnack('Use an ISO schedule time.', isError: true);
        return null;
      }
      payload['scheduled_at'] = parsed.toUtc().toIso8601String();
    }

    return payload;
  }

  Future<void> _runCampaign(String id) async {
    if (id.isEmpty) return;
    final result = await ref
        .read(adminRepositoryProvider)
        .runNotificationCampaign(id);
    if (!mounted) return;

    result.when(
      success: (_) {
        ref.invalidate(adminSectionProvider(config));
        final analyticsConfig = adminSectionConfigs['notificationAnalytics'];
        if (analyticsConfig != null) {
          ref.invalidate(adminSectionProvider(analyticsConfig));
        }
        _showSnack('Campaign queued for delivery.');
      },
      error: (failure) => _showSnack(failure.message, isError: true),
    );
  }

  void _showRecordSheet(AdminRecord record) {
    final pretty = const JsonEncoder.withIndent('  ').convert(record.raw);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        final colors = context.dsColors;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
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
                  record.title,
                  style: TextStyle(
                    fontSize: DsTypography.titleLarge,
                    fontWeight: DsTypography.bold,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: DsSpacing.xs),
                Text(
                  record.subtitle,
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
                const SizedBox(height: DsSpacing.md),
                Wrap(
                  spacing: DsSpacing.xs,
                  runSpacing: DsSpacing.xs,
                  children: [
                    Chip(label: Text(record.status)),
                    for (final entry in record.metrics.entries)
                      Chip(label: Text('${entry.key}: ${entry.value}')),
                  ],
                ),
                const SizedBox(height: DsSpacing.lg),
                SelectableText(
                  pretty,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: colors.onSurface,
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
    final colors = context.dsColors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.error : colors.success,
      ),
    );
  }
}

class _RecordsList extends StatelessWidget {
  const _RecordsList({
    required this.keyName,
    required this.records,
    required this.onOpen,
    this.onRunCampaign,
  });

  final String keyName;
  final List<AdminRecord> records;
  final ValueChanged<AdminRecord> onOpen;
  final ValueChanged<String>? onRunCampaign;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final compact = MediaQuery.sizeOf(context).width < 780;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        children: [
          for (final entry in records.asMap().entries) ...[
            _RecordTile(
              keyName: keyName,
              record: entry.value,
              compact: compact,
              onOpen: () => onOpen(entry.value),
              onRunCampaign: onRunCampaign == null
                  ? null
                  : () => onRunCampaign!(entry.value.id),
            ),
            if (entry.key < records.length - 1)
              Divider(height: 1, color: colors.border),
          ],
        ],
      ),
    );
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.keyName,
    required this.record,
    required this.compact,
    required this.onOpen,
    this.onRunCampaign,
  });

  final String keyName;
  final AdminRecord record;
  final bool compact;
  final VoidCallback onOpen;
  final VoidCallback? onRunCampaign;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final badges = _RecordBadges(record: record, onRunCampaign: onRunCampaign);

    return Semantics(
      button: true,
      label: record.title,
      child: ListTile(
        onTap: onOpen,
        leading: CircleAvatar(
          backgroundColor: colors.primary.withValues(alpha: 0.12),
          child: Icon(_iconFor(keyName), color: colors.primary, size: 20),
        ),
        title: Text(record.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              record.subtitle,
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (compact) ...[const SizedBox(height: DsSpacing.xs), badges],
          ],
        ),
        trailing: compact ? null : badges,
      ),
    );
  }
}

class _RecordBadges extends StatelessWidget {
  const _RecordBadges({required this.record, this.onRunCampaign});

  final AdminRecord record;
  final VoidCallback? onRunCampaign;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final metric in record.metrics.entries.take(2))
          Chip(label: Text(metric.value)),
        Chip(label: Text(record.status)),
        if (onRunCampaign != null)
          IconButton(
            tooltip: 'Run campaign',
            onPressed: onRunCampaign,
            icon: const Icon(Icons.play_arrow_rounded),
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
    final colors = context.dsColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unable to load this section.',
            style: TextStyle(
              color: colors.error,
              fontWeight: DsTypography.semiBold,
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Text(message, style: TextStyle(color: colors.onSurfaceVariant)),
          const SizedBox(height: DsSpacing.md),
          SecondaryButton(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            isExpanded: false,
            onPressed: onRetry,
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
    final colors = context.dsColors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: DsRadius.borderLg,
        border: Border.all(color: colors.border),
      ),
      child: Text(
        searched ? 'No matching records found.' : 'No $title records yet.',
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
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
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label, hintText: hint),
    );
  }
}

IconData _iconFor(String key) => switch (key) {
  'users' => Icons.people_outline,
  'sellers' => Icons.storefront_outlined,
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
