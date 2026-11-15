import 'package:flutter/foundation.dart';
import 'package:base_design/base_design.dart';
import 'package:base_models/base_models.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../services.dart';

/// The models this app uses, where they live, and which other apps share them.
class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

  /// More missing than this, and one "download all" pill replaces the per-row pills.
  static const _manyMissing = 3;

  @override
  Widget build(BuildContext context) {
    final s = BaseScope.of(context);
    return ListenableBuilder(
      listenable: s.models,
      builder: (context, _) {
        final store = s.models;
        final mine = s.config.allModels.where((id) => store.catalog.byId(id) != null).toList();
        final others = [
          for (final m in store.catalog.all)
            if (store.isReady(m.id) && !mine.contains(m.id)) m,
        ];
        final missing = [for (final id in mine) if (_downloadable(s, store.spec(id))) id];
        final many = missing.length > _manyMissing;
        final missingBytes = missing.fold<int>(0, (sum, id) => sum + store.spec(id).bytes);
        final here = formatBytes(store.bytesOnDisk);
        return HandPage(
          onBack: () => Navigator.pop(context),
          children: [
            PageIntro(
              title: 'models',
              purpose:
                  'The AI models ${s.config.name} uses. They stay on this device and are shared with your other ${PlatformConfig.vendorName} apps, so each one is downloaded once.',
              doodle: Doodle.spark,
            ),
            MarkedText('$here on this device, for every app together.', mark: here, style: context.type.body),
            const SizedBox(height: SpaceTokens.xs),
            Meta('Kept in ${store.location.description}.'),
            if (s.ai.isDemo) const Meta('This build runs the demo engine: answers are scripted and labelled as a demo.'),
            const SectionHead('this app uses'),
            if (many)
              Padding(
                padding: const EdgeInsets.only(bottom: SpaceTokens.s),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: PillButton(
                    'download all (${formatBytes(missingBytes)})',
                    leading: Doodle.arrow,
                    onPressed: () => _ModelRow.run(context, () async {
                      for (final id in missing) {
                        await s.ensureModel(id);
                      }
                    }),
                  ),
                ),
              ),
            if (mine.isEmpty) const Meta('No models yet.'),
            for (final id in mine) _ModelRow(spec: store.spec(id), required: s.config.requiredModels.contains(id), compact: many),
            const SectionHead('gated models'),
            const Body('Some models, such as Gemma, need their licence accepted on huggingface.co first. Paste your access token here; it is only sent to huggingface.co.'),
            const SizedBox(height: SpaceTokens.sm),
            const _TokenField(),
            if (others.isNotEmpty) ...[
              const SectionHead('already here, from other apps', note: 'Free to use: no download.'),
              for (final m in others) _ModelRow(spec: m, required: false),
            ],
          ],
        );
      },
    );
  }

  static bool _downloadable(BaseServices s, ModelSpec spec) {
    final state = s.models.stateOf(spec.id);
    if (spec.source == ModelSource.sdk && s.ai.isDemo) return false;
    return (state.status == ModelStatus.absent || state.status == ModelStatus.failed) && !state.inSibling;
  }
}

String _sentence(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.spec, required this.required, this.compact = false});
  final ModelSpec spec;
  final bool required;

  /// Many rows need a download: each offers a link, not a pill.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = BaseScope.of(context);
    final state = s.models.stateOf(spec.id);
    final c = context.colors;
    final t = context.type;
    final others = state.users.where((u) => u != s.config.appId).length;
    final usedBy = state.users.contains(s.config.appId);
    final facts = _sentence([spec.role, if (required) 'needed'].join(' · '));

    Widget get(String label) => compact
        ? HandLink(label, onPressed: () => run(context, () => s.ensureModel(spec.id)))
        : PillButton(label, leading: Doodle.arrow, onPressed: () => run(context, () => s.ensureModel(spec.id)));

    Widget line(String text, Widget? action) => Row(
      children: [
        Expanded(child: Text(text, style: t.caption)),
        if (action != null) ...[const SizedBox(width: SpaceTokens.sm), action],
      ],
    );

    Widget stateLine;
    switch (state.status) {
      case ModelStatus.downloading:
        stateLine = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            HandProgress(fraction: state.busyElsewhere ? null : state.progress),
            line(
              state.busyElsewhere
                  ? 'Another app is downloading this; it will be ready here too.'
                  : 'Downloading, ${(state.progress * 100).round()}%',
              HandLink('cancel', onPressed: () => s.models.cancel(spec.id)),
            ),
          ],
        );
      case ModelStatus.ready:
        final where = others > 0 ? 'On this device · shared with $others other app${others == 1 ? '' : 's'}' : 'On this device';
        stateLine = usedBy
            ? line(where, HandLink('remove', onPressed: () => _remove(context)))
            : Align(alignment: Alignment.centerLeft, child: PillButton('use', onPressed: () => run(context, () => s.ensureModel(spec.id))));
      case ModelStatus.absent || ModelStatus.failed when spec.source == ModelSource.sdk && s.ai.isDemo:
        // SDK models install through the native engine; the demo build has none.
        stateLine = line('Needs the on-device engine, which this build does not have.', null);
      case ModelStatus.absent when state.inSibling:
        // Another app on this phone has it: using it copies the files, no download.
        stateLine = Align(
          alignment: Alignment.centerLeft,
          child: compact
              ? HandLink('use, no download', onPressed: () => run(context, () => s.ensureModel(spec.id)))
              : PillButton('use, no download', onPressed: () => run(context, () => s.ensureModel(spec.id))),
        );
      case ModelStatus.absent:
      case ModelStatus.failed:
        stateLine = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.status == ModelStatus.failed && state.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: SpaceTokens.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DoodleIcon(Doodle.exclaim, size: SizeTokens.iconSmall, color: c.redPen, stroke: 2.6),
                    const SizedBox(width: SpaceTokens.xs),
                    Expanded(child: Text(state.error!, style: t.meta.copyWith(color: c.ink))),
                  ],
                ),
              ),
            get(state.status == ModelStatus.failed ? 'try again' : 'download'),
          ],
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ItemRow(spec.name, aside: formatBytes(spec.bytes), meta: spec.summary, caption: facts, below: stateLine),
        const HandDivider(),
      ],
    );
  }

  static Future<void> run(BuildContext context, Future<void> Function() job) async {
    try {
      await job();
    } on DownloadCancelled {
      // Nothing to say.
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _remove(BuildContext context) async {
    final s = BaseScope.of(context);
    final others = s.models.stateOf(spec.id).users.where((u) => u != s.config.appId).length;
    // On iOS the Desert Ant SDK stores weights in its own folder, not in the shared store.
    final sdkKeepsOwnCopy = spec.source == ModelSource.sdk && defaultTargetPlatform == TargetPlatform.iOS;
    final ok = await confirmSheet(
      context,
      title: 'remove ${spec.name}?',
      body: others > 0
          ? '$others other app${others == 1 ? ' uses' : 's use'} it, so the file stays on this device for them. ${s.config.name} just stops using it.'
          : sdkKeepsOwnCopy
          ? 'Its SDK keeps the weights in its own folder on this device, so removing it here does not free that space. ${s.config.name} just stops using it.'
          : 'No other app uses it, so ${formatBytes(spec.bytes)} is freed. You can download it again later.',
      confirm: 'remove',
    );
    if (ok) await s.models.release(spec.id);
  }
}

/// The Hugging Face token for gated models, kept in this app's settings.
class _TokenField extends StatefulWidget {
  const _TokenField();

  @override
  State<_TokenField> createState() => _TokenFieldState();
}

class _TokenFieldState extends State<_TokenField> {
  late final _token = TextEditingController(text: BaseScope.of(context).settings.hfToken);
  bool _saved = false;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _token.text.trim();
    await BaseScope.of(context).settings.update((x) => x.hfToken = value);
    if (mounted) setState(() => _saved = true);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HandField(
        controller: _token,
        placeholder: 'hf_...',
        singleLine: true,
        obscure: true,
        leading: Doodle.lock,
        onChanged: (_) => setState(() => _saved = false),
        onSubmitted: (_) => _save(),
      ),
      const SizedBox(height: SpaceTokens.s),
      Row(
        children: [
          PillButton('save token', onPressed: _save),
          const SizedBox(width: SpaceTokens.sm),
          if (_saved) Flexible(child: Text('Saved on this device.', style: context.type.caption)),
        ],
      ),
    ],
  );
}
