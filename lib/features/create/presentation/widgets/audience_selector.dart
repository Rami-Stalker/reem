import 'package:flutter/material.dart';

class AudienceSelector
    extends StatefulWidget {

  const AudienceSelector({
    super.key,
  });

  @override
  State<AudienceSelector>
      createState() =>
          _AudienceSelectorState();
}

class _AudienceSelectorState
    extends State<
        AudienceSelector> {

  int selected = 0;

  final items = [
    "Public",
    "Followers",
    "Close Friends",
  ];

  @override
  Widget build(BuildContext context) {
    return Row(

      children: List.generate(
        items.length,
        (index) {

          final active =
              selected == index;

          return Expanded(

            child: GestureDetector(

              onTap: () {

                setState(() {
                  selected = index;
                });
              },

              child: AnimatedContainer(

                duration:
                    const Duration(
                  milliseconds: 350,
                ),

                margin:
                    const EdgeInsets.only(
                  right: 12,
                ),

                padding:
                    const EdgeInsets.symmetric(
                  vertical: 16,
                ),

                decoration:
                    BoxDecoration(

                  borderRadius:
                      BorderRadius
                          .circular(20),

                  gradient: active
                      ? const LinearGradient(
                          colors: [

                            Color(
                                0xffFF9EB5),

                            Color(
                                0xffFF5C8A),
                          ],
                        )
                      : null,

                  color:
                      active
                          ? null
                          : Colors.white,
                ),

                child: Center(

                  child: Text(

                    items[index],

                    style: TextStyle(

                      color: active
                          ? Colors.white
                          : Colors.black,

                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}