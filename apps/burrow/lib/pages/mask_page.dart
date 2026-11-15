import 'dart:async';

import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_config.dart';
import '../data/burrow_data.dart';

/// One masked message: the placeholders and what they stand for. Held in
/// memory only, and forgotten after 30 minutes.
class MaskSession {
  MaskSession(this.masked, this.items);
  final String masked;

  /// placeholder → original ("[EMAIL_1]" → "bob@acme.com").
  final Map<String, String> items;

  /// Puts the real details back in [reply].
  String restore(String reply) {
    var out = reply;
    // Longest first, so [NAME_10] is not caught by [NAME_1].
    final keys = items.keys.toList()..sort((a, b) => b.length.compareTo(a.length));
    for (final k in keys) {
      out = out.replaceAll(k, items[k]!);
    }
    return out;
  }
}

/// Mask: swap personal details for placeholders before text goes to an AI or
/// a form, then put them back in the reply. Redact runs on this device.
class MaskPage extends StatefulWidget {
  const MaskPage({super.key, this.initial});

  /// Text to start with ("mask before sharing" a talk's notes).
  final String? initial;

  @override
  State<MaskPage> createState() => _MaskPageState();
}

class _MaskPageState extends State<MaskPage> {
  late final _input = TextEditingController(text: widget.initial);
  final _reply = TextEditingController();
  MaskSession? _session;
  String? _restored;
  String? _error;
  String? _copied;
  bool _busy = false;
  Timer? _forget;

  /// 0 paste, 1 copy the masked text, 2 bring the reply back.
  int _stage = 0;

  @override
  void dispose() {
    _forget?.cancel();
    _input.dispose();
    _reply.dispose();
    super.dispose();
  }

  Future<void> _mask() async {
    final data = BurrowData.of(context);
    final s = data.services;
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
      _restored = null;
      _copied = null;
    });
    try {
      if (!s.ai.isDemo && !s.models.isReady(AppModels.redact)) await s.ensureModel(AppModels.redact);
      final r = await s.ai.specialists.run(AppModels.redact, 'redact', {'text': text});
      if (r['error'] != null) throw StateError('${r['error']}');
      final items = <String, String>{
        for (final i in (r['items'] as List? ?? const []).cast<Map>()) '${i['placeholder']}': '${i['original']}',
      };
      s.ledger.add(AppLedger.masked);
      setState(() {
        _session = MaskSession('${r['redactedText'] ?? text}', items);
        _stage = 1;
      });
      _forget?.cancel();
      _forget = Timer(const Duration(minutes: 30), () {
        if (mounted) {
          setState(() {
            _session = null;
            _stage = 0;
          });
        }
      });
    } on OfflineException catch (e) {
      setState(() => _error = '${e.modelName} is not on this device and "never go online" is on.');
    } on Object catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String text, String what) async {
    await Clipboard.setData(ClipboardData(text: text));
    setState(() => _copied = what);
  }

  Widget get _ink => switch (_stage) {
    0 => InkButton('mask', busy: _busy, trailing: Doodle.mask, onPressed: _busy ? null : _mask),
    1 => InkButton('copy masked text', trailing: Doodle.share, onPressed: () async {
      await _copy(_session!.masked, 'masked text');
      setState(() => _stage = 2);
    }),
    _ => _restored == null
        ? InkButton('put the details back', trailing: Doodle.eye, onPressed: () => setState(() => _restored = _session!.restore(_reply.text)))
        : InkButton('copy the reply', trailing: Doodle.share, onPressed: () => _copy(_restored!, 'reply')),
  };

  @override
  Widget build(BuildContext context) {
    final s = BurrowData.of(context).services;
    final m = _session;
    return HandPage(
      onBack: () => Navigator.of(context).pop(),
      bottom: _ink,
      children: [
        const PageIntro(
          title: 'mask a message',
          purpose: 'Before text goes into a chatbot, an email or a form, Burrow swaps names, numbers and addresses for placeholders. Paste the reply back and the real details return.',
          doodle: Doodle.mask,
        ),
        StepHead(1, 'paste', done: _stage > 0),
        if (_stage == 0) ...[
          const SizedBox(height: 8),
          HandField(controller: _input, placeholder: 'Paste the text to mask', minHeight: 120, leading: Doodle.pen),
          if (_error != null) ...[const SizedBox(height: 12), DoneNote('Could not mask it: $_error')],
        ],
        const SizedBox(height: 16),
        StepHead(2, 'copy the safe version', done: _stage > 1),
        if (_stage == 1 && m != null) ...[
          const SizedBox(height: 8),
          MarkedText('${m.items.length} hidden', mark: '${m.items.length}', style: context.type.title),
          const SizedBox(height: 8),
          SelectableText(m.masked, style: context.type.body),
          const SizedBox(height: 8),
          for (final k in m.items.keys)
            Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(k, style: context.type.mono)),
          if (s.ai.isDemo) ...[
            const SizedBox(height: 8),
            const OnDeviceStamp(text: 'demo engine: emails, phone numbers and cards found by pattern, not by Redact'),
          ],
          const SizedBox(height: 8),
          HandLink('start again', onPressed: () => setState(() => _stage = 0)),
        ],
        const SizedBox(height: 16),
        StepHead(3, 'bring the reply back', done: _restored != null),
        if (_stage == 2 && m != null) ...[
          const SizedBox(height: 8),
          HandField(controller: _reply, placeholder: 'Paste the reply that has the placeholders', minHeight: 96, leading: Doodle.bubble),
          if (_restored != null) ...[
            const SizedBox(height: 12),
            SelectableText(_restored!, style: context.type.body),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: [
              HandLink('copy the masked text again', onPressed: () => _copy(m.masked, 'masked text')),
              if (_restored != null) HandLink('restore another reply', onPressed: () => setState(() => _restored = null)),
            ],
          ),
        ],
        const SizedBox(height: 16),
        const Meta('The placeholders and what they stand for stay in memory on this device, and are forgotten after 30 minutes or when you leave this page.'),
        if (_copied != null) ...[const SizedBox(height: 12), DoneNote('Copied the $_copied.')],
      ],
    );
  }
}
