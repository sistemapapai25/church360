import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../../core/design/app_icons.dart';
import '../../../../../../core/design/community_design.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../../../../core/utils/whatsapp_launcher.dart';
import '../../../../../../core/widgets/app_filter_bar.dart';
import '../../../../../../core/widgets/glass_card.dart';
import '../../../../../dispatch/presentation/providers/dispatch_providers.dart';
import '../../../../presentation/providers/ministries_provider.dart';
import '../../../domain/models/baptism_student.dart';
import '../../../domain/models/baptism_turma.dart';
import '../../providers/baptism_providers.dart';

// ---------------------------------------------------------------------------
// Peças puras — ficam fora do widget para poderem ser testadas sem tela.
// ---------------------------------------------------------------------------

/// As variáveis que esta aba sabe substituir, com a explicação que aparece
/// na tela.
///
/// Os nomes espelham o `VariableRegistry` de `features/dispatch` onde há
/// equivalente, para que um modelo escrito aqui continue valendo lá. Duas
/// ressalvas honestas, repetidas na interface:
///
/// - `member_nickname` vira o **primeiro nome** do aluno: a ficha do batismo
///   não tem apelido, e o resolver global só acha apelido de quem tem
///   `user_account` — o candidato ao batismo quase nunca tem.
/// - `turma_name` só existe aqui. O registry global não conhece turma.
const Map<String, String> kBatismoWhatsAppVariables = {
  'member_nickname': 'Primeiro nome do aluno',
  'member_full_name': 'Nome completo do aluno',
  'member_phone': 'Telefone do aluno',
  'turma_name': 'Nome da turma',
  'ministry_name': 'Nome do ministério',
};

/// Mensagem com que a aba abre — a mesma saudação que a aba Alunos já usa.
const String kBatismoDefaultMessage = 'Olá, {member_nickname}!';

final RegExp _variablePattern = RegExp(r'\{([a-zA-Z0-9_]+)(\|[^}]*)?\}');

/// Em que pé está o telefone do aluno.
///
/// São três estados, e não dois, porque campo preenchido não é o mesmo que
/// número discável: `"(11) "` tem dígito e não leva a lugar nenhum — o
/// [launchWhatsAppMessage] prepende 55 e abre `wa.me/5511`, uma conversa
/// que não existe. Separar [incomplete] de [missing] é o que faz a tela
/// dizer *por que* aquele aluno não pode ser acionado.
enum StudentPhoneState {
  /// Dá para abrir a conversa.
  usable,

  /// Tem dígito, mas não o suficiente para um número brasileiro.
  incomplete,

  /// Campo vazio.
  missing,
}

/// Classifica o telefone do aluno pela convenção do app (números do Brasil,
/// como o [launchWhatsAppMessage] assume): 10 ou 11 dígitos com DDD, ou já
/// no formato internacional começando por 55.
StudentPhoneState studentPhoneState(BaptismStudent student) {
  final digits = (student.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return StudentPhoneState.missing;
  if (digits.startsWith('55') && digits.length >= 12) {
    return StudentPhoneState.usable;
  }
  if (digits.length == 10 || digits.length == 11) {
    return StudentPhoneState.usable;
  }
  return StudentPhoneState.incomplete;
}

/// Se dá para abrir uma conversa com este aluno.
bool studentHasWhatsAppPhone(BaptismStudent student) =>
    studentPhoneState(student) == StudentPhoneState.usable;

/// Substitui as variáveis de [template] pelos dados de [student].
///
/// Variável que esta aba não conhece vira texto vazio — é o mesmo que o
/// `TemplateEngine` do dispatch faz quando nenhum resolver responde. A tela
/// avisa antes quais são elas, via [unresolvedBatismoVariables]; aqui não há
/// como avisar, só como não inventar valor.
///
/// Dos modificadores do motor de mensagens, só `|default:` é aplicado. Os
/// outros (`|date:`, `|number:`) não teriam o que formatar: nenhuma variável
/// desta aba é data ou número.
String renderBatismoMessage(
  String template, {
  required BaptismStudent student,
  String? ministryName,
}) {
  return template.replaceAllMapped(_variablePattern, (match) {
    final name = match.group(1) ?? '';
    final modifier = match.group(2) ?? '';
    final value = _resolve(name, student: student, ministryName: ministryName);
    if (value.isEmpty && modifier.startsWith('|default:')) {
      return modifier.replaceFirst('|default:', '');
    }
    return value;
  });
}

/// As variáveis de [template] que esta aba não sabe resolver.
///
/// Serve para a tela dizer, antes de qualquer envio, o que vai sair em
/// branco — em vez de deixar a pessoa descobrir na conversa do aluno.
Set<String> unresolvedBatismoVariables(String template) {
  final found = <String>{};
  for (final match in _variablePattern.allMatches(template)) {
    final name = match.group(1) ?? '';
    if (name.isEmpty) continue;
    if (!kBatismoWhatsAppVariables.containsKey(name)) found.add(name);
  }
  return found;
}

String _resolve(
  String name, {
  required BaptismStudent student,
  String? ministryName,
}) {
  switch (name) {
    case 'member_nickname':
      return student.firstName;
    case 'member_full_name':
      return student.fullName.trim();
    case 'member_phone':
      return student.phone?.trim() ?? '';
    case 'turma_name':
      return student.turmaName ?? '';
    case 'ministry_name':
      return ministryName ?? '';
    default:
      return '';
  }
}

// ---------------------------------------------------------------------------
// A aba
// ---------------------------------------------------------------------------

/// Aba WhatsApp do workspace do Batismo.
///
/// Não grava nada: é uma tela de saída. Por isso não há `invalidate` depois
/// de agir nem checagem de escrita — quem chegou aqui já passou pelo
/// `MinistrySubmoduleGuard` do módulo.
///
/// **O que esta aba não faz, de propósito:** disparo em lote de verdade.
/// `wa.me` abre uma conversa por vez e não existe caminho de envio em massa
/// por ele. A mensagem da turma percorre uma fila com confirmação a cada
/// aluno, e a tela diz isso com todas as letras — prometer envio em massa
/// aqui seria mentira de interface.
class BatismoWhatsAppTab extends ConsumerStatefulWidget {
  final String ministryId;

  const BatismoWhatsAppTab({super.key, required this.ministryId});

  @override
  ConsumerState<BatismoWhatsAppTab> createState() => _BatismoWhatsAppTabState();
}

class _BatismoWhatsAppTabState extends ConsumerState<BatismoWhatsAppTab> {
  final _search = TextEditingController();
  final _message = TextEditingController(text: kBatismoDefaultMessage);

  String _query = '';
  String _turmaId = _TurmaFilter.all;

  /// O status padrão é **ativo**, e o filtro fica visível dizendo isso.
  ///
  /// Mandar aviso de aula para quem desistiu é o erro que a lista completa
  /// provoca. O filtro continua na tela para quem precisar do contrário — o
  /// padrão não esconde nada, só evita o disparo errado.
  BaptismStudentStatus? _status = BaptismStudentStatus.ativo;

  /// Nome do modelo escolhido, ou nulo para mensagem escrita na hora.
  String? _templateName;

  @override
  void dispose() {
    _search.dispose();
    _message.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Seleção (pura, para poder ser testada)
  // -------------------------------------------------------------------

  /// Filtra e ordena a lista.
  ///
  /// Quem tem telefone vem primeiro: são os alunos com quem dá para fazer
  /// alguma coisa nesta tela. Dentro de cada grupo, nome A-Z.
  List<BaptismStudent> _apply(List<BaptismStudent> students) {
    final query = _query.trim().toLowerCase();
    final digits = _query.replaceAll(RegExp(r'[^0-9]'), '');

    final filtered = students.where((s) {
      if (_status != null && s.status != _status) return false;
      if (_turmaId != _TurmaFilter.all && s.turmaId != _turmaId) return false;
      if (query.isEmpty) return true;
      if (s.fullName.trim().toLowerCase().contains(query)) return true;
      if (digits.isNotEmpty) {
        final phone = (s.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        if (phone.isNotEmpty && phone.contains(digits)) return true;
      }
      return false;
    }).toList();

    filtered.sort((a, b) {
      final phoneA = studentHasWhatsAppPhone(a);
      final phoneB = studentHasWhatsAppPhone(b);
      if (phoneA != phoneB) return phoneA ? -1 : 1;
      return a.fullName.trim().toLowerCase().compareTo(
        b.fullName.trim().toLowerCase(),
      );
    });

    return filtered;
  }

  // -------------------------------------------------------------------
  // Ações
  // -------------------------------------------------------------------

  Future<void> _sendToOne(BaptismStudent student, String? ministryName) async {
    final result = await launchWhatsAppMessage(
      phone: student.phone,
      message: renderBatismoMessage(
        _message.text,
        student: student,
        ministryName: ministryName,
      ),
    );
    if (!mounted || result == WhatsAppLaunchResult.launched) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == WhatsAppLaunchResult.invalidPhone
              ? '${student.fullName} não tem um telefone válido cadastrado.'
              : 'Não foi possível abrir o WhatsApp neste dispositivo.',
        ),
      ),
    );
  }

  Future<void> _sendToMany(
    List<BaptismStudent> students,
    String? ministryName,
  ) async {
    final queue = students.where(studentHasWhatsAppPhone).toList();
    if (queue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhum aluno desta seleção tem telefone cadastrado.'),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _QueueDialog(
        students: queue,
        template: _message.text,
        ministryName: ministryName,
      ),
    );
  }

  Future<void> _pickTemplate(List<MessageTemplate> templates) async {
    final picked = await showModalBottomSheet<MessageTemplate>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TemplateSheet(templates: templates),
    );
    if (picked == null || !mounted) return;

    // Id vazio é o item "Mensagem escrita na hora" da folha.
    final custom = picked.id.isEmpty;
    setState(() {
      _templateName = custom ? null : picked.name;
      _message.text = custom ? kBatismoDefaultMessage : picked.content;
    });
  }

  Future<void> _pickTurma(List<BaptismTurma> turmas) async {
    final picked = await _pickOption<String>(
      title: 'Turma',
      current: _turmaId,
      options: [
        (_TurmaFilter.all, 'Todas as turmas'),
        for (final t in turmas) (t.id, t.name),
      ],
    );
    if (picked != null && mounted) setState(() => _turmaId = picked);
  }

  Future<void> _pickStatus() async {
    final picked = await _pickOption<String>(
      title: 'Status',
      current: _status?.code ?? 'all',
      options: [
        ('all', 'Todos os status'),
        for (final s in BaptismStudentStatus.values) (s.code, s.label),
      ],
    );
    if (picked == null || !mounted) return;
    setState(() {
      _status = picked == 'all' ? null : BaptismStudentStatus.fromCode(picked);
    });
  }

  Future<T?> _pickOption<T>({
    required String title,
    required List<(T, String)> options,
    required T current,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                style: CommunityDesign.titleStyle(
                  context,
                ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            for (final option in options)
              ListTile(
                title: Text(option.$2),
                trailing: option.$1 == current
                    ? const Icon(AppIcons.check, size: 18)
                    : null,
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
          ],
        ),
      ),
    );
  }

  /// Insere a variável onde o cursor estiver.
  ///
  /// Sem cursor posicionado (campo que nunca recebeu foco) a variável vai
  /// para o fim do texto — melhor do que sobrescrever o começo.
  void _insertVariable(String name) {
    final text = _message.text;
    final selection = _message.selection;
    final token = '{$name}';
    final valid = selection.isValid;
    final start = valid ? selection.start : text.length;
    final end = valid ? selection.end : text.length;

    _message.value = TextEditingValue(
      text: text.replaceRange(start, end, token),
      selection: TextSelection.collapsed(offset: start + token.length),
    );
    setState(() {});
  }

  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(baptismStudentsProvider(widget.ministryId));
    final turmas = ref
        .watch(baptismTurmasProvider(widget.ministryId))
        .maybeWhen(data: (t) => t, orElse: () => const <BaptismTurma>[]);
    final ministryName = ref
        .watch(ministryByIdProvider(widget.ministryId))
        .maybeWhen(data: (m) => m?.name, orElse: () => null);
    // Modelos são um conforto, não um requisito: se a consulta falhar ou o
    // usuário não puder lê-los, a aba segue funcionando com texto livre.
    final templates = ref
        .watch(allMessageTemplatesProvider)
        .maybeWhen(
          data: (list) => list.where((t) => t.isActive).toList(),
          orElse: () => const <MessageTemplate>[],
        );

    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => _WhatsAppError(
        message: '$error',
        onRetry: () => invalidateBaptismData(ref, widget.ministryId),
      ),
      data: (students) {
        final visible = _apply(students);
        final withPhone = visible.where(studentHasWhatsAppPhone).length;
        final incomplete = visible
            .where((s) => studentPhoneState(s) == StudentPhoneState.incomplete)
            .length;

        return RefreshIndicator(
          onRefresh: () async {
            invalidateBaptismData(ref, widget.ministryId);
            await ref.read(baptismStudentsProvider(widget.ministryId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              AppFilterBar(
                searchController: _search,
                searchHint: 'Buscar por nome ou WhatsApp...',
                onSearchChanged: (v) => setState(() => _query = v),
                filters: [
                  AppFilterButton(
                    label: _status?.label ?? 'Todos os status',
                    icon: AppIcons.followUp,
                    active: _status != null,
                    onTap: _pickStatus,
                  ),
                  AppFilterButton(
                    label: _turmaLabel(turmas),
                    icon: AppIcons.group,
                    active: _turmaId != _TurmaFilter.all,
                    onTap: () => _pickTurma(turmas),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _MessageComposer(
                controller: _message,
                templateName: _templateName,
                onPickTemplate: () => _pickTemplate(templates),
                onInsertVariable: _insertVariable,
                onChanged: () => setState(() {}),
                previewStudent: visible.isEmpty ? null : visible.first,
                ministryName: ministryName,
                readyCount: withPhone,
                onSendToMany: withPhone == 0
                    ? null
                    : () => _sendToMany(visible, ministryName),
              ),
              const SizedBox(height: 14),
              _PhoneCountLine(
                withPhone: withPhone,
                total: visible.length,
                statusLabel: _status?.label,
                incomplete: incomplete,
              ),
              const SizedBox(height: 10),
              if (visible.isEmpty)
                _EmptyState(
                  hasStudents: students.isNotEmpty,
                  hasTurmas: turmas.isNotEmpty,
                )
              else
                for (final s in visible)
                  _StudentRow(
                    student: s,
                    onSend: studentHasWhatsAppPhone(s)
                        ? () => _sendToOne(s, ministryName)
                        : null,
                  ),
            ],
          ),
        );
      },
    );
  }

  String _turmaLabel(List<BaptismTurma> turmas) {
    if (_turmaId == _TurmaFilter.all) return 'Todas as turmas';
    for (final t in turmas) {
      if (t.id == _turmaId) return t.name;
    }
    return 'Turma';
  }
}

/// Filtro de turma. Espelha o da aba Alunos: `turma_id` é NOT NULL, então
/// não existe "sem turma".
class _TurmaFilter {
  static const all = 'all';
}

// ---------------------------------------------------------------------------
// Peças de tela
// ---------------------------------------------------------------------------

/// O bloco de escrever a mensagem: modelo, texto, variáveis, prévia e o
/// botão da fila.
class _MessageComposer extends StatelessWidget {
  final TextEditingController controller;
  final String? templateName;
  final VoidCallback onPickTemplate;
  final ValueChanged<String> onInsertVariable;
  final VoidCallback onChanged;

  /// Aluno usado na prévia — o primeiro da lista visível, ou nulo quando
  /// não há ninguém.
  final BaptismStudent? previewStudent;
  final String? ministryName;

  final int readyCount;
  final VoidCallback? onSendToMany;

  const _MessageComposer({
    required this.controller,
    required this.templateName,
    required this.onPickTemplate,
    required this.onInsertVariable,
    required this.onChanged,
    required this.previewStudent,
    required this.ministryName,
    required this.readyCount,
    required this.onSendToMany,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;
    final unresolved = unresolvedBatismoVariables(controller.text);
    final student = previewStudent;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mensagem',
                  style: CommunityDesign.titleStyle(
                    context,
                  ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: onPickTemplate,
                icon: const Icon(AppIcons.description, size: 18),
                label: Text(templateName ?? 'Escolher modelo'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            keyboardType: TextInputType.multiline,
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              hintText: 'Escreva a mensagem que será aberta no WhatsApp...',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Toque para inserir:',
            style: CommunityDesign.metaStyle(context),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final entry in kBatismoWhatsAppVariables.entries)
                Tooltip(
                  message: entry.value,
                  child: ActionChip(
                    label: Text('{${entry.key}}'),
                    onPressed: () => onInsertVariable(entry.key),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
          if (unresolved.isNotEmpty) ...[
            const SizedBox(height: 10),
            _Notice(
              icon: AppIcons.info,
              text: unresolved.length == 1
                  ? 'A variável {${unresolved.first}} não existe nesta aba e '
                        'vai sair em branco na mensagem.'
                  : 'Estas variáveis não existem nesta aba e vão sair em '
                        'branco: ${unresolved.map((v) => '{$v}').join(', ')}.',
            ),
          ],
          if (student != null) ...[
            const SizedBox(height: 12),
            Text(
              'Prévia — ${student.fullName}',
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 4),
            Text(
              renderBatismoMessage(
                controller.text,
                student: student,
                ministryName: ministryName,
              ),
              style: CommunityDesign.contentStyle(context),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onSendToMany,
              icon: const Icon(AppIcons.message, size: 18),
              label: Text(
                readyCount == 0
                    ? 'Ninguém desta seleção tem telefone'
                    : 'Abrir conversas da seleção ($readyCount)',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'O WhatsApp abre uma conversa por vez: a fila vai de aluno em '
            'aluno, e você confirma cada um. Não existe envio em massa por '
            'este caminho.',
            style: CommunityDesign.metaStyle(context).copyWith(color: muted),
          ),
        ],
      ),
    );
  }
}

/// Folha de escolha de modelo.
///
/// Os modelos vêm de `message_template`, o mesmo catálogo do módulo de
/// disparos — o Batismo não tem tabela de modelo própria, de propósito.
class _TemplateSheet extends StatelessWidget {
  final List<MessageTemplate> templates;

  const _TemplateSheet({required this.templates});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Modelo de mensagem',
              style: CommunityDesign.titleStyle(
                context,
              ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(AppIcons.edit),
            title: const Text('Escrever na hora'),
            subtitle: const Text('Volta para a saudação padrão'),
            onTap: () => Navigator.of(context).pop(
              MessageTemplate(
                id: '',
                name: '',
                content: '',
                variables: const [],
                isActive: true,
                createdAt: DateTime.now(),
              ),
            ),
          ),
          if (templates.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                'Nenhum modelo ativo cadastrado. Os modelos ficam em '
                'Configurações › Disparos e valem para o app inteiro.',
                style: CommunityDesign.metaStyle(context),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in templates)
                    ListTile(
                      leading: const Icon(AppIcons.description),
                      title: Text(t.name),
                      subtitle: Text(
                        t.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(t),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A fila de conversas.
///
/// Um aluno por vez, com confirmação. O contador de abertas/puladas/falhas
/// é o que resta como prova do que foi feito — `wa.me` não devolve nenhuma
/// confirmação de entrega, e inventar um "enviado" aqui seria falso.
class _QueueDialog extends StatefulWidget {
  final List<BaptismStudent> students;
  final String template;
  final String? ministryName;

  const _QueueDialog({
    required this.students,
    required this.template,
    required this.ministryName,
  });

  @override
  State<_QueueDialog> createState() => _QueueDialogState();
}

class _QueueDialogState extends State<_QueueDialog> {
  int _index = 0;
  int _opened = 0;
  int _skipped = 0;
  final List<String> _failures = [];
  bool _busy = false;

  bool get _done => _index >= widget.students.length;

  Future<void> _open() async {
    final student = widget.students[_index];
    setState(() => _busy = true);

    final result = await launchWhatsAppMessage(
      phone: student.phone,
      message: renderBatismoMessage(
        widget.template,
        student: student,
        ministryName: widget.ministryName,
      ),
    );
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (result == WhatsAppLaunchResult.launched) {
        _opened++;
      } else {
        _failures.add(
          '${student.fullName} — ${result == WhatsAppLaunchResult.invalidPhone ? 'telefone inválido' : 'não abriu no dispositivo'}',
        );
      }
      _index++;
    });
  }

  void _skip() {
    setState(() {
      _skipped++;
      _index++;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return _summary(context);

    final student = widget.students[_index];
    final message = renderBatismoMessage(
      widget.template,
      student: student,
      ministryName: widget.ministryName,
    );

    return AlertDialog(
      title: Text('Aluno ${_index + 1} de ${widget.students.length}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            student.fullName,
            style: CommunityDesign.titleStyle(
              context,
            ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (student.phone != null) ...[
            const SizedBox(height: 2),
            Text(student.phone!, style: CommunityDesign.metaStyle(context)),
          ],
          const SizedBox(height: 10),
          Text(message, style: CommunityDesign.contentStyle(context)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Parar'),
        ),
        TextButton(onPressed: _busy ? null : _skip, child: const Text('Pular')),
        FilledButton(
          onPressed: _busy ? null : _open,
          child: const Text('Abrir conversa'),
        ),
      ],
    );
  }

  Widget _summary(BuildContext context) {
    return AlertDialog(
      title: const Text('Fila concluída'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$_opened ${_opened == 1 ? 'conversa aberta' : 'conversas abertas'}'
            '${_skipped > 0 ? ', $_skipped ${_skipped == 1 ? 'pulado' : 'pulados'}' : ''}.',
            style: CommunityDesign.contentStyle(context),
          ),
          if (_failures.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Não deu para abrir:',
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 4),
            for (final f in _failures)
              Text('• $f', style: CommunityDesign.metaStyle(context)),
          ],
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

/// A contagem honesta do topo da lista.
///
/// Telefone é opcional no cadastro do aluno — e no cadastro de membros está
/// preenchido em 21 de 199 fichas. Se a proporção se repetir aqui, esta aba
/// nasce quase vazia. Sem esta linha, a tela pareceria quebrada; com ela,
/// fica claro que o que falta é dado.
class _PhoneCountLine extends StatelessWidget {
  final int withPhone;
  final int total;
  final String? statusLabel;

  /// Quantos têm telefone gravado que não dá para discar. Ficam de fora de
  /// [withPhone] e mesmo assim precisam aparecer: são fichas que alguém
  /// consegue consertar, não fichas vazias.
  final int incomplete;

  const _PhoneCountLine({
    required this.withPhone,
    required this.total,
    required this.statusLabel,
    required this.incomplete,
  });

  @override
  Widget build(BuildContext context) {
    final status = statusLabel?.toLowerCase();
    final plural = total != 1;
    final noun = plural ? 'alunos' : 'aluno';
    final qualified = status == null
        ? noun
        : '$noun $status${plural ? 's' : ''}';

    final String text;
    if (total == 0) {
      text = status == null
          ? 'Nenhum aluno nesta seleção'
          : 'Nenhum aluno $status nesta seleção';
    } else {
      final incompleteSuffix = incomplete == 0
          ? ''
          : ' · $incomplete com telefone incompleto';
      text =
          '$withPhone de $total $qualified '
          '${withPhone == 1 ? 'tem' : 'têm'} telefone$incompleteSuffix';
    }

    return Text(text, style: CommunityDesign.metaStyle(context));
  }
}

/// Uma linha da lista: quem é, e o que dá (ou não dá) para fazer com ele.
class _StudentRow extends StatelessWidget {
  final BaptismStudent student;

  /// Nulo quando o aluno não tem telefone — o botão apaga e o motivo
  /// aparece escrito, não só no tooltip.
  final VoidCallback? onSend;

  const _StudentRow({required this.student, required this.onSend});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppTheme.darkRing : AppTheme.primary;
    final muted = dark
        ? AppTheme.darkMutedForeground
        : AppTheme.mutedForeground;
    final phone = student.phone?.trim() ?? '';
    final hasPhone = onSend != null;
    final state = studentPhoneState(student);

    final meta = <String>[
      if (student.turmaName != null) student.turmaName!,
      switch (state) {
        StudentPhoneState.usable => phone,
        StudentPhoneState.incomplete => 'Telefone incompleto: $phone',
        StudentPhoneState.missing => 'Sem telefone cadastrado',
      },
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GlassCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.fullName,
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: CommunityDesign.metaStyle(
                      context,
                    ).copyWith(color: hasPhone ? null : muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: onSend,
              tooltip: switch (state) {
                StudentPhoneState.usable => 'Abrir conversa no WhatsApp',
                StudentPhoneState.incomplete =>
                  'Telefone incompleto — não dá para abrir a conversa',
                StudentPhoneState.missing => 'Aluno sem telefone cadastrado',
              },
              icon: Icon(
                AppIcons.message,
                color: hasPhone ? accent : Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Notice({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 6),
        Expanded(child: Text(text, style: CommunityDesign.metaStyle(context))),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasStudents;
  final bool hasTurmas;

  const _EmptyState({required this.hasStudents, required this.hasTurmas});

  @override
  Widget build(BuildContext context) {
    final String message;
    if (hasStudents) {
      message = 'Nenhum aluno encontrado com esses filtros.';
    } else if (!hasTurmas) {
      message =
          'Crie a primeira turma e cadastre alunos para poder falar '
          'com eles por aqui.';
    } else {
      message = 'Nenhum aluno cadastrado ainda.';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(
            hasStudents ? AppIcons.searchEmpty : AppIcons.message,
            size: 36,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: CommunityDesign.metaStyle(context),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _WhatsAppError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.error, size: 40),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar os alunos.',
              textAlign: TextAlign.center,
              style: CommunityDesign.titleStyle(context).copyWith(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: CommunityDesign.metaStyle(context),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
