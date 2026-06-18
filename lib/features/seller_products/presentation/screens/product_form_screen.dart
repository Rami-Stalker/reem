import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/design_system/components/snackbars/app_snackbar.dart'
    show DsSnackbar, DsSnackbarType;
import '../../../../core/shared/wedgets/app/premium_app_bar.dart';
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

  final List<TextEditingController> _media = [];
  final List<_VariantRow> _variants = [];

  ProductStatus _status = ProductStatus.draft;
  bool _isFeatured = false;
  bool _showInFeed = true;

  bool get _isEditing => widget.product != null;

  Future<void> _generateDescription() async {
    final title = _title.text.trim();
    final category = _category.text.trim();
    if (title.isEmpty || category.isEmpty) {
      DsSnackbar.show(
        context,
        message: 'Add a title and category first',
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
      message: 'AI description added',
      type: DsSnackbarType.success,
    );
  }

  Future<void> _generateTags() async {
    final title = _title.text.trim();
    final category = _category.text.trim();
    if (title.isEmpty || category.isEmpty) {
      DsSnackbar.show(
        context,
        message: 'Add a title and category first',
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
      message: tags.isEmpty ? 'No tags generated' : 'Tags: ${tags.join(', ')}',
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
      _category.text = p.category;
      _price.text = p.price.toString();
      _oldPrice.text = p.oldPrice?.toString() ?? '';
      _stock.text = p.stock.toString();
      _status = p.status;
      _isFeatured = p.isFeatured;
      _showInFeed = p.showInFeed;
      for (final m in p.media) {
        _media.add(TextEditingController(text: m.url));
      }
    }
    if (_media.isEmpty) _media.add(TextEditingController());
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
    for (final c in _media) {
      c.dispose();
    }
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final media = _media
        .map((c) => c.text.trim())
        .where((url) => url.isNotEmpty)
        .map((url) => MediaDraft(url))
        .toList();

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
        message: _isEditing ? 'Product updated' : 'Product created',
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
      slivers: [
        PremiumAppBar(
          title: _isEditing ? 'Edit Product' : 'New Product',
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
                    label: 'Title',
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? 'Title is required'
                        : null,
                  ),
                  DsInputField(
                    controller: _description,
                    label: 'Description',
                    maxLines: 4,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Description is required'
                        : null,
                  ),
                  DsInputField(
                    controller: _category,
                    label: 'Category',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Category is required'
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
                          label: const Text('AI description'),
                        ),
                        TextButton.icon(
                          onPressed: _generateTags,
                          icon: const Icon(Icons.sell_outlined),
                          label: const Text('AI tags'),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DsInputField(
                          controller: _price,
                          label: 'Price',
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final value = double.tryParse((v ?? '').trim());
                            if (value == null || value < 0) {
                              return 'Enter a valid price';
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
                    label: 'Stock',
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      final value = int.tryParse((v ?? '').trim());
                      if (value == null || value < 0)
                        return 'Enter valid stock';
                      return null;
                    },
                  ),
                  const SizedBox(height: DsSpacing.md),
                  _label(context, 'Status'),
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
                    title: const Text('Featured'),
                    value: _isFeatured,
                    onChanged: (v) => setState(() => _isFeatured = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Show in feed'),
                    value: _showInFeed,
                    onChanged: (v) => setState(() => _showInFeed = v),
                  ),
                  const SizedBox(height: DsSpacing.md),
                  _label(context, 'Gallery (image URLs)'),
                  const SizedBox(height: DsSpacing.xs),
                  ..._buildMediaRows(),
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => _media.add(TextEditingController())),
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Add image'),
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
                      label: const Text('Add variant'),
                    ),
                  ],
                  const SizedBox(height: DsSpacing.lg),
                  PrimaryButton(
                    label: _isEditing ? 'Save changes' : 'Publish product',
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

  List<Widget> _buildMediaRows() {
    return [
      for (var i = 0; i < _media.length; i++)
        Row(
          children: [
            Expanded(
              child: DsInputField(
                controller: _media[i],
                hint: 'https://…',
                keyboardType: TextInputType.url,
              ),
            ),
            if (_media.length > 1)
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => setState(() {
                  _media.removeAt(i).dispose();
                }),
              ),
          ],
        ),
    ];
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
                  hint: 'Name',
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                flex: 2,
                child: DsInputField(
                  controller: _variants[i].stock,
                  hint: 'Stock',
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
