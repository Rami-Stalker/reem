import 'package:flutter/material.dart';

class SwipeReplyContainer
    extends StatelessWidget {

  final Widget child;

  const SwipeReplyContainer({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(

      key: UniqueKey(),

      direction:
          DismissDirection
              .startToEnd,

      background: Container(

        margin:
            const EdgeInsets.symmetric(
          vertical: 6,
        ),

        padding:
            const EdgeInsetsDirectional.only(
          start: 24,
        ),

        alignment:
            AlignmentDirectional.centerStart,

        decoration:
            BoxDecoration(

          borderRadius:
              BorderRadius.circular(
            28,
          ),

          gradient:
              const LinearGradient(

            colors: [

              Color(0xffFF9EB5),
              Color(0xffFF5C8A),
            ],
          ),
        ),

        child: const Icon(

          Icons.reply_rounded,

          color: Colors.white,

          size: 32,
        ),
      ),

      onDismissed: (_) {},

      child: child,
    );
  }
}