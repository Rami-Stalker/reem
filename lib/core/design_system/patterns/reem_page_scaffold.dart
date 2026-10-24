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

    // No `physics` on purpose. It used to force iOS bounce on every platform,
    // which is the loudest tell that an Android app was drawn for an iPhone.
    // `AppScrollBehavior` answers instead: bounce on iOS, clamp-and-stretch on
    // Android, and always-scrollable on both so pull-to-refresh works on a
    // page whose content fits.
    Widget scrollView = CustomScrollView(
      controller: controller,
      slivers: [
        ...slivers,
        // The page ends where the bar begins. With `extendBody` the bar floats
        // over the content, and pages used to guess its height with a fixed
        // gap — a guess the checkout ticket outgrew, so the policy links under
        // the summary sat behind «تأكيد الطلب» and could not be scrolled to.
        // The scaffold already reports the bar's measured height (system
        // inset included) as the body's bottom padding; this pays exactly it.
        if (bottom != null && extendBody) const _BottomBarClearance(),
      ],
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
        children: [background ?? const CustomerBackdrop(), scrollView],
      ),
    );
  }
}

/// Room at the foot of a [ReemScrollPage] for its floating bottom bar.
///
/// Read inside the scaffold's body, where `MediaQuery.padding.bottom` is the
/// larger of the system inset and the bar's laid-out height.
class _BottomBarClearance extends StatelessWidget {
  const _BottomBarClearance();

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: SizedBox(height: MediaQuery.paddingOf(context).bottom),
    );
  }
}
