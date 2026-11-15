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
  const MaskPage({super.key});

  @override
  State<MaskPage> createState() => _MaskPageState();
}

class _MaskPageState extends State<MaskPage> {
  final _input = TextEditingController();
  final _reply = TextEditingController();
  MaskSession? _session;
  String? _restored;
  String? _error;
  String? _copied;
  bool _busy = false;
  Timer? _forget;

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
      setState(() => _session = MaskSession('${r['redactedText'] ?? text}', items));
      _forget?.cancel();
      _forget = Timer(const Duration(minutes: 30), () {
        if (mounted) setState(() => _session = null);
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

  @override
  Widget build(BuildContext context) {
    final s = BurrowData.of(context).services;
    final m = _session;
    return HandPage(
      onBack: () => Navigator.of(context).pop(),
      bottom: InkButton('mask', busy: _busy, trailing: Doodle.mask, onPressed: _busy ? null : _mask),
      children: [
        const PageIntro(
          title: 'mask a message.',
          purpose: 'Before text goes into a chatbot, an email or a form, Burrow swaps names, numbers and addresses for placeholders. Paste the reply back and the real details return.',
          mark: 'mask',
          doodle: Doodle.mask,
        ),
        HandField(controller: _input, placeholder: 'paste the text to mask', minHeight: 120, leading: Doodle.pen),
        if (_error != null) ...[const SizedBox(height: 12), DoneNote('Could not mask it: $_error')],
        if (m != null) ...[
          const SizedBox(height: 16),
          SectionHead('masked', note: '${m.items.length} detail${m.items.length == 1 ? '' : 's'} hidden'),
          SelectableText(m.masked, style: context.type.body),
          const SizedBox(height: 8),
          for (final e in m.items.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(e.key, style: context.type.mono),
                  const SizedBox(width: 8),
                  Flexible(child: Meta('stands for something private, kept on this device')),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: PillButton('copy masked text', leading: Doodle.share, onPressed: () => _copy(m.masked, 'masked text')),
          ),
          if (s.ai.isDemo) ...[
            const SizedBox(height: 8),
            const OnDeviceStamp(text: 'demo engine: emails, phone numbers and cards found by pattern, not by Redact'),
          ],
          const HandDivider(seed: 8),
          const SectionHead('the reply'),
          HandField(controller: _reply, placeholder: 'paste the reply that has the placeholders', minHeight: 96, leading: Doodle.bubble),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: PillButton(
              'put the details back',
              leading: Doodle.eye,
              onPressed: () => setState(() => _restored = m.restore(_reply.text)),
            ),
          ),
          if (_restored != null) ...[
            const SizedBox(height: 12),
            SelectableText(_restored!, style: context.type.body),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: PillButton('copy the reply', leading: Doodle.share, onPressed: () => _copy(_restored!, 'reply')),
            ),
          ],
          const SizedBox(height: 12),
          const Meta('Burrow forgets this masked message after 30 minutes, or when you leave this page.'),
        ],
        if (_copied != null) ...[const SizedBox(height: 12), DoneNote('Copied the $_copied.')],
      ],
    );
  }
}
