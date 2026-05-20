import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceAround,
        children: [
          _navItem(
            icon: Icons.home_rounded,
            index: 0,
          ),
          _navItem(
            icon: Icons.search_rounded,
            index: 1,
          ),

          const SizedBox(width: 30),

          _navItem(
            icon: Icons.favorite_border_rounded,
            index: 2,
          ),
          _navItem(
            icon: Icons.person_outline_rounded,
            index: 3,
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required int index,
  }) {
    final bool active =
        currentIndex == index;

    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration:
            const Duration(milliseconds: 250),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.softPink
              : Colors.transparent,
        ),
        child: Icon(
          icon,
          size: 28,
          color: active
              ? AppColors.primary
              : Colors.grey,
        ),
      ),
    );
  }
}