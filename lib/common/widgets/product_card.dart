import 'package:flutter/material.dart';
import 'network_image.dart';

class ProductCard extends StatelessWidget {
  final String title;
  final String image;
  final double price;
  final VoidCallback? onTap;

  const ProductCard({
    super.key,
    required this.title,
    required this.image,
    required this.price,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkImageWidget(
              url: image,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              child: Text('\$${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                      color: Colors.green,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}