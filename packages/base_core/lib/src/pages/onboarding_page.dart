import 'package:base_design/base_design.dart';
import 'package:base_models/base_models.dart';
import 'package:flutter/material.dart';

import '../format.dart';
import '../services.dart';

/// First run: what the app is, the models it needs (reusing any another app
/// already downloaded), and the offer to never go online again.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int _step = 0;
  bool _neverOnline = true;
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final s = BaseScope.of(context);
    final needs = s.config.requiredModels;
    return ListenableBuilder(
      listenable: s.models,
      builder: (context, _) => switch (_step) {
        0 => _welcome(s, needs),
        1 => _models(s, needs),
        _ => _privacy(s, needs),
      },
    );
  }

  Widget _welcome(BaseServices s, List<String> needs) => HandPage(
    bottom: InkButton("let's start", trailing: Doodle.arrow, onPressed: () => setState(() => _step = needs.isEmpty ? 2 : 1)),
    children: [
      const SizedBox(height: 40),
      DoodleIcon(s.config.welcomeDoodle, size: 56, tilt: -8),
      const SizedBox(height: 16),
      Text(s.config.wordmark ?? s.config.name, style: context.type.display),
      const SizedBox(height: 12),
      MarkedText(s.config.tagline, mark: s.config.welcomeMark, style: context.type.title),
      const SizedBox(height: 24),
      Steps([if (needs.isNotEmpty) 'get the AI models (once per device)', 'decide whether it may ever go online', 'start']),
      const SizedBox(height: 16),
      const OnDeviceStamp(text: 'everything runs on this device'),
    ],
  );

  Widget _models(BaseServices s, List<String> needs) {
    final store = s.models;
    final missing = needs.where((id) => !store.isReady(id)).toList();
    final bytes = missing.fold<int>(0, (sum, id) => sum + store.spec(id).bytes);
    final allReady = missing.isEmpty;
    return HandPage(
      onBack: () => setState(() => _step = 0),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkButton(
            allReady ? 'next' : 'download ${formatBytes(bytes)}',
            busy: _busy,
            trailing: Doodle.arrow,
            onPressed: () async {
              await _download(s, needs);
              if (mounted && needs.every(s.models.isReady)) setState(() => _step = 2);
            },
          ),
          if (!allReady) Center(child: HandLink('later', onPressed: () => setState(() => _step = 2))),
        ],
      ),
      children: [
        PageIntro(
          title: 'the models',
          purpose:
              '${s.config.name} uses these on-device AI models. Any that another ${PlatformConfig.vendorName} app already downloaded are reused, not downloaded again.',
          mark: 'models',
          doodle: Doodle.spark,
        ),
        for (final id in needs) _NeedRow(spec: store.spec(id), state: store.stateOf(id)),
        if (_error != null) Meta(_error!, color: context.colors.redPen),
      ],
    );
  }

  /// Makes every model this app needs ready and claims it, including ones
  /// another app already downloaded, so they are not deleted under this app.
  Future<void> _download(BaseServices s, List<String> ids) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      for (final id in ids) {
        await s.ensureModel(id);
      }
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _privacy(BaseServices s, List<String> needs) {
    final ready = needs.every(s.models.isReady);
    return HandPage(
      bottom: InkButton(
        'start',
        onPressed: () async {
          await s.settings.update((x) {
            x.onboarded = true;
            // Only offer offline mode once the models it needs are here.
            if (ready) x.neverOnline = _neverOnline;
          });
        },
      ),
      children: [
        const SizedBox(height: 24),
        MarkedText('nothing leaves this device.', mark: 'nothing', style: context.type.headline),
        const SizedBox(height: 8),
        Body(
          'The only thing ${s.config.name} ever fetches is AI models. There is no account and no analytics. You can check it any time behind the padlock.',
          color: context.colors.pencil,
        ),
        const SizedBox(height: 16),
        if (ready)
          SwitchRow(
            title: 'then never go online',
            body: 'Turn it off later if you want a new model.',
            doodle: Doodle.cloudOff,
            value: _neverOnline,
            onChanged: (v) => setState(() => _neverOnline = v),
          )
        else
          const Meta('Some models are not here yet, so the app will ask before fetching them.'),
      ],
    );
  }
}

class _NeedRow extends StatelessWidget {
  const _NeedRow({required this.spec, required this.state});
  final ModelSpec spec;
  final ModelState state;

  @override
  Widget build(BuildContext context) {
    final shared = state.isReady && state.users.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(spec.name, style: context.type.door.copyWith(fontSize: 24))),
              if (state.isReady) const DoodleIcon(Doodle.tick, size: 22),
            ],
          ),
          Meta(state.isReady ? (shared ? 'already on this device · shared' : 'ready') : '${formatBytes(spec.bytes)} · ${spec.summary}'),
          if (state.status == ModelStatus.downloading) HandProgress(fraction: state.busyElsewhere ? null : state.progress),
          if (state.status == ModelStatus.failed && state.error != null) Meta(state.error!, color: context.colors.redPen),
        ],
      ),
    );
  }
}
