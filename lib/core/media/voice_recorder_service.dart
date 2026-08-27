import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records a voice note to a file the upload can send.
///
/// AAC in an M4A container, deliberately: it is what both phone platforms
/// encode to natively, it is what the server's sniffer recognises as
/// `audio/mp4`, and at 32 kbps mono a minute of speech is about a quarter of a
/// megabyte — which matters more here than fidelity, because the recording has
/// to cross a Syrian mobile uplink before anyone hears it.
class VoiceRecorderService {
  VoiceRecorderService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;

  /// The longest note the composer will take. Past this it stops itself: a
  /// recording left running in a pocket is a large upload and a message nobody
  /// wanted to send.
  static const maxDuration = Duration(minutes: 3);

  Future<bool> hasPermission() => _recorder.hasPermission();

  /// Loudness, for drawing something that moves while she speaks. Amplitude
  /// arrives in dBFS — negative, zero being the loudest — and is normalised
  /// here so the widget never has to know that.
  Stream<double> get levels => _recorder
      .onAmplitudeChanged(const Duration(milliseconds: 120))
      .map((amplitude) => ((amplitude.current + 45) / 45).clamp(0.0, 1.0));

  Future<void> start() async {
    final directory = await getTemporaryDirectory();
    final path =
        '${directory.path}/voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 32000,
        sampleRate: 44100,
        numChannels: 1,
      ),
      path: path,
    );
  }

  /// Stops and returns the file's path, or null if nothing was captured.
  Future<String?> stop() => _recorder.stop();

  /// Stops and throws the recording away. Distinct from [stop] because a
  /// cancelled note must leave no file behind for the sweeper to wonder about.
  Future<void> cancel() async {
    await _recorder.cancel();
  }

  Future<void> dispose() => _recorder.dispose();
}

final voiceRecorderServiceProvider = Provider<VoiceRecorderService>((ref) {
  final service = VoiceRecorderService();
  ref.onDispose(service.dispose);
  return service;
});
