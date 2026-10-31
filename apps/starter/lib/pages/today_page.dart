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
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(child: Text(greeting(now), style: context.type.headline.copyWith(fontSize: 44))),
                const SizedBox(width: 10),
                DoodleIcon(day ? Doodle.sun : Doodle.moon, size: 36, color: context.colors.pencil, tilt: -10),
              ],
            ),
            Meta(MaterialLocalizations.of(context).formatFullDate(now)),
            const SizedBox(height: 16),
            if (missing.isNotEmpty)
              Door(
                'get the model',
                mark: 'model',
                meta: '${s.models.spec(missing.first).name}, ${formatBytes(s.models.spec(missing.first).bytes)}',
                leading: const DoodleIcon(Doodle.spark, size: 28),
                onTap: () => pushPage(context, const ModelsPage()),
              )
            else ...[
              const SizedBox(height: 24),
              MarkedText('all quiet.', mark: 'quiet', style: context.type.title),
              const SizedBox(height: 4),
              Meta('${s.models.claimedByThisApp.length} model(s) ready, ${formatBytes(s.models.bytesOnDisk)} shared on this device'),
            ],
            const HandDivider(seed: 4),
            Door(
              'models',
              meta: s.models.location.description,
              leading: const DoodleIcon(Doodle.spark, size: 28),
              onTap: () => pushPage(context, const ModelsPage()),
            ),
            Door(
              'privacy',
              meta: '${formatBytes(s.ledger.bytesDownloaded)} downloaded, nothing uploaded',
              leading: const DoodleIcon(Doodle.lock, size: 28),
              onTap: () => pushPage(context, const PrivacyPage()),
            ),
          ],
        );
      },
    );
  }
}
