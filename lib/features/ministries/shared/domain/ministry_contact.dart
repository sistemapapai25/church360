import '../../domain/models/ministry.dart';

/// Em que pé está o telefone de alguém da equipe.
///
/// São três estados, e não dois, porque campo preenchido não é o mesmo que
/// número discável: `"(11) "` tem dígito e não leva a lugar nenhum — o
/// `launchWhatsAppMessage` prepende 55 e abre `wa.me/5511`, uma conversa que
/// não existe. Separar [incomplete] de [missing] é o que faz a tela dizer
/// *por que* aquela pessoa não pode ser acionada, em vez de sumir com ela.
enum MinistryPhoneState {
  /// Dá para abrir a conversa.
  usable,

  /// Tem dígito, mas não o suficiente para um número brasileiro.
  incomplete,

  /// Campo vazio.
  missing,
}

/// Classifica um telefone pela convenção do app (números do Brasil, como o
/// `launchWhatsAppMessage` assume): 10 ou 11 dígitos com DDD, ou já no
/// formato internacional começando por 55.
///
/// Esta é a régua única do módulo — a aba WhatsApp do Batismo classifica o
/// telefone do aluno chamando aqui.
MinistryPhoneState ministryPhoneState(String? phone) {
  final digits = (phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return MinistryPhoneState.missing;
  if (digits.startsWith('55') && digits.length >= 12) {
    return MinistryPhoneState.usable;
  }
  if (digits.length == 10 || digits.length == 11) {
    return MinistryPhoneState.usable;
  }
  return MinistryPhoneState.incomplete;
}

/// Se dá para abrir uma conversa com esta pessoa da equipe.
bool ministryMemberHasWhatsApp(MinistryMember member) =>
    ministryPhoneState(member.phone) == MinistryPhoneState.usable;

/// As variáveis que a aba Avisos sabe substituir, com a explicação que
/// aparece na tela.
///
/// É um subconjunto do que a aba do Batismo conhece: aqui não há aluno nem
/// turma, só quem está vinculado ao ministério. Os nomes espelham o
/// `VariableRegistry` de `features/dispatch` para que um modelo escrito aqui
/// continue valendo lá.
const Map<String, String> kMinistryNoticeVariables = {
  'member_nickname': 'Primeiro nome de quem recebe',
  'member_full_name': 'Nome como está no cadastro',
  'member_phone': 'Telefone da pessoa',
  'ministry_role': 'Função dela no ministério',
  'ministry_name': 'Nome do ministério',
};

/// Mensagem com que a aba abre.
const String kMinistryDefaultNotice = 'Olá, {member_nickname}!';

final RegExp _variablePattern = RegExp(r'\{(\w+)((?:\|[^}]*)?)\}');

/// Substitui as variáveis de [template] pelos dados de [member].
///
/// Variável desconhecida vira texto vazio — é o mesmo que o `TemplateEngine`
/// do dispatch faz quando nenhum resolver responde. A tela avisa antes quais
/// são, via [unresolvedMinistryVariables]; aqui não há como avisar, só como
/// não inventar valor.
///
/// Dos modificadores do motor de mensagens, só `|default:` é aplicado: nenhuma
/// variável desta aba é data ou número.
String renderMinistryNotice(
  String template, {
  required MinistryMember member,
  String? ministryName,
}) {
  return template.replaceAllMapped(_variablePattern, (match) {
    final name = match.group(1) ?? '';
    final modifier = match.group(2) ?? '';
    final value = _resolve(name, member: member, ministryName: ministryName);
    if (value.isEmpty && modifier.startsWith('|default:')) {
      return modifier.replaceFirst('|default:', '');
    }
    return value;
  });
}

/// As variáveis de [template] que esta aba não sabe resolver.
///
/// Serve para a tela dizer, antes de qualquer envio, o que vai sair em
/// branco — em vez de deixar a pessoa descobrir na conversa do outro.
Set<String> unresolvedMinistryVariables(String template) {
  final found = <String>{};
  for (final match in _variablePattern.allMatches(template)) {
    final name = match.group(1) ?? '';
    if (name.isEmpty) continue;
    if (!kMinistryNoticeVariables.containsKey(name)) found.add(name);
  }
  return found;
}

String _resolve(
  String name, {
  required MinistryMember member,
  String? ministryName,
}) {
  final fullName = member.memberName.trim();
  switch (name) {
    case 'member_nickname':
      if (fullName.isEmpty) return '';
      final first = fullName.split(RegExp(r'\s+')).first;
      return first;
    case 'member_full_name':
      return fullName;
    case 'member_phone':
      return member.phone?.trim() ?? '';
    case 'ministry_role':
      return member.role.label;
    case 'ministry_name':
      return ministryName ?? '';
    default:
      return '';
  }
}
