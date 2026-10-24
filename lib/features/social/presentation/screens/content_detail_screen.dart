import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/social/presentation/providers/social_providers.dart';
import 'package:ohara/features/social/presentation/widgets/interactive_content_card.dart';

/// One piece, on its own — where a shared link lands.
///
/// This screen is the hole at the end of every post share. `RoutePaths
/// .contentDetailOf` and `RouteNames.contentDetail` have both existed for
/// some time; there was no route, no screen and no endpoint behind either of
/// them. So the share sheet handed out `…/p/<id>`, and `/p/<id>` opened
/// nothing on the web and nothing in the app.
///
/// It renders exactly what the feed renders — [InteractiveContentCard], which
/// already owns the heart, the thread, the share and the «…» menu and already
/// corrects itself against the server. A second, detail-only rendering of a
/// post is how the two drift, and how a woman finds that the post she opened
/// from a link behaves differently from the same post in her feed.
class ContentDetailScreen extends ConsumerWidget {
  const ContentDetailScreen({super.key, required this.contentId});

  final String contentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final async = ref.watch(contentByIdProvider(contentId));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CustomScrollView(
        slivers: [
          PremiumAppBar(
            title: l10n.socialFeedTitle,
            showBack: true,
            // Arriving from a link means there is nothing beneath this on the
            // stack, and a back arrow that closes the app is a dead end for
            // somebody who has just met Ohara. Home is the honest destination.
            onBack: () =>
                context.canPop() ? context.pop() : context.go(RoutePaths.home),
          ),
          switch (async) {
            AsyncData(:final value) => SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: DsSpacing.md,
                vertical: DsSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: InteractiveContentCard(
                  content: value,
                  // Hiding a post she opened by its own link leaves an empty
                  // screen, so the card sends her back to the feed instead of
                  // asking this screen to remove a list item it does not have.
                  onRemoved: () => context.canPop()
                      ? context.pop()
                      : context.go(RoutePaths.socialFeed),
                ),
              ),
            ),
            AsyncError() => SliverFillRemaining(
              hasScrollBody: false,
              child: DsErrorState(
                // Deliberately not "something went wrong". A link that has been
                // forwarded for a week is much more often pointing at something
                // deleted or made private than at a failure, and the server
                // answers both the same way.
                title: l10n.contentUnavailableTitle,
                message: l10n.contentUnavailableBody,
                onRetry: () => ref.invalidate(contentByIdProvider(contentId)),
              ),
            ),
            _ => const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: DsLoadingIndicator()),
            ),
          },
        ],
      ),
    );
  }
}
