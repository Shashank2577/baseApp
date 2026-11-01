import 'package:base_design/base_design.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services.dart';

/// The app's step-by-step log, to copy and paste when something goes wrong.
class LogsPage extends StatelessWidget {
  const LogsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = BaseScope.of(context);
    return ListenableBuilder(
      listenable: s.log,
      builder: (context, _) {
        final lines = s.log.lines;
        return HandPage(
          onBack: () => Navigator.pop(context),
          children: [
            const PageIntro(
              title: 'logs',
              purpose: 'Each step the app took with its models, and anything that failed. Copy it and paste it when you report a problem.',
              mark: 'logs',
              doodle: Doodle.spark,
            ),
            Row(
              children: [
                PillButton('copy all', onPressed: () => _copy(context)),
                const SizedBox(width: 12),
                HandLink('clear', onPressed: s.log.clear),
              ],
            ),
            const SizedBox(height: 12),
            Meta('${lines.length} line${lines.length == 1 ? '' : 's'}, newest last. Kept on this device only.'),
            const HandDivider(),
            if (lines.isEmpty) const Meta('Nothing yet.'),
            for (final line in lines) SelectableText(line, style: context.type.mono),
          ],
        );
      },
    );
  }

  Future<void> _copy(BuildContext context) async {
    final s = BaseScope.of(context);
    final header = '${s.config.name} (${s.config.appId}) on ${defaultTargetPlatform.name}, models in ${s.models.location.path}';
    await Clipboard.setData(ClipboardData(text: s.log.text(header: header)));
    if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(const SnackBar(content: Text('Copied')));
  }
}
