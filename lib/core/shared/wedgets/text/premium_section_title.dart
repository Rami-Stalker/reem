import 'package:flutter/material.dart';

import '../app/reem_section_header.dart';

/// Legacy alias — use [ReemSectionHeader].
class PremiumSectionTitle extends StatelessWidget {
  const PremiumSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return ReemSectionHeader(title: title, subtitle: subtitle);
  }
}
