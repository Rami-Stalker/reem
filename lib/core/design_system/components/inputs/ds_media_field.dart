import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reem/core/design_system/components/sheets/ds_bottom_sheet.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/color_extension.dart';
import 'package:reem/core/design_system/foundation/theme/extensions/typography_extension.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_colors.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_radius.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_spacing.dart';
import 'package:reem/core/design_system/foundation/tokens/ds_typography.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/media_asset.dart';
import 'package:reem/core/media/media_limits.dart';
import 'package:reem/core/media/media_providers.dart';
import 'package:reem/core/media/media_variants.dart';

/// Pick photographs from the camera or the gallery and upload them as they are
/// chosen.
///
/// Uploading per photograph rather than on submit is the whole design. A woman
/// filling in a product form on a Syrian mobile connection who taps *publish*
/// with four photographs attached is one dropped packet away from losing all
/// four and starting again. Here each one is already on the server by the time
/// she reaches the button, and the button posts a few short URLs.
///
/// Uncontrolled by necessity: an upload in flight has no URL yet, so there is
/// no value the parent could hold that would describe the widget's real state.
/// It seeds from [initialUrls] and reports through [onChanged].
class DsMediaField extends ConsumerStatefulWidget {
  const DsMediaField({
    super.key,
    required this.onChanged,
    this.initialUrls = const [],
    this.purpose = MediaPurpose.product,
    this.video = false,
    this.documents = false,
    this.maxItems = 8,
    this.label,
    this.helperText,
    this.enabled = true,
    this.onUploadingChanged,
  });

  /// Called with the URLs of every upload that has completed, in tile order.
  final ValueChanged<List<String>> onChanged;

  /// Seeds the tiles when editing something that already has photographs.
  final List<String> initialUrls;

  final MediaPurpose purpose;

  /// Pick video instead of stills.
  ///
  /// A separate flag rather than "accept whatever the OS offers", because the
  /// screens that want video already ask her — the story composer has an
  /// image/video selector — and a gallery that silently accepts a 40 MB clip
  /// where a photograph was meant is not a kindness on this network.
  ///
  /// Video tiles show a play placeholder rather than a frame: decoding a
  /// thumbnail needs a native decoder, and a placeholder that says "this is a
  /// video" costs nothing and never lies.
  final bool video;

  /// Offer the device's file browser as a third source, and accept a PDF.
  ///
  /// For the papers a seller is asked for: a commercial register often arrives
  /// from an accountant as a PDF that was never on the camera roll, and a
  /// reviewer would rather read that than a photograph of a screen. The camera
  /// stays on offer, because most of these are still photographed.
  ///
  /// The server decides for itself whether a PDF is acceptable — this flag only
  /// decides what the picker offers her.
  final bool documents;

  final int maxItems;
  final String? label;
  final String? helperText;
  final bool enabled;

  /// Fires whenever an upload starts or the last one settles, so a form can
  /// keep its submit button disabled while bytes are still moving.
  final ValueChanged<bool>? onUploadingChanged;

  @override
  ConsumerState<DsMediaField> createState() => _DsMediaFieldState();
}

class _DsMediaFieldState extends ConsumerState<DsMediaField> {
  late final List<_Slot> _slots = [
    for (final url in widget.initialUrls) _Slot.uploaded(url),
  ];

  bool _wasUploading = false;
  int _pickSequence = 0;

  bool get _isSingle => widget.maxItems == 1;
  bool get _canAddMore => _slots.length < widget.maxItems;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: DsSpacing.xxs,
              bottom: DsSpacing.xs,
            ),
            child: Text(
              widget.label!,
              style: theme.textTheme.labelLarge?.copyWith(
                color: c.onSurface,
                fontWeight: DsTypography.semiBold,
              ),
            ),
          ),
        if (_isSingle) _buildSingle() else _buildGrid(),
        if (widget.helperText != null) ...[
          const SizedBox(height: DsSpacing.xs),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: DsSpacing.xxs),
            child: Text(
              widget.helperText!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Layouts ───────────────────────────────────────────────────────────────

  /// One large tile — a story's image, a store logo. Portrait, because that is
  /// the shape a story is shown in and cropping a preview to a square would
  /// hide the part she framed.
  ///
  /// Width-capped and centred rather than filling: 3:4 of a tablet's width is
  /// taller than the screen, and a field that overflows whenever its parent is
  /// generous is not one anybody can drop into a layout with confidence.
  Widget _buildSingle() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: _slots.isEmpty
              ? _AddTile(enabled: widget.enabled, onTap: _promptForSource)
              : _tileFor(0),
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across on a phone, four once there is room — worked out from
        // the actual width rather than a breakpoint, because this field also
        // renders inside a dialog on the admin console.
        final columns = constraints.maxWidth > 420 ? 4 : 3;
        const gap = DsSpacing.xs;
        final side =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < _slots.length; i++)
              SizedBox(width: side, height: side, child: _tileFor(i)),
            if (_canAddMore)
              SizedBox(
                width: side,
                height: side,
                child: _AddTile(
                  enabled: widget.enabled,
                  onTap: _promptForSource,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _tileFor(int index) {
    return _MediaTile(
      key: ValueKey(_slots[index].key),
      slot: _slots[index],
      isPrivate: widget.purpose.isPrivate,
      // The first photograph is what a shopper sees in the grid, so it is
      // worth saying so rather than leaving the order to look arbitrary.
      showCoverBadge: index == 0 && widget.maxItems > 1,
      enabled: widget.enabled,
      onRemove: () => _remove(index),
      onRetry: () => _upload(index),
    );
  }

  // ── Picking ───────────────────────────────────────────────────────────────

  Future<void> _promptForSource() async {
    if (!widget.enabled) return;
    final l10n = context.l10n;

    final source = await DsBottomSheet.showTitled<_PickSource>(
      context,
      title: l10n.mediaSourceTitle,
      scrollable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SourceTile(
            icon: widget.video
                ? Icons.videocam_outlined
                : Icons.photo_camera_outlined,
            label: l10n.mediaFromCamera,
            onTap: () => Navigator.of(context).pop(_PickSource.camera),
          ),
          _SourceTile(
            icon: Icons.photo_library_outlined,
            label: l10n.mediaFromGallery,
            onTap: () => Navigator.of(context).pop(_PickSource.gallery),
          ),
          if (widget.documents)
            _SourceTile(
              icon: Icons.folder_open_outlined,
              label: l10n.mediaFromFiles,
              onTap: () => Navigator.of(context).pop(_PickSource.files),
            ),
          const SizedBox(height: DsSpacing.sm),
        ],
      ),
    );

    if (source == null || !mounted) return;
    await _pick(source);
  }

  Future<void> _pick(_PickSource source) async {
    final service = ref.read(mediaUploadServiceProvider);
    final room = widget.maxItems - _slots.length;
    if (room <= 0) return;

    final imageSource = source == _PickSource.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    List<XFile> picked;
    try {
      // The gallery can give several at once; the camera gives one by
      // definition, and so does the file browser here. Multi-pick for a
      // single-slot field would only mean discarding what she chose.
      if (source == _PickSource.files) {
        final one = await service.pickDocument();
        picked = one == null ? const [] : [one];
      } else if (widget.video) {
        final one = await service.pickVideo(source: imageSource);
        picked = one == null ? const [] : [one];
      } else if (source == _PickSource.gallery && room > 1) {
        picked = await service.pickImages();
      } else {
        final one = await service.pickImage(source: imageSource);
        picked = one == null ? const [] : [one];
      }
    } catch (_) {
      // Almost always a denied photo permission. The plugin throws rather than
      // returning null, and the raw platform message is not something to show.
      if (mounted) _showPickFailure();
      return;
    }

    if (picked.isEmpty || !mounted) return;

    final accepted = picked.take(room).toList(growable: false);
    final startIndex = _slots.length;

    // Read the bytes once and keep them: they are the preview she sees while
    // the upload runs, and the payload a retry re-sends without sending her
    // back to the picker.
    for (final file in accepted) {
      final kind = _kindOf(file);

      // Video bytes are not held: a clip is tens of megabytes and nothing
      // renders it as a preview, so keeping it in memory would buy a play icon
      // at the cost of the app being killed on a modest phone. A PDF is not
      // drawn either, but it is small enough to keep so a retry does not send
      // her back to the file browser.
      Uint8List? bytes;
      if (kind != _TileKind.video) {
        try {
          bytes = await file.readAsBytes();
        } catch (_) {
          continue;
        }
      }
      if (!mounted) return;

      if (!await _withinSizeLimit(file, bytes, kind)) continue;
      if (!mounted) return;

      setState(
        () => _slots.add(
          _Slot.pending(
            file,
            bytes,
            key: 'pick-${_pickSequence++}',
            kind: kind,
          ),
        ),
      );
    }

    for (var i = startIndex; i < _slots.length; i++) {
      // Sequential, not concurrent. Four parallel uploads on a narrow
      // connection finish later than four in a row and make every progress
      // bar crawl at once, which reads as the app having hung.
      await _upload(i);
      if (!mounted) return;
    }
  }

  _TileKind _kindOf(XFile file) {
    if (widget.video) return _TileKind.video;
    return file.name.toLowerCase().endsWith('.pdf')
        ? _TileKind.document
        : _TileKind.image;
  }

  /// Refuse an over-sized file here rather than after a long upload.
  ///
  /// The server is the authority and will refuse it too — but only once every
  /// byte has crossed the network. On a narrow, metered connection that is
  /// minutes of her time and her data spent to be told no, so the client keeps
  /// a copy of the ceilings and says it immediately. See [MediaLimits].
  Future<bool> _withinSizeLimit(
    XFile file,
    Uint8List? bytes,
    _TileKind kind,
  ) async {
    final size = bytes?.length ?? await file.length();
    final limit = MediaLimits.forKind(kind.name);
    if (size <= limit) return true;

    if (mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.mediaTooLarge(MediaLimits.megabytes(limit)),
          ),
        ),
      );
    }
    return false;
  }

  // ── Uploading ─────────────────────────────────────────────────────────────

  Future<void> _upload(int index) async {
    if (index >= _slots.length) return;
    final slot = _slots[index];
    final file = slot.source;
    if (file == null) return;

    setState(() {
      _slots[index] = slot.uploading(0);
      _notifyUploading();
    });

    try {
      final asset = await ref
          .read(mediaUploadServiceProvider)
          .upload(
            file,
            purpose: widget.purpose,
            bytes: slot.preview,
            onProgress: (value) {
              if (!mounted) return;
              // A rebuild per progress tick is cheap here — one small tile —
              // and it is the only signal that anything is happening.
              setState(() {
                if (index < _slots.length) {
                  _slots[index] = _slots[index].uploading(value);
                }
              });
            },
          );

      if (!mounted) return;
      setState(() {
        if (index < _slots.length) _slots[index] = slot.done(asset);
      });
    } catch (_) {
      if (!mounted) return;
      // The tile keeps its preview and its source file, so the retry costs her
      // one tap rather than a second trip through the picker.
      setState(() {
        if (index < _slots.length) _slots[index] = slot.failed();
      });
    } finally {
      if (mounted) {
        _notifyUploading();
        _emit();
      }
    }
  }

  void _remove(int index) {
    setState(() => _slots.removeAt(index));
    _notifyUploading();
    _emit();
  }

  void _emit() => widget.onChanged(_uploadedUrls());

  List<String> _uploadedUrls() => [
    for (final slot in _slots)
      if (slot.url != null) slot.url!,
  ];

  void _notifyUploading() {
    final busy = _slots.any((slot) => slot.isUploading);
    if (busy == _wasUploading) return;
    _wasUploading = busy;
    widget.onUploadingChanged?.call(busy);
  }

  void _showPickFailure() {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.mediaPickFailed)),
    );
  }
}

/// The circular variant, for a profile photograph.
///
/// Controlled, unlike [DsMediaField]: an avatar has exactly one value, the
/// parent already holds it, and the only state this widget owns is the moment
/// between choosing a photograph and the server accepting it.
class DsAvatarPicker extends ConsumerStatefulWidget {
  const DsAvatarPicker({
    super.key,
    required this.imageUrl,
    required this.onChanged,
    this.purpose = MediaPurpose.avatar,
    this.radius = 54,
    this.enabled = true,
  });

  final String? imageUrl;
  final ValueChanged<String> onChanged;
  final MediaPurpose purpose;
  final double radius;
  final bool enabled;

  @override
  ConsumerState<DsAvatarPicker> createState() => _DsAvatarPickerState();
}

class _DsAvatarPickerState extends ConsumerState<DsAvatarPicker> {
  Uint8List? _preview;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final diameter = widget.radius * 2;

    return Semantics(
      button: widget.enabled,
      label: context.l10n.mediaSourceTitle,
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipOval(
                child: Material(
                  color: c.surfaceVariant,
                  child: InkWell(
                    onTap: widget.enabled && !_busy ? _pick : null,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _image(c.surfaceVariant, c.onSurfaceVariant),
                        if (_busy)
                          ColoredBox(
                            color: DsColors.black.withValues(alpha: 0.45),
                            child: const Center(
                              child: SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: DsColors.onMedia,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // The badge is what makes the avatar read as editable at all — a
            // bare circle looks like a picture of her, not a control.
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: c.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: c.background, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(DsSpacing.xxs),
                  child: Icon(
                    Icons.photo_camera_rounded,
                    size: 16,
                    color: c.onPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(Color background, Color iconColor) {
    final bytes = _preview;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      return ColoredBox(
        color: background,
        child: Icon(Icons.person_outline, size: widget.radius, color: iconColor),
      );
    }
    return CachedNetworkImage(
      // A tile is a third of the form's width.
      imageUrl: MediaVariants.thumb(url),
      fit: BoxFit.cover,
      placeholder: (_, _) => ColoredBox(color: background),
      errorWidget: (_, _, _) =>
          Icon(Icons.person_outline, size: widget.radius, color: iconColor),
    );
  }

  Future<void> _pick() async {
    final service = ref.read(mediaUploadServiceProvider);
    final l10n = context.l10n;

    final source = await DsBottomSheet.showTitled<ImageSource>(
      context,
      title: l10n.mediaSourceTitle,
      scrollable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SourceTile(
            icon: Icons.photo_camera_outlined,
            label: l10n.mediaFromCamera,
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
          _SourceTile(
            icon: Icons.photo_library_outlined,
            label: l10n.mediaFromGallery,
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          const SizedBox(height: DsSpacing.sm),
        ],
      ),
    );
    if (source == null || !mounted) return;

    XFile? file;
    try {
      file = await service.pickImage(source: source);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(l10n.mediaPickFailed)),
        );
      }
      return;
    }
    if (file == null || !mounted) return;

    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() {
      _preview = bytes;
      _busy = true;
    });

    try {
      final asset = await service.upload(
        file,
        purpose: widget.purpose,
        bytes: bytes,
      );
      if (!mounted) return;
      widget.onChanged(asset.url);
    } catch (_) {
      if (!mounted) return;
      // Drop the preview: leaving it would show her a new photograph that the
      // server never received, and she would leave the screen believing it saved.
      setState(() => _preview = null);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.mediaUploadFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

// ── State ───────────────────────────────────────────────────────────────────

/// Where a pick came from. The sheet's three buttons, and nothing more.
enum _PickSource { camera, gallery, files }

/// What a tile is standing for, which decides what it draws. Names match the
/// server's `MediaType` so [MediaLimits.forKind] can be shared.
enum _TileKind { image, video, document }

/// One tile. Immutable so a rebuild mid-upload cannot half-apply a change.
@immutable
class _Slot {
  const _Slot({
    required this.key,
    this.url,
    this.source,
    this.preview,
    this.progress = 0,
    this.hasFailed = false,
    this.isUploading = false,
    this.kind = _TileKind.image,
  });

  factory _Slot.uploaded(String url) =>
      _Slot(key: url, url: url, kind: _kindFromUrl(url));

  factory _Slot.pending(
    XFile source,
    Uint8List? preview, {
    required String key,
    _TileKind kind = _TileKind.image,
  }) => _Slot(key: key, source: source, preview: preview, kind: kind);

  /// Seeded tiles arrive as bare URLs, so the extension is all there is to go
  /// on. Only ever decides which placeholder to draw — nothing is validated
  /// from it, and the server decided the real type from the bytes.
  static _TileKind _kindFromUrl(String url) {
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    if (path.endsWith('.mp4') || path.endsWith('.mov')) return _TileKind.video;
    if (path.endsWith('.pdf')) return _TileKind.document;
    return _TileKind.image;
  }

  /// Identity for the widget tree. Minted per pick rather than taken from the
  /// file path: picking the same photograph twice is something a person
  /// actually does, and two tiles sharing a key is a framework error. Stable
  /// across the tile's whole life, so removing tile 0 does not make tile 1
  /// restart its upload animation.
  final String key;

  final String? url;
  final XFile? source;
  final Uint8List? preview;
  final double progress;
  final bool hasFailed;
  final bool isUploading;
  final _TileKind kind;

  _Slot uploading(double progress) => _Slot(
    key: key,
    source: source,
    preview: preview,
    progress: progress,
    isUploading: true,
    kind: kind,
  );

  _Slot done(MediaAsset asset) => _Slot(
    key: key,
    url: asset.url,
    source: source,
    preview: preview,
    // The server's word, not the extension's: it sniffed the bytes.
    kind: switch (asset.type) {
      'video' => _TileKind.video,
      'document' => _TileKind.document,
      _ => _TileKind.image,
    },
  );

  _Slot failed() => _Slot(
    key: key,
    source: source,
    preview: preview,
    hasFailed: true,
    kind: kind,
  );
}

// ── Tiles ───────────────────────────────────────────────────────────────────

class _MediaTile extends StatelessWidget {
  const _MediaTile({
    super.key,
    required this.slot,
    required this.isPrivate,
    required this.showCoverBadge,
    required this.enabled,
    required this.onRemove,
    required this.onRetry,
  });

  final _Slot slot;

  /// Suppresses the network fetch for an asset the image loader cannot reach
  /// and should not cache. See [MediaPurpose.isPrivate].
  final bool isPrivate;

  final bool showCoverBadge;
  final bool enabled;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final l10n = context.l10n;

    return ClipRRect(
      borderRadius: BorderRadius.circular(DsRadius.md),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _preview(c.shimmerBase),
          if (slot.isUploading) _uploadingScrim(context),
          if (slot.hasFailed) _failureScrim(context),
          if (showCoverBadge && !slot.isUploading && !slot.hasFailed)
            PositionedDirectional(
              start: DsSpacing.xxs,
              bottom: DsSpacing.xxs,
              child: _Badge(label: l10n.mediaCoverBadge),
            ),
          if (enabled)
            PositionedDirectional(
              top: DsSpacing.xxs,
              end: DsSpacing.xxs,
              child: _RoundAction(
                icon: Icons.close_rounded,
                tooltip: l10n.mediaRemovePhoto,
                onTap: onRemove,
              ),
            ),
        ],
      ),
    );
  }

  Widget _preview(Color placeholder) {
    switch (slot.kind) {
      case _TileKind.video:
        return _VideoPlaceholder(background: placeholder);
      case _TileKind.document:
        // A PDF has no thumbnail without a renderer, and the file name is more
        // use to her than a grey rectangle would be — when there is one.
        // `XFile.name` is the basename of the path on mobile and desktop, so a
        // file the OS handed over without one leaves this blank.
        final name = slot.source?.name.trim();
        return _DocumentPlaceholder(
          background: placeholder,
          attached: slot.source == null,
          caption: (name == null || name.isEmpty) ? null : name,
        );
      case _TileKind.image:
        break;
    }

    // Local bytes win while they exist: they are already decoded and they are
    // exactly what she picked, so the tile never flickers from a local preview
    // to a network fetch of the same photograph.
    final bytes = slot.preview;
    if (bytes != null) {
      return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    }
    final url = slot.url;
    if (url == null) return ColoredBox(color: placeholder);
    // A document she uploaded in an earlier session. It stays a chip: the
    // bytes are behind an authorised endpoint the image loader cannot reach,
    // and re-downloading a photograph of her ID onto the device to draw a
    // 100-pixel thumbnail would be the wrong trade even if it could.
    if (isPrivate) {
      return _DocumentPlaceholder(background: placeholder, attached: true);
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (_, _) => ColoredBox(color: placeholder),
      errorWidget: (_, _, _) => ColoredBox(color: placeholder),
    );
  }

  Widget _uploadingScrim(BuildContext context) {
    return ColoredBox(
      color: DsColors.black.withValues(alpha: 0.45),
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            // Indeterminate until the first byte report: a bar pinned at zero
            // looks stalled, which is the one thing it is not.
            value: slot.progress > 0 ? slot.progress : null,
            strokeWidth: 3,
            color: DsColors.onMedia,
            backgroundColor: DsColors.onMediaFaint,
          ),
        ),
      ),
    );
  }

  Widget _failureScrim(BuildContext context) {
    final l10n = context.l10n;
    return Material(
      color: context.dsColors.error.withValues(alpha: 0.55),
      child: InkWell(
        onTap: enabled ? onRetry : null,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, color: DsColors.onMedia, size: 22),
              const SizedBox(height: DsSpacing.xxxs),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: DsSpacing.xxs,
                ),
                child: Text(
                  l10n.mediaUploadFailed,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.caption.semibold.tint(DsColors.onMedia),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Stands in for a document already on the server. See [_MediaTile.isPrivate].
class _DocumentPlaceholder extends StatelessWidget {
  const _DocumentPlaceholder({
    required this.background,
    required this.attached,
    this.caption,
  });

  final Color background;

  /// True for a document already on the server — it gets a tick, because the
  /// question she has about it is whether it arrived. False for one she just
  /// chose, which gets a document icon.
  ///
  /// Deliberately not inferred from [caption] being null: a file the OS handed
  /// over without a usable name would then wear the wrong icon and claim to be
  /// attached before it had been uploaded.
  final bool attached;

  /// The file name, when there is one.
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;

    return ColoredBox(
      color: background,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            attached ? Icons.task_alt_rounded : Icons.picture_as_pdf_rounded,
            size: 28,
            color: attached ? c.success : c.onSurfaceVariant,
          ),
          const SizedBox(height: DsSpacing.xxs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
            child: Text(
              caption ?? context.l10n.mediaDocumentAttached,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: c.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Stands in for a clip. Drawing a real frame needs a native decoder, and this
/// says the same thing for the price of an icon.
class _VideoPlaceholder extends StatelessWidget {
  const _VideoPlaceholder({required this.background});

  final Color background;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          size: 32,
          color: context.dsColors.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final theme = Theme.of(context);

    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(DsRadius.md),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(DsRadius.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DsRadius.md),
            border: Border.all(color: c.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_photo_alternate_outlined,
                color: enabled ? c.primary : c.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: DsSpacing.xxs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: DsSpacing.xxs),
                child: Text(
                  context.l10n.formAddImage,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: c.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: c.primary.withValues(alpha: 0.12),
        child: Icon(icon, color: c.primary, size: 20),
      ),
      title: Text(label),
      trailing: Icon(Icons.chevron_right_rounded, color: c.onSurfaceVariant),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: DsColors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(DsRadius.full),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: DsSpacing.xs,
          vertical: DsSpacing.xxxs,
        ),
        child: Text(
          label,
          style: context.dsText.caption.semibold.tint(DsColors.onMedia),
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: DsColors.black.withValues(alpha: 0.55),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(DsSpacing.xxxs),
            child: Icon(icon, color: DsColors.onMedia, size: 16),
          ),
        ),
      ),
    );
  }
}
