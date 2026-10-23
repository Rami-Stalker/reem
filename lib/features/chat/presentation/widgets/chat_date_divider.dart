import 'package:flutter/material.dart';

import 'package:reem/core/design_system/design_system.dart';

/// The "اليوم" / "أمس" seal between days in a conversation.
class ChatDateDivider extends StatelessWidget {
  const ChatDateDivider({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => SealDivider(label: title);
}
