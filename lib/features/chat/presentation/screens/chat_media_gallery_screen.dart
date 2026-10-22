import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_lightbox.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/open_route.dart';
import 'package:reem/features/chat/presentation/providers/chat_provider.dart';
import 'package:reem/features/chat/presentation/providers/chat_state.dart';

/// Every photograph shared in one conversation.
///
/// It used to show four stock portraits from Unsplash regardless of which
/// conversation you had come from — not merely unfinished but misleading, since
/// the screen's whole claim is "this is what the two of you have sent".
class ChatMediaGalleryScreen extends ConsumerStatefulWidget {
  const ChatMediaGalleryScreen({super.key, required this.chatId});

  final String chatId;

  @override
  ConsumerState<ChatMediaGalleryScreen> createState() =>
      _ChatMediaGalleryScreenState();
}

class _ChatMediaGalleryScreenState
    extends ConsumerState<ChatMediaGalleryScreen> {
  @override
  void initState() {
    super.initState();
    // Usually a no-op: this screen is opened from the conversation, whose
    // messages the notifier already holds. The load is for arriving cold —
    // a deep link, or a restart on this route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.chatId.isEmpty) return;
      final state = ref.read(chatMessagesNotifierProvider(widget.chatId));
      if (state.messages.isEmpty && !state.isLoading) {
        ref.read(chatMessagesNotifierProvider(widget.chatId).notifier).load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = widget.chatId.isEmpty
        ? const ChatMessagesState()
        : ref.watch(chatMessagesNotifierProvider(widget.chatId));

    // Newest first: what she is looking for is nearly always the last thing
    // sent, and the conversation itself is ordered the other way.
    final photos = [
      for (final message in state.messages.reversed)
        if (!message.isLocal)
          for (final attachment in message.attachments)
          if (attachment.kind == 'image') attachment.url,
    ];

    return Scaffold(
      body: LuxuryBlurredBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Header(title: l10n.chatSharedMedia),
              Expanded(
                child: switch ((state.isLoading, photos.isEmpty)) {
                  (true, true) => const Center(child: DsLoadingIndicator()),
                  (_, true) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(DsSpacing.xl),
                      child: Text(
                        l10n.chatNoSharedMedia,
                        textAlign: TextAlign.center,
                        style: context.dsText.body.copyWith(
                          color: context.dsColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  (_, false) => GridView.builder(
                    padding: const EdgeInsets.all(DsSpacing.lg),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: DsSpacing.xs,
                          mainAxisSpacing: DsSpacing.xs,
                        ),
                    itemCount: photos.length,
                    itemBuilder: (context, index) => _Tile(url: photos[index]),
                  ),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.sm,
        DsSpacing.sm,
        DsSpacing.lg,
        DsSpacing.xs,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => popOrHome(context),
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          const SizedBox(width: DsSpacing.xxs),
          Text(
            title,
            style: context.dsText.sectionTitle.copyWith(
              fontWeight: DsTypography.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => MediaLightbox.open(context, url: url),
      child: AuthorizedMediaImage(
        url: url,
        // A third of the screen; the full upload here would be a megabyte a
        // tile for a grid nobody is studying.
        variantWidth: MediaVariants.thumbnail,
        borderRadius: BorderRadius.circular(DsRadius.md),
      ),
    );
  }
}
