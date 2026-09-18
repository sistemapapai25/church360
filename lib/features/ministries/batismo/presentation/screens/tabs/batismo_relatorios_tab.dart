import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../../../core/design/community_design.dart';
import '../../../../../../core/widgets/glass_card.dart';
import '../../../../presentation/providers/ministries_provider.dart';
import '../../../domain/baptism_pdf_renderer.dart';
import '../../../domain/baptism_report_data.dart';
import '../../../domain/models/baptism_student.dart';
import '../../../domain/models/baptism_turma.dart';
import '../../providers/baptism_providers.dart';

/// Aba Relatórios do workspace do Batismo.
///
/// Só lê: gera PDF a partir do que as abas Turmas e Alunos já gravaram.
/// Por isso não há checagem de escrita nem `invalidate` — quem chegou aqui
/// passou pelo `MinistrySubmoduleGuard` do módulo, e nada nesta tela
/// altera o banco.
///
/// A lista de presença por encontro não está aqui de propósito: a tabela de
/// presença ainda não existe, e um relatório de chamada sobre nada
/// imprimiria 0% para todo aluno. Ela entra quando a aba Presença entrar.
class BatismoRelatoriosTab extends ConsumerStatefulWidget {
  final String ministryId;

  const BatismoRelatoriosTab({super.key, required this.ministryId});

  @override
  ConsumerState<BatismoRelatoriosTab> createState() =>
      _BatismoRelatoriosTabState();
}

class _BatismoRelatoriosTabState extends ConsumerState<BatismoRelatoriosTab> {
  /// Turma escolhida no card do relatório de turma. Nulo enquanto ninguém
  /// escolheu — nesse caso vale a primeira da lista.
  String? _turmaId;

  /// Qual relatório está sendo gerado, para travar só o botão daquele card
  /// em vez da tela inteira.
  String? _busy;

  BaptismTurma? _selectedTurma(List<BaptismTurma> turmas) {
    if (turmas.isEmpty) return null;
    for (final t in turmas) {
      if (t.id == _turmaId) return t;
    }
    return turmas.first;
  }

  // -------------------------------------------------------------------
  // Saída: abrir no visualizador ou mandar para o compartilhar
  // -------------------------------------------------------------------

  /// Gera e entrega o PDF.
  ///
  /// `Printing` faz as duas pontas, e é o mesmo pacote que o financeiro e a
  /// escala já usam: `layoutPdf` abre o visualizador (com imprimir e
  /// salvar dentro dele) e `sharePdf` entrega os bytes ao compartilhar do
  /// sistema — na web, vira download.
  Future<void> _emit({
    required String key,
    required String filename,
    required Future<Uint8List> Function() build,
    required bool share,
  }) async {
    setState(() => _busy = key);
    try {
      final bytes = await build();
      if (!mounted) return;
      if (share) {
        await Printing.sharePdf(bytes: bytes, filename: filename);
      } else {
        await Printing.layoutPdf(onLayout: (_) async => bytes, name: filename);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível gerar o PDF: $error')),
      );
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _pickTurma(List<BaptismTurma> turmas) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _TurmaPicker(
        turmas: turmas,
        selectedId: _selectedTurma(turmas)?.id,
      ),
    );
    if (picked != null && mounted) setState(() => _turmaId = picked);
  }

  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(baptismStudentsProvider(widget.ministryId));
    final turmasAsync = ref.watch(baptismTurmasProvider(widget.ministryId));
    final ministryName =
        ref.watch(ministryByIdProvider(widget.ministryId)).maybeWhen(
              data: (m) => m?.name,
              orElse: () => null,
            ) ??
            'Batismo nas Águas';

    if (studentsAsync.isLoading || turmasAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final error = studentsAsync.error ?? turmasAsync.error;
    if (error != null) {
      return _ReportsError(
        message: '$error',
        onRetry: () => invalidateBaptismData(ref, widget.ministryId),
      );
    }

    final students = studentsAsync.value ?? const <BaptismStudent>[];
    final turmas = turmasAsync.value ?? const <BaptismTurma>[];
    final turma = _selectedTurma(turmas);

    final ministryReport = BaptismMinistryReport.build(
      ministryName: ministryName,
      turmas: turmas,
      allStudents: students,
    );
    final turmaReport = turma == null
        ? null
        : BaptismTurmaReport.build(
            turma: turma,
            ministryName: ministryName,
            allStudents: students,
          );

    return RefreshIndicator(
      onRefresh: () async {
        invalidateBaptismData(ref, widget.ministryId);
        await ref.read(baptismStudentsProvider(widget.ministryId).future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          _ReportCard(
            icon: Icons.groups_2_outlined,
            title: 'Relatório da turma',
            description:
                'Lista nominal com situação, data de nascimento, idade e '
                'contato de cada aluno.',
            busy: _busy == _kTurmaKey,
            onOpen: turmaReport == null
                ? null
                : () => _emit(
                      key: _kTurmaKey,
                      filename: _filename('turma', turmaReport.turma.name),
                      share: false,
                      build: () => buildBaptismTurmaPdf(
                        turmaReport,
                        generatedAt: DateTime.now(),
                      ),
                    ),
            onShare: turmaReport == null
                ? null
                : () => _emit(
                      key: _kTurmaKey,
                      filename: _filename('turma', turmaReport.turma.name),
                      share: true,
                      build: () => buildBaptismTurmaPdf(
                        turmaReport,
                        generatedAt: DateTime.now(),
                      ),
                    ),
            child: turma == null
                ? const _NoTurmasNote()
                : _TurmaSelection(
                    turma: turma,
                    report: turmaReport!,
                    onChange:
                        turmas.length < 2 ? null : () => _pickTurma(turmas),
                  ),
          ),
          const SizedBox(height: 12),
          _ReportCard(
            icon: Icons.summarize_outlined,
            title: 'Resumo do ministério',
            description:
                'Alunos por situação, alunos por turma e o total de turmas.',
            busy: _busy == _kMinistryKey,
            onOpen: () => _emit(
              key: _kMinistryKey,
              filename: _filename('resumo', ministryName),
              share: false,
              build: () => buildBaptismMinistryPdf(
                ministryReport,
                generatedAt: DateTime.now(),
              ),
            ),
            onShare: () => _emit(
              key: _kMinistryKey,
              filename: _filename('resumo', ministryName),
              share: true,
              build: () => buildBaptismMinistryPdf(
                ministryReport,
                generatedAt: DateTime.now(),
              ),
            ),
            child: _MinistrySummary(report: ministryReport),
          ),
          const SizedBox(height: 12),
          const _PendingNote(),
        ],
      ),
    );
  }

  /// `relatorio-turma-sexta-19h-2026-09-18.pdf`.
  String _filename(String kind, String label) {
    final slug = label
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final now = DateTime.now();
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final stamp = '${now.year}-$m-$d';
    return 'relatorio-$kind-${slug.isEmpty ? 'batismo' : slug}-$stamp.pdf';
  }
}

const String _kTurmaKey = 'turma';
const String _kMinistryKey = 'ministry';

// ---------------------------------------------------------------------------
// Peças de tela
// ---------------------------------------------------------------------------

/// Um relatório: o que ele traz, uma prévia dos números e as duas saídas.
class _ReportCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget child;
  final bool busy;
  final VoidCallback? onOpen;
  final VoidCallback? onShare;

  const _ReportCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.child,
    required this.busy,
    required this.onOpen,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;

    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: CommunityDesign.titleStyle(context)
                      .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(description, style: CommunityDesign.metaStyle(context)),
          const SizedBox(height: 12),
          child,
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: busy ? null : onOpen,
                  icon: busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(busy ? 'Gerando...' : 'Abrir PDF'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: busy ? null : onShare,
                tooltip: 'Compartilhar PDF',
                icon: const Icon(Icons.ios_share),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A turma escolhida e o que o PDF dela vai conter.
class _TurmaSelection extends StatelessWidget {
  final BaptismTurma turma;
  final BaptismTurmaReport report;

  /// Nulo quando há uma turma só — não há o que escolher.
  final VoidCallback? onChange;

  const _TurmaSelection({
    required this.turma,
    required this.report,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    final meta = [
      formatTurmaPeriod(turma),
      turma.status.label,
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onChange,
          icon: const Icon(Icons.swap_horiz, size: 18),
          label: Text(
            turma.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(shape: const StadiumBorder()),
        ),
        const SizedBox(height: 8),
        Text(meta, style: CommunityDesign.metaStyle(context)),
        const SizedBox(height: 4),
        _TallyText(tally: report.tally, emptyLabel: 'Turma ainda sem alunos'),
      ],
    );
  }
}

/// Os números do ministério, os mesmos que vão para o PDF.
class _MinistrySummary extends StatelessWidget {
  final BaptismMinistryReport report;

  const _MinistrySummary({required this.report});

  @override
  Widget build(BuildContext context) {
    final turmaLine = report.turmaCount == 0
        ? 'Nenhuma turma cadastrada'
        : '${report.turmaCount} '
            '${report.turmaCount == 1 ? 'turma' : 'turmas'} · '
            '${report.activeTurmaCount} '
            '${report.activeTurmaCount == 1 ? 'ativa' : 'ativas'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(turmaLine, style: CommunityDesign.metaStyle(context)),
        const SizedBox(height: 4),
        _TallyText(
          tally: report.tally,
          emptyLabel: 'Nenhum aluno cadastrado ainda',
        ),
      ],
    );
  }
}

/// A contagem por situação em uma linha.
class _TallyText extends StatelessWidget {
  final BaptismStatusTally tally;
  final String emptyLabel;

  const _TallyText({required this.tally, required this.emptyLabel});

  @override
  Widget build(BuildContext context) {
    if (tally.total == 0) {
      return Text(
        emptyLabel,
        style: CommunityDesign.metaStyle(context).copyWith(
          color: Theme.of(context).disabledColor,
        ),
      );
    }

    final parts = [
      for (final s in BaptismStudentStatus.values)
        if (tally.forStatus(s) > 0) '${tally.forStatus(s)} ${s.label}',
    ];

    return Text(
      '${tally.total} ${tally.total == 1 ? 'aluno' : 'alunos'} · '
      '${parts.join(' · ')}',
      style: CommunityDesign.titleStyle(context)
          .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}

class _NoTurmasNote extends StatelessWidget {
  const _NoTurmasNote();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Crie a primeira turma na aba Alunos para poder emitir este relatório.',
      style: CommunityDesign.metaStyle(context).copyWith(
        color: Theme.of(context).disabledColor,
      ),
    );
  }
}

/// O que esta aba ainda não faz, dito na própria aba.
class _PendingNote extends StatelessWidget {
  const _PendingNote();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.schedule_outlined,
            size: 16,
            color: Theme.of(context).disabledColor,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'A lista de presença por encontro entra aqui quando a aba '
              'Presença existir — antes disso ela imprimiria 0% para todo '
              'aluno.',
              style: CommunityDesign.metaStyle(context).copyWith(
                color: Theme.of(context).disabledColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Folha de escolha da turma.
class _TurmaPicker extends StatelessWidget {
  final List<BaptismTurma> turmas;
  final String? selectedId;

  const _TurmaPicker({required this.turmas, required this.selectedId});

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
              'Turma do relatório',
              style: CommunityDesign.titleStyle(context)
                  .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final t in turmas)
                  ListTile(
                    title: Text(t.name),
                    subtitle: Text(
                      '${formatTurmaPeriod(t)} · ${t.status.label}',
                    ),
                    trailing: t.id == selectedId
                        ? const Icon(Icons.check, size: 20)
                        : null,
                    onTap: () => Navigator.of(context).pop(t.id),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportsError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ReportsError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar os dados dos relatórios.',
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
