import 'package:flutter/material.dart';
import '../../../../common/styles/text_styles.dart';

class CustomAppBar extends StatelessWidget {
  const CustomAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      title: const Text(
        "Glow & Gift",
        style: AppTextStyles.logo,
      ),
      leading: const Icon(Icons.favorite_border),
      actions: [
        Stack(
          children: [
            IconButton(
              onPressed: () {},
              icon: const Icon(Icons.notifications_none),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            )
          ],
        )
      ],
    );
  }
}