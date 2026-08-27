import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/router/route_paths.dart';
import '../../../seller_products/domain/entities/managed_product.dart';
import '../../../seller_products/domain/entities/product_status.dart';
import '../../../seller_products/presentation/providers/seller_products_providers.dart';
import '../providers/create_provider.dart';
import '../providers/create_state.dart';
import '../widgets/create_header.dart';
import '../widgets/post_caption_field.dart';

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
          message: next.successMessage!,
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
        const PremiumAppBar(title: 'Create Post', showBack: true),
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
                title: 'Create Post',
                subtitle: 'Publish product-led content for your customers',
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
                label: 'Publish Post',
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
        message: 'Choose an active product before publishing.',
        type: DsSnackbarType.error,
      );
      return;
    }
    if (caption.isEmpty) {
      DsSnackbar.show(
        context,
        message: 'Write a caption before publishing.',
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
        value: selectedId,
        decoration: const InputDecoration(
          labelText: 'Featured product',
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
                  : Image.network(
                      product.coverImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => ColoredBox(
                        color: colors.surfaceVariant,
                        child: Icon(Icons.broken_image, color: colors.primary),
                      ),
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
                  style: const TextStyle(fontWeight: DsTypography.bold),
                ),
                const SizedBox(height: DsSpacing.xxs),
                Text(
                  '${product.price?.format() ?? ''} · ${product.stock} في المخزون',
                  style: TextStyle(color: colors.onSurfaceVariant),
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
          const DsEmptyState(
            icon: Icons.inventory_2_outlined,
            title: 'No active products',
            message: 'Activate a product before creating a seller post.',
          ),
          const SizedBox(height: DsSpacing.md),
          SecondaryButton(
            label: 'Create product',
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
    return const SurfaceCard(
      child: DsLoadingIndicator(label: 'Loading products'),
    );
  }
}
