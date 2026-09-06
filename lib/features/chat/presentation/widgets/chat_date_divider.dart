import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// The "اليوم" / "أمس" rule between days in a conversation.
class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colors = context.dsColors;
    return Row(
      children: [
        Expanded(child: Divider(color: colors.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: DsSpacing.md),
          child: Text(title, style: context.dsText.captionStrong),
        ),
        Expanded(child: Divider(color: colors.divider)),
      ],
    );
  }
}
