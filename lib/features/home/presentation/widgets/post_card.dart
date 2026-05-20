import 'package:flutter/material.dart';
import 'package:reem/features/home/data/models/post_model.dart';
import 'package:reem/features/home/presentation/widgets/product_card.dart';

import '../../../../core/theme/app_theme.dart';

class PostCard extends StatelessWidget {
  final PostModel post;

  const PostCard({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        // color: Colors.white,
        borderRadius: BorderRadius.circular(32),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .05),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// HEADER

          /// IMAGE
          Column(
            children: [
              Stack(
                children: [
                  GestureDetector(
                    onTap: () {
                      // product details
                    },
                    child: Hero(
                      tag: post.postImage,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Image.network(
                          post.postImage,
                          height: 360,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          /// AVATAR
                          GestureDetector(
                            onTap: () {
                              // profile details
                            },
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.secondary,
                                    AppColors.primary,
                                  ],
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 24,
                                backgroundImage: NetworkImage(post.userImage),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          /// USER INFO
                          GestureDetector(
                            onTap: () {
                              // profile details
                            },
                            child: Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    post.user,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),

                                  const SizedBox(height: 3),

                                  Text(
                                    "منذ ساعتين",
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () {},
                            icon: const Icon(Icons.more_horiz),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          /// ACTIONS
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                /// LIKE
                _actionButton(
                  onPressedIcon: () {},
                  onPressedText: () {},
                  icon: Icons.favorite_rounded,
                  text: post.likes.toString(),
                  color: Colors.pink,
                ),

                const SizedBox(width: 20),

                /// COMMENT
                _actionButton(
                  onPressedIcon: () {},
                  onPressedText: () {},
                  icon: Icons.mode_comment_outlined,
                  text: post.comments.toString(),
                ),

                const SizedBox(width: 20),

                /// SHARE
                _actionButton(
                  onPressedIcon: () {},
                  onPressedText: () {},
                  icon: Icons.share_outlined,
                ),

                const SizedBox(width: 20),

                _actionButton(
                  onPressedIcon: () {},
                  onPressedText: () {},
                  icon: Icons.save,
                ),

                const Spacer(),

                /// BUY BUTTON
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(.25),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    onPressed: () {},

                    icon: const Icon(
                      Icons.shopping_bag_outlined,
                      color: Colors.white,
                    ),

                    label: const Text(
                      "شراء",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// CAPTION
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              post.caption,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),

          const SizedBox(height: 20),

          /// PRODUCTS TITLE
          // const Padding(
          //   padding:
          //       EdgeInsets.symmetric(
          //     horizontal: 18,
          //   ),
          //   child: Text(
          //     "المنتجات في الإطلالة",
          //     style: TextStyle(
          //       fontSize: 18,
          //       fontWeight:
          //           FontWeight.bold,
          //     ),
          //   ),
          // ),

          // const SizedBox(height: 16),

          // /// PRODUCTS
          // SizedBox(
          //   height: 190,
          //   child: ListView.builder(
          //     padding:
          //         const EdgeInsets.only(
          //       right: 12,
          //       left: 4,
          //     ),
          //     scrollDirection:
          //         Axis.horizontal,
          //     itemCount:
          //         post.products.length,
          //     itemBuilder:
          //         (context, index) {
          //       return ProductCard(
          //         product: post.products[index],
          //       );
          //     },
          //   ),
          // ),

          // const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Function onPressedIcon,
    required Function onPressedText,
    String? text,
    Color color = Colors.black87,
  }) {
    return Row(
      children: [
        IconButton(
          onPressed: onPressedIcon(),
          icon: Icon(icon, color: color),
        ),

        if (text != null)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: onPressedText(),
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}
