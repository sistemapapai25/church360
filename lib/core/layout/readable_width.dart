import 'package:flutter/widgets.dart';

/// Formulário e tela de detalhe no padrão web (17/10/2026): não viram grade,
/// ficam numa coluna centralizada de no máximo [maxWidth]. No celular não
/// muda nada (a tela já é mais estreita que isso).
///
/// Vai no `body` do `Scaffold`, por fora da lista: é o mesmo
/// `Align` + `ConstrainedBox` que o Louvor já usava solto (§10.4 S3).
class ReadableWidth extends StatelessWidget {
  const ReadableWidth({super.key, required this.child, this.maxWidth = 960});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      );
}
