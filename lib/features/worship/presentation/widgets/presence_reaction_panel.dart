import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/app_icons.dart';
import '../../../../core/design/community_design.dart';
import '../../data/geo_checkin_service.dart';

/// (valor gravado, rótulo do botão)
const kPresenceReactions = [
  ('otimo', 'Tá ótimo! 🙌'),
  ('gostando', 'Tô gostando 🙂'),
  ('mais_ou_menos', 'Mais ou menos 😐'),
];

/// Painel "Chegou bem? / O que está achando do culto?" da presença pelo
/// celular. É o miolo da tela /presenca e, em [compact], entra dentro do
/// bloco do culto na Home (roadmap 14/10, fase A4).
///
/// Responder marca a presença pela localização (pede a permissão no toque,
/// o navegador exige) e guarda a reação. Se a presença já estava marcada, só
/// guarda a reação. Em [compact] os estados que não pedem nada da pessoa
/// (sem culto na janela, sem local, sem conta) não aparecem, e depois de
/// responder sobra uma linha só.
class PresenceReactionPanel extends ConsumerStatefulWidget {
  final bool compact;

  const PresenceReactionPanel({super.key, this.compact = false});

  @override
  ConsumerState<PresenceReactionPanel> createState() =>
      _PresenceReactionPanelState();
}

class _PresenceReactionPanelState extends ConsumerState<PresenceReactionPanel> {
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
      // Quem já respondeu antes (reaction vem do servidor) não vê os botões.
      if (r.reaction != null) reacted = true;
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
    if (_busy || _result == null) {
      if (widget.compact) return const SizedBox.shrink();
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Só um instante...'),
        ],
      );
    }
    if (widget.compact) {
      switch (_result!.status) {
        case GeoCheckinStatus.fechada:
        case GeoCheckinStatus.semLocal:
        case GeoCheckinStatus.semConta:
          return const SizedBox.shrink();
        default:
          break;
      }
    }
    return _ResultView(
      result: _result!,
      reacted: _reacted,
      compact: widget.compact,
      onReact: _react,
      onRetry: () => _run(ask: true),
    );
  }
}

class _ResultView extends StatelessWidget {
  final GeoCheckinResult result;
  final bool reacted;
  final bool compact;
  final ValueChanged<String> onReact;
  final VoidCallback onRetry;

  const _ResultView({
    required this.result,
    required this.reacted,
    required this.compact,
    required this.onReact,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final culto = result.eventName ?? 'culto';
    final primary = Theme.of(context).colorScheme.primary;
    final present = _PresenceReactionPanelState._isPresent(result);
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

    // Na Home, depois de responder, sobra uma linha só.
    if (compact && present && reacted) {
      return Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Presença confirmada. Bom culto!',
              style: CommunityDesign.metaStyle(context),
            ),
          ),
        ],
      );
    }

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
    final align = compact ? TextAlign.start : TextAlign.center;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        if (!compact) ...[
          Icon(icon, size: 56, color: color),
          const SizedBox(height: 16),
        ],
        Text(
          title,
          textAlign: align,
          style: CommunityDesign.titleStyle(context).copyWith(
            fontWeight: FontWeight.w700,
            fontSize: compact ? 15 : 18,
          ),
        ),
        const SizedBox(height: 8),
        Text(text, textAlign: align, style: CommunityDesign.metaStyle(context)),
        if (showReactions) ...[
          SizedBox(height: compact ? 10 : 20),
          if (compact)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (value, label) in kPresenceReactions)
                  FilledButton.tonal(
                    onPressed: () => onReact(value),
                    child: Text(label),
                  ),
              ],
            )
          else
            for (final (value, label) in kPresenceReactions)
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
            textAlign: align,
            style: CommunityDesign.metaStyle(context).copyWith(fontSize: 12),
          ),
        ],
        if (canRetry) ...[
          SizedBox(height: compact ? 10 : 20),
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
