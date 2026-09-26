import 'package:supabase_flutter/supabase_flutter.dart';

/// Copy PT-BR das recusas que `register_baptism_public` e
/// `baptism_public_registration_info` emitem por `RAISE EXCEPTION`.
///
/// O repositório não traduz código de erro — a copy é da camada de tela,
/// por convenção do projeto. Vive aqui porque duas telas inscrevem pela
/// mesma RPC: o link público e o botão "Inscrever-se" do curso (decisão 21
/// do ROADMAP-FORMACAO).
const Map<String, String> baptismRegistrationRefusalCopy = {
  'ALREADY_REGISTERED':
      'Já existe uma inscrição com este WhatsApp nesta turma. Se você não reconhece, fale com a liderança do ministério.',
  'TURMA_REGISTRATION_CLOSED':
      'As inscrições para esta turma foram encerradas enquanto você preenchia o formulário.',
  'TURMA_NOT_ACTIVE': 'Esta turma não está mais aberta.',
  'TURMA_NOT_FOUND': 'Esta turma não existe mais.',
  'INVALID_NAME': 'Escreva seu nome completo.',
  'INVALID_PHONE': 'Informe um WhatsApp válido, com DDD.',
  'INVALID_EMAIL': 'O e-mail informado não parece válido.',
  'MINISTRY_INACTIVE': 'Este curso não está mais ativo.',
  'MINISTRY_NOT_FOUND': 'Não encontramos este curso.',
  'TENANT_NOT_FOUND': 'Não encontramos esta igreja.',
};

/// Frase para quem está se inscrevendo; nunca o literal cru do banco.
String baptismRegistrationErrorMessage(Object error) {
  final texto = error is PostgrestException
      ? '${error.code ?? ''} ${error.message} ${error.details ?? ''} ${error.hint ?? ''}'
      : '$error';

  for (final entry in baptismRegistrationRefusalCopy.entries) {
    if (texto.contains(entry.key)) return entry.value;
  }
  return 'Não foi possível concluir a inscrição agora. Tente de novo em instantes.';
}
