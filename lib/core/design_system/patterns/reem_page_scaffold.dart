import 'package:flutter/material.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/patterns/experience_design.dart';
import 'package:reem/core/design_system/utilities/extensions/context_extensions.dart';

/// Standard scroll page with feminine mesh background.
///
/// Pass [onRefresh] to enable pull-to-refresh — the sliver content is wrapped
/// in a brand-tinted [RefreshIndicator] anchored below the status bar.
class ReemScrollPage extends StatelessWidget {
  const ReemScrollPage({
    super.key,
    required this.slivers,
    this.bottom,
    this.floatingActionButton,
    this.extendBody = true,
    this.onRefresh,
    this.controller,
    this.background,
    this.backgroundColor,
  });

  final List<Widget> slivers;
  final Widget? bottom;
  final Widget? floatingActionButton;
  final bool extendBody;

  /// When provided, enables pull-to-refresh.
  final Future<void> Function()? onRefresh;

  /// Optional external scroll controller (e.g. scroll-to-top affordances).
  final ScrollController? controller;
  final Widget? background;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;

    Widget scrollView = CustomScrollView(
      controller: controller,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: slivers,
    );

    if (onRefresh != null) {
      scrollView = RefreshIndicator(
        onRefresh: onRefresh!,
        color: colors.primary,
        backgroundColor: colors.surface,
        // Anchor the spinner just below the translucent app bar / status bar.
        edgeOffset: MediaQuery.paddingOf(context).top + 56,
        displacement: 24,
        child: scrollView,
      );
    }

    return Scaffold(
      extendBody: extendBody,
      extendBodyBehindAppBar: true,
      backgroundColor: backgroundColor ?? colors.background,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottom,
      body: Stack(
        children: [
          background ?? const CustomerBackdrop(),
          scrollView,
        ],
      ),
    );
  }
}
