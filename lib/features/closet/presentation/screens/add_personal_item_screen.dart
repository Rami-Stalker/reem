import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/media/media_asset.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/repositories/closet_repository.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';

/// Add a garment Ohara never sold her.
///
/// The screen that makes the whole feature something other than an order
/// history. Its job is to be short: a photograph, a name, and the one question
/// that cannot be guessed. Everything else — colour, fabric, season, occasion —
/// is derived on the server from what she typed and can be corrected later, so
/// nothing else is asked for here.
class AddPersonalItemScreen extends ConsumerStatefulWidget {
  const AddPersonalItemScreen({super.key});

  @override
  ConsumerState<AddPersonalItemScreen> createState() =>
      _AddPersonalItemScreenState();
}

class _AddPersonalItemScreenState extends ConsumerState<AddPersonalItemScreen> {
  final _title = TextEditingController();
  final _brand = TextEditingController();

  String? _slot;
  String? _imageUrl;
  String? _size;
  bool _uploading = false;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _brand.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && !_uploading && _slot != null && _title.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final overviewAsync = ref.watch(closetOverviewProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: OharaAppBar(title: context.l10n.closetAddPiece),
      body: overviewAsync.when(
        loading: () => const Center(child: DsLoadingIndicator()),
        error: (_, _) => DsErrorState(
          message: context.l10n.closetPageLoadFailed,
          onRetry: () => ref.invalidate(closetOverviewProvider),
        ),
        data: (overview) => ListView(
          padding: const EdgeInsets.all(DsSpacing.md),
          children: [
            // Private, and said so plainly. She is about to photograph her
            // bedroom; the app owes her the sentence before she does, not in a
            // settings page afterwards.
            Text(
              context.l10n.closetPhotoPrivate,
              style: context.dsText.caption.tint(colors.onSurfaceVariant),
            ),
            const SizedBox(height: DsSpacing.sm),
            DsMediaField(
              purpose: MediaPurpose.closet,
              maxItems: 1,
              label: context.l10n.closetPiecePhoto,
              onChanged: (urls) =>
                  setState(() => _imageUrl = urls.isEmpty ? null : urls.first),
              onUploadingChanged: (value) => setState(() => _uploading = value),
            ),
            const SizedBox(height: DsSpacing.md),
            DsInputField(
              controller: _title,
              label: context.l10n.closetPieceWhat,
              hint: context.l10n.closetPieceWhatHint,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: DsSpacing.md),
            Text(
              context.l10n.closetPieceSlot,
              style: context.dsText.labelStrong,
            ),
            const SizedBox(height: DsSpacing.xs),
            // The one required answer. A photograph has no category to fall
            // back on, and a piece filed in the wrong slot quietly distorts
            // every gap and every outfit from then on.
            _SlotPicker(
              slots: overview.vocabulary.slots,
              selected: _slot,
              onSelected: (slot) => setState(() => _slot = slot),
            ),
            const SizedBox(height: DsSpacing.md),
            DsInputField(
              controller: _brand,
              label: context.l10n.closetPieceBrandOptional,
            ),
            const SizedBox(height: DsSpacing.md),
            Text(
              context.l10n.closetPieceSizeOptional,
              style: context.dsText.labelStrong,
            ),
            const SizedBox(height: DsSpacing.xs),
            _SizePicker(
              selected: _size,
              onSelected: (size) => setState(() => _size = size),
            ),
            const SizedBox(height: DsSpacing.xl),
            DsButton(
              label: context.l10n.closetAddToMyCloset,
              isLoading: _saving,
              onPressed: _canSave ? _save : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);

    final result = await ref.read(closetActionsProvider).addPersonal(
          PersonalItemDraft(
            title: _title.text.trim(),
            slot: _slot!,
            imageUrl: _imageUrl,
            brandName: _brand.text.trim(),
            descriptor: DescriptorPatch(size: _size),
          ),
        );

    if (!mounted) return;
    setState(() => _saving = false);

    result.when(
      success: (_) {
        DsSnackbar.show(context, message: context.l10n.closetAdded);
        // Opened from a link there is nothing to pop back to; the closet is
        // where the new piece is.
        context.canPop() ? context.pop() : context.go(RoutePaths.closet);
      },
      error: (_) => DsSnackbar.show(
        context,
        message: context.l10n.closetAddFailed,
        type: DsSnackbarType.error,
      ),
    );
  }
}

class _SlotPicker extends StatelessWidget {
  const _SlotPicker({
    required this.slots,
    required this.selected,
    required this.onSelected,
  });

  final List<ClosetTerm> slots;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final slot in slots)
          // `GIFT` is a purchase intent, not a body position — nothing in a
          // wardrobe is filed under it.
          if (slot.key != 'GIFT')
            DsChip(
              label: slot.label,
              selected: selected == slot.key,
              onTap: () => onSelected(slot.key),
            ),
      ],
    );
  }
}

class _SizePicker extends StatelessWidget {
  const _SizePicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String?> onSelected;

  static const _sizes = ['S', 'M', 'L', 'XL', '36', '37', '38', '39', '40'];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: DsSpacing.xs,
      runSpacing: DsSpacing.xs,
      children: [
        for (final size in _sizes)
          DsChip(
            label: size,
            selected: selected == size,
            // Tapping the selected chip clears it — a size guessed wrong is
            // worse than no size, because it filters every future suggestion.
            onTap: () => onSelected(selected == size ? null : size),
          ),
      ],
    );
  }
}
