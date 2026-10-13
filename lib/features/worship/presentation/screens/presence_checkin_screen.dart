import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../data/geo_checkin_service.dart';

/// `/presenca`: aberta pelo aviso "Você está no culto?". Confere a
/// localização na hora; se a permissão ainda não foi dada, explica e pede
/// com um toque (o navegador exige o toque em alguns aparelhos).
class PresenceCheckinScreen extends ConsumerStatefulWidget {
  const PresenceCheckinScreen({super.key});

  @override
  ConsumerState<PresenceCheckinScreen> createState() =>
      _PresenceCheckinScreenState();
}

class _PresenceCheckinScreenState extends ConsumerState<PresenceCheckinScreen> {
  GeoCheckinResult? _result;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _run(ask: false);
  }

  Future<void> _run({required bool ask}) async {
    setState(() => _busy = true);
    GeoCheckinResult r;
    try {
      r = await ref.read(geoCheckinServiceProvider).checkIn(ask: ask);
    } catch (_) {
      r = const GeoCheckinResult(GeoCheckinStatus.erro);
    }
    if (!mounted) return;
    setState(() {
      _result = r;
      _busy = false;
    });
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
                  : _ResultView(result: _result!, onAsk: () => _run(ask: true)),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final GeoCheckinResult result;
  final VoidCallback onAsk;

  const _ResultView({required this.result, required this.onAsk});

  @override
  Widget build(BuildContext context) {
    final culto = result.eventName ?? 'culto';
    final (icon, color, title, text) = switch (result.status) {
      GeoCheckinStatus.presente || GeoCheckinStatus.jaMarcado => (
        AppIcons.checkCircle,
        Colors.green,
        'Que bom ter você aqui!',
        'Sua chegada ao $culto ficou registrada. Bom culto!',
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
        Theme.of(context).colorScheme.primary,
        'Chegou ao $culto?',
        'Toque em "Cheguei" e a gente fica sabendo que você está aqui. '
            'O app confere sua localização só neste momento e não a guarda.',
      ),
      GeoCheckinStatus.semGps => (
        AppIcons.location,
        Colors.orange,
        'Localização desligada',
        'Ligue a localização do celular e toque em tentar de novo.',
      ),
      GeoCheckinStatus.fechada => (
        AppIcons.info,
        Theme.of(context).colorScheme.primary,
        'Nenhum culto agora',
        'A confirmação pela localização vale na primeira hora do culto.',
      ),
      GeoCheckinStatus.semLocal => (
        AppIcons.info,
        Theme.of(context).colorScheme.primary,
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
    final canRetry = switch (result.status) {
      GeoCheckinStatus.longe ||
      GeoCheckinStatus.semPermissao ||
      GeoCheckinStatus.aberta ||
      GeoCheckinStatus.semGps ||
      GeoCheckinStatus.erro => true,
      _ => false,
    };
    final asking =
        result.status == GeoCheckinStatus.semPermissao ||
        result.status == GeoCheckinStatus.aberta;

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
        if (canRetry) ...[
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onAsk,
            icon: Icon(asking ? AppIcons.location : AppIcons.refresh),
            label: Text(asking ? 'Cheguei!' : 'Tentar de novo'),
          ),
        ],
      ],
    );
  }
}
