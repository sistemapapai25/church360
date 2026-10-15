import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/design/community_design.dart';
import '../../domain/models/course_purchase.dart';
import '../providers/courses_provider.dart';

/// Comprovantes PIX do curso, para a gestão (E6, `courses.manage_lessons`):
/// pendentes primeiro, com "Ver comprovante", "Aprovar" e "Recusar".
/// Aprovar matricula o aluno na turma padrão do curso (o servidor cria
/// "Alunos de ..." se o curso ainda não tiver turma).
class CoursePurchasesScreen extends ConsumerStatefulWidget {
  final String courseId;

  const CoursePurchasesScreen({super.key, required this.courseId});

  @override
  ConsumerState<CoursePurchasesScreen> createState() =>
      _CoursePurchasesScreenState();
}

class _CoursePurchasesScreenState extends ConsumerState<CoursePurchasesScreen> {
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final purchases = ref.watch(coursePurchasesProvider(widget.courseId));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Comprovantes PIX', style: CommunityDesign.titleStyle(context)),
            Text(
              'Aprovar libera o curso para o aluno',
              style: CommunityDesign.metaStyle(context),
            ),
          ],
        ),
      ),
      body: purchases.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nenhum comprovante enviado ainda.',
                  textAlign: TextAlign.center,
                  style: CommunityDesign.contentStyle(context),
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(coursePurchasesProvider(widget.courseId)),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, i) => _tile(items[i]),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      ),
    );
  }

  Widget _tile(CoursePurchase p) {
    final d = p.createdAt.toLocal();
    final sent =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} '
        '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final (label, color) = switch (p.status) {
      'approved' => ('Aprovado', Colors.green),
      'rejected' => ('Recusado', Colors.red),
      _ => ('Pendente', Colors.orange),
    };
    final busy = _busyId == p.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    p.buyerName ?? 'Membro',
                    style: CommunityDesign.titleStyle(
                      context,
                    ).copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Chip(
                  label: Text(label, style: const TextStyle(color: Colors.white)),
                  backgroundColor: color,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [
                if (p.buyerPhone != null && p.buyerPhone!.trim().isNotEmpty)
                  p.buyerPhone!,
                if (p.amount != null) 'R\$ ${p.amount!.toStringAsFixed(2)}',
                'enviado em $sent',
              ].join(' · '),
              style: CommunityDesign.metaStyle(context),
            ),
            if (p.notes != null && p.notes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text('Motivo: ${p.notes}', style: CommunityDesign.metaStyle(context)),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openReceipt(p),
                  icon: const Icon(Icons.receipt_long, size: 18),
                  label: const Text('Ver comprovante'),
                ),
                if (p.isPending) ...[
                  FilledButton.icon(
                    key: ValueKey('approve-${p.id}'),
                    onPressed: busy ? null : () => _review(p, ok: true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aprovar'),
                  ),
                  TextButton.icon(
                    onPressed: busy ? null : () => _reject(p),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Recusar'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openReceipt(CoursePurchase p) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final url = await ref.read(coursesRepositoryProvider).receiptUrl(
        p.receiptPath,
      );
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Não foi possível abrir o comprovante: $e')),
      );
    }
  }

  Future<void> _reject(CoursePurchase p) async {
    final controller = TextEditingController();
    final notes = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recusar comprovante'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: const InputDecoration(
            labelText: 'Motivo (o aluno vê)',
            hintText: 'Ex.: valor diferente do curso',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Recusar'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (notes == null || !mounted) return;
    await _review(p, ok: false, notes: notes);
  }

  Future<void> _review(CoursePurchase p, {required bool ok, String? notes}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busyId = p.id);
    try {
      await ref
          .read(coursePurchaseActionsProvider)
          .review(widget.courseId, p.id, ok: ok, notes: notes);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Aprovado: ${p.buyerName ?? 'o aluno'} já está na turma do curso.'
                : 'Comprovante recusado.',
          ),
          backgroundColor: ok ? Colors.green : null,
        ),
      );
    } catch (e) {
      final msg = e.toString().contains('JA_REVISADO')
          ? 'Esse comprovante já foi revisado.'
          : 'Não foi possível revisar: $e';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}
