import 'package:flutter/material.dart';

class ImageMessageBubble
    extends StatelessWidget {

  final String image;

  final bool isMe;

  const ImageMessageBubble({
    super.key,
    required this.image,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(

      alignment:
          isMe
              ? Alignment.centerRight
              : Alignment.centerLeft,

      child: ClipRRect(

        borderRadius:
            BorderRadius.only(

          topLeft:
              const Radius.circular(
            30,
          ),

          topRight:
              const Radius.circular(
            30,
          ),

          bottomLeft:
              Radius.circular(
            isMe ? 30 : 8,
          ),

          bottomRight:
              Radius.circular(
            isMe ? 8 : 30,
          ),
        ),

        child: Stack(

          children: [

            Image.network(

              image,

              width: 260,
              height: 320,

              fit: BoxFit.cover,
            ),

            Positioned(

              bottom: 16,
              right: 16,

              child: Container(

                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),

                decoration:
                    BoxDecoration(

                  borderRadius:
                      BorderRadius
                          .circular(18),

                  color: Colors.black
                      .withOpacity(.35),
                ),

                child: const Row(

                  children: [

                    Icon(

                      Icons.favorite_rounded,

                      color:
                          Colors.white,

                      size: 18,
                    ),

                    SizedBox(width: 8),

                    Text(

                      "2.4k",

                      style: TextStyle(

                        color:
                            Colors.white,

                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}