import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/l10n_extension.dart';
import 'package:reem/core/media/authorized_media_image.dart';
import 'package:reem/core/media/media_variants.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/features/create/presentation/providers/create_provider.dart';
import 'package:reem/features/create/presentation/providers/create_state.dart';
import 'package:reem/features/create/presentation/widgets/create_header.dart';
import 'package:reem/features/create/presentation/widgets/post_caption_field.dart';
import 'package:reem/features/seller_products/domain/entities/managed_product.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/features/seller_products/presentation/providers/seller_products_providers.dart';

class AddPostScreen extends ConsumerStatefulWidget {
  const AddPostScreen({super.key});

  @override
  ConsumerState<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends ConsumerState<AddPostScreen> {
  final _captionController = TextEditingController();
  String? _selectedProductId;

  @override
  void dispose() {
    _captionController.dispose();
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
        _captionController.clear();
        DsSnackbar.show(
          context,
          message: next.successMessage!.resolve(context.l10n),
          type: DsSnackbarType.success,
        );
      }
    });

    ref.listen(myProductsNotifierProvider.select((s) => s.error), (_, error) {
      if (error != null) {
        DsSnackbar.show(context, message: error, type: DsSnackbarType.error);
      }
    });

    final createState = ref.watch(createNotifierProvider);
    final productsState = ref.watch(myProductsNotifierProvider);
    final products = productsState.products
        .where((product) => product.status == ProductStatus.active)
        .toList(growable: false);
    final selectedProduct = _selectedProduct(products);

    return ReemScrollPage(
      onRefresh: () => ref.read(myProductsNotifierProvider.notifier).refresh(),
      slivers: [
        PremiumAppBar(title: context.l10n.createPostTitle, showBack: true),
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
                title: context.l10n.createPostTitle,
                subtitle: context.l10n.createPostBody,
              ),
              const SizedBox(height: DsSpacing.xl),
              if (productsState.isLoading && productsState.products.isEmpty)
                const _LoadingProductsCard()
              else if (products.isEmpty)
                _NoProductsCard(
                  onCreateProduct: () => context.push(RoutePaths.productForm),
                )
              else ...[
                _ProductPickerCard(
                  products: products,
                  selectedId: selectedProduct?.id,
                  onChanged: (value) =>
                      setState(() => _selectedProductId = value),
                ),
                const SizedBox(height: DsSpacing.lg),
                if (selectedProduct != null)
                  _SelectedProductCard(product: selectedProduct),
              ],
              const SizedBox(height: DsSpacing.lg),
              PostCaptionField(
                controller: _captionController,
                enabled: !createState.isLoading,
              ),
              const SizedBox(height: DsSpacing.xl),
              PrimaryButton(
                label: context.l10n.createPostAction,
                icon: Icons.send_rounded,
                isLoading: createState.isLoading,
                onPressed: createState.isLoading || products.isEmpty
                    ? null
                    : () => _submit(products),
              ),
            ],
          ),
        ),
      ],
    );
  }

  ManagedProduct? _selectedProduct(List<ManagedProduct> products) {
    if (products.isEmpty) return null;
    final selectedId = _selectedProductId;
    if (selectedId == null) return null;
    for (final product in products) {
      if (product.id == selectedId) return product;
    }
    return null;
  }

  Future<void> _submit(List<ManagedProduct> products) async {
    final caption = _captionController.text.trim();
    final productId = _selectedProductId;
    final ownsSelectedProduct =
        products.any((product) => product.id == productId);
    if (productId == null || !ownsSelectedProduct) {
      DsSnackbar.show(
        context,
        message: context.l10n.createPostNeedsProduct,
        type: DsSnackbarType.error,
      );
      return;
    }
    if (caption.isEmpty) {
      DsSnackbar.show(
        context,
        message: context.l10n.createPostNeedsCaption,
        type: DsSnackbarType.error,
      );
      return;
    }

    await ref.read(createNotifierProvider.notifier).createPost(
          caption: caption,
          productId: productId,
        );
  }
}

class _ProductPickerCard extends StatelessWidget {
  const _ProductPickerCard({
    required this.products,
    required this.selectedId,
    required this.onChanged,
  });

  final List<ManagedProduct> products;
  final String? selectedId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: DropdownButtonFormField<String>(
        initialValue: selectedId,
        decoration: InputDecoration(
          labelText: context.l10n.createPostFeatured,
          prefixIcon: Icon(Icons.inventory_2_outlined),
        ),
        items: [
          for (final product in products)
            DropdownMenuItem(
              value: product.id,
              child: Text(
                product.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _SelectedProductCard extends StatelessWidget {
  const _SelectedProductCard({required this.product});

  final ManagedProduct product;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return SurfaceCard(
      child: Row(
        children: [
          ClipRRect(
            borderRadius: DsRadius.borderLg,
            child: SizedBox(
              width: 76,
              height: 76,
              child: product.coverImage == null
                  ? ColoredBox(
                      color: colors.surfaceVariant,
                      child: Icon(Icons.image_outlined, color: colors.primary),
                    )
                  : AuthorizedMediaImage(
                      url: product.coverImage!,
                      variantWidth: MediaVariants.thumbnail,
                    ),
            ),
          ),
          const SizedBox(width: DsSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.dsText.body.bold,
                ),
                const SizedBox(height: DsSpacing.xxs),
                Text(
                  context.l10n.createProductPriceStock(
                    product.price.format(),
                    product.stock,
                  ),
                  style: context.dsText.body.tint(colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NoProductsCard extends StatelessWidget {
  const _NoProductsCard({required this.onCreateProduct});

  final VoidCallback onCreateProduct;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        children: [
          DsEmptyState(
            icon: Icons.inventory_2_outlined,
            title: context.l10n.createPostNoProducts,
            message: context.l10n.createPostNoProductsBody,
          ),
          const SizedBox(height: DsSpacing.md),
          SecondaryButton(
            label: context.l10n.createPostAddProduct,
            icon: Icons.add_business_rounded,
            onPressed: onCreateProduct,
          ),
        ],
      ),
    );
  }
}

class _LoadingProductsCard extends StatelessWidget {
  const _LoadingProductsCard();

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: DsLoadingIndicator(label: context.l10n.createPostLoadingProducts),
    );
  }
}
