import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';


class PublishFab
    extends StatelessWidget {

  final VoidCallback onTap;

  const PublishFab({
    super.key,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(

      onTap: onTap,

      child: Container(

        width: 84,
        height: 84,

        decoration: BoxDecoration(

          shape: BoxShape.circle,

          gradient:
              DsGradients.primary,

          boxShadow: [

            BoxShadow(

              color: Colors.pink
                  .withOpacity(.35),

              blurRadius: 28,

              spreadRadius: 2,
            ),
          ],
        ),

        child: const Icon(

          Icons.send_rounded,

          color: Colors.white,

          size: 34,
        ),
      ),
    );
  }
}