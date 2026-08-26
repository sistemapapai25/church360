import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

/// Dialog com o link pronto pra copiar, além da opção de compartilhar
/// via apps (WhatsApp, etc). Existe porque clicar no link compartilhado
/// pelo share sheet nem sempre abre a rota certa (o app instalado como
/// PWA às vezes reabre na última tela em vez de navegar pro link) —
/// colar o link manualmente sempre funciona.
Future<void> showShareLinkDialog(
  BuildContext context, {
  required String title,
  required String url,
  required String shareText,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Copie o link ou compartilhe diretamente:'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              url,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      actions: [
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Link copiado!')),
              );
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copiar link'),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.of(context).pop();
            Share.share(shareText);
          },
          icon: const Icon(Icons.share),
          label: const Text('Compartilhar via apps'),
        ),
      ],
    ),
  );
}
