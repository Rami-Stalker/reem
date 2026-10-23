import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/presentation/providers/chat_notifier.dart';
import 'package:reem/features/chat/presentation/providers/chat_provider.dart';
import 'package:reem/features/chat/presentation/providers/chat_state.dart';
import 'package:reem/features/chat/presentation/widgets/chat_tile.dart';
import 'package:reem/features/chat/presentation/widgets/encrypted_chat_banner.dart';
import 'package:reem/features/chat/presentation/widgets/glass_search_bar.dart';

/// Her conversations with the boutiques she buys from.
///
/// There is deliberately no "compose" button: a conversation here is always
/// *about* something — a product, a parcel — and the server needs to know
/// which. The way in is «راسلي المتجر» on the product, the storefront or the
/// order, which is also where she is when the question occurs to her.
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen> {
  StreamSubscription<Map<String, dynamic>>? _realtimeSub;

  /// Coalesces a burst of arriving messages into one reload.
  Timer? _refreshDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    await ref.read(chatNotifierProvider.notifier).load();
    if (!mounted) return;

    // The gateway addresses message events to every participant, not just to
    // whoever has joined the room — so the inbox stays current without ever
    // joining a conversation.
    final realtime = ref.read(chatRealtimeServiceProvider);
    await realtime.connect();
    if (!mounted) return;
    _realtimeSub = realtime.events.listen((event) {
      if (!mounted) return;
      // Applied in place where it can be — a new message moves its row to
      // the top at once, presence and typing land on their row — and
      // refetched only when it cannot: a conversation not on screen yet, or
      // the socket coming back after a drop.
      final needsRefresh = ref
          .read(chatNotifierProvider.notifier)
          .applyRealtime(event);
      if (!needsRefresh) return;
      _refreshDebounce?.cancel();
      _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
        if (mounted) {
          unawaited(ref.read(chatNotifierProvider.notifier).refresh());
        }
      });
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    // The socket is shared with the conversation screen and owned by its
    // provider, so it is not disconnected here — only this listener goes away.
    _realtimeSub?.cancel();
    super.dispose();
  }

  void _open(String chatId) {
    context.push('${RoutePaths.chatDetails}?id=$chatId').then((_) {
      // She may have read messages while she was in there.
      if (mounted) unawaited(ref.read(chatNotifierProvider.notifier).refresh());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref.watch(chatNotifierProvider);
    final notifier = ref.read(chatNotifierProvider.notifier);
    // Sellers reach this same inbox from their workspace, and the copy has to
    // face the right way: she is answering customers, not asking boutiques.
    final isSeller = ref.watch(
      authNotifierProvider.select((s) => s.user?.isSeller ?? false),
    );

    return ReemScrollPage(
      onRefresh: notifier.refresh,
      slivers: [
        PremiumAppBar(title: l10n.chatsTitle, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.sm,
            DsSpacing.lg,
            DsSpacing.md,
          ),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(
                isSeller ? l10n.chatsSubtitleSeller : l10n.chatsSubtitle,
                style: context.dsText.body.copyWith(
                  color: context.dsColors.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: DsSpacing.lg),
              GlassSearchBar(
                hintText: l10n.chatsSearchHint,
                onChanged: notifier.search,
              ),
              const SizedBox(height: DsSpacing.md),
              const EncryptedChatBanner(),
            ]),
          ),
        ),
        ..._body(context, state, notifier, isSeller: isSeller),
      ],
    );
  }

  List<Widget> _body(
    BuildContext context,
    ChatState state,
    ChatNotifier notifier, {
    required bool isSeller,
  }) {
    final l10n = context.l10n;

    // The very first load, with nothing yet to show behind it.
    if (state.isLoading && !state.hasLoadedOnce) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator.adaptive()),
        ),
      ];
    }

    if (state.error != null && state.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: DsErrorState(
            title: l10n.chatsLoadFailed,
            message: state.error,
            retryLabel: l10n.retry,
            onRetry: notifier.load,
          ),
        ),
      ];
    }

    if (state.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: state.isSearching
              ? DsEmptyState(
                  icon: Icons.search_off_rounded,
                  title: l10n.chatsSearchEmptyTitle,
                  message: l10n.chatsSearchEmptyMessage(state.query),
                )
              // A seller has nowhere to be sent: she cannot start the
              // conversation, she can only be written to.
              : isSeller
              ? DsEmptyState(
                  icon: Icons.forum_outlined,
                  title: l10n.chatsEmptyTitle,
                  message: l10n.chatsEmptyMessageSeller,
                )
              : DsEmptyState(
                  icon: Icons.forum_outlined,
                  title: l10n.chatsEmptyTitle,
                  message: l10n.chatsEmptyMessage,
                  actionLabel: l10n.chatsEmptyAction,
                  onAction: () => context.go(RoutePaths.home),
                ),
        ),
      ];
    }

    // Unread letters first, then the rest, each in the server's order.
    final fresh = [
      for (final t in state.threads)
        if (t.hasUnread) t,
    ];
    final earlier = [
      for (final t in state.threads)
        if (!t.hasUnread) t,
    ];
    final online = [
      for (final t in state.threads)
        if (t.isOnline) t,
    ];

    Widget tile(ChatThreadEntity thread) => ChatTile(
      thread: thread,
      isTyping: state.typingChatIds.contains(thread.id),
      onTap: () => _open(thread.id),
    );

    List<Widget> section(String title, List<ChatThreadEntity> threads) => [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          DsSpacing.lg,
          DsSpacing.sm,
          DsSpacing.lg,
          DsSpacing.sm,
        ),
        sliver: SliverToBoxAdapter(child: _SectionLabel(title)),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
        sliver: SliverList.separated(
          itemCount: threads.length,
          separatorBuilder: (_, _) => DsGaps.vSm,
          itemBuilder: (context, index) => tile(threads[index]),
        ),
      ),
    ];

    return [
      // A failure while rows are already on screen is a banner, not a takeover.
      if (state.error != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.xxxs,
            DsSpacing.lg,
            DsSpacing.md,
          ),
          sliver: SliverToBoxAdapter(
            child: DsInlineError(message: state.error!, onRetry: notifier.load),
          ),
        ),
      // Who is here right now: the quickest way back into a conversation
      // while the other side can still answer it.
      if (online.isNotEmpty && !state.isSearching)
        SliverToBoxAdapter(
          child: _OnlineRail(threads: online, onOpen: _open),
        ),
      if (fresh.isNotEmpty) ...section(l10n.chatsSectionNew, fresh),
      if (earlier.isNotEmpty)
        ...section(
          // A single list needs no heading; "earlier" only means something
          // under a "new".
          fresh.isEmpty ? '' : l10n.chatsSectionEarlier,
          earlier,
        ),
      // Room under the last letter for the floating tab bar.
      const SliverToBoxAdapter(child: SizedBox(height: DsSizes.bottomSafeGap)),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    if (title.isEmpty) return const SizedBox.shrink();
    final colors = context.dsColors;
    return Row(
      children: [
        DsSparkle(size: 9, color: colors.accent),
        DsGaps.hXs,
        Text(
          title,
          style: context.dsText.overline.copyWith(
            color: colors.primary,
            letterSpacing: 1.4,
          ),
        ),
      ],
    );
  }
}

/// The people here right now, as a row of arch portraits.
class _OnlineRail extends StatelessWidget {
  const _OnlineRail({required this.threads, required this.onOpen});

  final List<ChatThreadEntity> threads;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.xs,
            DsSpacing.lg,
            DsSpacing.sm,
          ),
          child: _SectionLabel(l10n.chatsOnlineRail),
        ),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.lg),
            itemCount: threads.length,
            separatorBuilder: (_, _) => DsGaps.hMd,
            itemBuilder: (context, index) {
              final thread = threads[index];
              final name = thread.peerName?.trim().isNotEmpty == true
                  ? thread.peerName!
                  : (thread.title.isNotEmpty
                        ? thread.title
                        : l10n.chatUntitled);
              return SizedBox(
                width: 64,
                child: Column(
                  children: [
                    ArchAvatar(
                      name: name,
                      imageUrl: thread.avatarUrl.isEmpty
                          ? null
                          : thread.avatarUrl,
                      width: 56,
                      isOnline: true,
                      lit: thread.hasUnread,
                      onTap: () => onOpen(thread.id),
                    ),
                    DsGaps.vXxs,
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: context.dsText.caption,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        DsGaps.vXs,
      ],
    );
  }
}
