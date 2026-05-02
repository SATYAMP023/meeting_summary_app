import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioService {
  final recorder = AudioRecorder();

  Stream<Amplitude>? amplitudeStream;

  Future<String?> startRecording() async {
    if (await recorder.hasPermission()) {
      final dir = await getApplicationDocumentsDirectory();

      // ✅ FIX: correct extension
      final path =
          "${dir.path}/recording_${DateTime.now().millisecondsSinceEpoch}.wav";

      await recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav, // ✅ WAV
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      amplitudeStream =
          recorder.onAmplitudeChanged(const Duration(milliseconds: 80));

      return path;
    } else {
      return null;
    }
  }

  Future<String?> stopRecording() async {
    final path = await recorder.stop();
    return path;
  }
}