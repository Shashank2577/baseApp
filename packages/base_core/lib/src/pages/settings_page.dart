import 'package:base_design/base_design.dart';
import 'package:flutter/material.dart';

import '../services.dart';
import '../shell.dart';
import 'models_page.dart';
import 'privacy_page.dart';

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
            const SectionHead('light or dark'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
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
            const SizedBox(height: 16),
            const SectionHead('handwriting', note: 'headlines stay hand-lettered'),
            for (final v in Voice.all) _VoiceRow(voice: v, selected: settings.voiceId == v.id),
            const SizedBox(height: 16),
            Door('models', meta: 'on-device AI, shared between apps', onTap: () => pushPage(context, const ModelsPage())),
            Door('privacy', meta: 'what this app did, and switches', onTap: () => pushPage(context, const PrivacyPage())),
            const SizedBox(height: 16),
            Meta('${s.config.name} · ${s.config.appId} · design tokens $tokensVersion'),
          ],
        );
      },
    );
  }
}

/// A handwriting choice that previews itself.
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
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
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
                    Text('Notes, transcripts and summaries read like this.', style: voice.style(15, 21, color: c.ink)),
                    Meta(voice.note),
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
