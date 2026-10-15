import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/community_design.dart';
import '../../domain/models/course.dart';
import '../../domain/models/course_purchase.dart';
import '../hub/course_hub.dart';
import '../providers/courses_provider.dart';

/// Limite do bucket `course-receipts` (5 MB).
const int courseReceiptMaxBytes = 5 * 1024 * 1024;

/// Card "Curso pago" (E6): valor, chave PIX com "Copiar" e o estado da
/// compra de quem está olhando. Quem já é aluno ou gestão vê só o valor.
///
/// O estado vem de `course_purchase` (RLS own): sem compra ou recusada
/// → "Enviar comprovante do PIX"; pendente → "em análise"; aprovada →
/// "Pagamento confirmado".
class CoursePurchaseCard extends ConsumerStatefulWidget {
  final Course course;

  const CoursePurchaseCard({super.key, required this.course});

  @override
  ConsumerState<CoursePurchaseCard> createState() => _CoursePurchaseCardState();
}

class _CoursePurchaseCardState extends ConsumerState<CoursePurchaseCard> {
  bool _sending = false;

  Course get course => widget.course;

  @override
  Widget build(BuildContext context) {
    final purchase = ref.watch(myCoursePurchaseProvider(course.id)).valueOrNull;
    final hub = ref.watch(courseHubProvider(course.id)).valueOrNull;
    // Já tem acesso (aluno) ou cuida do curso: nada a comprar.
    final canBuy = hub != null && !hub.isStudent && !hub.management;
    final pixInfo = course.paymentInfo?.trim() ?? '';

    return Container(
      decoration: CommunityDesign.overlayDecoration(
        Theme.of(context).colorScheme,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.payment, color: Colors.orange),
                SizedBox(width: 8),
                Text(
                  'Curso Pago',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (course.price != null)
              Text(
                'Valor: R\$ ${course.price!.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            if (pixInfo.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Informações de Pagamento:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(pixInfo, style: const TextStyle(fontSize: 14)),
                  ),
                  IconButton(
                    tooltip: 'Copiar',
                    icon: const Icon(Icons.copy, size: 20),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: pixInfo));
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copiado.')),
                      );
                    },
                  ),
                ],
              ),
            ],
            if (purchase != null) ...[
              const SizedBox(height: 12),
              _PurchaseStatus(purchase: purchase),
            ],
            if (canBuy && (purchase == null || purchase.isRejected)) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  key: const ValueKey('send-receipt'),
                  onPressed: _sending ? null : _buy,
                  icon: const Icon(Icons.upload_file),
                  label: Text(
                    _sending
                        ? 'Enviando...'
                        : purchase == null
                        ? 'Enviar comprovante do PIX'
                        : 'Enviar outro comprovante',
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Faça o PIX, envie a foto ou o PDF do comprovante e a '
                'liderança libera o curso para você.',
                style: CommunityDesign.metaStyle(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _buy() async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );
    final file = picked?.files.firstOrNull;
    if (file == null || !mounted) return;
    final bytes = file.bytes;
    if (bytes == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Não foi possível ler o arquivo.')),
      );
      return;
    }
    if (bytes.length > courseReceiptMaxBytes) {
      messenger.showSnackBar(
        const SnackBar(content: Text('O comprovante precisa ter até 5 MB.')),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await ref
          .read(coursePurchaseActionsProvider)
          .buy(courseId: course.id, bytes: bytes, fileName: file.name);
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Comprovante enviado. A liderança confere e libera o curso.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      final msg = e.toString().contains('JA_APROVADO')
          ? 'Seu pagamento já foi confirmado.'
          : 'Não foi possível enviar o comprovante: $e';
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _PurchaseStatus extends StatelessWidget {
  final CoursePurchase purchase;

  const _PurchaseStatus({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final d = purchase.createdAt.toLocal();
    final sent =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final (icon, color, text) = switch (purchase.status) {
      'approved' => (Icons.check_circle, Colors.green, 'Pagamento confirmado'),
      'rejected' => (
        Icons.cancel,
        Colors.red,
        'Comprovante recusado'
            '${purchase.notes == null ? '' : ': ${purchase.notes}'}',
      ),
      _ => (
        Icons.hourglass_top,
        Colors.orange,
        'Comprovante em análise (enviado em $sent)',
      ),
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
