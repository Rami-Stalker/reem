import 'package:flutter/material.dart';

class IncomingCallOverlay
    extends StatelessWidget {

  const IncomingCallOverlay({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      backgroundColor:
          Colors.black
              .withOpacity(.82),

      body: SafeArea(

        child: Column(

          children: [

            const Spacer(),

            const CircleAvatar(

              radius: 72,

              backgroundImage:
                  NetworkImage(
                "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
              ),
            ),

            const SizedBox(height: 28),

            const Text(

              "Lujain Fashion",

              style: TextStyle(

                color: Colors.white,

                fontSize: 30,

                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            Text(

              "Incoming Video Call...",

              style: TextStyle(

                color: Colors.white
                    .withOpacity(.75),

                fontSize: 16,
              ),
            ),

            const Spacer(),

            Padding(

              padding:
                  const EdgeInsets.all(
                34,
              ),

              child: Row(

                mainAxisAlignment:
                    MainAxisAlignment
                        .spaceEvenly,

                children: [

                  _button(
                    Icons.call_end_rounded,
                    Colors.red,
                  ),

                  _button(
                    Icons.call_rounded,
                    Colors.green,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _button(
    IconData icon,
    Color color,
  ) {
    return Container(

      width: 86,
      height: 86,

      decoration:
          BoxDecoration(

        shape:
            BoxShape.circle,

        color: color,
      ),

      child: Icon(
        icon,
        color: Colors.white,
        size: 36,
      ),
    );
  }
}