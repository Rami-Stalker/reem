import 'package:flutter/material.dart';

class MessageDeliveryStatus
    extends StatelessWidget {

  final bool sent;

  final bool delivered;

  final bool seen;

  const MessageDeliveryStatus({
    super.key,
    this.sent = true,
    this.delivered = false,
    this.seen = false,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon =
        Icons.check_rounded;

    Color color =
        Colors.grey;

    if (delivered) {
      icon = Icons.done_all;
    }

    if (seen) {
      icon = Icons.done_all;

      color =
          const Color(
        0xff4FC3F7,
      );
    }

    return Icon(

      icon,

      size: 18,

      color: color,
    );
  }
}