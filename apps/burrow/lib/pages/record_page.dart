import 'dart:async';

import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

import '../data/burrow_data.dart';
import '../logic/audio_io.dart';
import '../logic/processor.dart';

/// The recorder: one big stop, a clock, and the level. Stopping saves the talk
/// and starts writing its notes. Returns the new talk.
class RecordPage extends StatefulWidget {
  const RecordPage({super.key});

  @override
  State<RecordPage> createState() => _RecordPageState();
}

enum _State { asking, denied, recording, paused, saving }

class _RecordPageState extends State<RecordPage> {
  final TalkRecorder _rec = AudioIo.recorder();
  _State _state = _State.asking;
  final _clock = Stopwatch();
  Timer? _tick;
  double _level = 0;
  StreamSubscription<double>? _levels;
  String? _id;
  String? _path;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final data = BurrowData.of(context);
    try {
      if (!await _rec.hasPermission()) {
        setState(() => _state = _State.denied);
        return;
      }
      _id = newTalkId();
      _path = data.newAudioPath(_id!, 'wav');
      if (_path == null) throw StateError('This device has no folder for recordings.');
      // Recording can run long: keep the app awake meanwhile.
      await KeepAwake.begin('record', 'recording a talk');
      await _rec.start(_path!);
      _levels = _rec.levels().listen((v) => setState(() => _level = v));
      _clock.start();
      _tick = Timer.periodic(const Duration(milliseconds: 500), (_) => setState(() {}));
      setState(() => _state = _State.recording);
    } on Object catch (e) {
      setState(() {
        _state = _State.denied;
        _error = '$e';
      });
    }
  }

  Future<void> _pause() async {
    if (_state == _State.recording) {
      await _rec.pause();
      _clock.stop();
      setState(() => _state = _State.paused);
    } else {
      await _rec.resume();
      _clock.start();
      setState(() => _state = _State.recording);
    }
  }

  Future<void> _stop() async {
    final data = BurrowData.of(context);
    setState(() => _state = _State.saving);
    _clock.stop();
    final path = await _rec.stop() ?? _path;
    await KeepAwake.end('record');
    final t = await data.addTalk(id: _id!, audioPath: path, imported: false, durationSec: _clock.elapsedMilliseconds / 1000);
    unawaited(TalkProcessor(data).process(t));
    if (mounted) Navigator.of(context).pop(t);
  }

  Future<void> _discard() async {
    if (_state == _State.recording || _state == _State.paused) {
      final ok = await confirmSheet(
        context,
        title: 'throw this recording away?',
        body: 'Nothing has been saved yet. The audio is deleted from this device.',
        confirm: 'throw it away',
        danger: true,
        cancel: 'keep recording',
      );
      if (!ok) return;
      await _rec.cancel();
      await KeepAwake.end('record');
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _levels?.cancel();
    _rec.dispose();
    super.dispose();
  }

  String get _time {
    final s = _clock.elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final live = _state == _State.recording || _state == _State.paused;
    return PopScope(
      canPop: !live,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _discard();
      },
      child: HandPage(
        onBack: _discard,
        bottom: InkButton(
          _state == _State.saving ? 'saving' : 'stop and write the notes',
          busy: _state == _State.saving,
          trailing: Doodle.stop,
          onPressed: live ? _stop : null,
        ),
        children: [
          const PageIntro(
            title: 'recording',
            purpose: 'Burrow is listening. The audio is saved on this device and nowhere else.',
            doodle: Doodle.mic,
          ),
          if (_state == _State.denied) ...[
            DoneNote(
              _error ?? 'Burrow may not use the microphone. Allow it in the system settings, then try again.',
              action: 'try again',
              onAction: () {
                setState(() {
                  _state = _State.asking;
                  _error = null;
                });
                _start();
              },
            ),
          ] else ...[
            const SizedBox(height: 24),
            Center(child: Text(_time, style: context.type.display)),
            const SizedBox(height: 8),
            Center(child: Meta(_state == _State.paused ? 'paused' : (_state == _State.recording ? 'recording' : 'starting'))),
            const SizedBox(height: 24),
            HandProgress(fraction: live ? _level : 0),
            const SizedBox(height: 24),
            Center(
              child: PillButton(
                _state == _State.paused ? 'go on' : 'pause',
                leading: _state == _State.paused ? Doodle.play : Doodle.pause,
                onPressed: live ? _pause : null,
              ),
            ),
            const SizedBox(height: 16),
            Meta(
              'On iPhone and Mac the recording goes on with the screen locked or Burrow in the background. On Android, keep Burrow open.',
              color: c.pencil,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}
