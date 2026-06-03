import 'package:flutter/material.dart';

class DisappearingMessageTimer
    extends StatefulWidget {

  final int seconds;

  const DisappearingMessageTimer({
    super.key,
    required this.seconds,
  });

  @override
  State<
          DisappearingMessageTimer>
      createState() =>
          _DisappearingMessageTimerState();
}

class _DisappearingMessageTimerState
    extends State<
        DisappearingMessageTimer> {

  late int current;

  @override
  void initState() {
    super.initState();

    current = widget.seconds;

    _start();
  }

  void _start() async {

    while (current > 0) {

      await Future.delayed(
        const Duration(seconds: 1),
      );

      if (!mounted) return;

      setState(() {
        current--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(

      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),

      decoration:
          BoxDecoration(

        borderRadius:
            BorderRadius.circular(
          18,
        ),

        color:
            Colors.black
                .withOpacity(.06),
      ),

      child: Row(

        mainAxisSize:
            MainAxisSize.min,

        children: [

          const Icon(

            Icons.timer_rounded,

            size: 18,

            color:
                Color(
              0xffFF5C8A,
            ),
          ),

          const SizedBox(width: 8),

          Text(

            "${current}s",

            style: const TextStyle(

              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}