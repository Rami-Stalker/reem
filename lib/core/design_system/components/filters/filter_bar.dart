import 'package:flutter/material.dart';
import 'package:reem/core/design_system/components/chips/ds_chip.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';

/// One option in a [DsFilterBar].
class DsFilterOption {
  const DsFilterOption({
    required this.label,
    this.selected = false,
    this.icon,
    this.count,
    this.onTap,
  });

  final String label;
  final bool selected;
  final IconData? icon;
  final int? count;
  final VoidCallback? onTap;
}

/// A horizontally scrollable row of filter / category chips.
///
/// Selection is caller-owned: pass [DsFilterOption]s with their `selected`
/// flag and an `onTap`. Works for single- or multi-select.
class DsFilterBar extends StatelessWidget {
  const DsFilterBar({
    super.key,
    required this.options,
    this.leading,
    this.padding =
        const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
    this.spacing = DsSpacing.xs,
    this.height = 44,
  });

  final List<DsFilterOption> options;

  /// Optional leading widget (e.g. a "Filters" button) pinned before the chips.
  final Widget? leading;
  final EdgeInsets padding;
  final double spacing;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length + (leading != null ? 1 : 0),
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder: (context, index) {
          if (leading != null && index == 0) {
            return Center(child: leading);
          }
          final option = options[index - (leading != null ? 1 : 0)];
          return Center(
            child: DsChip(
              label: option.label,
              selected: option.selected,
              icon: option.icon,
              count: option.count,
              onTap: option.onTap,
            ),
          );
        },
      ),
    );
  }
}
