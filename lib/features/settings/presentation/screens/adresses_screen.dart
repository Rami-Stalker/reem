import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/auth/presentation/widgets/step_up_sheet.dart';
import 'package:ohara/features/settings/domain/entities/address_entity.dart';
import 'package:ohara/features/settings/presentation/providers/address_book_provider.dart';
import 'package:ohara/features/settings/presentation/widgets/address_card.dart';
import 'package:ohara/features/settings/presentation/widgets/address_form_sheet.dart';

/// Her address book.
///
/// This screen used to show four hardcoded cards and an «Add new address»
/// button wired to `() {}` — a working-looking book she could not add to,
/// correct, or delete, while checkout read a real list from the server. The
/// only address she could ever save was one typed during a purchase.
///
/// Writes here carry a step-up: the server treats the address as what it is on
/// this platform — a woman's home — and refuses to change it on a bearer token
/// alone. [runWithStepUp] turns that refusal into the second factor rather
/// than into a dead end.
class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addressBookProvider);
    final gutter = vanityGutter(context);

    return OharaScrollPage(
      slivers: [
        VanityAppBar(
          title: context.l10n.settingsMyAddresses,
          subtitle: context.l10n.settingsDeliveryAddressesSubtitle,
          icon: Icons.location_on_outlined,
          showBack: true,
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(gutter, DsSpacing.xl, gutter, 120),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (state.isLoading && state.addresses.isEmpty)
                const _BookSkeleton()
              else if (state.failure != null && state.addresses.isEmpty)
                _LoadFailed(
                  failure: state.failure!,
                  onRetry: () => ref.read(addressBookProvider.notifier).load(),
                )
              else if (state.isEmpty)
                const _EmptyBook()
              else
                for (final address in state.addresses) ...[
                  AddressCard(
                    address: address,
                    onEdit: () => _edit(context, ref, address),
                    onDelete: () => _delete(context, ref, address),
                    onMakeDefault: () => _makeDefault(context, ref, address),
                  ),
                  const SizedBox(height: DsSpacing.md),
                ],

              const SizedBox(height: DsSpacing.xs),
              _AddSlot(
                label: context.l10n.settingsAddAddress,
                onTap: state.isSaving ? null : () => _add(context, ref),
              ),
              if (state.isSaving) ...[
                const SizedBox(height: DsSpacing.md),
                const Center(child: DsLoadingIndicator.inline()),
              ],
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showAddressFormSheet(context);
    if (draft == null || !context.mounted) return;
    await _save(
      context,
      ref,
      action: () => ref.read(addressBookProvider.notifier).create(draft),
      success: context.l10n.settingsAddressAdded,
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    AddressEntity address,
  ) async {
    final draft = await showAddressFormSheet(context, existing: address);
    if (draft == null || !context.mounted) return;
    await _save(
      context,
      ref,
      action: () =>
          ref.read(addressBookProvider.notifier).update(address.id, draft),
      success: context.l10n.settingsAddressUpdated,
    );
  }

  Future<void> _makeDefault(
    BuildContext context,
    WidgetRef ref,
    AddressEntity address,
  ) async {
    await _save(
      context,
      ref,
      action: () =>
          ref.read(addressBookProvider.notifier).makeDefault(address.id),
      success: context.l10n.settingsAddressNowDefault,
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AddressEntity address,
  ) async {
    final confirmed = await DsDialog.confirm(
      context,
      title: context.l10n.settingsDeleteAddressTitle,
      message: context.l10n.settingsDeleteAddressBody(address.label),
      confirmLabel: context.l10n.settingsDelete,
      cancelLabel: context.l10n.settingsKeep,
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    await _save(
      context,
      ref,
      action: () => ref.read(addressBookProvider.notifier).remove(address.id),
      success: context.l10n.settingsAddressDeleted,
    );
  }

  /// One path for every write, because every one of them is step-up guarded.
  ///
  /// [runWithStepUp] wants an action returning a `Result`; the notifier returns
  /// the [Failure] instead so it can refresh the book itself on success, so the
  /// two are bridged here rather than giving the notifier a second shape.
  Future<void> _save(
    BuildContext context,
    WidgetRef ref, {
    required Future<Failure?> Function() action,
    required String success,
  }) async {
    final outcome = await runWithStepUp(
      context,
      ref,
      action: () async {
        final failure = await action();
        return failure == null ? const Success<Object?>(null) : Error(failure);
      },
    );

    if (!context.mounted) return;

    switch (outcome.outcome) {
      case StepUpOutcome.succeeded:
        DsSnackbar.show(
          context,
          message: success,
          type: DsSnackbarType.success,
        );
      case StepUpOutcome.elevated:
        // She proved it was her; the write has not happened yet.
        final failure = await action();
        if (!context.mounted) return;
        DsSnackbar.show(
          context,
          message: failure?.displayMessage ?? success,
          type: failure == null ? DsSnackbarType.success : DsSnackbarType.error,
        );
      case StepUpOutcome.cancelled:
        break;
      case StepUpOutcome.blocked:
        DsSnackbar.show(
          context,
          message: outcome.message ?? context.l10n.settingsActionFailed,
          type: DsSnackbarType.error,
        );
    }
  }
}

/// The empty place at the end of the book: a dashed card with a pearl
/// holding a plus — where the next address will sit.
class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.boutique;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: DsRadius.borderXxl,
          child: CustomPaint(
            painter: _DashedFrame(color: palette.gold),
            child: Padding(
              padding: DsSpacing.paddingLg,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const VanityPearl(icon: Icons.add_rounded),
                  DsGaps.hMd,
                  Text(
                    label,
                    style: context.dsText.bodyStrong.tint(palette.primary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedFrame extends CustomPainter {
  const _DashedFrame({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(1),
          const Radius.circular(DsRadius.xxl),
        ),
      );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = color.withValues(alpha: 0.7);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedFrame old) => old.color != color;
}

class _EmptyBook extends StatelessWidget {
  const _EmptyBook();

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 48,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            context.l10n.settingsNoAddresses,
            style: context.dsText.tileTitle.semibold.tint(colors.onSurface),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            context.l10n.settingsNoAddressesBody,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _LoadFailed extends StatelessWidget {
  const _LoadFailed({required this.failure, required this.onRetry});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 44,
            color: colors.onSurfaceVariant,
          ),
          const SizedBox(height: DsSpacing.md),
          Text(
            failure.displayMessage,
            textAlign: TextAlign.center,
            style: context.dsText.body.tint(colors.onSurfaceVariant),
          ),
          const SizedBox(height: DsSpacing.md),
          SecondaryButton(label: context.l10n.retry, onPressed: onRetry),
        ],
      ),
    );
  }
}

class _BookSkeleton extends StatelessWidget {
  const _BookSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++) ...[
          const DsShimmer(child: DsSkeleton.box(height: 132)),
          const SizedBox(height: DsSpacing.md),
        ],
      ],
    );
  }
}
