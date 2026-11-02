import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';

/// The frame every store settings page shares: the atelier banner, a gutter,
/// pull to refresh, and room at the bottom.
class StoreSettingsPage extends StatelessWidget {
  const StoreSettingsPage({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    required this.onRefresh,
    this.subtitle,
    this.actions,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget child;
  final Future<void> Function() onRefresh;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return OharaScrollPage(
      onRefresh: onRefresh,
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        AtelierAppBar(
          icon: icon,
          title: title,
          subtitle: subtitle,
          showBack: true,
          actions: actions,
        ),
        DsGaps.sliverMd,
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: atelierGutter(context)),
          sliver: SliverToBoxAdapter(child: child),
        ),
        DsGaps.sliverBottomSafe,
      ],
    );
  }
}

class StoreLoading extends StatelessWidget {
  const StoreLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(DsSpacing.xxl),
    child: Center(child: DsLoadingIndicator()),
  );
}

/// A gold-edged note at the head of a page.
class StoreNotice extends StatelessWidget {
  const StoreNotice({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return SellerPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: palette.gold),
          DsGaps.hSm,
          Expanded(
            child: Text(
              text,
              style: context.dsText.bodySmall
                  .tint(palette.ink)
                  .copyWith(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// A labelled switch inside a panel.
class StoreSwitchRow extends StatelessWidget {
  const StoreSwitchRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return MergeSemantics(
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: context.dsText.tileTitle.tint(palette.ink),
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// A free-text note: a few lines, a hint, a length cap.
class StoreNoteField extends StatelessWidget {
  const StoreNoteField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.maxLength = 600,
    this.maxLines = 3,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) => DsInputField(
    controller: controller,
    label: label,
    hint: hint,
    maxLines: maxLines,
    minLines: 1,
    maxLength: maxLength,
    textCapitalization: TextCapitalization.sentences,
  );
}
