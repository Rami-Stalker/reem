import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/platform/unsaved_changes_guard.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/features/policies/presentation/widgets/policy_link.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/domain/entities/content_draft.dart';
import 'package:reem/features/social/presentation/content_type_labels.dart';
import 'package:reem/features/social/presentation/providers/composer_notifier.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';
import 'package:reem/features/social/presentation/widgets/product_tag_picker.dart';

/// Writing a post, a reel or a story.
///
/// One composer for all three, and for boutiques and shoppers alike. The
/// formats on offer come from the server's registry filtered to what this role
/// may publish — so a shopper sees post / reel / story and a boutique also sees
/// its campaign formats, and neither list can drift from what the server will
/// actually accept.
///
/// This replaces `AddPostScreen` (seller-only, product-mandatory, with no
/// media picker at all — a post borrowed the product's photographs) and
/// `AddStoryScreen`.
class ContentComposerScreen extends ConsumerStatefulWidget {
  const ContentComposerScreen({super.key, this.initialFormat});

  /// `post`, `reel` or `story` — the shape she picked on the way in, from the
  /// create sheet or her page. Unknown or absent leaves the registry's first.
  final String? initialFormat;

  @override
  ConsumerState<ContentComposerScreen> createState() =>
      _ContentComposerScreenState();
}

class _ContentComposerScreenState extends ConsumerState<ContentComposerScreen> {
  final _caption = TextEditingController();
  bool _uploading = false;
  bool _formatApplied = false;

  /// A story may be a photograph or a clip; a reel is always a clip and a
  /// post always photographs. Only read while the format is a story.
  bool _storyVideo = false;

  /// Selects the format she asked for, once, when the registry has answered —
  /// and never over a choice she has since made herself.
  void _applyInitialFormat(ComposerState state, ComposerNotifier notifier) {
    if (_formatApplied || state.types.isEmpty || state.draft == null) return;
    _formatApplied = true;
    final wanted = ContentFormat.fromWire(widget.initialFormat);
    if (widget.initialFormat == null) return;
    final match = state.types.where((t) => t.format == wanted).firstOrNull;
    if (match == null || match.key == state.draft!.contentType) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      notifier.selectType(match.key);
      setState(() {});
    });
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(composerProvider);
    final notifier = ref.read(composerProvider.notifier);

    ref.listen(composerProvider, (previous, next) {
      final success = next.successMessage;
      if (success != null && previous?.successMessage != success) {
        DsSnackbar.success(context, success.resolve(context.l10n));
        Navigator.of(context).maybePop(next.published);
        return;
      }
      final typed = next.errorMessage;
      if (typed != null && previous?.errorMessage != typed) {
        DsSnackbar.error(context, typed.resolve(context.l10n));
        notifier.clearMessages();
        return;
      }
      final message = next.error;
      if (message != null && previous?.error != message) {
        DsSnackbar.error(context, message);
        notifier.clearMessages();
      }
    });

    _applyInitialFormat(state, notifier);
    final draft = state.draft;
    final type = state.selectedType;

    // A caption she has typed, or a photograph already uploaded, is work the
    // back gesture must not silently throw away. `state.published` means the
    // post has left — at that point the screen is closing on purpose and
    // there is nothing to protect.
    final hasWork =
        !state.isSubmitting &&
        state.published == null &&
        (_caption.text.trim().isNotEmpty || (draft?.media.isNotEmpty ?? false));

    return UnsavedChangesGuard(
      hasUnsavedChanges: hasWork,
      child: _body(context, state, notifier, draft, type),
    );
  }

  Widget _body(
    BuildContext context,
    ComposerState state,
    ComposerNotifier notifier,
    ContentDraft? draft,
    ContentTypeOption? type,
  ) {
    final l10n = context.l10n;
    return ReemScrollPage(
      // The studio stands in the same slow light as the way in: making
      // something should feel like an occasion, not a form.
      background: const AuthAurora(),
      slivers: [
        PremiumAppBar(title: l10n.composerTitle, showBack: true),
        if (state.isLoading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: DsLoadingIndicator()),
          )
        else if (draft == null || state.types.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: DsErrorState(message: state.error, onRetry: notifier.load),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.all(DsSpacing.gutter),
            sliver: SliverList.list(
              children: [
                StudioModeSwitch(
                  modes: [
                    for (final option in state.types)
                      StudioMode(
                        icon: _iconOf(option.format),
                        label: l10n.contentTypeName(
                          option.key,
                          fallback: option.name,
                        ),
                        gradient: _lightOf(context, option.format),
                      ),
                  ],
                  selected: state.types
                      .indexWhere((option) => option.key == draft.contentType)
                      .clamp(0, state.types.length - 1),
                  onSelect: (index) {
                    notifier.selectType(state.types[index].key);
                    // The picker resets media, so the field must be rebuilt
                    // from scratch rather than keeping tiles for a format that
                    // no longer accepts them.
                    setState(() {});
                  },
                ),
                DsGaps.vLg,
                if (type?.format == ContentFormat.story) ...[
                  StudioSegment(
                    options: [
                      StudioSegmentOption(
                        icon: Icons.photo_camera_rounded,
                        label: l10n.composerStoryPhoto,
                      ),
                      StudioSegmentOption(
                        icon: Icons.videocam_rounded,
                        label: l10n.composerStoryVideo,
                      ),
                    ],
                    selected: _storyVideo ? 1 : 0,
                    onSelect: state.isSubmitting || _uploading
                        ? (_) {}
                        : (index) {
                            // Switching clears what she picked: the field is
                            // rebuilt for the other kind, and the draft must
                            // not keep media the field no longer shows.
                            notifier.setMedia(const []);
                            setState(() => _storyVideo = index == 1);
                          },
                  ),
                  DsGaps.vLg,
                ],
                ViewfinderFrame(
                  label: type == null
                      ? l10n.composerMediaLabel
                      : l10n.contentTypeName(type.key, fallback: type.name),
                  shape: switch (type?.format) {
                    ContentFormat.post => '4:5',
                    ContentFormat.reel || ContentFormat.story => '9:16',
                    _ => null,
                  },
                  gradient: _lightOf(context, type?.format),
                  child: DsMediaField(
                    // Keyed by format so switching post → reel rebuilds the
                    // field from scratch: `DsMediaField` takes its tiles at
                    // construction, and carrying photographs into a reel would
                    // leave her looking at media the server will refuse.
                    // l10n-ignore: a widget identity, not copy.
                    key: ValueKey(
                      // l10n-ignore: a widget identity, not copy.
                      'composer-media-${draft.contentType}-${_wantsVideo(type)}',
                    ),
                    label: l10n.composerMediaLabel,
                    helperText: _wantsVideo(type)
                        ? l10n.composerMediaVideoHelp
                        : null,
                    purpose: MediaPurpose.post,
                    video: _wantsVideo(type),
                    // One clip per story or reel: a clip is a whole story.
                    maxItems: _wantsVideo(type) ? 1 : (type?.maxMedia ?? 5),
                    enabled: !state.isSubmitting,
                    onChanged: (urls) => notifier.setMedia([
                      for (final url in urls)
                        MediaItem(
                          url: url,
                          type: _wantsVideo(type)
                              ? MediaType.video
                              : MediaType.image,
                        ),
                    ]),
                    onUploadingChanged: (busy) =>
                        setState(() => _uploading = busy),
                  ),
                ),
                DsGaps.vLg,
                _Sheet(
                  child: DsInputField(
                    controller: _caption,
                    label: l10n.composerCaptionLabel,
                    hint: l10n.composerCaptionHint,
                    maxLines: 4,
                    enabled: !state.isSubmitting,
                    onChanged: notifier.setCaption,
                  ),
                ),
                if (type?.supportsProductTags ?? false) ...[
                  DsGaps.vLg,
                  _Sheet(
                    child: ProductTagPicker(
                      products: state.taggable,
                      selected: draft.productTags,
                      onToggle: notifier.toggleProduct,
                    ),
                  ),
                ],
                DsGaps.vLg,
                Text(l10n.composerAudience, style: context.dsText.labelLarge),
                DsGaps.vSm,
                StudioSegment(
                  options: [
                    StudioSegmentOption(
                      icon: Icons.public_rounded,
                      label: l10n.composerAudiencePublic,
                      hint: l10n.composerAudiencePublicHint,
                    ),
                    StudioSegmentOption(
                      icon: Icons.people_rounded,
                      label: l10n.composerAudienceFollowers,
                      hint: l10n.composerAudienceFollowersHint,
                    ),
                  ],
                  selected: draft.visibility == ContentVisibility.followers
                      ? 1
                      : 0,
                  onSelect: (index) => notifier.setVisibility(
                    index == 1
                        ? ContentVisibility.followers
                        : ContentVisibility.public,
                  ),
                ),
                DsGaps.vXl,
                PrimaryButton(
                  label: l10n.composerPublish,
                  icon: Icons.auto_awesome_rounded,
                  isLoading: state.isSubmitting,
                  // A submit while a photograph is still uploading would post
                  // a look with a missing picture.
                  onPressed: _uploading || state.isSubmitting
                      ? null
                      : notifier.publish,
                ),
                if (_uploading) ...[
                  DsGaps.vSm,
                  Text(
                    l10n.mediaWaitForUploads,
                    textAlign: TextAlign.center,
                    style: context.dsText.caption,
                  ),
                ],

                // The rules a removal will be judged by, under the button that
                // publishes. The content policy promises that nothing is taken
                // down in silence and that every removal names the rule it
                // broke — a promise worth putting where the risk is taken,
                // rather than only in the notification that follows one.
                DsGaps.vLg,
                PolicyNotice(
                  alignment: CrossAxisAlignment.center,
                  message: l10n.composerPolicyNotice,
                  links: [
                    PolicyLink(
                      label: l10n.policiesLinkContent,
                      slug: PolicySlugs.content,
                    ),
                  ],
                ),
                DsGaps.bottomSafe,
              ],
            ),
          ),
      ],
    );
  }

  /// Whether the media field picks clips: always for a reel, by her choice
  /// for a story, never for a post.
  bool _wantsVideo(ContentTypeOption? type) =>
      (type?.videoRequired ?? false) ||
      (type?.format == ContentFormat.story && _storyVideo);

  static IconData _iconOf(ContentFormat format) => switch (format) {
    ContentFormat.reel => Icons.movie_creation_rounded,
    ContentFormat.story => Icons.auto_stories_rounded,
    ContentFormat.offer => Icons.local_offer_rounded,
    ContentFormat.collection => Icons.collections_bookmark_rounded,
    ContentFormat.live => Icons.podcasts_rounded,
    ContentFormat.post => Icons.photo_camera_rounded,
  };

  /// Each format's own light: rose for a post, rose into orchid for a reel,
  /// champagne for a story — the same three the create sheet draws.
  static Gradient _lightOf(BuildContext context, ContentFormat? format) =>
      switch (format) {
        ContentFormat.reel => DsGradients.rewards,
        ContentFormat.story => DsGradients.gold,
        ContentFormat.post || null => context.primaryGradient,
        _ => DsGradients.mauve,
      };
}

/// A sheet of frosted paper for the words.
class _Sheet extends StatelessWidget {
  const _Sheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        borderRadius: DsRadius.borderXxl,
        color: (isDark ? colors.surfaceElevated : colors.surface).withValues(
          alpha: 0.88,
        ),
        border: Border.all(color: colors.border.withValues(alpha: 0.6)),
        boxShadow: context.shadowSoft,
      ),
      child: child,
    );
  }
}
