import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/errors/failure.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/auth/presentation/widgets/step_up_sheet.dart';
import 'package:reem/features/settings/domain/entities/address_entity.dart';
import 'package:reem/features/settings/presentation/providers/address_book_provider.dart';
import 'package:reem/features/settings/presentation/widgets/address_card.dart';
import 'package:reem/features/settings/presentation/widgets/address_form_sheet.dart';

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

    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'عناويني', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.all(DsSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              const ReemSectionHeader(
                title: 'عناوين التوصيل',
                subtitle: 'إلى أين نرسل طلباتكِ؟',
              ),
              const SizedBox(height: DsSpacing.lg),

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

              const SizedBox(height: DsSpacing.md),
              SecondaryButton(
                label: 'إضافة عنوان جديد',
                onPressed: state.isSaving ? null : () => _add(context, ref),
              ),
              if (state.isSaving) ...[
                const SizedBox(height: DsSpacing.md),
                const Center(
                  child: DsLoadingIndicator.inline(),
                ),
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
      success: 'تمت إضافة العنوان',
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
      success: 'تم حفظ التعديل',
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
      success: 'صار هذا عنوانكِ الافتراضي',
    );
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    AddressEntity address,
  ) async {
    final confirmed = await DsDialog.confirm(
      context,
      title: 'حذف العنوان',
      message: 'سيُحذف «${address.label}» من عناوينكِ.',
      confirmLabel: 'حذف',
      cancelLabel: 'تراجع',
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }

    await _save(
      context,
      ref,
      action: () => ref.read(addressBookProvider.notifier).remove(address.id),
      success: 'تم حذف العنوان',
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
          message: outcome.message ?? 'تعذّر تنفيذ العملية الآن',
          type: DsSnackbarType.error,
        );
    }
  }
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
            'لا عناوين محفوظة بعد',
            style: context.dsText.tileTitle.semibold.tint(colors.onSurface),
          ),
          const SizedBox(height: DsSpacing.sm),
          Text(
            'احفظي عنواناً الآن ليكون جاهزاً عند أول طلب',
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
          SecondaryButton(label: 'إعادة المحاولة', onPressed: onRetry),
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
