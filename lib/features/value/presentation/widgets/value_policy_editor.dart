import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/value/domain/entities/value_admin.dart';
import 'package:reem/features/value/presentation/providers/value_admin_providers.dart';

/// The label column beside each slider. Every row in the editor shares it, so
/// the sliders start on one line down the panel instead of stepping in and out
/// with the length of each Arabic label.
const double _sliderLabelWidth = 130;

/// The economics, retuned.
///
/// The whole point of this widget is the sequence it enforces: **draft →
/// simulate → activate**. Activation is disabled until a simulation exists for
/// that exact version, and a disruptive result has to be confirmed in words.
///
/// That is not ceremony. Activating a policy rescores every profile on the
/// platform, and a woman who loses a rung overnight because somebody nudged a
/// weight has been told something about her relationship with Reem that nobody
/// intended to say. The server supports the sequence with three endpoints; this
/// screen is what makes it the only available path.
class ValuePolicySection extends ConsumerWidget {
  const ValuePolicySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final console = context.console;
    final policiesAsync = ref.watch(valuePoliciesProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(DsSpacing.lg),
      decoration: BoxDecoration(
        color: console.surface,
        borderRadius: BorderRadius.circular(DsRadius.card),
        border: Border.all(color: console.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('السياسة', style: context.dsText.sectionTitle),
                    Text(
                      'كل تعديل بيصير نسخة جديدة — بتتجرّب على الناس قبل ما تنفّذ.',
                      style: context.dsText.sectionSubtitle,
                    ),
                  ],
                ),
              ),
              policiesAsync.maybeWhen(
                data: (policies) => FilledButton.icon(
                  icon: const Icon(Icons.tune_rounded, size: 18),
                  label: const Text('نسخة جديدة'),
                  onPressed: policies.isEmpty
                      ? null
                      : () => _openEditor(
                          context,
                          ref,
                          policies.firstWhere(
                            (p) => p.isActive,
                            orElse: () => policies.first,
                          ),
                        ),
                ),
                orElse: () => const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: DsSpacing.md),
          policiesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(DsSpacing.lg),
              child: Center(child: DsLoadingIndicator()),
            ),
            error: (_, _) => const Text('ما قدرنا نجيب السياسات.'),
            data: (policies) => Column(
              children: [
                for (final policy in policies.take(8))
                  _PolicyRow(policy: policy),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    ValuePolicyVersion base,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _PolicyEditorDialog(base: base),
    );
  }
}

class _PolicyRow extends ConsumerWidget {
  const _PolicyRow({required this.policy});

  final ValuePolicyVersion policy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final console = context.console;
    final simulation = ref.watch(valueSimulationProvider)[policy.id];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: DsSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Row(
                  children: [
                    Text(
                      'v${policy.version}',
                      style: context.dsText.labelStrong,
                    ),
                    if (policy.isActive) ...[
                      DsGaps.hXxs,
                      Icon(Icons.circle, size: 8, color: console.positive),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  policy.note ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.body,
                ),
              ),
              SizedBox(
                width: 150,
                child: Text(
                  'سقف الشرا ${policy.commerceCeilingPoints} · '
                  'نصف العمر ${policy.halfLifeDays}ي',
                  textAlign: TextAlign.end,
                  style: context.dsText.micro.tint(console.muted),
                ),
              ),
              if (!policy.isActive) ...[
                const SizedBox(width: DsSpacing.sm),
                TextButton(
                  onPressed: () => _simulate(context, ref),
                  child: const Text('جرّبي'),
                ),
                // Disabled until this exact version has been simulated. The
                // sequence is the safeguard, so the button enforces it rather
                // than a warning nobody reads.
                FilledButton(
                  onPressed: simulation == null
                      ? null
                      : () => _activate(context, ref, simulation),
                  child: const Text('فعّلي'),
                ),
              ],
            ],
          ),
          if (simulation != null) _SimulationSummary(simulation: simulation),
        ],
      ),
    );
  }

  Future<void> _simulate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(valueAdminActionsProvider).simulate(policy.id);
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('ما نجحت التجربة.')));
    }
  }

  Future<void> _activate(
    BuildContext context,
    WidgetRef ref,
    ValueSimulation simulation,
  ) async {
    // The number that should make somebody stop, spelled out rather than left
    // in a table: a demotion is the one change here a customer feels as a
    // loss. It used to be carried by a red tint as well; the words alone now
    // say it, which is what a screen reader — and a colour-blind operator —
    // actually receives.
    final impact = simulation.isDisruptive
        ? '${simulation.movedDown} من ${simulation.sampled} رح ينزلوا درجة. '
              'هيدا تغيير محسوس — تأكّدي إنك ناوية ياه.'
        : '${simulation.movedUp} رح يطلعوا و${simulation.movedDown} رح ينزلوا '
              'من أصل ${simulation.sampled}.';

    final confirmed = await DsDialog.confirm(
      context,
      title: 'تفعيل السياسة',
      message: 'رح تنعاد حسبة كل الملفات على القواعد الجديدة.\n\n$impact',
      confirmLabel: 'فعّلي',
      cancelLabel: 'إلغاء',
      destructive: simulation.isDisruptive,
    );

    if (!confirmed || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(valueAdminActionsProvider).activate(policy.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('تم التفعيل، وانعادت الحسبة.')),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('ما نجح التفعيل.')));
    }
  }
}

class _SimulationSummary extends StatelessWidget {
  const _SimulationSummary({required this.simulation});

  final ValueSimulation simulation;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    final accent = simulation.isDisruptive ? console.caution : console.info;

    return Container(
      margin: const EdgeInsets.only(top: DsSpacing.xs, bottom: DsSpacing.xs),
      padding: const EdgeInsets.all(DsSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DsRadius.sm),
      ),
      child: Row(
        children: [
          Icon(Icons.science_outlined, size: 16, color: accent),
          const SizedBox(width: DsSpacing.xs),
          Expanded(
            child: Text(
              'على ${simulation.sampled} ملف: '
              '↑${simulation.movedUp} · ↓${simulation.movedDown} · '
              '=${simulation.unchanged} · '
              'متوسط الفرق ${simulation.averageScoreDelta.toStringAsFixed(1)}',
              style: context.dsText.caption,
            ),
          ),
        ],
      ),
    );
  }
}

/// The editor.
///
/// Only the tunables an operator has a real reason to move are here — the pillar
/// weights, the commerce ceiling, the half-life, the evidence floor. Per-event
/// weights and pillar scales are deliberately absent: they are the difference
/// between "what Reem values" and "how quickly a pillar fills", and changing
/// them from a dialog with no simulation of their own is how a programme drifts
/// without anybody deciding it should.
class _PolicyEditorDialog extends ConsumerStatefulWidget {
  const _PolicyEditorDialog({required this.base});

  final ValuePolicyVersion base;

  @override
  ConsumerState<_PolicyEditorDialog> createState() =>
      _PolicyEditorDialogState();
}

class _PolicyEditorDialogState extends ConsumerState<_PolicyEditorDialog> {
  static const _pillars = [
    ('COMMERCE', 'شراء'),
    ('CRAFT', 'رأي'),
    ('COMMUNITY', 'مجتمع'),
    ('ADVOCACY', 'دعوة'),
    ('DISCOVERY', 'اكتشاف'),
    ('RELIABILITY', 'التزام'),
  ];

  late final Map<String, int> _weights = {
    for (final (key, _) in _pillars)
      key: (widget.base.pillarWeights[key] as num?)?.toInt() ?? 0,
  };

  late int _ceilingBps = widget.base.commerceCeilingBps;
  late int _halfLife = widget.base.halfLifeDays;
  late int _minEvidence = widget.base.minEvidencePerPillar;
  final _note = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int get _totalWeight => _weights.values.fold(0, (a, b) => a + b);

  /// The live preview of the guarantee, computed the same way the kernel does.
  ///
  /// Shown while she drags, because the alternative is drafting a policy,
  /// simulating it, and only then discovering it broke the one promise the
  /// programme makes. The server re-checks it on activation; this is so the
  /// answer is not a surprise.
  int get _spendingCeiling {
    if (_totalWeight == 0) return 0;
    final commerceShare = (_weights['COMMERCE'] ?? 0) / _totalWeight;
    final commerce = (1000 * commerceShare)
        .clamp(0, _ceilingBps / 10000 * 1000)
        .toDouble();
    final reliabilityShare = (_weights['RELIABILITY'] ?? 0) / _totalWeight;
    final reliability =
        1000 * reliabilityShare * (widget.base.reliabilityBaseline / 100);
    return (commerce + reliability).round();
  }

  @override
  Widget build(BuildContext context) {
    final console = context.console;

    return AlertDialog(
      title: Text('نسخة جديدة من v${widget.base.version}'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('أوزان الجهات', style: context.dsText.labelStrong),
              Text(
                'نسبية — المجموع ما لازم يكون ١٠٠.',
                style: context.dsText.micro.tint(console.muted),
              ),
              const SizedBox(height: DsSpacing.xs),
              for (final (key, label) in _pillars)
                _SliderRow(
                  label: label,
                  value: _weights[key]!.toDouble(),
                  min: 0,
                  max: 50,
                  suffix:
                      '${_totalWeight == 0 ? 0 : ((_weights[key]! / _totalWeight) * 100).round()}%',
                  onChanged: (v) => setState(() => _weights[key] = v.round()),
                ),

              const Divider(height: DsSpacing.lg),

              _SliderRow(
                label: 'سقف الشرا',
                value: _ceilingBps.toDouble(),
                min: 0,
                max: 6000,
                divisions: 60,
                suffix: '${(_ceilingBps / 10).round()} نقطة',
                onChanged: (v) => setState(() => _ceilingBps = v.round()),
              ),
              _SliderRow(
                label: 'نصف العمر',
                value: _halfLife.toDouble(),
                min: 30,
                max: 1460,
                divisions: 143,
                suffix: '$_halfLife يوم',
                onChanged: (v) => setState(() => _halfLife = v.round()),
              ),
              _SliderRow(
                label: 'أقل عدد أدلة للجهة',
                value: _minEvidence.toDouble(),
                min: 1,
                max: 20,
                divisions: 19,
                suffix: '$_minEvidence',
                onChanged: (v) => setState(() => _minEvidence = v.round()),
              ),

              const SizedBox(height: DsSpacing.md),
              _GuaranteePreview(ceiling: _spendingCeiling),

              const SizedBox(height: DsSpacing.md),
              DsInputField(
                controller: _note,
                label: 'ليش هالتغيير؟',
                hint: 'بتنقرأ بعد سنة من حدا تاني',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving || _totalWeight == 0 ? null : _save,
          child: Text(_saving ? '...' : 'احفظي كمسوّدة'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await ref
          .read(valueAdminActionsProvider)
          .draft(
            ValuePolicyDraft(
              pillarWeights: _weights,
              commerceCeilingBps: _ceilingBps,
              halfLifeDays: _halfLife,
              minEvidencePerPillar: _minEvidence,
              note: _note.text.trim(),
            ),
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('انحفظت كمسوّدة — جرّبيها قبل ما تفعّليها.'),
        ),
      );
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(const SnackBar(content: Text('ما نجح الحفظ.')));
    }
  }
}

class _GuaranteePreview extends StatelessWidget {
  const _GuaranteePreview({required this.ceiling});

  final int ceiling;

  @override
  Widget build(BuildContext context) {
    final console = context.console;
    // 420 is the third rung in the seeded ladder. Read from the ladder would be
    // better; this preview errs towards warning early, and the server's own
    // check is authoritative on activation.
    final risky = ceiling >= 420;
    final accent = risky ? console.critical : console.positive;

    return Container(
      padding: const EdgeInsets.all(DsSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DsRadius.sm),
      ),
      child: Row(
        children: [
          Icon(
            risky ? Icons.warning_amber_rounded : Icons.verified_rounded,
            size: 16,
            color: accent,
          ),
          const SizedBox(width: DsSpacing.xs),
          Expanded(
            child: Text(
              risky
                  ? 'بهالأوزان، يلي بس بتشتري بتوصل $ceiling — عم توصل للدرجات العليا.'
                  : 'يلي بس بتشتري بتوصل $ceiling من ١٠٠٠ — المكانة بتضل ما بتنشرى.',
              style: context.dsText.caption.tint(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.suffix,
    required this.onChanged,
    this.divisions,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final int? divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _sliderLabelWidth,
          child: Text(label, style: context.dsText.body),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions ?? (max - min).round(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 80,
          child: Text(
            suffix,
            textAlign: TextAlign.end,
            style: context.dsText.numeric,
          ),
        ),
      ],
    );
  }
}
