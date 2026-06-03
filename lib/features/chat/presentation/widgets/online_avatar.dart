import 'package:flutter/material.dart';

class OnlineAvatar
    extends StatelessWidget {

  final String image;

  final bool online;

  const OnlineAvatar({
    super.key,
    required this.image,
    this.online = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(

      children: [

        Container(

          padding:
              const EdgeInsets.all(3),

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

          child: CircleAvatar(

            radius: 34,

            backgroundImage:
                NetworkImage(image),
          ),
        ),

        if (online)

          Positioned(

            right: 2,
            bottom: 4,

            child: Container(

              width: 18,
              height: 18,

              decoration:
                  BoxDecoration(

                shape:
                    BoxShape.circle,

                color: Colors.green,

                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
              ),
            ),
          ),
      ],
    );
  }
}