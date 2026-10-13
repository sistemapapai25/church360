import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/geo_checkin_service.dart';

/// `/presenca`: aberta pelo aviso "Chegou bem? / O que está achando do
/// culto?". A pessoa responde com uma reação; responder marca a presença pela
/// localização (pede a permissão no toque, o navegador exige) e guarda a
/// reação. Se a presença já estava marcada, só guarda a reação.
class PresenceCheckinScreen extends ConsumerStatefulWidget {
  const PresenceCheckinScreen({super.key});

  @override
  ConsumerState<PresenceCheckinScreen> createState() =>
      _PresenceCheckinScreenState();
}

/// (valor gravado, rótulo do botão)
const _reactions = [
  ('otimo', 'Tá ótimo! 🙌'),
  ('gostando', 'Tô gostando 🙂'),
  ('mais_ou_menos', 'Mais ou menos 😐'),
];

class _PresenceCheckinScreenState extends ConsumerState<PresenceCheckinScreen> {
  GeoCheckinResult? _result;
  bool _busy = false;
  bool _reacted = false;
  String? _reaction;

  @override
  void initState() {
    super.initState();
    _run(ask: false);
  }

  static bool _isPresent(GeoCheckinResult? r) =>
      r?.status == GeoCheckinStatus.presente ||
      r?.status == GeoCheckinStatus.jaMarcado;

  Future<void> _run({required bool ask}) async {
    setState(() => _busy = true);
    final service = ref.read(geoCheckinServiceProvider);
    GeoCheckinResult r;
    var reacted = _reacted;
    try {
      r = _isPresent(_result) ? _result! : await service.checkIn(ask: ask);
      if (_isPresent(r) && _reaction != null) {
        reacted = await service.react(_reaction!);
      }
    } catch (_) {
      r = const GeoCheckinResult(GeoCheckinStatus.erro);
    }
    if (!mounted) return;
    setState(() {
      _result = r;
      _reacted = reacted;
      _busy = false;
    });
  }

  void _react(String reaction) {
    _reaction = reaction;
    _run(ask: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: const Text('Bom culto!'),
        leading: IconButton(
          icon: const Icon(AppIcons.back),
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: GlassCard(
              padding: const EdgeInsets.all(24),
              child: _busy || _result == null
                  ? const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Só um instante...'),
                      ],
                    )
                  : _ResultView(
                      result: _result!,
                      reacted: _reacted,
                      onReact: _react,
                      onRetry: () => _run(ask: true),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final GeoCheckinResult result;
  final bool reacted;
  final ValueChanged<String> onReact;
  final VoidCallback onRetry;

  const _ResultView({
    required this.result,
    required this.reacted,
    required this.onReact,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final culto = result.eventName ?? 'culto';
    final primary = Theme.of(context).colorScheme.primary;
    final present = _PresenceCheckinScreenState._isPresent(result);
    final (icon, color, title, text) = switch (result.status) {
      _ when present && reacted => (
        AppIcons.checkCircle,
        Colors.green,
        'Obrigado por contar!',
        'Que bom ter você no $culto. Bom culto!',
      ),
      GeoCheckinStatus.presente || GeoCheckinStatus.jaMarcado => (
        AppIcons.checkCircle,
        Colors.green,
        'Que bom ter você aqui!',
        'O que está achando do $culto?',
      ),
      GeoCheckinStatus.longe => (
        AppIcons.location,
        Colors.orange,
        'Você parece estar longe da igreja',
        'Pelo GPS, você está a ${result.distanceM ?? '?'} m. Se você está '
            'no culto, tente de novo perto da entrada ou avise um diácono.',
      ),
      GeoCheckinStatus.semPermissao || GeoCheckinStatus.aberta => (
        AppIcons.location,
        primary,
        'Chegou bem?',
        'O que está achando do $culto?',
      ),
      GeoCheckinStatus.semGps => (
        AppIcons.location,
        Colors.orange,
        'Localização desligada',
        'Ligue a localização do celular e toque em tentar de novo.',
      ),
      GeoCheckinStatus.fechada => (
        AppIcons.info,
        primary,
        'Nenhum culto agora',
        'A confirmação pela localização vale na primeira hora do culto.',
      ),
      GeoCheckinStatus.semLocal => (
        AppIcons.info,
        primary,
        'Recurso não configurado',
        'A igreja ainda não cadastrou o local para a presença pelo celular.',
      ),
      GeoCheckinStatus.semConta || GeoCheckinStatus.erro => (
        AppIcons.error,
        Theme.of(context).colorScheme.error,
        'Não deu para confirmar',
        'Tente de novo em instantes. Se continuar, avise um diácono.',
      ),
    };
    final asking =
        result.status == GeoCheckinStatus.semPermissao ||
        result.status == GeoCheckinStatus.aberta;
    final showReactions = asking || (present && !reacted);
    final canRetry = switch (result.status) {
      GeoCheckinStatus.longe ||
      GeoCheckinStatus.semGps ||
      GeoCheckinStatus.erro => true,
      _ => false,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: color),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: CommunityDesign.titleStyle(
            context,
          ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          textAlign: TextAlign.center,
          style: CommunityDesign.metaStyle(context),
        ),
        if (showReactions) ...[
          const SizedBox(height: 20),
          for (final (value, label) in _reactions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () => onReact(value),
                  child: Text(label),
                ),
              ),
            ),
        ],
        if (asking) ...[
          const SizedBox(height: 8),
          Text(
            'Ao responder, o app confere sua localização só agora, para '
            'registrar sua presença, e não a guarda.',
            textAlign: TextAlign.center,
            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 12),
          ),
        ],
        if (canRetry) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(AppIcons.refresh),
            label: const Text('Tentar de novo'),
          ),
        ],
      ],
    );
  }
}
