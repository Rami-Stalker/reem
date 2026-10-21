import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_outfit.dart';
import 'package:reem/features/ai_stylist/domain/entities/stylist_recommendation.dart';
import 'package:reem/features/ai_stylist/presentation/providers/ai_stylist_providers.dart';
import 'package:reem/features/ai_stylist/presentation/providers/stylist_chat_notifier.dart';
import 'package:reem/features/ai_stylist/presentation/providers/stylist_chat_state.dart';
import 'package:reem/features/ai_stylist/presentation/widgets/stylist_brief_bar.dart';
import 'package:reem/features/ai_stylist/presentation/widgets/stylist_composer.dart';
import 'package:reem/features/ai_stylist/presentation/widgets/stylist_message_bubble.dart';
import 'package:reem/features/ai_stylist/presentation/widgets/stylist_welcome.dart';

/// Reem AI Stylist — the conversation.
///
/// A chat surface rather than a search screen, because the thing she is doing
/// is describing a situation ("عندي مناسبة بعد أسبوع") rather than naming a
/// product. Everything the assistant answers with is a real, live catalogue
/// row: the screen renders what the server chose and never composes a result
/// of its own.
class AiStylistScreen extends ConsumerStatefulWidget {
  const AiStylistScreen({super.key, this.conversationId, this.initialQuestion});

  /// Null for a new thread; set when resuming one from the history.
  final String? conversationId;

  /// Asked as the screen opens, in a fresh thread. Set when she asked from
  /// Discover, so the answer is what she arrives at rather than a welcome
  /// screen asking her to say it again.
  final String? initialQuestion;

  @override
  ConsumerState<AiStylistScreen> createState() => _AiStylistScreenState();
}

class _AiStylistScreenState extends ConsumerState<AiStylistScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final question = widget.initialQuestion?.trim() ?? '';
    if (widget.conversationId == null && question.isNotEmpty) {
      // After the first frame: the notifier is created by that frame's watch.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(stylistChatProvider(null).notifier).ask(question);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    // After the frame, so the new bubble has been laid out and its extent is
    // part of `maxScrollExtent`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: DsDurations.normal,
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final provider = stylistChatProvider(widget.conversationId);
    final state = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    ref.listen(provider, (previous, next) {
      if (previous?.messages.length != next.messages.length) _scrollToEnd();
    });

    return Scaffold(
      backgroundColor: colors.background,
      appBar: ReemAppBar(
        title: context.l10n.aiStylistTitle,
        actions: [
          IconButton(
            tooltip: context.l10n.stylistNewChat,
            onPressed: state.isSending
                ? null
                : () => notifier.startNewConversation(),
            icon: const Icon(Icons.add_comment_outlined),
          ),
          IconButton(
            tooltip: context.l10n.stylistMyPreferences,
            onPressed: () => context.push(RoutePaths.stylistPreferences),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          StylistBriefBar(
            brief: state.brief,
            onEdit: () => context.push(RoutePaths.stylistPreferences),
          ),
          Expanded(
            child: _Body(
              state: state,
              notifier: notifier,
              controller: _scrollController,
            ),
          ),
          StylistComposer(
            enabled: state.canSend,
            suggestions: state.activeSuggestions,
            onSend: notifier.send,
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.state,
    required this.notifier,
    required this.controller,
  });

  final StylistChatState state;

  /// Passed down rather than re-read from the provider. The family is keyed by
  /// the id the screen opened with, and `state.conversationId` changes the
  /// moment she sends her first message — reading with that key would spin up
  /// a second, empty notifier in the middle of the conversation.
  final StylistChatNotifier notifier;

  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: DsLoadingIndicator());
    }

    if (state.isEmpty) {
      return StylistWelcome(
        prompts: state.suggestions,
        onPromptSelected: notifier.send,
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(
        DsSpacing.md,
        DsSpacing.md,
        DsSpacing.md,
        DsSpacing.lg,
      ),
      // One extra row for the typing indicator while a turn is in flight.
      itemCount: state.messages.length + (state.isSending ? 1 : 0),
      separatorBuilder: (_, _) => const SizedBox(height: DsSpacing.md),
      itemBuilder: (context, index) {
        if (index >= state.messages.length) {
          return const StylistTypingIndicator();
        }

        final message = state.messages[index];
        final failed = message.isPending && state.failure != null;

        return StylistMessageBubble(
          message: message,
          failed: failed,
          onRetry: failed ? notifier.retry : null,
          onProductTap: (recommendation) => _openProduct(context, recommendation),
          onLike: (recommendation) => notifier.react(
            recommendation,
            recommendation.isLiked
                ? StylistFeedback.none
                : StylistFeedback.liked,
          ),
          onDismiss: (recommendation) => notifier.react(
            recommendation,
            recommendation.isDismissed
                ? StylistFeedback.none
                : StylistFeedback.dismissed,
          ),
          onSaveOutfit: notifier.saveOutfit,
          onOpenOutfit: (outfit) => _openOutfit(context, outfit),
        );
      },
    );
  }

  void _openProduct(BuildContext context, StylistRecommendation recommendation) {
    // The product screen reads its id off the query string, so the card links
    // to exactly the same URL a search result would.
    context.push(RoutePaths.productDetailsOf(recommendation.product.id));
  }

  void _openOutfit(BuildContext context, StylistOutfit outfit) {
    context.push(RoutePaths.stylistOutfitOf(outfit.id));
  }
}
