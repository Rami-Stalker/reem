import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/features/create/presentation/providers/create_provider.dart';
import 'package:reem/features/create/presentation/providers/create_state.dart';
import 'package:reem/features/create/presentation/widgets/create_header.dart';

class AddStoryScreen extends ConsumerStatefulWidget {
  const AddStoryScreen({super.key});

  @override
  ConsumerState<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends ConsumerState<AddStoryScreen> {
  final _linkController = TextEditingController();
  MediaType _type = MediaType.image;

  String? _mediaUrl;
  bool _mediaUploading = false;

  /// Rebuilds the picker from scratch when she switches between image and
  /// video. Without it the tile would keep a still she had already uploaded
  /// while the composer went on to publish it as a video.
  Key _pickerKey = UniqueKey();

  @override
  void dispose() {
    _linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<CreateState>(createNotifierProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        DsSnackbar.show(
          context,
          message: next.error!,
          type: DsSnackbarType.error,
        );
      }
      if (next.successMessage != null &&
          next.successMessage != previous?.successMessage) {
        setState(() {
          _mediaUrl = null;
          _pickerKey = UniqueKey();
        });
        _linkController.clear();
        DsSnackbar.show(
          context,
          message: next.successMessage!.resolve(context.l10n),
          type: DsSnackbarType.success,
        );
      }
    });

    final state = ref.watch(createNotifierProvider);
    return ReemScrollPage(
      slivers: [
        PremiumAppBar(title: context.l10n.createStoryTitle, showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.xxxl,
          ),
          sliver: SliverList.list(
            children: [
              CreateHeader(
                title: context.l10n.createStoryTitle,
                subtitle: context.l10n.createStoryBody,
              ),
              const SizedBox(height: DsSpacing.xl),
              _TypeSelector(
                selected: _type,
                onChanged: (type) => setState(() {
                  if (type == _type) return;
                  _type = type;
                  _mediaUrl = null;
                  _pickerKey = UniqueKey();
                }),
              ),
              const SizedBox(height: DsSpacing.lg),
              DsMediaField(
                key: _pickerKey,
                label: context.l10n.mediaStoryLabel,
                purpose: MediaPurpose.story,
                video: _type == MediaType.video,
                maxItems: 1,
                enabled: !state.isLoading,
                onChanged: (urls) =>
                    setState(() => _mediaUrl = urls.isEmpty ? null : urls.first),
                onUploadingChanged: (busy) =>
                    setState(() => _mediaUploading = busy),
              ),
              const SizedBox(height: DsSpacing.lg),
              SurfaceCard(
                child: Column(
                  children: [
                    DsInputField(
                      controller: _linkController,
                      enabled: !state.isLoading,
                      keyboardType: TextInputType.url,
                      label: context.l10n.createStoryOptionalLink,
                      // l10n-ignore: an address shape, not language
                      hint: 'https://example.com/product',
                      prefixIcon: const Icon(Icons.open_in_new_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DsSpacing.xl),
              PrimaryButton(
                label: context.l10n.createStoryAction,
                icon: Icons.auto_stories_rounded,
                isLoading: state.isLoading,
                onPressed: state.isLoading ? null : _submit,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_mediaUploading) {
      DsSnackbar.show(
        context,
        message: context.l10n.mediaWaitForUploads,
        type: DsSnackbarType.warning,
      );
      return;
    }

    final mediaUrl = _mediaUrl ?? '';
    final link = _linkController.text.trim();
    if (mediaUrl.isEmpty) {
      DsSnackbar.show(
        context,
        message: context.l10n.mediaStoryRequired,
        type: DsSnackbarType.error,
      );
      return;
    }
    if (link.isNotEmpty && !_isValidUrl(link)) {
      DsSnackbar.show(
        context,
        message: context.l10n.createStoryBadLink,
        type: DsSnackbarType.error,
      );
      return;
    }

    await ref.read(createNotifierProvider.notifier).createStory(
          mediaUrl: mediaUrl,
          type: _type,
          link: link.isEmpty ? null : link,
        );
  }

  bool _isValidUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final MediaType selected;
  final ValueChanged<MediaType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<MediaType>(
      segments: [
        ButtonSegment(
          value: MediaType.image,
          icon: Icon(Icons.image_rounded),
          label: Text(context.l10n.mediaImage),
        ),
        ButtonSegment(
          value: MediaType.video,
          icon: Icon(Icons.play_circle_rounded),
          label: Text(context.l10n.mediaVideo),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}
