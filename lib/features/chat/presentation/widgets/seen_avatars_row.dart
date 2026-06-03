import 'package:flutter/material.dart';

class SeenAvatarsRow
    extends StatelessWidget {

  const SeenAvatarsRow({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final images = [

      "https://images.unsplash.com/photo-1494790108377-be9c29b29330",

      "https://images.unsplash.com/photo-1524504388940-b1c1722653e1",

      "https://images.unsplash.com/photo-1488426862026-3ee34a7d66df",
    ];

    return Row(

      mainAxisAlignment:
          MainAxisAlignment.end,

      children: [

        SizedBox(

          width: 90,

          child: Stack(

            children: List.generate(
              images.length,
              (index) {

                return Positioned(

                  right:
                      index * 22,

                  child: Container(

                    width: 34,
                    height: 34,

                    decoration:
                        BoxDecoration(

                      shape:
                          BoxShape.circle,

                      border:
                          Border.all(

                        color:
                            Colors.white,

                        width: 2,
                      ),

                      image:
                          DecorationImage(

                        image:
                            NetworkImage(
                          images[index],
                        ),

                        fit:
                            BoxFit.cover,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(width: 10),

        Text(

          "Seen",

          style: TextStyle(

            color:
                Colors.grey[600],

            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}