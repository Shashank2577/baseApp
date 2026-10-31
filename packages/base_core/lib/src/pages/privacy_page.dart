import 'package:base_design/base_design.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../ledger.dart';
import '../services.dart';
import '../shell.dart';
import 'models_page.dart';

/// Privacy you can check: what the app did, what it downloaded, and switches
/// that are enforced in code.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = BaseScope.of(context);
    final entries = [...s.config.ledgerEntries, LedgerEntry.modelsDownloaded, LedgerEntry.modelsShared];
    return ListenableBuilder(
      listenable: Listenable.merge([s.ledger, s.settings]),
      builder: (context, _) {
        final today = s.ledger.summary(entries);
        final total = s.ledger.summary(entries, totals: true);
        final c = context.colors;
        return HandPage(
          onBack: () => Navigator.pop(context),
          children: [
            MarkedText(
              'nothing of yours left this device.',
              mark: 'nothing',
              style: context.type.headline.copyWith(fontSize: 42, height: 44 / 42),
            ),
            const SizedBox(height: 8),
            Body(
              '${formatBytes(s.ledger.bytesDownloaded)} downloaded, all of it AI models. ${s.config.name} has no account, no analytics and no upload code.',
              color: c.pencil,
            ),
            const SizedBox(height: 16),
            const SectionHead('today'),
            if (today.isEmpty) const Meta('nothing yet today'),
            for (final line in today) Body(line),
            const SizedBox(height: 8),
            SectionHead('since you set ${s.config.name} up'),
            if (total.isEmpty) const Meta('nothing yet'),
            for (final line in total) Body(line),
            const SizedBox(height: 16),
            SwitchRow(
              title: 'never go online',
              body: 'Models you have stay usable. Nothing new is downloaded until you turn this off.',
              doodle: Doodle.cloudOff,
              value: s.settings.neverOnline,
              onChanged: (v) => s.settings.update((x) => x.neverOnline = v),
            ),
            Door('models', meta: 'what is on this device, and who shares it', onTap: () => pushPage(context, const ModelsPage())),
            if (s.ledger.events.isNotEmpty) ...[
              const SectionHead('recently'),
              for (final e in s.ledger.events.take(8))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      DoodleIcon(e.network ? Doodle.arrow : Doodle.tick, size: 16, color: c.pencil),
                      const SizedBox(width: 8),
                      Expanded(child: Meta(e.detail)),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Center(
              child: HandLink(
                'wipe everything',
                color: c.redPen,
                onPressed: () async {
                  final ok = await confirmSheet(
                    context,
                    title: 'wipe everything?',
                    body:
                        '${s.config.name} forgets its settings, its history and this list. Models other apps still use stay on the device; the rest are deleted.',
                    confirm: 'wipe everything',
                    danger: true,
                  );
                  if (ok) {
                    await s.wipe();
                    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
