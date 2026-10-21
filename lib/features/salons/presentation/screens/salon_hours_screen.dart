import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/salons/domain/entities/salon.dart';
import 'package:reem/features/salons/presentation/providers/salons_providers.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';

/// «أوقات الدوام» — the week, and the days off.
///
/// Edited locally and sent in one `PUT`, because the server replaces the whole
/// week at once: seven separate saves would leave a half-written week live if
/// the fourth one failed, and a salon open Monday but not Tuesday for no
/// reason is worse than a save that did not happen.
///
/// Closures are the other half of the screen and are *not* part of that
/// replace — «إجازة العيد» is a fact about one date, not about Thursdays.
class SalonHoursScreen extends ConsumerStatefulWidget {
  const SalonHoursScreen({super.key});

  @override
  ConsumerState<SalonHoursScreen> createState() => _SalonHoursScreenState();
}

class _SalonHoursScreenState extends ConsumerState<SalonHoursScreen> {
  /// The week being edited, 0 = Sunday. Seeded once from the salon.
  List<_Day>? _week;
  bool _saving = false;

  void _seed(Salon salon) {
    final byWeekday = {for (final day in salon.hours) day.weekday: day};
    _week = [
      for (var weekday = 0; weekday < 7; weekday += 1)
        _Day.from(
          byWeekday[weekday] ??
              // A weekday the salon has never set is closed rather than
              // guessed open: an invented opening hour is a booking she did
              // not agree to.
              SalonHours(
                weekday: weekday,
                opensAt: '10:00',
                closesAt: '20:00',
                isClosed: true,
              ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final async = ref.watch(mySalonProvider);

    return Scaffold(
      backgroundColor: c.background,
      appBar: const ReemAppBar(title: 'أوقات الدوام'),
      body: async.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: 'ما قدرنا نفتح دوامك.',
          onRetry: () => ref.invalidate(mySalonProvider),
        ),
        data: (salon) {
          if (salon == null) {
            return const DsEmptyState(
              icon: Icons.storefront_outlined,
              title: 'ما في صالون بعد',
              message: 'افتحي صالونك أول شي، بعدين حدّدي دوامك.',
            );
          }
          if (_week == null) _seed(salon);
          return _body(salon, _week!);
        },
      ),
    );
  }

  Widget _body(Salon salon, List<_Day> week) {
    return ListView(
      padding: const EdgeInsets.all(DsSpacing.lg),
      children: [
        for (final day in week) ...[
          _DayCard(
            day: day,
            onToggle: (open) => setState(() => day.isClosed = !open),
            onPick: (which) => unawaited(_pick(day, which)),
            onClearBreak: () => setState(() {
              day.breakStartsAt = null;
              day.breakEndsAt = null;
            }),
          ),
          const SizedBox(height: DsSpacing.sm),
        ],

        DsGaps.vMd,
        DsButton(
          label: 'احفظي الدوام',
          isLoading: _saving,
          onPressed: () => unawaited(_save(week)),
        ),

        DsGaps.vXl,
        Text(
          'أيام الإغلاق',
          style: context.dsText.sectionTitle.tint(context.dsColors.onSurface),
        ),
        DsGaps.vXxxs,
        Text(
          'أعياد أو إجازات — بينسكّر الحجز بهالتواريخ بغضّ النظر عن الدوام.',
          style: context.dsText.caption.tint(
            context.dsColors.onSurfaceVariant,
          ),
        ),
        DsGaps.vSm,
        if (salon.closures.isEmpty)
          Text(
            'ما في أيام إغلاق.',
            style: context.dsText.body.tint(context.dsColors.onSurfaceVariant),
          )
        else
          for (final closure in salon.closures)
            _ClosureRow(
              closure: closure,
              onRemove: () => unawaited(_removeClosure(closure.date)),
            ),
        DsGaps.vSm,
        DsButton(
          label: 'أضيفي يوم إغلاق',
          icon: Icons.event_busy_outlined,
          variant: DsButtonVariant.tonal,
          onPressed: () => unawaited(_addClosure(salon)),
        ),
        DsGaps.vXl,
      ],
    );
  }

  Future<void> _pick(_Day day, _Which which) async {
    final current = switch (which) {
      _Which.opens => day.opensAt,
      _Which.closes => day.closesAt,
      _Which.breakStart => day.breakStartsAt ?? '13:00',
      _Which.breakEnd => day.breakEndsAt ?? '14:00',
    };
    final parts = current.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts.first) ?? 10,
        minute: int.tryParse(parts.last) ?? 0,
      ),
    );
    if (picked == null || !mounted) return;

    final value =
        '${picked.hour.toString().padLeft(2, '0')}:'
        '${picked.minute.toString().padLeft(2, '0')}';
    setState(() {
      switch (which) {
        case _Which.opens:
          day.opensAt = value;
        case _Which.closes:
          day.closesAt = value;
        case _Which.breakStart:
          day.breakStartsAt = value;
          day.breakEndsAt ??= value;
        case _Which.breakEnd:
          day.breakEndsAt = value;
          day.breakStartsAt ??= value;
      }
    });
  }

  Future<void> _save(List<_Day> week) async {
    if (_saving) return;

    // Caught here rather than by the server, because the server's refusal is
    // about the whole week and this says which day is wrong.
    for (final day in week) {
      if (day.isClosed) continue;
      if (_minutes(day.closesAt) <= _minutes(day.opensAt)) {
        DsSnackbar.error(
          context,
          'دوام ${SalonLabels.weekday(day.weekday)}: وقت الإغلاق لازم يكون بعد الافتتاح.',
        );
        return;
      }
      if (day.breakStartsAt != null &&
          day.breakEndsAt != null &&
          _minutes(day.breakEndsAt!) <= _minutes(day.breakStartsAt!)) {
        DsSnackbar.error(
          context,
          'استراحة ${SalonLabels.weekday(day.weekday)}: وقت النهاية لازم يكون بعد البداية.',
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      await ref
          .read(salonOwnerActionsProvider)
          .setHours(week.map((day) => day.toEntity()).toList(growable: false));
      if (!mounted) return;
      DsSnackbar.success(context, 'انحفظ الدوام');
    } catch (_) {
      if (!mounted) return;
      DsSnackbar.error(context, 'ما قدرنا نحفظ الدوام.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addClosure(Salon salon) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(Duration(days: salon.horizonDays + 365)),
      initialDate: now,
    );
    if (date == null || !mounted) return;

    final iso =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(salonOwnerActionsProvider).addClosure(iso);
      if (!mounted) return;
      DsSnackbar.success(context, 'انضاف يوم الإغلاق');
    } catch (_) {
      if (!mounted) return;
      DsSnackbar.error(context, 'ما قدرنا نضيف اليوم.');
    }
  }

  Future<void> _removeClosure(String date) async {
    try {
      await ref.read(salonOwnerActionsProvider).removeClosure(date);
      if (!mounted) return;
      DsSnackbar.success(context, 'انشال يوم الإغلاق');
    } catch (_) {
      if (!mounted) return;
      DsSnackbar.error(context, 'ما قدرنا نشيل اليوم.');
    }
  }

  static int _minutes(String time) {
    final parts = time.split(':');
    return (int.tryParse(parts.first) ?? 0) * 60 +
        (int.tryParse(parts.last) ?? 0);
  }
}

enum _Which { opens, closes, breakStart, breakEnd }

/// One weekday, mutable while she edits it.
class _Day {
  _Day({
    required this.weekday,
    required this.isClosed,
    required this.opensAt,
    required this.closesAt,
    this.breakStartsAt,
    this.breakEndsAt,
  });

  factory _Day.from(SalonHours hours) => _Day(
    weekday: hours.weekday,
    isClosed: hours.isClosed,
    opensAt: hours.opensAt,
    closesAt: hours.closesAt,
    breakStartsAt: hours.breakStartsAt,
    breakEndsAt: hours.breakEndsAt,
  );

  final int weekday;
  bool isClosed;
  String opensAt;
  String closesAt;
  String? breakStartsAt;
  String? breakEndsAt;

  SalonHours toEntity() => SalonHours(
    weekday: weekday,
    isClosed: isClosed,
    opensAt: opensAt,
    closesAt: closesAt,
    breakStartsAt: breakStartsAt,
    breakEndsAt: breakEndsAt,
  );
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.onToggle,
    required this.onPick,
    required this.onClearBreak,
  });

  final _Day day;
  final ValueChanged<bool> onToggle;
  final ValueChanged<_Which> onPick;
  final VoidCallback onClearBreak;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SurfaceCard(
      padding: const EdgeInsets.all(DsSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  SalonLabels.weekday(day.weekday),
                  style: context.dsText.tileTitle.semibold.tint(c.onSurface),
                ),
              ),
              Text(
                day.isClosed ? 'مسكّر' : 'فاتح',
                style: context.dsText.caption.tint(
                  day.isClosed ? c.onSurfaceVariant : c.success,
                ),
              ),
              Switch(value: !day.isClosed, onChanged: onToggle),
            ],
          ),
          if (!day.isClosed) ...[
            DsGaps.vXs,
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: 'من',
                    value: day.opensAt,
                    onTap: () => onPick(_Which.opens),
                  ),
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: _TimeButton(
                    label: 'إلى',
                    value: day.closesAt,
                    onTap: () => onPick(_Which.closes),
                  ),
                ),
              ],
            ),
            DsGaps.vXs,
            if (day.breakStartsAt == null && day.breakEndsAt == null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => onPick(_Which.breakStart),
                  icon: const Icon(Icons.free_breakfast_outlined, size: 16),
                  label: const Text('أضيفي استراحة'),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _TimeButton(
                      label: 'استراحة من',
                      value: day.breakStartsAt ?? '—',
                      onTap: () => onPick(_Which.breakStart),
                    ),
                  ),
                  const SizedBox(width: DsSpacing.sm),
                  Expanded(
                    child: _TimeButton(
                      label: 'إلى',
                      value: day.breakEndsAt ?? '—',
                      onTap: () => onPick(_Which.breakEnd),
                    ),
                  ),
                  IconButton(
                    onPressed: onClearBreak,
                    tooltip: 'شيلي الاستراحة',
                    icon: Icon(Icons.close_rounded, color: c.onSurfaceVariant),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return InkWell(
      onTap: onTap,
      borderRadius: DsRadius.borderMd,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.sm,
          vertical: DsSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: c.surfaceVariant,
          borderRadius: DsRadius.borderMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: context.dsText.micro.tint(c.onSurfaceVariant)),
            Text(
              value,
              style: context.dsText.body.semibold.tint(c.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClosureRow extends StatelessWidget {
  const _ClosureRow({required this.closure, required this.onRemove});

  final SalonClosure closure;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final parsed = DateTime.tryParse(closure.date);
    return Padding(
      padding: const EdgeInsets.only(bottom: DsSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.event_busy_outlined, size: 16, color: c.onSurfaceVariant),
          const SizedBox(width: DsSpacing.xs),
          Expanded(
            child: Text(
              parsed == null ? closure.date : SalonLabels.date(parsed),
              style: context.dsText.body.tint(c.onSurface),
            ),
          ),
          if (closure.reason != null && closure.reason!.isNotEmpty)
            Text(
              closure.reason!,
              style: context.dsText.caption.tint(c.onSurfaceVariant),
            ),
          IconButton(
            onPressed: onRemove,
            tooltip: 'شيلي',
            icon: Icon(Icons.close_rounded, color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
