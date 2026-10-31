import 'package:flutter/foundation.dart';
import 'package:base_design/base_design.dart';
import 'package:base_models/base_models.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../services.dart';

/// The models this app uses, where they live, and which other apps share them.
class ModelsPage extends StatelessWidget {
  const ModelsPage({super.key});

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
        return HandPage(
          onBack: () => Navigator.pop(context),
          children: [
            PageIntro(
              title: 'models',
              purpose:
                  'The AI models ${s.config.name} uses. They stay on this device and are shared with your other ${PlatformConfig.vendorName} apps, so each one is downloaded once.',
              mark: 'models',
              doodle: Doodle.spark,
            ),
            Meta('Kept in: ${store.location.description}.'),
            Meta('${formatBytes(store.bytesOnDisk)} on this device, for every app together.'),
            if (s.ai.isDemo) const Meta('This build runs the demo engine: model output is scripted and labelled as a demo.'),
            const SizedBox(height: 8),
            const SectionHead('this app uses'),
            if (mine.isEmpty) const Meta('No models yet.'),
            for (final id in mine) _ModelRow(spec: store.spec(id), required: s.config.requiredModels.contains(id)),
            const SizedBox(height: 16),
            const SectionHead('gated models', note: 'Gemma'),
            const Meta('Some models need their licence accepted on huggingface.co first. Paste your access token here; it is only sent to huggingface.co.'),
            const SizedBox(height: 8),
            const _TokenField(),
            if (others.isNotEmpty) ...[
              const SizedBox(height: 16),
              const SectionHead('already here, from other apps', note: 'free to use'),
              for (final m in others) _ModelRow(spec: m, required: false),
            ],
          ],
        );
      },
    );
  }
}

class _ModelRow extends StatelessWidget {
  const _ModelRow({required this.spec, required this.required});
  final ModelSpec spec;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final s = BaseScope.of(context);
    final state = s.models.stateOf(spec.id);
    final c = context.colors;
    final others = state.users.where((u) => u != s.config.appId).length;
    final usedBy = state.users.contains(s.config.appId);
    final facts = [
      formatBytes(spec.bytes),
      spec.role,
      if (others > 0) 'shared with $others other app${others == 1 ? '' : 's'}',
      if (state.inSibling) 'on this phone in another app, no download',
      if (required) 'needed',
    ].join(' · ');

    Widget action;
    switch (state.status) {
      case ModelStatus.downloading:
        action = HandLink('cancel', onPressed: () => s.models.cancel(spec.id));
      case ModelStatus.ready:
        action = usedBy
            ? HandLink('remove', onPressed: () => _remove(context))
            : PillButton('use', onPressed: () => _run(context, () => s.ensureModel(spec.id)));
      case ModelStatus.absent || ModelStatus.failed when spec.source == ModelSource.sdk && s.ai.isDemo:
        // SDK models install through the native engine; the demo build has none.
        action = const SizedBox(width: 96, child: Meta('needs the on-device engine', textAlign: TextAlign.end));
      case ModelStatus.absent when state.inSibling:
        // Another app on this phone has it: using it copies the files, no download.
        action = PillButton('use', onPressed: () => _run(context, () => s.ensureModel(spec.id)));
      case ModelStatus.absent:
      case ModelStatus.failed:
        action = PillButton(
          state.status == ModelStatus.failed ? 'try again' : 'download',
          leading: Doodle.arrow,
          onPressed: () => _run(context, () => s.ensureModel(spec.id)),
        );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spec.name, style: context.type.door.copyWith(fontSize: 24)),
                    Meta(spec.summary),
                    Meta(facts),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              action,
            ],
          ),
          if (state.status == ModelStatus.downloading) ...[
            const SizedBox(height: 6),
            HandProgress(fraction: state.busyElsewhere ? null : state.progress),
            if (state.busyElsewhere) const Meta('another app is downloading this; it will be ready here too'),
          ],
          if (state.status == ModelStatus.failed && state.error != null) Meta(state.error!, color: c.redPen),
          const HandDivider(),
        ],
      ),
    );
  }

  Future<void> _run(BuildContext context, Future<void> Function() job) async {
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
      const SizedBox(height: 8),
      Row(
        children: [
          PillButton('save token', onPressed: _save),
          const SizedBox(width: 12),
          if (_saved) const Flexible(child: Meta('saved on this device')),
        ],
      ),
    ],
  );
}
