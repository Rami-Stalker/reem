import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/admin/domain/entities/delivery_provider.dart';
import 'package:reem/features/admin/presentation/providers/delivery_admin_provider.dart';
import 'package:reem/features/admin/presentation/widgets/admin_page_header.dart';

/// The delivery companies desk.
///
/// Reem manages the order; a delivery company manages the journey. So this
/// screen has no drivers on it, no routes and no fleet — those belong to the
/// carrier's own system, and building them here would be building the business
/// Reem decided not to be in.
///
/// What it does have is the four decisions an operator actually makes: which
/// companies are on, where each one delivers, which one wins when two cover the
/// same governorate, and what to do about a parcel a carrier never accepted.
/// Every one of them is a row in the database rather than a deploy.
///
/// Credentials are never here. The server says which environment variables a
/// carrier needs and whether each is set; the values never leave it, and the
/// app has no route that would return one.
class AdminDeliveryScreen extends ConsumerWidget {
  const AdminDeliveryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.console;
    final providers = ref.watch(deliveryProvidersProvider);
    final stuck = ref.watch(failedDispatchesProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminPageHeader(
            title: l10n.adminDelivery,
            subtitle: l10n.adminDeliverySubtitle,
            actions: [
              IconButton(
                tooltip: l10n.refresh,
                onPressed: () {
                  ref.invalidate(deliveryProvidersProvider);
                  ref.invalidate(failedDispatchesProvider);
                },
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                providers.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(DsSpacing.xl),
                    child: DsLoadingIndicator(),
                  ),
                  error: (error, _) => _Panel(
                    child: Text(
                      '$error',
                      style: context.dsText.bodySmall.tint(palette.critical),
                    ),
                  ),
                  data: (rows) => Column(
                    children: [
                      for (final row in rows)
                        _ProviderCard(
                          account: row,
                          onToggle: () => _toggle(context, ref, row),
                        ),
                      if (rows.isEmpty)
                        _Panel(
                          child: Text(
                            l10n.adminDeliveryNoProviders,
                            style: context.dsText.bodySmall.tint(palette.muted),
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: DsSpacing.lg),
                Text(
                  l10n.adminDeliveryStuck,
                  style: context.dsText.sectionTitle.bold.tint(palette.ink),
                ),
                const SizedBox(height: DsSpacing.xs),
                stuck.when(
                  loading: () => const SizedBox(
                    height: 48,
                    child: DsLoadingIndicator(),
                  ),
                  error: (error, _) => Text(
                    '$error',
                    style: context.dsText.bodySmall.tint(palette.critical),
                  ),
                  data: (rows) => rows.isEmpty
                      ? _Panel(
                          child: Text(
                            l10n.adminDeliveryNothingStuck,
                            style: context.dsText.bodySmall.tint(
                              palette.positive,
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            for (final row in rows)
                              _StuckCard(
                                row: row,
                                onRetry: () => _retry(context, ref, row),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: DsSpacing.xxl),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    DeliveryProviderAccount account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(deliveryAdminDataSourceProvider)
          .setEnabled(account.id, !account.isEnabled);
      ref.invalidate(deliveryProvidersProvider);
    } catch (error) {
      // The server refuses to enable a carrier it cannot reach — no base URL,
      // no API key, no signing secret — and that refusal is the useful part of
      // this screen, so it is shown as it was written rather than flattened.
      DsSnackbar.on(messenger, message: '$error', type: DsSnackbarType.error);
    }
  }

  Future<void> _retry(
    BuildContext context,
    WidgetRef ref,
    DeliveryDispatchRow row,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(deliveryAdminDataSourceProvider).retry(row.id);
      ref.invalidate(failedDispatchesProvider);
    } catch (error) {
      DsSnackbar.on(messenger, message: '$error', type: DsSnackbarType.error);
    }
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({required this.account, required this.onToggle});

  final DeliveryProviderAccount account;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.console;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.displayName,
                      style: context.dsText.body.bold.tint(palette.ink),
                    ),
                    Text(
                      account.isInternal
                          ? l10n.adminDeliveryInternalFleet
                          : '${account.code} · ${account.adapter}',
                      style: context.dsText.caption.tint(palette.muted),
                    ),
                  ],
                ),
              ),
              Switch(value: account.isEnabled, onChanged: (_) => onToggle()),
            ],
          ),
          const SizedBox(height: DsSpacing.xs),
          Wrap(
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xxs,
            children: [
              _Tag(
                label: account.governorates.isEmpty
                    ? l10n.adminDeliveryEverywhere
                    : account.governorates.join('، '),
                color: palette.muted,
              ),
              _Tag(
                label: l10n.adminDeliveryPriority(account.priority),
                color: palette.muted,
              ),
              if (account.isDefault)
                _Tag(label: l10n.adminDeliveryDefault, color: palette.positive),
              if (account.supportsWebhook)
                _Tag(label: account.webhookUrl, color: palette.muted),
            ],
          ),
          // A carrier is only dispatchable when every secret it names is
          // actually present on the server. Naming the variable and saying
          // whether it is set answers "why can I not turn this on" without
          // showing anybody a key.
          if (account.credentials.isNotEmpty) ...[
            const SizedBox(height: DsSpacing.xs),
            for (final credential in account.credentials)
              Text(
                '${credential.field}: ${credential.envKey} '
                '${credential.isSet ? '✓' : '—'}',
                style: context.dsText.caption.tint(
                  credential.isSet ? palette.muted : palette.caution,
                ),
              ),
          ],
          if (!account.adapterAvailable)
            Padding(
              padding: const EdgeInsets.only(top: DsSpacing.xxs),
              child: Text(
                l10n.adminDeliveryAdapterMissing(account.adapter),
                style: context.dsText.caption.tint(palette.critical),
              ),
            ),
          if (account.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: DsSpacing.xxs),
              child: Text(
                account.lastError!,
                style: context.dsText.caption.tint(palette.critical),
              ),
            ),
        ],
      ),
    );
  }
}

class _StuckCard extends StatelessWidget {
  const _StuckCard({required this.row, required this.onRetry});

  final DeliveryDispatchRow row;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return _Panel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${row.orderNumber} · ${row.provider}',
                  style: context.dsText.bodySmall.bold.tint(palette.ink),
                ),
                if (row.lastError != null)
                  Text(
                    row.lastError!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.dsText.caption.tint(palette.critical),
                  ),
              ],
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.adminDeliveryRetry),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: DsSpacing.xs,
      vertical: DsSpacing.xxs,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(DsRadius.sm),
    ),
    child: Text(label, style: context.dsText.caption.tint(color)),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = context.console;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: DsSpacing.sm),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderCard,
        border: Border.all(color: palette.line),
      ),
      child: child,
    );
  }
}
