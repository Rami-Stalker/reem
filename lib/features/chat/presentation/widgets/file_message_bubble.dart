import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../../core/media/media_file_opener.dart';
import '../../../../core/media/media_limits.dart';

/// A document in a conversation — an invoice, a size chart, a receipt.
///
/// It cannot be drawn, so the bubble says what it is and how big, and opening
/// it is a deliberate tap. That tap downloads before it opens: the URL is
/// private, and handing it to the OS browser would get a 401 from a client
/// that has no session and no way to be given one.
class FileMessageBubble extends ConsumerStatefulWidget {
  const FileMessageBubble({
    super.key,
    required this.url,
    required this.attachmentId,
    this.isMe = false,
    this.fileName,
    this.sizeBytes,
  });

  final String url;

  /// Names the copy on disk, so a second tap opens the file already fetched
  /// rather than paying for the bytes again.
  final String attachmentId;

  final bool isMe;
  final String? fileName;
  final int? sizeBytes;

  @override
  ConsumerState<FileMessageBubble> createState() => _FileMessageBubbleState();
}

class _FileMessageBubbleState extends ConsumerState<FileMessageBubble> {
  bool _busy = false;
  double _progress = 0;

  Future<void> _open() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _progress = 0;
    });

    try {
      await ref
          .read(mediaFileOpenerProvider)
          .open(
            url: widget.url,
            cacheKey: widget.attachmentId,
            fileName: widget.fileName,
            onProgress: (value) {
              if (mounted) setState(() => _progress = value);
            },
          );
    } catch (error) {
      if (!mounted) return;
      // Two different failures, and she can act on the difference: no handler
      // installed is not the same as the download not arriving.
      DsSnackbar.show(
        context,
        message: _isMissingHandler(error)
            ? context.l10n.chatOpenFileFailed
            : context.l10n.chatDownloadFailed,
        type: DsSnackbarType.warning,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static bool _isMissingHandler(Object error) =>
      error.toString().toLowerCase().contains('no app');

  @override
  Widget build(BuildContext context) {
    final c = context.dsColors;
    final onBubble = widget.isMe ? Colors.white : c.onSurface;

    return Align(
      // Directional, not absolute: the sender's own bubble sits on the trailing
      // edge of the reading direction, which flips with the locale instead of
      // staying pinned to a physical side.
      alignment: widget.isMe
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Material(
        color: widget.isMe ? c.primary : c.surface,
        borderRadius: BorderRadius.circular(DsRadius.xxl),
        child: InkWell(
          onTap: _open,
          borderRadius: BorderRadius.circular(DsRadius.xxl),
          child: Container(
            width: 260,
            padding: const EdgeInsets.all(DsSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DsRadius.xxl),
              border: widget.isMe ? null : Border.all(color: c.border),
            ),
            child: Row(
              children: [
                _Leading(
                  busy: _busy,
                  progress: _progress,
                  tint: widget.isMe ? Colors.white : c.primary,
                ),
                const SizedBox(width: DsSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName?.trim().isNotEmpty == true
                            ? widget.fileName!.trim()
                            : context.l10n.chatFileMessage,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: onBubble,
                          fontWeight: DsTypography.semiBold,
                        ),
                      ),
                      if (widget.sizeBytes != null) ...[
                        const SizedBox(height: DsSpacing.xxxs),
                        Text(
                          '${MediaLimits.megabytes(widget.sizeBytes!)} MB',
                          style: TextStyle(
                            color: onBubble.withValues(alpha: 0.75),
                            fontSize: DsTypography.labelSmall,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    required this.busy,
    required this.progress,
    required this.tint,
  });

  final bool busy;
  final double progress;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 36,
      child: busy
          ? CircularProgressIndicator(
              // Indeterminate until the first byte report: a bar pinned at
              // zero looks stalled, which is the one thing it is not.
              value: progress > 0 ? progress : null,
              strokeWidth: 2.5,
              color: tint,
            )
          : Icon(Icons.description_outlined, size: 32, color: tint),
    );
  }
}
