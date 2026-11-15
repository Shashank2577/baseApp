import 'package:base_core/base_core.dart';
import 'package:flutter/material.dart';

/// Home: only what needs you right now.
class TodayPage extends StatelessWidget {
  const TodayPage(BuildContext context, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = BaseScope.of(context);
    final now = DateTime.now();
    final day = now.hour >= 6 && now.hour < 18;
    return ListenableBuilder(
      listenable: s.models,
      builder: (context, _) {
        final missing = s.config.requiredModels.where((id) => !s.models.isReady(id)).toList();
        return HandPage(
          wordmark: s.config.wordmark,
          actions: const [ShellActions()],
          children: [
            const SizedBox(height: SpaceTokens.m),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: Text(greeting(now), style: context.type.headline)),
                const SizedBox(width: SpaceTokens.sm),
                DoodleIcon(day ? Doodle.sun : Doodle.moon, size: 32, color: context.colors.pencil, tilt: -10),
              ],
            ),
            Text(MaterialLocalizations.of(context).formatFullDate(now), style: context.type.caption),
            if (missing.isNotEmpty) ...[
              const SectionHead('needs you'),
              for (final id in missing)
                ItemRow(
                  s.models.spec(id).name,
                  aside: formatBytes(s.models.spec(id).bytes),
                  meta: 'Not on this device yet. ${s.config.name} needs it.',
                  doodle: Doodle.spark,
                  onTap: () => pushPage(context, const ModelsPage()),
                ),
            ] else ...[
              const SizedBox(height: SpaceTokens.xl),
              MarkedText('all quiet.', mark: 'quiet', style: context.type.title),
              const SizedBox(height: SpaceTokens.xs),
              Body(_ready(s)),
            ],
            const SizedBox(height: SpaceTokens.l),
            const HandDivider(seed: 4),
            Door(
              'models',
              meta: s.models.location.description,
              leading: const DoodleIcon(Doodle.spark, size: SizeTokens.icon),
              onTap: () => pushPage(context, const ModelsPage()),
            ),
            Door(
              'privacy',
              meta: '${formatBytes(s.ledger.bytesDownloaded)} downloaded, nothing uploaded',
              leading: const DoodleIcon(Doodle.lock, size: SizeTokens.icon),
              onTap: () => pushPage(context, const PrivacyPage()),
            ),
          ],
        );
      },
    );
  }
}

String _ready(BaseServices s) {
  final n = s.models.claimedByThisApp.where(s.models.isReady).length;
  return '${n == 0 ? 'No models' : n == 1 ? '1 model' : '$n models'} ready here, ${formatBytes(s.models.bytesOnDisk)} shared on this device.';
}
