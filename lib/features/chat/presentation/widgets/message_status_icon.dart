import 'package:flutter/material.dart';

class MessageStatusIcon
    extends StatelessWidget {

  final bool seen;

  const MessageStatusIcon({
    super.key,
    this.seen = false,
  });

  @override
  Widget build(BuildContext context) {
    return Icon(

      seen
          ? Icons.done_all_rounded
          : Icons.done_rounded,

      size: 18,

      color:
          seen
              ? const Color(
                  0xffFF5C8A,
                )
              : Colors.grey,
    );
  }
}