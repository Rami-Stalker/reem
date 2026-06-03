import 'package:flutter/material.dart';

class PostActionBar
    extends StatelessWidget {

  const PostActionBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(

      mainAxisAlignment:
          MainAxisAlignment
              .spaceBetween,

      children: [

        _item(
          Icons.image_rounded,
          "Gallery",
        ),

        _item(
          Icons.camera_alt_rounded,
          "Camera",
        ),

        _item(
          Icons.auto_awesome_rounded,
          "Effects",
        ),

        _item(
          Icons.tag_faces_rounded,
          "Emoji",
        ),
      ],
    );
  }

  Widget _item(
    IconData icon,
    String title,
  ) {
    return Column(

      children: [

        Container(

          width: 70,
          height: 70,

          decoration:
              BoxDecoration(

            shape:
                BoxShape.circle,

            color:
                Colors.white,

            boxShadow: [

              BoxShadow(

                color: Colors.black
                    .withOpacity(.05),

                blurRadius: 18,
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
        ),

        const SizedBox(height: 10),

        Text(

          title,

          style: TextStyle(
            color: Colors.grey[700],
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}