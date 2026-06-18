import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/design_system/design_system.dart';
import '../../domain/entities/seller_chart_data.dart';
import '../providers/seller_dashboard_provider.dart';

/// Full analytics chart: period toggle + smooth gradient line chart + labels.
class SellerAnalyticsChart extends ConsumerStatefulWidget {
  const SellerAnalyticsChart({super.key});

  @override
  ConsumerState<SellerAnalyticsChart> createState() =>
      _SellerAnalyticsChartState();
}

class _SellerAnalyticsChartState extends ConsumerState<SellerAnalyticsChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _reAnimate() {
    _ctrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);
    final state = ref.watch(sellerDashboardNotifierProvider);
    final notifier = ref.read(sellerDashboardNotifierProvider.notifier);

    if (state.isInitialLoading) {
      return DsShimmer(
        child: DsSkeleton.box(height: 280, borderRadius: DsRadius.xl),
      );
    }

    final dataset = state.data?.charts[state.selectedChartPeriod];
    if (dataset == null) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: DsRadius.borderXxl,
        border: Border.all(color: c.border.withValues(alpha: 0.5)),
        boxShadow: context.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg, DsSpacing.lg, DsSpacing.lg, DsSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Revenue',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: DsTypography.bold),
                  ),
                ),
                _PeriodSelector(
                  selected: state.selectedChartPeriod,
                  onSelect: (p) {
                    notifier.setChartPeriod(p);
                    _reAnimate();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(double.infinity, 180),
                  painter: _LineChartPainter(
                    points: dataset.revenuePoints,
                    progress: _anim.value,
                    lineColor: c.primary,
                    fillStart: c.primary.withValues(alpha: 0.28),
                    fillEnd: c.primary.withValues(alpha: 0.0),
                    gridColor: c.divider,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: DsSpacing.xs),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                DsSpacing.lg, 0, DsSpacing.lg, DsSpacing.lg),
            child: _XLabels(points: dataset.revenuePoints),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 400.ms, curve: Curves.easeOut)
        .slideY(begin: 0.04, end: 0, duration: 400.ms);
  }
}

// ── Period selector ───────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelect});

  final ChartPeriod selected;
  final ValueChanged<ChartPeriod> onSelect;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: c.surfaceVariant,
        borderRadius: DsRadius.borderMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ChartPeriod.values.map((p) {
          final active = p == selected;
          return GestureDetector(
            onTap: () => onSelect(p),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.sm, vertical: DsSpacing.xxs + 1),
              decoration: BoxDecoration(
                color: active ? c.card : Colors.transparent,
                borderRadius: DsRadius.borderSm,
                boxShadow: active ? context.softShadow : null,
              ),
              child: Text(
                p.label,
                style: TextStyle(
                  fontFamily: DsTypography.fontFamily,
                  fontSize: DsTypography.labelSmall,
                  fontWeight: active ? DsTypography.bold : DsTypography.regular,
                  color: active ? c.primary : c.onSurfaceVariant,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── X-axis labels ─────────────────────────────────────────────────────────────

class _XLabels extends StatelessWidget {
  const _XLabels({required this.points});

  final List<SellerChartPoint> points;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    if (points.isEmpty) return const SizedBox.shrink();
    final step = points.length > 6 ? 2 : 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < points.length; i += step)
          Text(
            points[i].label,
            style: TextStyle(
              fontFamily: DsTypography.fontFamily,
              fontSize: 10,
              color: c.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

// ── Custom painter ─────────────────────────────────────────────────────────────

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.points,
    required this.progress,
    required this.lineColor,
    required this.fillStart,
    required this.fillEnd,
    required this.gridColor,
  });

  final List<SellerChartPoint> points;
  final double progress;
  final Color lineColor;
  final Color fillStart;
  final Color fillEnd;
  final Color gridColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = points.map((p) => p.value).reduce(math.max);
    final minVal = points.map((p) => p.value).reduce(math.min);
    final range = (maxVal - minVal).clamp(1.0, double.infinity);

    // Normalized [0..1] y positions (inverted: higher = lower on canvas).
    Offset pos(int i) {
      final x = points.length == 1
          ? size.width / 2
          : i / (points.length - 1) * size.width;
      final y = size.height -
          ((points[i].value - minVal) / range) * size.height * 0.82 -
          size.height * 0.09;
      return Offset(x, y);
    }

    // Build a smooth path using cubic bezier control points.
    final linePath = Path();
    final offsets = List.generate(points.length, pos);

    linePath.moveTo(offsets[0].dx, offsets[0].dy);
    for (var i = 0; i < offsets.length - 1; i++) {
      final cp1 = Offset(
        offsets[i].dx + (offsets[i + 1].dx - offsets[i].dx) / 2,
        offsets[i].dy,
      );
      final cp2 = Offset(
        offsets[i].dx + (offsets[i + 1].dx - offsets[i].dx) / 2,
        offsets[i + 1].dy,
      );
      linePath.cubicTo(
          cp1.dx, cp1.dy, cp2.dx, cp2.dy, offsets[i + 1].dx, offsets[i + 1].dy);
    }

    // Clip to the animated progress width.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width * progress, size.height));

    // Gradient fill.
    final fillPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, size.height)
      ..lineTo(offsets.first.dx, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [fillStart, fillEnd],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Line stroke.
    canvas.drawPath(
      linePath,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Dots at data points.
    for (final o in offsets) {
      canvas.drawCircle(o, 3.5, Paint()..color = lineColor);
      canvas.drawCircle(
          o, 3.5, Paint()..color = Colors.white..strokeWidth = 1.5..style = PaintingStyle.stroke);
    }

    canvas.restore();

    // Horizontal grid lines (3 lines).
    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) =>
      old.progress != progress || old.points != points;
}

// ── Tiny sparkline (for metric cards) ────────────────────────────────────────

class MiniSparkline extends StatelessWidget {
  const MiniSparkline({
    super.key,
    required this.values,
    this.color,
    this.height = 32,
    this.width = 64,
  });

  final List<double> values;
  final Color? color;
  final double height;
  final double width;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return CustomPaint(
      size: Size(width, height),
      painter: _SparklinePainter(
        values: values,
        color: color ?? c.primary,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  const _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final max = values.reduce(math.max);
    final min = values.reduce(math.min);
    final range = (max - min).clamp(1.0, double.infinity);

    Offset pos(int i) => Offset(
          i / (values.length - 1) * size.width,
          size.height - ((values[i] - min) / range) * size.height * 0.8 - size.height * 0.1,
        );

    final path = Path();
    final offsets = List.generate(values.length, pos);
    path.moveTo(offsets[0].dx, offsets[0].dy);
    for (var i = 0; i < offsets.length - 1; i++) {
      final cp1 = Offset(offsets[i].dx + (offsets[i + 1].dx - offsets[i].dx) / 2, offsets[i].dy);
      final cp2 = Offset(offsets[i].dx + (offsets[i + 1].dx - offsets[i].dx) / 2, offsets[i + 1].dy);
      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, offsets[i + 1].dx, offsets[i + 1].dy);
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.values != values;
}
