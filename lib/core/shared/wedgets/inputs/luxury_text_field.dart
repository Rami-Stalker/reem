import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';

class LuxuryTextField
    extends StatelessWidget {
  final String hint;
  final IconData icon;

  const LuxuryTextField({
    super.key,
    required this.hint,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return DsGlassCard(
      borderRadius: 26,

      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 6,
      ),

      child: TextField(
        decoration: InputDecoration(
          border: InputBorder.none,

          icon: Icon(
            icon,
            color: Colors.pink.shade300,
          ),

          hintText: hint,
        ),
      ),
    );
  }
}