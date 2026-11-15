import 'package:base_design/base_design.dart';
import 'package:flutter/material.dart';

import '../services.dart';
import '../shell.dart';
import 'models_page.dart';
import 'privacy_page.dart';
import 'logs_page.dart';

/// Appearance (light or dark, handwriting) and the doors to models and privacy.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = BaseScope.of(context);
    return ListenableBuilder(
      listenable: s.settings,
      builder: (context, _) {
        final settings = s.settings;
        return HandPage(
          onBack: () => Navigator.pop(context),
          children: [
            PageIntro(title: 'settings', purpose: 'How ${s.config.name} looks and reads. Saved on this device.', doodle: Doodle.gear),
            const SectionHead('light or dark', first: true),
            Wrap(
              spacing: SpaceTokens.s,
              runSpacing: SpaceTokens.s,
              children: [
                for (final (mode, label, doodle) in [
                  (ThemeMode.system, 'like the device', Doodle.phone),
                  (ThemeMode.light, 'light', Doodle.sun),
                  (ThemeMode.dark, 'dark', Doodle.moon),
                ])
                  ChoicePill(
                    label,
                    leading: doodle,
                    selected: settings.themeMode == mode,
                    onPressed: () => settings.update((x) => x.themeMode = mode),
                  ),
              ],
            ),
            SectionHead(
              'writing',
              note: settings.voice.isHand
                  ? 'Everything is handwritten: what you read, names and tags too.'
                  : 'What you read is plain type. Headings and buttons stay hand-lettered.',
            ),
            Wrap(
              spacing: SpaceTokens.s,
              runSpacing: SpaceTokens.s,
              children: [
                for (final (hand, label) in [(true, 'handwritten'), (false, 'formal')])
                  ChoicePill(
                    label,
                    selected: settings.voice.isHand == hand,
                    // Keeps the voice when the style is already this one.
                    onPressed: () => settings.voice.isHand == hand
                        ? null
                        : settings.update((x) => x.voiceId = Voice.ofStyle(hand: hand).first.id),
                  ),
              ],
            ),
            const SizedBox(height: SpaceTokens.s),
            for (final v in Voice.ofStyle(hand: settings.voice.isHand)) _VoiceRow(voice: v, selected: settings.voiceId == v.id),
            const SectionHead('more'),
            Door('models', meta: 'On-device AI, shared between apps', onTap: () => pushPage(context, const ModelsPage())),
            Door('privacy', meta: 'What this app did, and switches', onTap: () => pushPage(context, const PrivacyPage())),
            Door('logs', meta: 'Each step, to copy when something fails', onTap: () => pushPage(context, const LogsPage())),
            const SizedBox(height: SpaceTokens.l),
            Text('${s.config.name} · ${s.config.appId} · design tokens $tokensVersion', style: context.type.caption),
          ],
        );
      },
    );
  }
}

/// A reading voice that previews itself in its own face.
class _VoiceRow extends StatelessWidget {
  const _VoiceRow({required this.voice, required this.selected});
  final Voice voice;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = BaseScope.of(context);
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(RadiusTokens.row + 2),
        onTap: () => s.settings.update((x) => x.voiceId = voice.id),
        child: Container(
          decoration: BoxDecoration(color: selected ? c.smudge : null, borderRadius: BorderRadius.circular(RadiusTokens.row + 2)),
          constraints: const BoxConstraints(minHeight: SizeTokens.row),
          padding: const EdgeInsets.symmetric(horizontal: SpaceTokens.sm, vertical: SpaceTokens.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 3),
                decoration: ShapeDecoration(
                  shape: CircleBorder(side: BorderSide(color: c.ink, width: 1.8)),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: c.ink, shape: BoxShape.circle),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(voice.label, style: context.type.label),
                    Text('Notes, transcripts and summaries read like this.', style: voice.of(BodyTypeTokens.body, color: c.ink)),
                    Text(voice.note, style: voice.of(BodyTypeTokens.caption, color: c.pencil)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
