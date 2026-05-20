import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class DiscountBanner extends StatelessWidget {
  const DiscountBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),

        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffF8BBD0), Color(0xffE89AAE)],
        ),

        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: .25),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          /// TEXTS
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "تخفيضات الصيف ✨",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(height: 8),

                Text(
                  "خصومات تصل إلى 50% على أحدث المنتجات النسائية",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          /// ICON
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.local_offer_outlined,
              color: Colors.white,
              size: 38,
            ),
          ),
        ],
      ),
    );
  }
}
