import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/platform/unsaved_changes_guard.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/ai_assistant/presentation/providers/ai_assistant_provider.dart';
import 'package:reem/features/catalog/presentation/providers/categories_provider.dart';
import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_draft.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/features/seller_products/presentation/providers/seller_products_providers.dart';
import 'package:reem/features/seller_products/presentation/widgets/category_attribute_fields.dart';
import 'package:reem/features/seller_products/presentation/widgets/category_picker_field.dart';
import 'package:reem/l10n/app_localizations.dart';

/// Writing a listing.
///
/// The form is laid out along the seam the catalogue actually has. The first
/// block is the product's identity — what every seller of it shows — and the
/// second is this seller's own terms: her price, her stock, how long she needs
/// to prepare it. She does not own the first half once a competitor lists the
/// same item, and the form says so rather than letting her write an edit the
/// server will refuse.
class ProductFormScreen extends ConsumerStatefulWidget {
  const ProductFormScreen({super.key, this.product});

  /// Non-null when editing an existing listing.
  final ManagedProduct? product;

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _comparePrice = TextEditingController();
  final _stock = TextEditingController();
  final _sku = TextEditingController();
  final _handlingDays = TextEditingController(text: '1');
  final _minOrderQty = TextEditingController(text: '1');

  /// The leaf category's UUID. Nothing else opens `POST /seller/products`.
  String? _categoryId;
  String? _categoryError;

  /// The extra fields that category governs. A leaf inherits its schema from
  /// the nearest ancestor that declares one, and the endpoint refuses a draft
  /// missing any required key — so these are not decoration.
  final Map<String, String> _attributes = {};
  bool _showAttributeErrors = false;

  /// URLs of photographs already uploaded. `DsMediaField` owns the tiles and
  /// the in-flight state; the form only keeps what it will post.
  List<String> _mediaUrls = const [];
  bool _mediaUploading = false;

  final List<_VariantRow> _variants = [];

  /// Set once the listing has been accepted by the server. From that moment
  /// the screen is closing on purpose and there is nothing left to protect.
  bool _saved = false;

  Currency _currency = Currency.syp;
  ProductStatus _status = ProductStatus.draft;
  bool _acceptsReturns = true;
  bool _isMadeToOrder = false;

  /// Eight is what a listing can show without the grid turning into a scroll
  /// of its own, and enough for a garment from every angle.
  static const int _maxMedia = 8;

  /// The states a seller may choose. `pendingReview` is the platform's to set
  /// and `outOfStock` is derived from the stock figure — offering either as a
  /// button would be offering work she cannot do.
  static const _selectableStatuses = [
    ProductStatus.draft,
    ProductStatus.active,
    ProductStatus.paused,
    ProductStatus.archived,
  ];

  bool get _isEditing => widget.product != null;

  /// The shared half is read-only once someone else lists the same product.
  bool get _canEditIdentity => !(widget.product?.hasCompetition ?? false);

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    if (p == null) return;

    _title.text = p.title;
    _description.text = p.description;
    _categoryId = p.category.id.isEmpty ? null : p.category.id;
    // The raw decimal string, not a formatted figure — this feeds an input
    // that is posted straight back to the server.
    _price.text = p.price.raw;
    _comparePrice.text = p.compareAtPrice?.raw ?? '';
    _currency = p.price.currency;
    _stock.text = p.stock.toString();
    _sku.text = p.sku ?? '';
    _handlingDays.text = p.handlingDays.toString();
    _minOrderQty.text = p.minOrderQty.toString();
    _status = p.status;
    _acceptsReturns = p.acceptsReturns;
    _isMadeToOrder = p.isMadeToOrder;
    _mediaUrls = [for (final m in p.media) m.url];
    _attributes.addAll({
      for (final entry in p.attributes.entries)
        entry.key: entry.value?.toString() ?? '',
    });

    // A listing's options are the product's names joined to this seller's own
    // price and stock for each — two rows on two tables, one line on screen.
    for (final variant in p.variants) {
      final mine = p.offerVariants
          .where((offer) => offer.variantId == variant.id)
          .firstOrNull;
      _variants.add(
        _VariantRow()
          ..name.text = variant.name
          ..price.text = mine?.price.raw ?? ''
          ..stock.text = (mine?.stock ?? 0).toString()
          ..sku.text = mine?.sku ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _price,
      _comparePrice,
      _stock,
      _sku,
      _handlingDays,
      _minOrderQty,
    ]) {
      c.dispose();
    }
    for (final v in _variants) {
      v.dispose();
    }
    super.dispose();
  }

  // ── AI helpers ───────────────────────────────────────────────────────────

  /// The AI helpers want a category *name*, not the id the server wants.
  String get _categoryName {
    final id = _categoryId;
    if (id == null) return '';
    return ref.read(categoryByIdProvider(id))?.name ??
        widget.product?.category.nameAr ??
        '';
  }

  Future<void> _generateDescription() async {
    if (!_hasTitleAndCategory) return;
    final output = await ref
        .read(aiAssistantActionsProvider)
        .generateDescription(
          title: _title.text.trim(),
          category: _categoryName,
          productId: widget.product?.productId,
          attributes: _variantNames,
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
    if (!_hasTitleAndCategory) return;
    final tags = await ref
        .read(aiAssistantActionsProvider)
        .generateTags(
          title: _title.text.trim(),
          category: _categoryName,
          productId: widget.product?.productId,
          description: _description.text,
        );
    if (!mounted) return;
    DsSnackbar.show(
      context,
      message: tags.isEmpty ? context.l10n.formNoTags : tags.join('، '),
      type: tags.isEmpty ? DsSnackbarType.warning : DsSnackbarType.success,
    );
  }

  bool get _hasTitleAndCategory {
    if (_title.text.trim().isNotEmpty && _categoryId != null) return true;
    DsSnackbar.show(
      context,
      message: context.l10n.formTitleCategoryFirst,
      type: DsSnackbarType.warning,
    );
    return false;
  }

  List<String> get _variantNames => [
    for (final v in _variants)
      if (v.name.text.trim().isNotEmpty) v.name.text.trim(),
  ];

  // ── Saving ───────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final categoryMissing = _categoryId == null;
    setState(() {
      _categoryError = categoryMissing
          ? context.l10n.formCategoryRequired
          : null;
      _showAttributeErrors = true;
    });
    if (!_formKey.currentState!.validate() || categoryMissing) return;

    // The same check the endpoint makes, made here so she is told which field
    // is missing rather than handed `This category requires: material` from a
    // server that does not speak her language.
    final schema = switch (ref.read(categoryAttributesProvider(_categoryId!))) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (schema != null && schema.missingFrom(_attributes).isNotEmpty) {
      DsSnackbar.show(
        context,
        message: context.l10n.formCategoryNeedsDetails,
        type: DsSnackbarType.warning,
      );
      return;
    }

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

    final draft = ProductDraft(
      title: _title.text.trim(),
      description: _description.text.trim(),
      categoryId: _categoryId!,
      currency: _currency,
      price: _price.text.trim(),
      compareAtPrice: _comparePrice.text.trim().isEmpty
          ? null
          : _comparePrice.text.trim(),
      stock: int.tryParse(_stock.text.trim()) ?? 0,
      sku: _sku.text.trim().isEmpty ? null : _sku.text.trim(),
      handlingDays: int.tryParse(_handlingDays.text.trim()) ?? 1,
      minOrderQty: int.tryParse(_minOrderQty.text.trim()) ?? 1,
      acceptsReturns: _acceptsReturns,
      isMadeToOrder: _isMadeToOrder,
      status: _status,
      attributes: {
        for (final entry in _attributes.entries)
          if (entry.value.trim().isNotEmpty) entry.key: entry.value.trim(),
      },
      media: [for (final url in _mediaUrls) MediaDraft(url)],
      variants: [
        for (final v in _variants)
          if (v.name.text.trim().isNotEmpty)
            VariantDraft(
              name: v.name.text.trim(),
              sku: v.sku.text.trim().isEmpty ? null : v.sku.text.trim(),
              price: v.price.text.trim().isEmpty ? null : v.price.text.trim(),
              stock: int.tryParse(v.stock.text.trim()) ?? 0,
            ),
      ],
    );

    final saved = await ref
        .read(productFormNotifierProvider.notifier)
        .submit(listing: widget.product, draft: draft);

    if (!mounted) return;
    if (saved == null) {
      final error = ref.read(productFormNotifierProvider).error;
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
      return;
    }

    _saved = true;
    ref.read(myProductsNotifierProvider.notifier).upsert(saved);
    DsSnackbar.show(
      context,
      message: _isEditing
          ? context.l10n.formProductUpdated
          : context.l10n.formProductCreated,
      type: DsSnackbarType.success,
    );
    context.pop();
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isSubmitting = ref.watch(
      productFormNotifierProvider.select((s) => s.isSubmitting),
    );

    return UnsavedChangesGuard(
      // A listing is the longest form in the app — eight photographs, a
      // category, a schema of attributes, a table of variants. Losing it to a
      // stray edge swipe is half an hour of a seller's evening.
      hasUnsavedChanges: !_saved && !isSubmitting && _isDirty,
      child: _body(context, l10n, isSubmitting),
    );
  }

  /// Whether anything on the form has been touched since it opened.
  ///
  /// An edit starts populated, so "not empty" would mean every edit screen
  /// asks on the way out; it compares against what it was handed instead.
  bool get _isDirty {
    final original = widget.product;
    if (original == null) {
      return _title.text.trim().isNotEmpty ||
          _description.text.trim().isNotEmpty ||
          _price.text.trim().isNotEmpty ||
          _categoryId != null ||
          _mediaUrls.isNotEmpty ||
          _variants.isNotEmpty;
    }
    return _title.text != original.title ||
        _description.text != original.description ||
        _price.text != original.price.raw ||
        _categoryId !=
            (original.category.id.isEmpty ? null : original.category.id) ||
        _status != original.status ||
        _currency != original.price.currency;
  }

  Widget _body(BuildContext context, AppLocalizations l10n, bool isSubmitting) {
    return ReemScrollPage(
      // Without these the form inherits the buyer's blush silk — the wrong
      // room for a seller writing a listing.
      background: const SellerAtelierBackground(),
      backgroundColor: context.atelier.background,
      slivers: [
        PremiumAppBar(
          title: _isEditing ? l10n.formEditProduct : l10n.formNewProduct,
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
                  if (!_canEditIdentity)
                    _Notice(
                      icon: Icons.groups_rounded,
                      message: l10n.formSharedProductLocked,
                    ),
                  if (!_isEditing)
                    _Notice(
                      icon: Icons.verified_outlined,
                      message: l10n.formNewListingReview,
                    ),

                  _SectionHeader(l10n.formIdentitySection),
                  DsInputField(
                    controller: _title,
                    label: l10n.formTitle,
                    enabled: _canEditIdentity,
                    validator: (v) => (v == null || v.trim().length < 2)
                        ? l10n.formTitleRequired
                        : null,
                  ),
                  DsInputField(
                    controller: _description,
                    label: l10n.formDescription,
                    maxLines: 4,
                    enabled: _canEditIdentity,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? l10n.formDescriptionRequired
                        : null,
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  CategoryPickerField(
                    selectedId: _categoryId,
                    enabled: _canEditIdentity,
                    errorText: _categoryError,
                    onSelected: (node) => setState(() {
                      // A different shelf governs different extra fields, so
                      // the answers to the old one's do not carry over.
                      if (node.id != _categoryId) _attributes.clear();
                      _categoryId = node.id;
                      _categoryError = null;
                    }),
                  ),
                  CategoryAttributeFields(
                    categoryId: _categoryId,
                    values: _attributes,
                    enabled: _canEditIdentity,
                    showErrors: _showAttributeErrors,
                    onChanged: (key, value) => setState(() {
                      _attributes[key] = value;
                    }),
                  ),
                  if (_canEditIdentity)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Wrap(
                        spacing: DsSpacing.sm,
                        children: [
                          TextButton.icon(
                            onPressed: _generateDescription,
                            icon: const Icon(Icons.auto_awesome_rounded),
                            label: Text(l10n.formAiDescription),
                          ),
                          TextButton.icon(
                            onPressed: _generateTags,
                            icon: const Icon(Icons.sell_outlined),
                            label: Text(l10n.formAiTags),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: DsSpacing.sm),
                  DsMediaField(
                    label: l10n.mediaProductGallery,
                    helperText: l10n.mediaGalleryHint(_maxMedia),
                    initialUrls: _mediaUrls,
                    maxItems: _maxMedia,
                    enabled: !isSubmitting && _canEditIdentity,
                    onChanged: (urls) => _mediaUrls = urls,
                    onUploadingChanged: (busy) =>
                        setState(() => _mediaUploading = busy),
                  ),

                  _SectionHeader(l10n.formPricingSection),
                  _CurrencyChips(
                    value: _currency,
                    onChanged: (c) => setState(() => _currency = c),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: DsInputField(
                          controller: _price,
                          label: l10n.formPrice,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final value = double.tryParse((v ?? '').trim());
                            if (value == null || value <= 0) {
                              return l10n.formPriceInvalid;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(
                        child: DsInputField(
                          controller: _comparePrice,
                          label: l10n.formComparePrice,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final raw = (v ?? '').trim();
                            if (raw.isEmpty) return null;
                            final value = double.tryParse(raw);
                            if (value == null || value <= 0) {
                              return l10n.formPriceInvalid;
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: DsInputField(
                          controller: _stock,
                          label: l10n.formStock,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final value = int.tryParse((v ?? '').trim());
                            if (value == null || value < 0) {
                              return l10n.formStockInvalid;
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(
                        child: DsInputField(
                          controller: _sku,
                          label: l10n.formSku,
                        ),
                      ),
                    ],
                  ),

                  _SectionHeader(l10n.formListingTerms),
                  Row(
                    children: [
                      Expanded(
                        child: DsInputField(
                          controller: _handlingDays,
                          label: l10n.formHandlingDays,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: DsSpacing.md),
                      Expanded(
                        child: DsInputField(
                          controller: _minOrderQty,
                          label: l10n.formMinOrderQty,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.formAcceptsReturns),
                    value: _acceptsReturns,
                    onChanged: (v) => setState(() => _acceptsReturns = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.formMadeToOrder),
                    value: _isMadeToOrder,
                    onChanged: (v) => setState(() => _isMadeToOrder = v),
                  ),

                  _SectionHeader(l10n.formStatus),
                  Wrap(
                    spacing: DsSpacing.sm,
                    children: [
                      for (final s in _selectableStatuses)
                        ChoiceChip(
                          label: Text(s.label),
                          selected: _status == s,
                          selectedColor: context.dsColors.primary.withValues(
                            alpha: 0.16,
                          ),
                          onSelected: (_) => setState(() => _status = s),
                        ),
                    ],
                  ),

                  _SectionHeader(l10n.formVariantsTitle),
                  Text(
                    l10n.formVariantsHint,
                    style: context.dsText.caption.tint(context.atelier.muted),
                  ),
                  const SizedBox(height: DsSpacing.sm),
                  ..._buildVariantRows(),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _variants.add(_VariantRow())),
                      icon: const Icon(Icons.tune),
                      label: Text(l10n.formAddVariant),
                    ),
                  ),

                  const SizedBox(height: DsSpacing.lg),
                  PrimaryButton(
                    label: _isEditing
                        ? l10n.saveChanges
                        : l10n.formPublishProduct,
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
    final l10n = context.l10n;
    return [
      for (var i = 0; i < _variants.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: DsSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 4,
                child: DsInputField(
                  controller: _variants[i].name,
                  hint: l10n.formVariantName,
                  // Renaming an option would orphan this seller's price and
                  // stock for it, which are keyed by the canonical variant.
                  enabled: _canEditIdentity,
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                flex: 3,
                child: DsInputField(
                  controller: _variants[i].price,
                  hint: l10n.formVariantPrice,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: DsSpacing.sm),
              Expanded(
                flex: 2,
                child: DsInputField(
                  controller: _variants[i].stock,
                  hint: l10n.formStock,
                  keyboardType: TextInputType.number,
                ),
              ),
              IconButton(
                tooltip: context.l10n.delete,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: _canEditIdentity
                    ? () => setState(() => _variants.removeAt(i).dispose())
                    : null,
              ),
            ],
          ),
        ),
    ];
  }
}

// ── Internal components ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: DsSpacing.lg, bottom: DsSpacing.xs),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          label.toUpperCase(),
          style: DsTypography.overline(context.atelier.muted),
        ),
      ),
    );
  }
}

/// A quiet explanation of something the form will not let her do, placed where
/// she meets the restriction rather than behind an error she triggers.
class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.atelier;
    return Container(
      margin: const EdgeInsets.only(bottom: DsSpacing.sm),
      padding: const EdgeInsets.all(DsSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: DsRadius.borderMd,
        border: Border.all(color: palette.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: context.dsColors.primary),
          const SizedBox(width: DsSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: context.dsText.labelMedium
                  .tint(palette.muted)
                  .copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrencyChips extends StatelessWidget {
  const _CurrencyChips({required this.value, required this.onChanged});

  final Currency value;
  final ValueChanged<Currency> onChanged;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: DsSpacing.sm,
        children: [
          for (final currency in Currency.values)
            ChoiceChip(
              label: Text(currency.symbol),
              selected: value == currency,
              selectedColor: context.dsColors.primary.withValues(alpha: 0.16),
              onSelected: (_) => onChanged(currency),
            ),
        ],
      ),
    );
  }
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
