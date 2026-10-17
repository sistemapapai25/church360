import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/design/community_design.dart';

/// "Não perturbe" no culto (P2, roadmap 16/10). Só o app Android consegue
/// ligar sozinho, e só se a pessoa der o acesso ("Acesso ao Não perturbe",
/// opcional). iPhone e navegador não deixam: lá aparece só a dica do Foco.
///
/// Só desliga o que o app ligou: se o celular já estava em Não perturbe,
/// fica como estava. O desligar roda em [CultoSilence.restore], chamado a
/// cada consulta de "tem culto agora?" quando não tem culto (ao abrir o app,
/// a cada 60 s e ao voltar para a frente).
class CultoSilence {
  static const _channel = MethodChannel('church360/dnd');
  static const _prefKey = 'culto_dnd_ligado_pelo_app';

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Celular (app ou navegador): mostra o botão ou a dica.
  static bool get hasRow =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static Future<bool> isOn() async =>
      await _channel.invokeMethod<bool>('isOn') ?? false;

  /// Liga. Sem o acesso, abre a tela do Android para a pessoa permitir e
  /// devolve false (ela volta e toca de novo).
  static Future<bool> turnOn() async {
    if (await _channel.invokeMethod<bool>('granted') != true) {
      await _channel.invokeMethod('openSettings');
      return false;
    }
    if (await isOn()) return true;
    final ok = await _channel.invokeMethod<bool>('set', true) ?? false;
    if (ok) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, true);
    }
    return ok;
  }

  static Future<void> restore() async {
    if (!supported) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_prefKey) != true) return;
      await _channel.invokeMethod<bool>('set', false);
      await prefs.remove(_prefKey);
    } catch (_) {}
  }
}

/// Linha do bloco do culto na Home: botão no Android, dica no iPhone e no
/// navegador do celular. No computador não aparece.
class CultoSilenceRow extends StatefulWidget {
  const CultoSilenceRow({super.key});

  @override
  State<CultoSilenceRow> createState() => _CultoSilenceRowState();
}

class _CultoSilenceRowState extends State<CultoSilenceRow>
    with WidgetsBindingObserver {
  bool _on = false;

  @override
  void initState() {
    super.initState();
    if (CultoSilence.supported) {
      WidgetsBinding.instance.addObserver(this);
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Volta da tela do Android onde a pessoa deu (ou não) o acesso.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final on = await CultoSilence.isOn();
      if (mounted) setState(() => _on = on);
    } catch (_) {}
  }

  Future<void> _turnOn() async {
    try {
      final on = await CultoSilence.turnOn();
      if (mounted) setState(() => _on = on);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não deu para ligar o Não perturbe neste celular.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final style = CommunityDesign.metaStyle(context);
    if (CultoSilence.supported) {
      return Row(
        children: [
          Icon(
            _on ? Icons.do_not_disturb_on : Icons.do_not_disturb_off_outlined,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _on
                  ? 'Celular em Não perturbe. Desliga sozinho no fim do culto.'
                  : 'Silenciar o celular durante o culto?',
              style: style,
            ),
          ),
          if (!_on)
            TextButton(
              key: const ValueKey('culto-dnd-on'),
              onPressed: _turnOn,
              child: const Text('Silenciar'),
            ),
        ],
      );
    }
    if (!CultoSilence.hasRow) return const SizedBox.shrink();
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return Row(
      children: [
        const Icon(Icons.do_not_disturb_on_outlined, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ios
                ? 'Dica: puxe a Central de Controle e ligue o Foco '
                      '"Não perturbe" durante o culto.'
                : 'Dica: puxe a barra de cima do celular e ligue o '
                      '"Não perturbe" durante o culto.',
            style: style,
          ),
        ),
      ],
    );
  }
}
