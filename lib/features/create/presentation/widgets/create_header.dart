import 'package:flutter/material.dart';
import 'package:ohara/core/design_system/design_system.dart';


class CreateHeader
    extends StatelessWidget {

  final String title;
  final String subtitle;

  const CreateHeader({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(

      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [

        Text(
          title,

          style:
             context.dsText.sectionTitle,
        ),

        DsGaps.vSm,

        Text(

          subtitle,

          // style:
          //     DsTypography
          //         .bodyMedium
          //         .copyWith(

          //   color:
          //       DsColors
          //           .textSecondary,

          //   height: 1.8,
          // ),
        ),
      ],
    );
  }
}