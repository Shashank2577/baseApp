import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:record/record.dart';

/// The microphone, behind an interface so tests can stand in for it.
abstract class TalkRecorder {
  Future<bool> hasPermission();

  /// Starts writing a 16 kHz mono WAV file at [path] (what the speech models read best).
  Future<void> start(String path);
  Future<void> pause();
  Future<void> resume();

  /// Stops and returns the file's path.
  Future<String?> stop();
  Future<void> cancel();

  /// Loudness 0..1, a few times a second, while recording.
  Stream<double> levels();
  void dispose();
}

/// Lets the user pick an audio file to import; null when they cancel.
typedef AudioPicker = Future<String?> Function();

/// What the app uses for the microphone and file picking. Tests replace these.
abstract final class AudioIo {
  static TalkRecorder Function() recorder = PluginRecorder.new;
  static AudioPicker pickAudio = _pick;

  static Future<String?> _pick() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    return files.isEmpty ? null : files.first.path;
  }
}

/// [TalkRecorder] on the `record` plugin (Android, iOS, macOS, Windows, Linux).
class PluginRecorder implements TalkRecorder {
  final _r = AudioRecorder();

  @override
  Future<bool> hasPermission() => _r.hasPermission();

  @override
  Future<void> start(String path) =>
      _r.start(const RecordConfig(encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1), path: path);

  @override
  Future<void> pause() => _r.pause();

  @override
  Future<void> resume() => _r.resume();

  @override
  Future<String?> stop() => _r.stop();

  @override
  Future<void> cancel() => _r.cancel();

  @override
  Stream<double> levels() => _r
      .onAmplitudeChanged(const Duration(milliseconds: 200))
      .map((a) => ((a.current + 50) / 50).clamp(0.0, 1.0).toDouble());

  @override
  void dispose() => unawaited(_r.dispose());
}
