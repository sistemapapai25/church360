import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../../../core/design/community_design.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../domain/certificate_pdf.dart';
import '../../domain/models/course_quiz.dart';
import '../providers/courses_provider.dart';

/// Página pública do certificado (`/certificado/:code`, E5): quem tem o
/// código valida; o aluno baixa o PDF daqui. Lê por `certificate_lookup`
/// (anon), então abre sem login.
class CertificateScreen extends ConsumerStatefulWidget {
  final String code;

  const CertificateScreen({super.key, required this.code});

  @override
  ConsumerState<CertificateScreen> createState() => _CertificateScreenState();
}

class _CertificateScreenState extends ConsumerState<CertificateScreen> {
  bool _busy = false;

  Future<void> _pdf(CertificateInfo info) async {
    setState(() => _busy = true);
    try {
      final bytes = await buildCertificatePdf(info);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'certificado-${info.code}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Não foi possível gerar o PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lookup = ref.watch(certificateLookupProvider(widget.code));
    return Scaffold(
      backgroundColor: CommunityDesign.scaffoldBackgroundColor(context),
      appBar: AppBar(
        backgroundColor: CommunityDesign.headerColor(context),
        title: const Text('Certificado'),
      ),
      body: lookup.when(
        data: (info) {
          if (info == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.search_off, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      'Certificado não encontrado',
                      style: CommunityDesign.titleStyle(context),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Confira o código ${widget.code}.',
                      style: CommunityDesign.metaStyle(context),
                    ),
                  ],
                ),
              ),
            );
          }
          final d = info.issuedAt.toLocal();
          final date =
              '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: ListView(
                padding: const EdgeInsets.all(16),
                shrinkWrap: true,
                children: [
                  GlassCard(
                    child: Column(
                      children: [
                        Icon(
                          Icons.workspace_premium_rounded,
                          size: 64,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          info.churchName,
                          textAlign: TextAlign.center,
                          style: CommunityDesign.metaStyle(context),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Certificamos que',
                          style: CommunityDesign.contentStyle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          info.personName,
                          key: const ValueKey('certificate-name'),
                          textAlign: TextAlign.center,
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 24, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'concluiu o curso',
                          style: CommunityDesign.contentStyle(context),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          info.courseTitle,
                          textAlign: TextAlign.center,
                          style: CommunityDesign.titleStyle(
                            context,
                          ).copyWith(fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Emitido em $date · código ${info.code}',
                          textAlign: TextAlign.center,
                          style: CommunityDesign.metaStyle(context),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 44,
                          child: FilledButton.icon(
                            key: const ValueKey('certificate-pdf'),
                            onPressed: _busy ? null : () => _pdf(info),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: const Text('Baixar PDF'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Este certificado é válido: o código acima foi emitido pelo app da igreja.',
                    textAlign: TextAlign.center,
                    style: CommunityDesign.metaStyle(context),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Erro ao validar o certificado: $error')),
      ),
    );
  }
}
