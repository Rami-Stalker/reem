import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/media/media_asset.dart';
import '../../../../core/shared/entities/media.dart';
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
import '../providers/create_provider.dart';
import '../providers/create_state.dart';
import '../widgets/create_header.dart';

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
          message: next.successMessage!,
          type: DsSnackbarType.success,
        );
      }
    });

    final state = ref.watch(createNotifierProvider);
    return ReemScrollPage(
      slivers: [
        const PremiumAppBar(title: 'Create Story', showBack: true),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.xxxl,
          ),
          sliver: SliverList.list(
            children: [
              const CreateHeader(
                title: 'Create Story',
                subtitle: 'Publish a 24-hour store moment for buyers',
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
                    TextField(
                      controller: _linkController,
                      enabled: !state.isLoading,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Optional link',
                        hintText: 'https://example.com/product',
                        prefixIcon: Icon(Icons.open_in_new_rounded),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DsSpacing.xl),
              PrimaryButton(
                label: 'Publish Story',
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
        message: 'Enter a valid story link or leave it blank.',
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
      segments: const [
        ButtonSegment(
          value: MediaType.image,
          icon: Icon(Icons.image_rounded),
          label: Text('Image'),
        ),
        ButtonSegment(
          value: MediaType.video,
          icon: Icon(Icons.play_circle_rounded),
          label: Text('Video'),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (values) => onChanged(values.first),
    );
  }
}
