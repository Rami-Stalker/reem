import 'package:flutter/material.dart';

class EncryptedChatBanner
    extends StatelessWidget {

  const EncryptedChatBanner({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Center(

      child: Container(

        margin:
            const EdgeInsets.symmetric(
          vertical: 18,
        ),

        padding:
            const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),

        decoration:
            BoxDecoration(

          color: const Color(
            0xffE9FFF3,
          ),

          borderRadius:
              BorderRadius.circular(
            18,
          ),
        ),

        child: const Row(

          mainAxisSize:
              MainAxisSize.min,

          children: [

            Icon(

              Icons.lock_rounded,

              color:
                  Colors.green,
            ),

            SizedBox(width: 10),

            Text(

              "End-to-end encrypted",

              style: TextStyle(

                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}