import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/features/salons/data/datasources/salons_remote_datasource.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';
import 'package:reem/features/salons/presentation/providers/salons_providers.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';

/// «الخدمات والأسعار» — the menu, as its owner edits it.
///
/// Inactive services stay on the list, greyed, rather than disappearing: a
/// service she has stopped offering this month is one she will offer again,
/// and the server keeps it for the appointments that already reference it.
class SalonServicesScreen extends ConsumerWidget {
  const SalonServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.dsColors;
    final async = ref.watch(mySalonProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: ReemAppBar(title: context.l10n.salonServicesAndPrices),
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.salonServicesLoadError,
          onRetry: () => ref.invalidate(mySalonProvider),
        ),
        data: (salon) {
          if (salon == null) {
            return DsEmptyState(
              icon: Icons.storefront_outlined,
              title: context.l10n.salonNoSalonYet,
              message: context.l10n.salonOpenFirstServices,
            );
          }
          final services = [...salon.services]
            ..sort((a, b) {
              if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
              return a.sortOrder.compareTo(b.sortOrder);
            });

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(mySalonProvider),
            child: services.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: DsSpacing.xxxl),
                      DsEmptyState(
                        icon: Icons.spa_outlined,
                        title: context.l10n.salonNoServices,
                        message: context.l10n.salonAddFirstService,
                        actionLabel: context.l10n.salonAddService,
                        onAction: () => unawaited(_edit(context, ref, null)),
                      ),
                    ],
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      DsSpacing.lg,
                      DsSpacing.lg,
                      DsSpacing.lg,
                      DsSpacing.xxxl,
                    ),
                    itemCount: services.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: DsSpacing.sm),
                    itemBuilder: (context, index) => _ServiceRow(
                      service: services[index],
                      onEdit: () =>
                          unawaited(_edit(context, ref, services[index])),
                      onToggle: () =>
                          unawaited(_toggle(context, ref, services[index])),
                    ),
                  ),
          );
        },
      ),
      floatingActionButton: async.asData?.value == null
          ? null
          : FloatingActionButton(
              onPressed: () => unawaited(_edit(context, ref, null)),
              backgroundColor: c.primary,
              child: Icon(Icons.add_rounded, color: c.onPrimary),
            ),
    );
  }

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    SalonService? service,
  ) async {
    final draft = await DsBottomSheet.show<ServiceDraft>(
      context,
      builder: (_) => _ServiceSheet(service: service),
    );
    if (draft == null || !context.mounted) return;

    try {
      await ref.read(salonOwnerActionsProvider).saveService(service?.id, draft);
      if (!context.mounted) return;
      DsSnackbar.success(context, context.l10n.salonServiceSaved);
    } catch (_) {
      if (!context.mounted) return;
      DsSnackbar.error(context, context.l10n.salonServiceSaveFailed);
    }
  }

  Future<void> _toggle(
    BuildContext context,
    WidgetRef ref,
    SalonService service,
  ) async {
    final actions = ref.read(salonOwnerActionsProvider);
    try {
      if (service.isActive) {
        // Never deleted: appointments already booked against it have to keep
        // reading a real row, and the server soft-closes it for that reason.
        await actions.deactivateService(service.id);
      } else {
        await actions.saveService(
          service.id,
          ServiceDraft(
            name: service.name,
            category: service.category,
            price: service.price.approximateValue,
            durationMinutes: service.durationMinutes,
            isActive: true,
          ),
        );
      }
      if (!context.mounted) return;
      DsSnackbar.success(
        context,
        service.isActive
            ? context.l10n.salonServicePaused
            : context.l10n.salonServiceResumed,
      );
    } catch (_) {
      if (!context.mounted) return;
      DsSnackbar.error(context, context.l10n.salonServiceToggleFailed);
    }
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.service,
    required this.onEdit,
    required this.onToggle,
  });

  final SalonService service;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final dim = service.isActive ? c.onSurface : c.onSurfaceVariant;

    return SurfaceCard(
      onTap: onEdit,
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        style: context.dsText.tileTitle.semibold.tint(dim),
                      ),
                    ),
                    if (!service.isActive)
                      DsBadge(
                        label: context.l10n.salonPausedBadge,
                        tone: DsBadgeTone.neutral,
                      ),
                    if (service.isPackage) ...[
                      const SizedBox(width: DsSpacing.xxs),
                      DsBadge(
                        label: context.l10n.salonPackage,
                        tone: DsBadgeTone.accent,
                      ),
                    ],
                  ],
                ),
                DsGaps.vXxxs,
                Text(
                  '${SalonLabels.category(context.l10n, service.category)} · '
                  '${SalonLabels.duration(context.l10n, service.durationMinutes)} · '
                  '${SalonLabels.location(context.l10n, service.location)}',
                  style: context.dsText.caption.tint(c.onSurfaceVariant),
                ),
                DsGaps.vXs,
                Text(
                  service.price.format(),
                  style: DsTypography.price(
                    service.isActive ? c.price : c.onSurfaceVariant,
                    size: DsTypography.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onToggle,
            tooltip: service.isActive
                ? context.l10n.salonPause
                : context.l10n.salonResume,
            icon: Icon(
              service.isActive
                  ? Icons.pause_circle_outline_rounded
                  : Icons.play_circle_outline_rounded,
              color: c.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The add/edit form, in a sheet.
///
/// It returns a [ServiceDraft] and writes nothing itself — so the one place
/// that saves is the screen, and the sheet stays a form.
class _ServiceSheet extends StatefulWidget {
  const _ServiceSheet({required this.service});

  final SalonService? service;

  @override
  State<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends State<_ServiceSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.service?.name ?? '');
  late final _description = TextEditingController(
    text: widget.service?.description ?? '',
  );
  late final _price = TextEditingController(
    text: widget.service?.price.raw ?? '',
  );
  late final _compareAt = TextEditingController(
    text: widget.service?.compareAtPrice?.raw ?? '',
  );

  late SalonCategory _category = widget.service?.category ?? SalonCategory.hair;
  late ServiceLocation _location =
      widget.service?.location ?? ServiceLocation.inSalon;
  late int _duration = widget.service?.durationMinutes ?? 30;
  late int _buffer = widget.service?.bufferMinutes ?? 0;
  late bool _isPackage = widget.service?.isPackage ?? false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _price.dispose();
    _compareAt.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return DsSheetScaffold(
      title: widget.service == null
          ? context.l10n.salonNewService
          : context.l10n.salonEditService,
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DsInputField(
              controller: _name,
              label: context.l10n.salonServiceName,
              labelAbove: true,
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.l10n.salonFieldRequired
                  : null,
            ),
            DsGaps.vSm,
            DsInputField(
              controller: _description,
              label: context.l10n.salonDescription,
              labelAbove: true,
              maxLines: 3,
              minLines: 2,
              maxLength: 500,
            ),

            DsGaps.vMd,
            Text(
              context.l10n.salonType,
              style: context.dsText.labelMedium.semibold.tint(c.onSurface),
            ),
            DsGaps.vXs,
            Wrap(
              spacing: DsSpacing.xs,
              runSpacing: DsSpacing.xs,
              children: [
                for (final category in SalonCategory.values)
                  DsChip(
                    label: SalonLabels.category(context.l10n, category),
                    selected: _category == category,
                    onTap: () => setState(() => _category = category),
                  ),
              ],
            ),

            DsGaps.vMd,
            Row(
              children: [
                Expanded(
                  child: DsInputField(
                    controller: _price,
                    label: context.l10n.salonPrice,
                    labelAbove: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) {
                      final parsed = double.tryParse(value?.trim() ?? '');
                      if (parsed == null || parsed <= 0) {
                        return context.l10n.salonInvalidPrice;
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: DsInputField(
                    controller: _compareAt,
                    label: context.l10n.salonBeforeDiscount,
                    labelAbove: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ),
              ],
            ),

            DsGaps.vMd,
            _Minutes(
              label: context.l10n.salonDuration,
              value: _duration,
              min: 5,
              max: 480,
              step: 5,
              onChanged: (value) => setState(() => _duration = value),
            ),
            DsGaps.vXs,
            _Minutes(
              label: context.l10n.salonBufferAfter,
              value: _buffer,
              min: 0,
              max: 120,
              step: 5,
              onChanged: (value) => setState(() => _buffer = value),
            ),

            DsGaps.vMd,
            Text(
              context.l10n.salonWhereDone,
              style: context.dsText.labelMedium.semibold.tint(c.onSurface),
            ),
            DsGaps.vXs,
            Wrap(
              spacing: DsSpacing.xs,
              children: [
                for (final location in ServiceLocation.values)
                  DsChip(
                    label: SalonLabels.location(context.l10n, location),
                    selected: _location == location,
                    onTap: () => setState(() => _location = location),
                  ),
              ],
            ),

            DsGaps.vMd,
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.salonIsPackage,
                    style: context.dsText.body.tint(c.onSurface),
                  ),
                ),
                Switch(
                  value: _isPackage,
                  onChanged: (value) => setState(() => _isPackage = value),
                ),
              ],
            ),

            DsGaps.vLg,
            DsButton(label: context.l10n.salonSave, onPressed: _submit),
            DsGaps.vSm,
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final compareAt = double.tryParse(_compareAt.text.trim());
    Navigator.of(context).pop(
      ServiceDraft(
        name: _name.text.trim(),
        category: _category,
        price: double.parse(_price.text.trim()),
        durationMinutes: _duration,
        description: _description.text.trim().isEmpty
            ? null
            : _description.text.trim(),
        // Zero clears it on the server rather than leaving a stale strike
        // through a price she has since changed.
        compareAtPrice: compareAt ?? 0,
        bufferMinutes: _buffer,
        location: _location,
        isPackage: _isPackage,
        isActive: true,
      ),
    );
  }
}

class _Minutes extends StatelessWidget {
  const _Minutes({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Row(
      children: [
        Expanded(
          child: Text(label, style: context.dsText.body.tint(c.onSurface)),
        ),
        IconButton(
          onPressed: value <= min
              ? null
              : () => onChanged((value - step).clamp(min, max)),
          icon: const Icon(Icons.remove_circle_outline_rounded),
          color: c.primary,
        ),
        SizedBox(
          width: 88,
          child: Text(
            value == 0
                ? context.l10n.salonNone
                : SalonLabels.duration(context.l10n, value),
            textAlign: TextAlign.center,
            style: context.dsText.body.semibold.tint(c.onSurface),
          ),
        ),
        IconButton(
          onPressed: value >= max
              ? null
              : () => onChanged((value + step).clamp(min, max)),
          icon: const Icon(Icons.add_circle_outline_rounded),
          color: c.primary,
        ),
      ],
    );
  }
}
