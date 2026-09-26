import 'package:flutter/material.dart';

import '../../../../../core/design/app_icons.dart';
import '../../../../../core/design/community_design.dart';
import '../../../../../core/theme/app_theme.dart';

/// Abre uma folha inferior da tela da turma, no mesmo desenho das folhas do
/// Batismo (`baptism_turmas_sheet.dart`): fundo transparente, cantos de 20,
/// alça no topo e rolagem quando o teclado sobe.
Future<T?> showTurmaSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    constraints: const BoxConstraints(maxWidth: 640),
    backgroundColor: Colors.transparent,
    builder: builder,
  );
}

/// Corpo de uma folha: alça, título e conteúdo rolável.
class TurmaSheetBody extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const TurmaSheetBody({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.mutedForeground.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Mensagem centralizada da tela da turma (vazio, erro, sem acesso).
class TurmaMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const TurmaMessage({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Erro de carga com "Tentar novamente".
  const TurmaMessage.error({
    super.key,
    required this.message,
    required VoidCallback onRetry,
  }) : icon = AppIcons.error,
       actionLabel = 'Tentar novamente',
       onAction = onRetry;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(
      context,
    ).colorScheme.onSurface.withValues(alpha: 0.5);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: muted),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
