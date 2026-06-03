import 'package:flutter/material.dart';

class AttachmentSheet
    extends StatelessWidget {

  const AttachmentSheet({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      padding:
          const EdgeInsets.all(
        28,
      ),

      decoration: const BoxDecoration(

        color: Color(0xffFFF8FA),

        borderRadius:
            BorderRadius.vertical(

          top: Radius.circular(38),
        ),
      ),

      child: Column(

        mainAxisSize:
            MainAxisSize.min,

        children: [

          Container(

            width: 70,
            height: 6,

            decoration:
                BoxDecoration(

              borderRadius:
                  BorderRadius
                      .circular(20),

              color:
                  Colors.grey[300],
            ),
          ),

          const SizedBox(height: 32),

          Row(

            mainAxisAlignment:
                MainAxisAlignment
                    .spaceAround,

            children: [

              _item(
                Icons.photo_rounded,
                "Gallery",
              ),

              _item(
                Icons.camera_alt_rounded,
                "Camera",
              ),

              _item(
                Icons.mic_rounded,
                "Voice",
              ),

              _item(
                Icons.location_on_rounded,
                "Location",
              ),
            ],
          ),

          const SizedBox(height: 34),
        ],
      ),
    );
  }

  Widget _item(
    IconData icon,
    String title,
  ) {
    return Column(

      children: [

        Container(

          width: 72,
          height: 72,

          decoration:
              const BoxDecoration(

            shape: BoxShape.circle,

            gradient:
                LinearGradient(

              colors: [

                Color(0xffFF9EB5),
                Color(0xffFF5C8A),
              ],
            ),
          ),

          child: Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
        ),

        const SizedBox(height: 12),

        Text(

          title,

          style: const TextStyle(

            fontWeight:
                FontWeight.bold,
          ),
        ),
      ],
    );
  }
}