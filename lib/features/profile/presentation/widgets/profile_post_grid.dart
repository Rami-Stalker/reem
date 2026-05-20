import 'package:flutter/material.dart';

class ProfilePostGrid
    extends StatelessWidget {
  const ProfilePostGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final images = List.generate(
      12,
      (index) =>
          "https://picsum.photos/300?random=$index",
    );

    return SliverPadding(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),

      sliver: SliverGrid(
        delegate:
            SliverChildBuilderDelegate(
          (context, index) {
            return ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                      22),

              child: Image.network(
                images[index],
                fit: BoxFit.cover,
              ),
            );
          },
          childCount: images.length,
        ),

        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: .7,
        ),
      ),
    );
  }
}