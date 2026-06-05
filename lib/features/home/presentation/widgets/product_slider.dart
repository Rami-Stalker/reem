import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/app/reem_section_header.dart';
import '../../../../core/shared/wedgets/cards/animated_product_card.dart';
import '../providers/home_provider.dart';

class ProductSlider extends ConsumerWidget {
  const ProductSlider({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(homeNotifierProvider).posts;
    final products = posts.map((e) => e.product).toList();

    // Fallback to demo if backend returns empty (keeps screen usable during integration).
      final items = products.isNotEmpty
          ? products
          : (posts.isNotEmpty ? [posts.first.product] : []);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ReemSectionHeader(
          title: 'New Arrivals',
          subtitle: 'Fresh picks for you',
        ),
        const SizedBox(height: DsSpacing.lg),
        SizedBox(
          height: 340,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: DsSpacing.lg),
            itemBuilder: (context, index) {
              final product = items[index];
              final imageUrl = product.media.isNotEmpty ? product.media.first.url : '';

              return SizedBox(
                width: 250,
                child: AnimatedProductCard(
                  image: imageUrl,
                  title: product.title,
                  price: '\$${product.price.toStringAsFixed(0)}',
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

