import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/supabase_constants.dart';

/// Versão do Termo publicada em `web/terms.html`. Ao publicar texto novo
/// que exija novo aceite, suba esta versão junto: quem aceitou a anterior
/// volta a ser perguntado.
const kTermsVersion = '1.1';
const kTermsUrl = 'https://papai.church360.com.br/termos';

/// Quando a pessoa logada aceitou a versão atual nesta igreja; null se ainda
/// não aceitou.
final currentTermsAcceptanceProvider = FutureProvider<DateTime?>((ref) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return null;
  final row = await client
      .from('terms_acceptance')
      .select('accepted_at')
      .eq('tenant_id', SupabaseConstants.currentTenantId)
      .eq('user_id', uid)
      .eq('version', kTermsVersion)
      .maybeSingle();
  return row == null ? null : DateTime.parse(row['accepted_at'] as String);
});

/// Registra o aceite da versão atual. Data e dono vêm do servidor; aceitar
/// de novo (outra aba, toque duplo) não é erro.
Future<void> acceptCurrentTerms(WidgetRef ref) async {
  try {
    await Supabase.instance.client.from('terms_acceptance').insert({
      'tenant_id': SupabaseConstants.currentTenantId,
      'version': kTermsVersion,
      'user_agent': kIsWeb ? 'web' : defaultTargetPlatform.name,
    });
  } on PostgrestException catch (e) {
    if (e.code != '23505') rethrow;
  }
  ref.invalidate(currentTermsAcceptanceProvider);
}

Future<void> openTerms() =>
    launchUrl(Uri.parse(kTermsUrl), mode: LaunchMode.externalApplication);

bool _askedThisSession = false;

/// Pede o aceite a quem ainda não aceitou a versão atual. "Agora não" adia:
/// volta a perguntar na próxima vez que o app abrir (uma vez por sessão).
Future<void> askTermsAcceptanceIfPending(
  BuildContext context,
  WidgetRef ref,
) async {
  if (_askedThisSession) return;
  final DateTime? acceptedAt;
  try {
    acceptedAt = await ref.read(currentTermsAcceptanceProvider.future);
  } catch (_) {
    return; // Sem rede/tabela: não trava a entrada no app por isso.
  }
  if (acceptedAt != null || !context.mounted) return;
  _askedThisSession = true;
  await showTermsAcceptanceDialog(context, ref);
}

/// Diálogo de aceite: ler, adiar ou aceitar.
Future<void> showTermsAcceptanceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  final accept = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Termo de Uso e Compromisso'),
      content: const Text(
        'Publicamos a versão $kTermsVersion do Termo de Uso e Compromisso. '
        'Leia e confirme que concorda para continuar usando o app.',
      ),
      actions: [
        TextButton(onPressed: openTerms, child: const Text('Ler o Termo')),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Agora não'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Li e aceito'),
        ),
      ],
    ),
  );
  if (accept != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await acceptCurrentTerms(ref);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Aceite registrado. Obrigado!'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text('Não foi possível registrar o aceite: $e'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
