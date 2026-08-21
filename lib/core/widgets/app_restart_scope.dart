import 'package:flutter/widgets.dart';

/// Envolve a árvore de widgets num `Key` reconstruível, permitindo forçar um
/// "restart" da subtree (inclusive uma `ProviderScope` interna, se houver
/// uma dentro de [child]) sem matar o processo do app.
///
/// Usado pelo CHU-300 pra limpar o cache dos providers Riverpod depois de
/// "Trocar de igreja" em runtime — sem isso, telas já visitadas na sessão
/// continuam mostrando dado da unidade anterior até o app ser fechado e
/// reaberto (nem o logout resolve isso hoje: só "funciona" no Android porque
/// mata o processo, não porque algo invalida o cache).
class AppRestartScope extends StatefulWidget {
  final Widget child;

  const AppRestartScope({super.key, required this.child});

  static void restart(BuildContext context) {
    context.findAncestorStateOfType<_AppRestartScopeState>()?._restart();
  }

  @override
  State<AppRestartScope> createState() => _AppRestartScopeState();
}

class _AppRestartScopeState extends State<AppRestartScope> {
  Key _key = UniqueKey();

  void _restart() {
    setState(() {
      _key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
