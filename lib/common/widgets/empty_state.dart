import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final IconData? icon;
  const EmptyState({
    super.key,
    required this.message,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null)
            Icon(icon, size: 60, color: Colors.grey.shade300),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}