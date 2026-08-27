import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/localization/l10n_extension.dart';
import '../../../ai_assistant/presentation/providers/ai_assistant_provider.dart';
import '../../domain/entities/managed_product.dart';
import '../../domain/entities/product_draft.dart';
import '../../domain/entities/product_status.dart';
import '../providers/seller_products_providers.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  /// Non-null when editing.
  final ManagedProduct? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _category = TextEditingController();
  final _price = TextEditingController();
  final _oldPrice = TextEditingController();
  final _stock = TextEditingController();

  /// URLs of photographs already uploaded. `DsMediaField` owns the tiles and
  /// the in-flight state; the form only keeps what it will post.
  List<String> _mediaUrls = const [];
  bool _mediaUploading = false;

  final List<_VariantRow> _variants = [];

  ProductStatus _status = ProductStatus.draft;
  bool _isFeatured = false;
  bool _showInFeed = true;

  /// Eight is what a listing can show without the grid turning into a scroll
  /// of its own, and enough for a garment from every angle.
  static const int _maxMedia = 8;

  bool get _isEditing => widget.product != null;

  Future<void> _generateDescription() async {
    final title = _title.text.trim();
    final category = _category.text.trim();
    if (title.isEmpty || category.isEmpty) {
      DsSnackbar.show(
        context,
        message: context.l10n.formTitleCategoryFirst,
        type: DsSnackbarType.warning,
      );
      return;
    }
    final output = await ref
        .read(aiAssistantActionsProvider)
        .generateDescription(
          title: title,
          category: category,
          productId: widget.product?.id,
          attributes: _variants
              .map((variant) => variant.name.text.trim())
              .where((value) => value.isNotEmpty)
              .toList(),
        );
    final description = output['description']?.toString();
    if (description == null || description.isEmpty) return;
    if (!mounted) return;
    setState(() => _description.text = description);
    DsSnackbar.show(
      context,
      message: context.l10n.formAiDescriptionAdded,
      type: DsSnackbarType.success,
    );
  }

  Future<void> _generateTags() async {
    final title = _title.text.trim();
    final category = _category.text.trim();
    if (title.isEmpty || category.isEmpty) {
      DsSnackbar.show(
        context,
        message: context.l10n.formTitleCategoryFirst,
        type: DsSnackbarType.warning,
      );
      return;
    }
    final tags = await ref
        .read(aiAssistantActionsProvider)
        .generateTags(
          title: title,
          category: category,
          productId: widget.product?.id,
          description: _description.text,
        );
    if (!mounted) return;
    DsSnackbar.show(
      context,
      message: tags.isEmpty
          ? context.l10n.formNoTags
          : tags.join('\u060C '),
      type: tags.isEmpty ? DsSnackbarType.warning : DsSnackbarType.success,
    );
  }

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p != null) {
      _title.text = p.title;
      _description.text = p.description;
      _category.text = p.category.slug;
      // The raw decimal string, not a formatted figure — this feeds an input
      // that is posted straight back to the server.
      _price.text = p.price.raw;
      _oldPrice.text = p.compareAtPrice?.raw ?? '';
      _stock.text = p.stock.toString();
      _status = p.status;
      _isFeatured = p.isFeatured;
      _showInFeed = p.showInFeed;
      _mediaUrls = [for (final m in p.media) m.url];
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _category,
      _price,
      _oldPrice,
      _stock,
    ]) {
      c.dispose();
    }
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Refuse rather than silently publish a product missing the photographs
    // she is watching upload. The draft would be saved without them and she
    // would have no way to tell that is what happened.
    if (_mediaUploading) {
      DsSnackbar.show(
        context,
        message: context.l10n.mediaWaitForUploads,
        type: DsSnackbarType.warning,
      );
      return;
    }

    final media = [for (final url in _mediaUrls) MediaDraft(url)];

    final variants = _variants
        .where((v) => v.name.text.trim().isNotEmpty)
        .map(
          (v) => VariantDraft(
            name: v.name.text.trim(),
            sku: v.sku.text.trim().isEmpty ? null : v.sku.text.trim(),
            price: double.tryParse(v.price.text.trim()),
            stock: int.tryParse(v.stock.text.trim()) ?? 0,
          ),
        )
        .toList();

    final draft = ProductDraft(
      title: _title.text.trim(),
      description: _description.text.trim(),
      category: _category.text.trim(),
      price: double.parse(_price.text.trim()),
      oldPrice: double.tryParse(_oldPrice.text.trim()),
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      status: _status,
      isFeatured: _isFeatured,
      showInFeed: _showInFeed,
      media: media,
      variants: variants,
    );

    final saved = await ref
        .read(productFormNotifierProvider.notifier)
        .submit(id: widget.product?.id, draft: draft);

    if (!mounted) return;
    if (saved != null) {
      ref.read(myProductsNotifierProvider.notifier).refresh();
      DsSnackbar.show(
        context,
        message: _isEditing
            ? context.l10n.formProductUpdated
            : context.l10n.formProductCreated,
        type: DsSnackbarType.success,
      );
      context.pop();
    } else {
      final error = ref.read(productFormNotifierProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    final isSubmitting = ref.watch(
      productFormNotifierProvider.select((s) => s.isSubmitting),
    );

    return ReemScrollPage(
      // Without these the form inherits the buyer's blush silk — the wrong
      // room for a seller writing a listing.
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        PremiumAppBar(
          title: _isEditing
              ? context.l10n.formEditProduct
              : context.l10n.formNewProduct,
          showBack: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            DsSpacing.lg,
            DsSpacing.md,
            DsSpacing.lg,
            DsSpacing.xxl,
          ),
          sliver: SliverToBoxAdapter(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DsInputField(
                    controller: _title,
                    label: context.l10n.formTitle,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? context.l10n.formTitleRequired
                        : null,
                  ),
                  DsInputField(
                    controller: _description,
                    label: context.l10n.formDescription,
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.formDescriptionRequired
                        : null,
                  ),
                  DsInputField(
                    controller: _category,
                    label: context.l10n.formCategory,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.l10n.formCategoryRequired
                        : null,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: DsSpacing.sm,
                      children: [
                        TextButton.icon(
                          onPressed: _generateDescription,
                          icon: const Icon(Icons.auto_awesome_rounded),
                          label: Text(context.l10n.formAiDescription),
                        ),
                        TextButton.icon(
                          onPressed: _generateTags,
                          icon: const Icon(Icons.sell_outlined),
                          label: Text(context.l10n.formAiTags),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DsInputField(
                          controller: _price,
                          label: context.l10n.formPrice,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final value = double.tryParse((v ?? '').trim());
                            if (value == null || value < 0) {
                              return context.l10n.formPriceInvalid;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(
                        child: DsInputField(
                          controller: _oldPrice,
                          label: 'Old price (opt.)',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  DsInputField(
                    controller: _stock,
                    label: context.l10n.formStock,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = int.tryParse((v ?? '').trim());
                      if (value == null || value < 0)
                        return context.l10n.formStockInvalid;
                      return null;
                    },
                  ),
                  const SizedBox(height: DsSpacing.md),
                  _label(context, context.l10n.formStatus),
                  const SizedBox(height: DsSpacing.xs),
                  Wrap(
                    spacing: DsSpacing.sm,
                    children: [
                      for (final s in ProductStatus.values)
                        ChoiceChip(
                          label: Text(s.label),
                          selected: _status == s,
                          selectedColor: colors.primary.withValues(alpha: 0.16),
                          onSelected: (_) => setState(() => _status = s),
                        ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.formFeatured),
                    value: _isFeatured,
                    onChanged: (v) => setState(() => _isFeatured = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(context.l10n.formShowInFeed),
                    value: _showInFeed,
                    onChanged: (v) => setState(() => _showInFeed = v),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  DsMediaField(
                    label: context.l10n.mediaProductGallery,
                    helperText: context.l10n.mediaGalleryHint(_maxMedia),
                    initialUrls: _mediaUrls,
                    maxItems: _maxMedia,
                    enabled: !isSubmitting,
                    onChanged: (urls) => _mediaUrls = urls,
                    onUploadingChanged: (busy) =>
                        setState(() => _mediaUploading = busy),
                  ),
                  if (!_isEditing) ...[
                    const SizedBox(height: DsSpacing.md),
                    _label(context, 'Variants (optional)'),
                    const SizedBox(height: DsSpacing.xs),
                    ..._buildVariantRows(),
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _variants.add(_VariantRow())),
                      icon: const Icon(Icons.tune),
                      label: Text(context.l10n.formAddVariant),
                    ),
                  ],
                  const SizedBox(height: DsSpacing.lg),
                  PrimaryButton(
                    label: _isEditing
                        ? context.l10n.saveChanges
                        : context.l10n.formPublishProduct,
                    isLoading: isSubmitting,
                    onPressed: isSubmitting ? null : _submit,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildVariantRows() {
    return [
      for (var i = 0; i < _variants.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: DsSpacing.sm),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: DsInputField(
                  controller: _variants[i].name,
                  hint: context.l10n.formTitle,
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                flex: 2,
                child: DsInputField(
                  controller: _variants[i].stock,
                  hint: context.l10n.formStock,
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () =>
                    setState(() => _variants.removeAt(i).dispose()),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _label(BuildContext context, String text) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(
      text,
      style: TextStyle(
        fontFamily: DsTypography.fontFamily,
        fontWeight: DsTypography.semiBold,
        color: context.dsColors.onSurfaceVariant,
      ),
    ),
  );
}

class _VariantRow {
  final name = TextEditingController();
  final sku = TextEditingController();
  final price = TextEditingController();
  final stock = TextEditingController();

  void dispose() {
    name.dispose();
    sku.dispose();
    price.dispose();
    stock.dispose();
  }
}
