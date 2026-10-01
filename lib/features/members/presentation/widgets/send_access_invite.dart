import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cria o login de quem já tem ficha e manda o link de primeiro acesso pelo
/// WhatsApp (Edge Function `provision-access`). Quem pode é decidido no
/// servidor (admin/owner da igreja da ficha); aqui só traduz o resultado.
/// Devolve true quando o link foi enviado.
Future<bool> sendAccessInvite(
  BuildContext context, {
  required String userAccountId,
  required String memberName,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Enviar acesso'),
      content: Text(
        '$memberName vai receber no WhatsApp um link para criar a senha '
        'do app. O link vale por 1 hora e funciona uma vez só.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Enviar'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  String message;
  var ok = false;
  try {
    final res = await Supabase.instance.client.functions.invoke(
      'provision-access',
      body: {
        'mode': 'invite',
        'user_account_ids': [userAccountId],
      },
    );
    final result =
        ((res.data as Map)['results'] as List).first as Map<String, dynamic>;
    final outcome = result['outcome'] as String?;
    ok = outcome == 'INVITED' || outcome == 'RESENT';
    message = switch (outcome ?? result['classification']) {
      'INVITED' => 'Acesso enviado pelo WhatsApp.',
      'RESENT' => 'Novo link enviado pelo WhatsApp.',
      'ALREADY_LINKED' => 'Esta pessoa já tem acesso ao app.',
      'READY_NO_WHATSAPP' =>
        'Telefone incompleto: corrija o celular na ficha para enviar.',
      'NO_CONTACT' => 'A ficha precisa de e-mail e celular válidos.',
      'DUPLICATE_EMAIL' => 'Este e-mail está em mais de uma ficha.',
      'EXISTING_AUTH_CANDIDATE' =>
        'Já existe uma conta com este e-mail. Fale com o suporte.',
      _ => 'Não foi possível enviar o acesso ($outcome).',
    };
  } on FunctionException catch (e) {
    message = e.status == 403
        ? 'Só administradores da igreja podem enviar acesso.'
        : 'Não foi possível enviar o acesso.';
  } catch (_) {
    message = 'Não foi possível enviar o acesso.';
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: ok ? Colors.green : Colors.orange,
    ),
  );
  return ok;
}
