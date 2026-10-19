import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/errors/app_error_handler.dart';
import '../../../../core/navigation/route_guard.dart';
import '../../../events/presentation/providers/events_provider.dart';
import '../../../kids/presentation/providers/kids_providers.dart';
import '../../domain/qr_payload.dart';

/// Quem abre o leitor: events.checkin OU equipe do Kids (kids_is_team, que
/// não é permissão RBAC). A tela não é a fronteira: cada RPC valida de novo.
class QrScannerRoute extends ConsumerWidget {
  const QrScannerRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kidsTeam = ref.watch(kidsIsTeamProvider);
    if (kidsTeam.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (kidsTeam.valueOrNull == true) return const QRScannerScreen();
    return const PermissionOnlyRoute(
      permission: 'events.checkin',
      child: QRScannerScreen(),
    );
  }
}

/// Leitor único de QR (.planning/ROADMAP-2026-10-19-QR-CODES.md §2.4).
/// A tela só classifica e mostra: quem decide tenant, permissão e validade é
/// a RPC de cada tipo.
class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

enum _Tone { ok, warn, error }

class _Result {
  final _Tone tone;
  final String title;
  final String message;
  final String? person;
  final String? context;
  final String? photoUrl;

  /// Ingresso legado: a entrada só é registrada depois da conferência.
  final String? confirmRegistrationId;

  /// Ação extra (ex.: abrir o Balcão Kids).
  final String? actionLabel;
  final String? actionRoute;

  const _Result(
    this.tone,
    this.title,
    this.message, {
    this.person,
    this.context,
    this.photoUrl,
    this.confirmRegistrationId,
    this.actionLabel,
    this.actionRoute,
  });
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  final _camera = MobileScannerController();
  bool _busy = false;
  _Result? _result;

  static final _appHosts = {
    Uri.parse(SupabaseConstants.appWebBaseUrl).host,
    if (kIsWeb) Uri.base.host,
  };

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy || _result != null) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .whereType<String>()
        .where((c) => c.trim().isNotEmpty)
        .firstOrNull;
    if (code == null) return;

    setState(() => _busy = true);
    await _camera.stop();
    final payload = parseQrPayload(code, appHosts: _appHosts);
    _Result result;
    try {
      switch (payload.kind) {
        case QrPayloadKind.eventTicket:
          result = _fromCheckIn(
            await ref.read(eventsRepositoryProvider).scanCheckIn(payload.raw),
          );
        case QrPayloadKind.kids:
          result = const _Result(
            _Tone.warn,
            'QR do Kids',
            'A entrada e a saída das crianças são registradas no Balcão Kids.',
            actionLabel: 'Abrir Balcão Kids',
            actionRoute: '/kids',
          );
        case QrPayloadKind.internalLink:
          if (!mounted) return;
          setState(() => _busy = false);
          await context.push(payload.path!);
          if (mounted) await _next();
          return;
        case QrPayloadKind.unknown:
          result = const _Result(
            _Tone.error,
            'QR não reconhecido',
            'Este código não é do Church360.',
          );
      }
    } catch (e) {
      result = _Result(
        _Tone.error,
        'Não foi possível ler agora',
        AppErrorHandler.userMessage(e, feature: 'events'),
      );
    }
    _show(result);
  }

  _Result _fromCheckIn(Map<String, dynamic> res) {
    final status = res['status'] as String?;
    final tone = switch (status) {
      'ok' => _Tone.ok,
      'already' || 'legacy' => _Tone.warn,
      _ => _Tone.error,
    };
    final title = switch (status) {
      'ok' => 'Entrada registrada',
      'already' => 'Já registrado',
      'legacy' => 'Confira a pessoa',
      'cancelled' => 'Inscrição cancelada',
      'forbidden' => 'Sem permissão',
      _ => 'QR inválido',
    };
    return _Result(
      tone,
      title,
      checkInStatusMessage(res),
      person: res['person_name'] as String?,
      context: res['event_name'] as String?,
      photoUrl: res['photo_url'] as String?,
      confirmRegistrationId: status == 'legacy'
          ? res['registration_id'] as String?
          : null,
    );
  }

  void _show(_Result result) {
    if (!mounted) return;
    if (result.tone == _Tone.ok) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _busy = false;
      _result = result;
    });
  }

  Future<void> _confirm(String registrationId) async {
    setState(() => _busy = true);
    try {
      _show(
        _fromCheckIn(
          await ref
              .read(eventsRepositoryProvider)
              .confirmCheckIn(registrationId),
        ),
      );
    } catch (e) {
      _show(
        _Result(
          _Tone.error,
          'Não foi possível registrar',
          AppErrorHandler.userMessage(e, feature: 'events'),
        ),
      );
    }
  }

  Future<void> _next() async {
    setState(() {
      _result = null;
      _busy = false;
    });
    await _camera.start();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor de QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _camera.toggleTorch(),
            tooltip: 'Lanterna',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => _camera.switchCamera(),
            tooltip: 'Trocar câmera',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _camera, onDetect: _onDetect),
                CustomPaint(painter: ScannerOverlayPainter(cs.primary)),
                if (_busy)
                  const ColoredBox(
                    color: Colors.black45,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _result == null ? _idle(cs) : _resultCard(_result!, cs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _idle(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Aponte para o QR do ingresso.',
          textAlign: TextAlign.center,
          style: TextStyle(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        // Fallback sem segundo segredo: achar a pessoa pelo nome na lista
        // de inscritos do evento (§2.4).
        TextButton.icon(
          onPressed: () => context.push('/events'),
          icon: const Icon(Icons.person_search),
          label: const Text('Buscar participante'),
        ),
      ],
    );
  }

  Widget _resultCard(_Result r, ColorScheme cs) {
    final (color, icon) = switch (r.tone) {
      _Tone.ok => (const Color(0xFF2E7D32), Icons.check_circle),
      _Tone.warn => (const Color(0xFFB26A00), Icons.warning_amber_rounded),
      _Tone.error => (cs.error, Icons.cancel),
    };
    final photo = r.photoUrl?.trim() ?? '';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        border: Border.all(color: color, width: 2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.title,
                  style: TextStyle(
                    color: color,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (r.person != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: photo.isEmpty ? null : NetworkImage(photo),
                  child: photo.isEmpty ? const Icon(Icons.person) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.person!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (r.context != null)
                        Text(
                          r.context!,
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Text(r.message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (r.confirmRegistrationId != null)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _confirm(r.confirmRegistrationId!),
                  icon: const Icon(Icons.how_to_reg),
                  label: const Text('Confirmar entrada'),
                ),
              if (r.actionRoute != null)
                FilledButton.tonal(
                  onPressed: () => context.go(r.actionRoute!),
                  child: Text(r.actionLabel ?? 'Abrir'),
                ),
              OutlinedButton.icon(
                onPressed: _busy ? null : _next,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Ler próximo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Escurece fora da área de leitura e marca os cantos.
class ScannerOverlayPainter extends CustomPainter {
  final Color color;

  ScannerOverlayPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide * 0.7;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: side,
      height: side,
    );
    canvas.drawPath(
      Path()
        ..addRect(Offset.zero & size)
        ..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)))
        ..fillType = PathFillType.evenOdd,
      Paint()..color = Colors.black.withValues(alpha: 0.5),
    );
    final pen = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    const c = 32.0;
    for (final (corner, dx, dy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      canvas.drawLine(corner, corner.translate(c * dx, 0), pen);
      canvas.drawLine(corner, corner.translate(0, c * dy), pen);
    }
  }

  @override
  bool shouldRepaint(covariant ScannerOverlayPainter old) => old.color != color;
}
