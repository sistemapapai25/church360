import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/church_info/presentation/providers/church_info_provider.dart';
import 'app_logo.dart';

/// O que o QR deixa fazer. Não há padrão universal: credencial (carteirinha,
/// Kids) não passa nenhuma. Regra em .planning/ROADMAP-2026-10-19-QR-CODES.md §2.3.
enum ChurchQrAction { share, print }

/// QR único do app: fundo branco e módulos pretos em qualquer tema, logo da
/// igreja no centro (correção H) e título dentro do cartão, para que a imagem
/// compartilhada/impressa saia igual à tela.
class ChurchQrCard extends ConsumerStatefulWidget {
  final String data;
  final String title;
  final String? subtitle;

  /// Mostra "Válido até HH:mm" e conta o tempo; vencido, apaga o QR.
  final DateTime? expiresAt;
  final VoidCallback? onRefresh;
  final Set<ChurchQrAction> actions;

  /// Texto que acompanha a imagem no Compartilhar (ex.: o link).
  final String? shareText;
  final bool brightnessHint;
  final double size;

  const ChurchQrCard({
    super.key,
    required this.data,
    required this.title,
    this.subtitle,
    this.expiresAt,
    this.onRefresh,
    this.actions = const {},
    this.shareText,
    this.brightnessHint = false,
    this.size = 220,
  });

  @override
  ConsumerState<ChurchQrCard> createState() => _ChurchQrCardState();
}

class _ChurchQrCardState extends ConsumerState<ChurchQrCard> {
  final _boundary = GlobalKey();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    if (widget.expiresAt != null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  bool get _expired =>
      widget.expiresAt != null && DateTime.now().isAfter(widget.expiresAt!);

  Future<Uint8List> _png() async {
    final boundary =
        _boundary.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  String get _fileName =>
      'qr_${widget.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

  Future<void> _share() async {
    final png = await _png();
    // No web sem Web Share, o share_plus baixa o arquivo.
    await Share.shareXFiles([
      XFile.fromData(png, name: '$_fileName.png', mimeType: 'image/png'),
    ], text: widget.shareText);
  }

  Future<void> _print() async {
    final png = pw.MemoryImage(await _png());
    final doc = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) => pw.Center(child: pw.Image(png, width: 360)),
        ),
      );
    await Printing.layoutPdf(
      onLayout: (_) async => doc.save(),
      name: '$_fileName.pdf',
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar a imagem do QR.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final church = ref.watch(churchInfoProvider).valueOrNull;
    final logoUrl = church?.logoUrl?.trim() ?? '';
    final hasLogo = logoUrl.isNotEmpty;
    final logoSize = widget.size * 0.22;
    final cs = Theme.of(context).colorScheme;
    final expiresAt = widget.expiresAt;

    final qr = Stack(
      alignment: Alignment.center,
      children: [
        QrImageView(
          data: widget.data,
          size: widget.size,
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white,
          errorCorrectionLevel: hasLogo
              ? QrErrorCorrectLevel.H
              : QrErrorCorrectLevel.M,
          eyeStyle: const QrEyeStyle(
            eyeShape: QrEyeShape.square,
            color: Colors.black,
          ),
          dataModuleStyle: const QrDataModuleStyle(
            dataModuleShape: QrDataModuleShape.square,
            color: Colors.black,
          ),
        ),
        if (hasLogo)
          Container(
            width: logoSize,
            height: logoSize,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: ChurchLogo(url: logoUrl, name: church?.name ?? ''),
            ),
          ),
        if (_expired)
          Container(
            width: widget.size,
            height: widget.size,
            color: Colors.white.withValues(alpha: 0.94),
            alignment: Alignment.center,
            child: const Text(
              'Código vencido',
              style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        RepaintBoundary(
          key: _boundary,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  label: 'QR Code: ${widget.title}',
                  image: true,
                  child: qr,
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: widget.size,
                  child: Text(
                    widget.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (widget.subtitle != null && widget.subtitle!.isNotEmpty)
                  SizedBox(
                    width: widget.size,
                    child: Text(
                      widget.subtitle!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (expiresAt != null) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.schedule, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(
                _expired
                    ? 'Venceu às ${DateFormat('HH:mm').format(expiresAt.toLocal())}'
                    : 'Válido até ${DateFormat('HH:mm').format(expiresAt.toLocal())}',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ],
        if (widget.onRefresh != null)
          TextButton.icon(
            onPressed: widget.onRefresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Gerar outro'),
          ),
        if (widget.brightnessHint)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Dica: aumente o brilho da tela para ler mais rápido.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ),
        if (widget.actions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (widget.actions.contains(ChurchQrAction.share))
                OutlinedButton.icon(
                  onPressed: () => _run(_share),
                  icon: const Icon(Icons.share_outlined),
                  label: const Text('Compartilhar'),
                ),
              if (widget.actions.contains(ChurchQrAction.print))
                OutlinedButton.icon(
                  onPressed: () => _run(_print),
                  icon: const Icon(Icons.print_outlined),
                  label: const Text('Imprimir'),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
