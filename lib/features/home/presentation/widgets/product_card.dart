// product_card.dart

import 'package:flutter/material.dart';
import '../../../../core/shared/models/product_model.dart';

import '../../../../core/theme/app_theme.dart';

class ProductCard extends StatelessWidget {
  final ProductModel product;

  const ProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // open product details
      },

      child: Container(
        width: 145,
        margin: const EdgeInsets.only(
          left: 14,
          bottom: 12,
        ),

        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(26),

          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            /// PRODUCT IMAGE
            Expanded(
              child: Stack(
                children: [

                  /// IMAGE
                  Hero(
                    tag: product.media[0].url,
                    child: ClipRRect(
                      borderRadius:
                          const BorderRadius
                              .vertical(
                        top:
                            Radius.circular(
                                26),
                      ),

                      child: Image.network(
                        product.media[0].url,
                        width:
                            double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),

                  /// FAVORITE BUTTON
                  Positioned(
                    top: 10,
                    left: 10,
                    child: Container(
                      padding:
                          const EdgeInsets
                              .all(8),

                      decoration:
                          BoxDecoration(
                        color: Colors.white
                            .withValues(alpha: .9),

                        shape:
                            BoxShape.circle,
                      ),

                      child: const Icon(
                        Icons
                            .favorite_border_rounded,
                        size: 18,
                        color:
                            AppColors.primary,
                      ),
                    ),
                  ),

                  /// DISCOUNT BADGE
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),

                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                                    14),

                        gradient:
                            const LinearGradient(
                          colors: [
                            AppColors
                                .primary,
                            AppColors
                                .secondary,
                          ],
                        ),
                      ),

                      child: const Text(
                        "-20%",
                        style: TextStyle(
                          color:
                              Colors.white,
                          fontSize: 11,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            /// PRODUCT INFO
            Padding(
              padding:
                  const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [

                  /// PRODUCT NAME
                  Text(
                    product.title,

                    maxLines: 1,

                    overflow:
                        TextOverflow
                            .ellipsis,

                    style:
                        const TextStyle(
                      fontSize: 15,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const SizedBox(height: 8),

                  /// RATING
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color:
                            Colors.amber,
                        size: 18,
                      ),

                      const SizedBox(
                          width: 4),

                      Text(
                        "4.9",

                        style:
                            TextStyle(
                          color: Colors
                              .grey[700],

                          fontWeight:
                              FontWeight
                                  .w600,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        "120 تقييم",

                        style:
                            TextStyle(
                          fontSize: 11,
                          color: Colors
                              .grey[500],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  /// PRICE + CART
                  Row(
                    children: [

                      /// PRICE
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [

                            /// OLD PRICE
                            Text(
                              "${(product.price + 40).toInt()} ر.س",

                              style:
                                  TextStyle(
                                fontSize:
                                    12,
                                decoration:
                                    TextDecoration
                                        .lineThrough,
                                color: Colors
                                    .grey[500],
                              ),
                            ),

                            const SizedBox(
                                height: 2),

                            /// NEW PRICE
                            Text(
                              "${product.price.toInt()} ر.س",

                              style:
                                  const TextStyle(
                                fontSize:
                                    18,
                                fontWeight:
                                    FontWeight
                                        .bold,
                                color:
                                    AppColors
                                        .primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      /// ADD TO CART
                      Container(
                        width: 42,
                        height: 42,

                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius
                                  .circular(
                                      14),

                          gradient:
                              const LinearGradient(
                            colors: [
                              AppColors
                                  .primary,
                              AppColors
                                  .secondary,
                            ],
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: AppColors
                                  .primary
                                  .withValues(
                                      alpha: 0.25),

                              blurRadius:
                                  12,

                              offset:
                                  const Offset(
                                      0, 5),
                            ),
                          ],
                        ),

                        child: IconButton(
                          onPressed: () {},

                          icon: const Icon(
                            Icons
                                .shopping_bag_outlined,
                            color:
                                Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}