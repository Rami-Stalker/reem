import 'package:flutter/material.dart';

import 'active_voice_wave.dart';

class VoiceRecordingPanel
    extends StatelessWidget {

  final Duration duration;

  const VoiceRecordingPanel({
    super.key,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(

      margin:
          const EdgeInsets.all(
        18,
      ),

      padding:
          const EdgeInsets.all(
        22,
      ),

      decoration:
          BoxDecoration(

        gradient:
            const LinearGradient(

          colors: [

            Color(0xffFF9EB5),

            Color(0xffFF5C8A),
          ],
        ),

        borderRadius:
            BorderRadius.circular(
          32,
        ),
      ),

      child: Column(

        children: [

          const Text(

            "Recording Voice...",

            style: TextStyle(

              color: Colors.white,

              fontWeight:
                  FontWeight.bold,

              fontSize: 18,
            ),
          ),

          const SizedBox(height: 22),

          const ActiveVoiceWave(),

          const SizedBox(height: 24),

          Text(

            duration
                .toString()
                .split('.')
                .first,

            style: const TextStyle(

              color: Colors.white,

              fontSize: 26,

              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 28),

          Row(

            mainAxisAlignment:
                MainAxisAlignment
                    .spaceEvenly,

            children: [

              _button(
                Icons.delete_rounded,
                Colors.white24,
              ),

              _button(
                Icons.stop_rounded,
                Colors.red,
              ),

              _button(
                Icons.send_rounded,
                Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _button(
    IconData icon,
    Color color,
  ) {
    return Container(

      width: 66,
      height: 66,

      decoration:
          BoxDecoration(

        shape:
            BoxShape.circle,

        color: color,
      ),

      child: Icon(
        icon,
        color: Colors.white,
        size: 30,
      ),
    );
  }
}