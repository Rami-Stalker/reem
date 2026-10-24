import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/design_system.dart';

/// How many messages are waiting, pressed into a wax seal.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => WaxSeal(count: count);
}
