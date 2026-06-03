import 'package:flutter/material.dart';

class ChatDateDivider
    extends StatelessWidget {

  final String title;

  const ChatDateDivider({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Row(

      children: [

        Expanded(

          child: Divider(
            color:
                Colors.grey
                    .withOpacity(.3),
          ),
        ),

        Padding(

          padding:
              const EdgeInsets.symmetric(
            horizontal: 18,
          ),

          child: Text(

            title,

            style: TextStyle(

              color:
                  Colors.grey[600],

              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        Expanded(

          child: Divider(
            color:
                Colors.grey
                    .withOpacity(.3),
          ),
        ),
      ],
    );
  }
}