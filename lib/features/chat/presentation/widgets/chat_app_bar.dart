import 'dart:ui';

import 'package:flutter/material.dart';

class ChatAppBar
    extends StatelessWidget {

  const ChatAppBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(

      child: BackdropFilter(

        filter: ImageFilter.blur(
          sigmaX: 20,
          sigmaY: 20,
        ),

        child: Container(

          padding:
              const EdgeInsets.symmetric(
            horizontal: 22,
            vertical: 18,
          ),

          decoration: BoxDecoration(

            color:
                Colors.white
                    .withOpacity(.7),

            border: Border(

              bottom: BorderSide(

                color: Colors.white
                    .withOpacity(.25),
              ),
            ),
          ),

          child: Row(

            children: [

              GestureDetector(

                onTap: () {
                  Navigator.pop(
                      context);
                },

                child: Container(

                  width: 48,
                  height: 48,

                  decoration:
                      BoxDecoration(

                    shape:
                        BoxShape.circle,

                    color: Colors.white,
                  ),

                  child: const Icon(
                    Icons
                        .arrow_back_ios_new_rounded,
                  ),
                ),
              ),

              const SizedBox(width: 18),

              const CircleAvatar(

                radius: 26,

                backgroundImage:
                    NetworkImage(
                  "https://images.unsplash.com/photo-1494790108377-be9c29b29330",
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

                      "Lujain Fashion",

                      style: TextStyle(

                        fontSize: 18,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Row(

                      children: [

                        Container(

                          width: 10,
                          height: 10,

                          decoration:
                              const BoxDecoration(

                            shape:
                                BoxShape.circle,

                            color:
                                Colors.green,
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(

                          "Online",

                          style: TextStyle(

                            color:
                                Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              _action(
                Icons.call_rounded,
              ),

              const SizedBox(width: 12),

              _action(
                Icons.videocam_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    IconData icon,
  ) {
    return Container(

      width: 48,
      height: 48,

      decoration: BoxDecoration(

        shape: BoxShape.circle,

        color: Colors.white,

        boxShadow: [

          BoxShadow(

            color: Colors.black
                .withOpacity(.04),

            blurRadius: 16,
          ),
        ],
      ),

      child: Icon(
        icon,

        color:
            const Color(
          0xffFF5C8A,
        ),
      ),
    );
  }
}