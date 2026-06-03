import 'package:flutter/material.dart';
import 'package:reem/core/design_system/design_system.dart';

class UploadProgress
    extends StatelessWidget {

  final double progress;

  const UploadProgress({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      padding:
          const EdgeInsets.all(24),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
            BorderRadius.circular(
          DsRadius.xl,
        ),

        boxShadow:
            DsShadows
                .glow(  DsColors.primary600),
      ),

      child: Column(

        crossAxisAlignment:
            CrossAxisAlignment
                .start,

        children: [

          Row(

            children: [

              const Icon(

                Icons.cloud_upload_rounded,

                color:
                    DsColors.primary100,
              ),

              const SizedBox(width: 12),

              Text(

                "Uploading Media",

                // style:
                //     DsTypography
                //         .titleMedium,
              ),
            ],
          ),

          const SizedBox(height: 24),

          ClipRRect(

            borderRadius:
                BorderRadius.circular(
              20,
            ),

            child:
                LinearProgressIndicator(

              value: progress,

              minHeight: 12,

              backgroundColor:
                  DsColors
                      .primary100
                      .withOpacity(.1),

              valueColor:
                  const AlwaysStoppedAnimation(
                DsColors.primary100,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(

            "${(progress * 100).toInt()}% completed",

            // style:
            //     DsTypography
            //         .bodyMedium
            //         .copyWith(

            //   color:
            //       DsColors
            //           .textSecondary,
            // ),
          ),
        ],
      ),
    );
  }
}