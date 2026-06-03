import 'package:flutter/material.dart';

import '../../../../core/design_system/design_system.dart';
import '../../../../core/shared/wedgets/backgrounds/luxury_mesh_background.dart';

import '../widgets/create_header.dart';
import '../widgets/add_media_card.dart';
import '../widgets/post_caption_field.dart';
import '../widgets/audience_selector.dart';

class AddPostScreen
    extends StatelessWidget {

  const AddPostScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: 
      // LuxuryMeshBackground(
      //   child: 
        SafeArea(

          child: SingleChildScrollView(

            padding:
                const EdgeInsets.all(
              22,
            ),

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,

              children: [

                const CreateHeader(

                  title: "Create Post",

                  subtitle:
                      "Design a premium post experience for your customers",
                ),

                const SizedBox(height: 28),

                AddMediaCard(
                  onTap: () {},
                ),

                const SizedBox(height: 26),

                const PostCaptionField(),

                const SizedBox(height: 26),

                const AudienceSelector(),

                const SizedBox(height: 34),

                PrimaryButton(
                  label: 'Publish Post',
                  onPressed: () {},
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      // ),
    );
  }
}