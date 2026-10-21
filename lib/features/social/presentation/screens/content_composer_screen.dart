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
    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.composerTitle, showBack: true),
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
                _FormatPicker(
                  types: state.types,
                  selected: draft.contentType,
                  onSelect: (key) {
                    notifier.selectType(key);
                    // The picker resets media, so the field must be rebuilt
                    // from scratch rather than keeping tiles for a format that
                    // no longer accepts them.
                    setState(() {});
                  },
                ),
                DsGaps.vLg,
                DsMediaField(
                  // Keyed by format so switching post → reel rebuilds the
                  // field from scratch: `DsMediaField` takes its tiles at
                  // construction, and carrying photographs into a reel would
                  // leave her looking at media the server will refuse.
                  // l10n-ignore: a widget identity, not copy.
                  key: ValueKey('composer-media-${draft.contentType}'),
                  label: context.l10n.composerMediaLabel,
                  helperText: type?.videoRequired == true
                      ? context.l10n.composerMediaVideoHelp
                      : null,
                  purpose: MediaPurpose.post,
                  video: type?.videoRequired ?? false,
                  maxItems: type?.maxMedia ?? 5,
                  enabled: !state.isSubmitting,
                  onChanged: (urls) => notifier.setMedia([
                    for (final url in urls)
                      MediaItem(
                        url: url,
                        type: type?.videoRequired == true
                            ? MediaType.video
                            : MediaType.image,
                      ),
                  ]),
                  onUploadingChanged: (busy) =>
                      setState(() => _uploading = busy),
                ),
                DsGaps.vLg,
                DsInputField(
                  controller: _caption,
                  label: context.l10n.composerCaptionLabel,
                  hint: context.l10n.composerCaptionHint,
                  maxLines: 4,
                  enabled: !state.isSubmitting,
                  onChanged: notifier.setCaption,
                ),
                if (type?.supportsProductTags ?? false) ...[
                  DsGaps.vLg,
                  ProductTagPicker(
                    products: state.taggable,
                    selected: draft.productTags,
                    onToggle: notifier.toggleProduct,
                  ),
                ],
                DsGaps.vLg,
                _AudiencePicker(
                  selected: draft.visibility,
                  onSelect: notifier.setVisibility,
                ),
                DsGaps.vXl,
                PrimaryButton(
                  label: context.l10n.composerPublish,
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
                    context.l10n.mediaWaitForUploads,
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
                  message: context.l10n.composerPolicyNotice,
                  links: [
                    PolicyLink(
                      label: context.l10n.policiesLinkContent,
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
}

/// Post / reel / story — whichever the registry says she may publish.
class _FormatPicker extends StatelessWidget {
  const _FormatPicker({
    required this.types,
    required this.selected,
    required this.onSelect,
  });

  final List<ContentTypeOption> types;
  final String selected;
  final ValueChanged<String> onSelect;

  IconData _icon(ContentFormat format) => switch (format) {
    ContentFormat.reel => Icons.movie_creation_outlined,
    ContentFormat.story => Icons.amp_stories_outlined,
    ContentFormat.offer => Icons.local_offer_outlined,
    ContentFormat.collection => Icons.collections_bookmark_outlined,
    ContentFormat.live => Icons.podcasts_rounded,
    ContentFormat.post => Icons.photo_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.sm,
      runSpacing: DsSpacing.sm,
      children: [
        for (final type in types)
          DsChip(
            label: type.name,
            icon: _icon(type.format),
            selected: type.key == selected,
            onTap: () => onSelect(type.key),
          ),
      ],
    );
  }
}

/// Who gets to see it.
class _AudiencePicker extends StatelessWidget {
  const _AudiencePicker({required this.selected, required this.onSelect});

  final ContentVisibility selected;
  final ValueChanged<ContentVisibility> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.composerAudience, style: context.dsText.labelLarge),
        DsGaps.vSm,
        Wrap(
          spacing: DsSpacing.sm,
          children: [
            DsChip(
              label: context.l10n.composerAudiencePublic,
              selected: selected == ContentVisibility.public,
              onTap: () => onSelect(ContentVisibility.public),
            ),
            DsChip(
              label: context.l10n.composerAudienceFollowers,
              selected: selected == ContentVisibility.followers,
              onTap: () => onSelect(ContentVisibility.followers),
            ),
          ],
        ),
      ],
    );
  }
}
