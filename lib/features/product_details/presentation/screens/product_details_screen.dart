import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:reem/features/product_details/presentation/widgets/floating_buy_bar.dart';
import 'package:reem/features/product_details/presentation/widgets/parallax_product_header.dart';
import 'package:reem/features/product_details/presentation/widgets/product_color_selector.dart';
import 'package:reem/features/product_details/presentation/widgets/product_description.dart';
import 'package:reem/features/product_details/presentation/widgets/product_info_section.dart';
import 'package:reem/features/product_details/presentation/widgets/product_price_section.dart';
import 'package:reem/features/product_details/presentation/widgets/product_reviews_section.dart';
import 'package:reem/features/product_details/presentation/widgets/product_size_selector.dart';
import 'package:reem/features/product_details/presentation/widgets/product_story_preview.dart';
import 'package:reem/features/product_details/presentation/widgets/quantity_selector.dart';
import 'package:reem/features/product_details/presentation/widgets/related_products_section.dart';

class ProductDetailsScreen extends ConsumerStatefulWidget {
  const ProductDetailsScreen({super.key, this.productId});

  final String? productId;

  @override
  ConsumerState<ProductDetailsScreen> createState() =>
      _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends ConsumerState<ProductDetailsScreen> {
  @override
  void initState() {
    super.initState();
    final id = widget.productId;
    if (id != null && id.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(productDetailsNotifierProvider.notifier).load(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final productId = widget.productId;
    final detailsState = productId != null && productId.isNotEmpty
        ? ref.watch(productDetailsNotifierProvider)
        : null;

    return Scaffold(
      backgroundColor: context.dsColors.background,
      bottomNavigationBar: const FloatingBuyBar(),
      body: Stack(
        children: [
          const FeminineMeshBackground(),
          if (detailsState?.isLoading == true)
            const Center(child: CircularProgressIndicator()),
          if (detailsState?.error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(DsSpacing.lg),
                child: Text(
                  detailsState!.error!,
                  style: TextStyle(color: context.dsColors.error),
                ),
              ),
            ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              const ParallaxProductHeader(),
              SliverPadding(
                padding: const EdgeInsets.all(DsSpacing.lg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const ProductInfoSection(),
                    const SizedBox(height: DsSpacing.xxl),
                    const ProductPriceSection(),
                    const SizedBox(height: DsSpacing.xxxl),
                    const ProductStoryPreview(),
                    const SizedBox(height: DsSpacing.xxxl),
                    const ProductSizeSelector(),
                    const SizedBox(height: DsSpacing.xl),
                    const ProductColorSelector(),
                    const SizedBox(height: DsSpacing.xxxl),
                    const QuantitySelector(),
                    const SizedBox(height: DsSpacing.xxxl),
                    const ProductDescription(),
                    const SizedBox(height: DsSpacing.xxxl),
                    ProductReviewsSection(productId: productId),
                    const SizedBox(height: DsSpacing.xxxl),
                    const RelatedProductsSection(),
                    const SizedBox(height: 100),
                  ]),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
