import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/features/seller_dashboard/domain/entities/seller_misc.dart';
import 'package:ohara/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';

class SellerStoreScoreWidget extends ConsumerWidget {
  const SellerStoreScoreWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sellerDashboardNotifierProvider);
    final c = context.dsColors;

    if (state.isInitialLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        child: DsShimmer(
            child: DsSkeleton.box(height: 180, borderRadius: DsRadius.xxl)),
      );
    }

    final score = state.data?.storeScore;
    if (score == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(DsSpacing.lg),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: DsRadius.borderXxl,
          border: Border.all(color: c.border.withValues(alpha: 0.5)),
          boxShadow: context.softShadow,
        ),
        child: Row(
          children: [
            _ScoreGauge(score: score),
            const SizedBox(width: DsSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.sellerStorePerformance,
                    style: context.dsText.tileTitle
                        .copyWith(fontWeight: DsTypography.bold),
                  ),
                  const SizedBox(height: DsSpacing.xs),
                  _ScoreBar(
                    label: context.l10n.sellerFulfillment,
                    value: score.fulfillment,
                    color: c.success,
                  ),
                  const SizedBox(height: DsSpacing.xs),
                  _ScoreBar(
                    label: context.l10n.sellerResponsiveness,
                    value: score.responsiveness,
                    color: c.info,
                  ),
                  const SizedBox(height: DsSpacing.xs),
                  _ScoreBar(
                    label: context.l10n.sellerProductQuality,
                    value: score.productQuality,
                    color: c.secondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 380.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 380.ms);
  }
}

class _ScoreGauge extends StatefulWidget {
  const _ScoreGauge({required this.score});

  final SellerStoreScore score;

  @override
  State<_ScoreGauge> createState() => _ScoreGaugeState();
}

class _ScoreGaugeState extends State<_ScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final score = widget.score;
    final gradeColor = context.toneColor(score.gradeTone);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) => CustomPaint(
        size: const Size(88, 88),
        painter: _GaugePainter(
          value: score.overall / 100 * _anim.value,
          color: gradeColor,
          trackColor: c.surfaceVariant,
        ),
        child: SizedBox(
          width: 88,
          height: 88,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(score.overall * _anim.value).round()}',
                  style: context.dsText.screenTitle.copyWith(
                    fontWeight: DsTypography.bold,
                    color: gradeColor,
                    height: 1,
                  ),
                ),
                Text(
                  score.grade,
                  style: context.dsText.caption
                      .copyWith(
                        color: c.onSurfaceVariant,
                        fontSize: DsTypography.labelMicro,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter({
    required this.value,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 8.0;
    const startAngle = math.pi * 0.75;
    const sweepFull = math.pi * 1.5;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Track.
    canvas.drawArc(
      rect,
      startAngle,
      sweepFull,
      false,
      Paint()
        ..color = trackColor
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );

    // Value arc.
    if (value > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        sweepFull * value,
        false,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.value != value || old.color != color;
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;

  /// Null means unmeasured, which is drawn as an empty track and a dash
  /// rather than as a score of zero.
  final int? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: context.dsText.caption
                .copyWith(color: c.onSurfaceVariant, fontSize: DsTypography.labelMicro),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: DsRadius.borderFull,
            child: Stack(
              children: [
                Container(height: 5, color: c.surfaceVariant),
                FractionallySizedBox(
                  widthFactor: (value ?? 0) / 100,
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: DsRadius.borderFull,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: DsSpacing.xs),
        SizedBox(
          width: 28,
          child: Text(
            value == null ? '—' : '$value',
            textAlign: TextAlign.end,
            style: context.dsText.caption.copyWith(
              fontWeight: DsTypography.bold,
              color: color,
              fontSize: DsTypography.labelMicro,
            ),
          ),
        ),
      ],
    );
  }
}
