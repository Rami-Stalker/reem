import 'package:flutter/material.dart';

import '../../../../core/shared/wedgets/backgrounds/luxury_mesh_background.dart';

import '../widgets/create_header.dart';
import '../widgets/add_media_card.dart';
import '../widgets/story_preview.dart';
import '../widgets/audience_selector.dart';

class AddStoryScreen
    extends StatelessWidget {

  const AddStoryScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: 
      // LuxuryMeshBackground(

      //   child: 
        SafeArea(

          child: Padding(

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

                  title: "Create Story",

                  subtitle:
                      "Share beautiful luxury moments with your audience",
                ),

                const SizedBox(height: 28),

                Expanded(

                  child: Row(

                    children: [

                      Expanded(

                        flex: 3,

                        child: AddMediaCard(

                          isStory: true,

                          onTap: () {},
                        ),
                      ),

                      const SizedBox(width: 20),

                      const Expanded(

                        flex: 2,

                        child: StoryPreview(

                          image:
                              "https://images.unsplash.com/photo-1524504388940-b1c1722653e1",
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                const AudienceSelector(),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ));
    //   ),
    // );
  }
}