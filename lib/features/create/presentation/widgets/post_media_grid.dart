import 'package:flutter/material.dart';

class PostMediaGrid
    extends StatelessWidget {

  final List<String> images;

  const PostMediaGrid({
    super.key,
    required this.images,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(

      shrinkWrap: true,

      physics:
          const NeverScrollableScrollPhysics(),

      itemCount: images.length,

      gridDelegate:
          const SliverGridDelegateWithFixedCrossAxisCount(

        crossAxisCount: 2,

        mainAxisSpacing: 16,
        crossAxisSpacing: 16,

        childAspectRatio: .8,
      ),

      itemBuilder: (_, index) {

        return ClipRRect(

          borderRadius:
              BorderRadius.circular(
            30,
          ),

          child: Stack(

            children: [

              Positioned.fill(

                child: Image.network(

                  images[index],

                  fit: BoxFit.cover,
                ),
              ),

              Positioned(

                top: 14,
                right: 14,

                child: Container(

                  width: 42,
                  height: 42,

                  decoration:
                      BoxDecoration(

                    shape:
                        BoxShape.circle,

                    color: Colors.black
                        .withOpacity(.35),
                  ),

                  child: const Icon(

                    Icons.close_rounded,

                    color:
                        Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}