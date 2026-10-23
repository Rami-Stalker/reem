import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/occasions/data/datasources/occasions_remote_datasource.dart';
import 'package:reem/features/occasions/domain/entities/occasion.dart';
import 'package:reem/features/occasions/presentation/providers/occasions_providers.dart';
import 'package:reem/features/occasions/presentation/widgets/occasion_labels.dart';
import 'package:reem/features/salons/presentation/widgets/salon_labels.dart';

/// Writing a day down, or correcting one.
///
/// Short on purpose: what kind of day, what to call it, and when. Everything
/// else is optional, and the one optional field worth explaining — who will be
/// there — says why it is asked right under it.
class OccasionEditorScreen extends ConsumerWidget {
  const OccasionEditorScreen({super.key, this.occasionId});

  /// Null for a new occasion.
  final String? occasionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = occasionId;
    if (id == null) return const _EditorForm();

    final async = ref.watch(occasionProvider(id));
    return async.when(
      loading: () => Scaffold(
        appBar: ReemAppBar(title: context.l10n.occasionEdit),
        body: const Center(child: DsLoadingIndicator()),
      ),
      error: (_, _) => Scaffold(
        appBar: ReemAppBar(title: context.l10n.occasionEdit),
        body: DsErrorState(
          message: context.l10n.occasionLoadError,
          onRetry: () => ref.invalidate(occasionProvider(id)),
        ),
      ),
      data: (occasion) => _EditorForm(initial: occasion),
    );
  }
}

class _EditorForm extends ConsumerStatefulWidget {
  const _EditorForm({this.initial});

  final Occasion? initial;

  @override
  ConsumerState<_EditorForm> createState() => _EditorFormState();
}

class _EditorFormState extends ConsumerState<_EditorForm> {
  late final _title = TextEditingController(text: widget.initial?.title);
  late final _circle = TextEditingController(text: widget.initial?.circle);
  late final _location = TextEditingController(text: widget.initial?.location);
  late final _note = TextEditingController(text: widget.initial?.note);

  late OccasionKind? _kind = widget.initial?.kind;
  late DateTime? _date = widget.initial?.date;
  late TimeOfDay? _time = _parseTime(widget.initial?.startsAtTime);
  late bool _reminders = widget.initial?.remindersEnabled ?? true;
  bool _saving = false;

  bool get _isEdit => widget.initial != null;

  @override
  void dispose() {
    _title.dispose();
    _circle.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving &&
      _kind != null &&
      _date != null &&
      _title.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: c.background,
      appBar: ReemAppBar(title: _isEdit ? l10n.occasionEdit : l10n.occasionNew),
      body: ListView(
        padding: const EdgeInsets.all(DsSpacing.md),
        children: [
          Text(l10n.occasionKindQuestion, style: context.dsText.labelStrong),
          DsGaps.vXs,
          Wrap(
            spacing: DsSpacing.xs,
            runSpacing: DsSpacing.xs,
            children: [
              for (final kind in OccasionKind.values)
                DsChip(
                  label: OccasionLabels.kind(l10n, kind),
                  icon: OccasionLabels.icon(kind),
                  selected: _kind == kind,
                  onTap: () => _chooseKind(kind),
                ),
            ],
          ),
          DsGaps.vMd,
          DsInputField(
            controller: _title,
            label: l10n.occasionTitleLabel,
            hint: l10n.occasionTitleHint,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
          ),
          DsGaps.vSm,
          _PickerRow(
            icon: Icons.event_rounded,
            label: l10n.occasionDateLabel,
            value: _date == null ? null : SalonLabels.date(l10n, _date!),
            placeholder: l10n.occasionDatePick,
            onTap: _pickDate,
          ),
          DsGaps.vSm,
          _PickerRow(
            icon: Icons.schedule_rounded,
            label: l10n.occasionTimeLabel,
            value: _time == null ? null : _formatTime(_time!),
            placeholder: l10n.occasionOptional,
            onTap: _pickTime,
            onClear: _time == null ? null : () => setState(() => _time = null),
          ),
          DsGaps.vMd,
          DsInputField(
            controller: _circle,
            label: l10n.occasionCircleLabel,
            hint: l10n.occasionCircleHint,
            helperText: l10n.occasionCircleHelper,
            maxLength: 80,
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _location,
            label: l10n.occasionLocationLabel,
            maxLength: 120,
          ),
          DsGaps.vSm,
          DsInputField(
            controller: _note,
            label: l10n.occasionNoteLabel,
            maxLines: 3,
            maxLength: 500,
          ),
          DsGaps.vSm,
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _reminders,
            onChanged: (value) => setState(() => _reminders = value),
            title: Text(
              l10n.occasionReminders,
              style: context.dsText.bodyStrong,
            ),
            subtitle: Text(
              l10n.occasionRemindersHint,
              style: context.dsText.caption.tint(c.onSurfaceVariant),
            ),
          ),
          DsGaps.vXl,
          DsButton(
            label: _isEdit ? l10n.occasionSave : l10n.occasionCreate,
            isLoading: _saving,
            onPressed: _canSave ? _save : null,
          ),
          DsGaps.bottomSafe,
        ],
      ),
    );
  }

  /// Choosing a kind names the day too, when she has not named it yet — «عرس»
  /// is a fine start, and she adds «سارة» to it.
  void _chooseKind(OccasionKind kind) {
    final previous = _kind;
    setState(() => _kind = kind);
    final current = _title.text.trim();
    final l10n = context.l10n;
    if (current.isEmpty ||
        (previous != null && current == OccasionLabels.kind(l10n, previous))) {
      _title.text = OccasionLabels.kind(l10n, kind);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      // The past is allowed: writing down what she wore to a wedding last
      // month is what makes the repeat warning work.
      firstDate: today.subtract(const Duration(days: 730)),
      lastDate: today.add(const Duration(days: 1095)),
      initialDate: _date ?? today.add(const Duration(days: 7)),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 19, minute: 0),
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  String _formatTime(TimeOfDay time) => SalonLabels.time(
    context.l10n,
    DateTime(2000, 1, 1, time.hour, time.minute),
  );

  Future<void> _save() async {
    setState(() => _saving = true);
    final draft = OccasionDraft(
      title: _title.text,
      kind: _kind!,
      date: _date!,
      startsAtTime: _time == null ? null : _wireTime(_time!),
      location: _location.text,
      circle: _circle.text,
      note: _note.text,
      remindersEnabled: _reminders,
    );

    try {
      final actions = ref.read(occasionActionsProvider);
      final initial = widget.initial;
      if (initial == null) {
        final created = await actions.create(draft);
        if (!mounted) return;
        // Straight to the plan: the reason she wrote it down is to get ready.
        context.pushReplacement(RoutePaths.occasionOf(created.id));
      } else {
        await actions.update(initial.id, draft);
        if (!mounted) return;
        DsSnackbar.success(context, context.l10n.occasionSaved);
        context.canPop()
            ? context.pop()
            : context.go(RoutePaths.occasionOf(initial.id));
      }
    } catch (_) {
      if (!mounted) return;
      DsSnackbar.error(context, context.l10n.occasionSaveFailed);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _wireTime(TimeOfDay time) =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  static TimeOfDay? _parseTime(String? value) {
    final parts = value?.split(':');
    if (parts == null || parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }
}

/// A form row that opens a picker rather than taking typing.
class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final String? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return SurfaceCard(
      onTap: onTap,
      semanticLabel: label,
      padding: DsSpacing.listRowPadding,
      child: Row(
        children: [
          Icon(icon, size: DsSizes.iconMd, color: c.primary),
          DsGaps.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: context.dsText.caption.tint(c.onSurfaceVariant),
                ),
                DsGaps.vXxxs,
                Text(
                  value ?? placeholder,
                  style: value == null
                      ? context.dsText.body.tint(c.onSurfaceVariant)
                      : context.dsText.bodyStrong,
                ),
              ],
            ),
          ),
          if (onClear != null)
            DsIconButton(
              icon: Icons.close_rounded,
              tooltip: context.l10n.occasionClear,
              onPressed: onClear,
            ),
        ],
      ),
    );
  }
}
