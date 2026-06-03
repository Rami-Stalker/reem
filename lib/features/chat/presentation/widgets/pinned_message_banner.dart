import 'package:flutter/material.dart';

class PinnedMessageBanner
    extends StatelessWidget {

  final String message;

  const PinnedMessageBanner({
    super.key,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      margin:
          const EdgeInsets.all(
        18,
      ),

      padding:
          const EdgeInsets.all(
        18,
      ),

      decoration: BoxDecoration(

        gradient:
            const LinearGradient(

          colors: [

            Color(0xffFF9EB5),
            Color(0xffFF5C8A),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          26,
        ),
      ),

      child: Row(

        children: [

          Container(

            width: 52,
            height: 52,

            decoration:
                BoxDecoration(

              shape:
                  BoxShape.circle,

              color: Colors.white
                  .withOpacity(.2),
            ),

            child: const Icon(

              Icons.push_pin_rounded,

              color: Colors.white,
            ),
          ),

          const SizedBox(width: 16),

          Expanded(

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                const Text(

                  "Pinned Message",

                  style: TextStyle(

                    color:
                        Colors.white,

                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(

                  message,

                  style: TextStyle(

                    color: Colors.white
                        .withOpacity(.92),

                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}