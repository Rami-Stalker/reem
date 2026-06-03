import 'package:flutter/material.dart';

import '../../../design_system/design_system.dart';

class AnimatedSwitchTile
    extends StatefulWidget {
  final String title;

  const AnimatedSwitchTile({
    super.key,
    required this.title,
  });

  @override
  State<AnimatedSwitchTile>
      createState() =>
          _AnimatedSwitchTileState();
}

class _AnimatedSwitchTileState
    extends State<AnimatedSwitchTile> {
  bool enabled = true;

  @override
  Widget build(BuildContext context) {
    return DsGlassCard(
      child: Row(
        children: [

          Expanded(
            child: Text(
              widget.title,

              style: const TextStyle(
                fontSize: 16,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),

          AnimatedContainer(
            duration:
                const Duration(
                    milliseconds: 350),

            width: 60,
            height: 34,

            padding:
                const EdgeInsets.all(4),

            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(
                      30),

              gradient: enabled
                  ? const LinearGradient(
                      colors: [
                        Color(
                            0xffFF9EB5),
                        Color(
                            0xffFF5C8A),
                      ],
                    )
                  : null,

              color: enabled
                  ? null
                  : Colors.grey
                      .withOpacity(.3),
            ),

            child: AnimatedAlign(
              duration:
                  const Duration(
                      milliseconds: 300),

              alignment: enabled
                  ? Alignment.centerRight
                  : Alignment.centerLeft,

              child: GestureDetector(
                onTap: () {
                  setState(() {
                    enabled = !enabled;
                  });
                },

                child: Container(
                  width: 26,
                  height: 26,

                  decoration:
                      const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}