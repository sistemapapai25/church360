import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import '../../../members/presentation/providers/members_provider.dart';
import '../../../members/domain/models/member.dart';
import '../../../events/domain/models/event.dart';
import '../../../events/presentation/providers/events_provider.dart';

/// Tela de leitura de QR Code para controle de presença
class QRScannerScreen extends ConsumerStatefulWidget {
  const QRScannerScreen({super.key});

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScannedCode;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leitor de QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => cameraController.toggleTorch(),
            tooltip: 'Flash',
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: () => cameraController.switchCamera(),
            tooltip: 'Trocar Câmera',
          ),
        ],
      ),
      body: Column(
        children: [
          // Área de instrução
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              children: [
                Icon(Icons.qr_code_scanner, size: 40, color: Colors.blue[700]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Escaneie o QR Code do Membro',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Posicione o QR Code dentro da área marcada',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Scanner
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: cameraController,
                  onDetect: (capture) {
                    _onQRCodeDetected(capture);
                  },
                ),
                // Overlay com área de scan
                CustomPaint(
                  painter: ScannerOverlayPainter(),
                  child: Container(),
                ),
                // Indicador de processamento
                if (_isProcessing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Área de informações
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Aguardando leitura...',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onQRCodeDetected(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Evitar processar o mesmo código múltiplas vezes
    if (code == _lastScannedCode) return;

    setState(() {
      _isProcessing = true;
      _lastScannedCode = code;
    });

    // Pausar scanner
    await cameraController.stop();

    // Detectar tipo de QR Code
    if (code.startsWith('EVENT_TICKET:')) {
      // QR Code de ingresso de evento
      _processEventTicket(code);
    } else {
      // QR Code de membro (ID do membro)
      _processMemberQRCode(code);
    }
  }

  void _processMemberQRCode(String memberId) {
    final memberAsync = ref.read(memberByIdProvider(memberId));

    memberAsync.when(
      data: (member) {
        if (member != null) {
          _showMemberDialog(member);
        } else {
          _showErrorDialog('Membro não encontrado', 'O QR Code escaneado não corresponde a nenhum membro cadastrado.');
        }
      },
      loading: () {
        // Já está mostrando loading
      },
      error: (error, stack) {
        _showErrorDialog('Erro ao buscar membro', error.toString());
      },
    );
  }

  void _processEventTicket(String qrCode) async {
    try {
      // Formato: EVENT_TICKET:eventId:memberId:ticketId
      final parts = qrCode.split(':');
      if (parts.length != 4) {
        _showErrorDialog('QR Code Inválido', 'O formato do QR Code do ingresso está incorreto.');
        return;
      }

      final eventId = parts[1];
      final memberId = parts[2];
      final ticketId = parts[3];

      // Buscar evento
      final eventAsync = ref.read(eventByIdProvider(eventId));
      final memberAsync = ref.read(memberByIdProvider(memberId));

      await eventAsync.when(
        data: (event) async {
          if (event == null) {
            _showErrorDialog('Evento não encontrado', 'O evento deste ingresso não foi encontrado.');
            return;
          }

          await memberAsync.when(
            data: (member) async {
              if (member == null) {
                _showErrorDialog('Membro não encontrado', 'O membro deste ingresso não foi encontrado.');
                return;
              }

              // Fazer check-in
              await _doEventCheckIn(event, member, ticketId);
            },
            loading: () {},
            error: (error, stack) {
              _showErrorDialog('Erro', 'Erro ao buscar membro: $error');
            },
          );
        },
        loading: () {},
        error: (error, stack) {
          _showErrorDialog('Erro', 'Erro ao buscar evento: $error');
        },
      );
    } catch (e) {
      _showErrorDialog('Erro', 'Erro ao processar ingresso: $e');
    }
  }

  Future<void> _doEventCheckIn(Event event, Member member, String ticketId) async {
    try {
      // Fazer check-in no evento
      await ref.read(eventsRepositoryProvider).checkIn(event.id, member.id);

      // Invalidar providers
      ref.invalidate(eventRegistrationsProvider(event.id));
      ref.invalidate(eventByIdProvider(event.id));

      // Mostrar sucesso
      _showEventCheckInSuccessDialog(event, member);
    } catch (e) {
      _showErrorDialog('Erro ao fazer check-in', e.toString());
    }
  }

  void _showMemberDialog(Member member) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header com foto e nome
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.green[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'QR Code Válido!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
              // Informações do membro
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Foto
                    Builder(builder: (context) {
                      final rawUrl = member.photoUrl;
                      String? resolvedUrl;
                      if (rawUrl != null && rawUrl.isNotEmpty) {
                        final parsed = Uri.tryParse(rawUrl);
                        if (parsed != null && parsed.hasScheme) {
                          resolvedUrl = rawUrl;
                        } else {
                          resolvedUrl = Supabase.instance.client.storage
                              .from('member-photos')
                              .getPublicUrl(rawUrl);
                        }
                      }

                      return CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        child: resolvedUrl != null
                            ? ClipOval(
                                child: Image.network(
                                  resolvedUrl,
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Text(
                                      member.initials,
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    );
                                  },
                                ),
                              )
                            : Text(
                                member.initials,
                                style: const TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                      );
                    }),
                    const SizedBox(height: 16),
                    // Nome
                    Text(
                      member.displayName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (member.nickname != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '"${member.nickname}"',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    // Informações
                    _buildInfoRow(Icons.phone, member.phone ?? 'Sem telefone'),
                    _buildInfoRow(
                      Icons.person,
                      member.gender == 'male'
                          ? 'Masculino'
                          : member.gender == 'female'
                              ? 'Feminino'
                              : 'Não informado',
                    ),
                    _buildInfoRow(
                      Icons.badge,
                      _getMemberTypeLabel(member.memberType),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            child: const Text('Fechar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/members/${member.id}/profile');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Ver Perfil'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[600]),
            const SizedBox(width: 12),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEventCheckInSuccessDialog(Event event, Member member) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: 350,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header com sucesso
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Colors.green[600],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CHECK-IN REALIZADO!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[800],
                      ),
                    ),
                  ],
                ),
              ),
              // Informações do evento e membro
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Evento
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.event, color: Colors.blue[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  event.name,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            DateFormat('dd/MM/yyyy - HH:mm').format(event.startDate),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Membro
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Builder(builder: (context) {
                            final rawUrl = member.photoUrl;
                            String? resolvedUrl;
                            if (rawUrl != null && rawUrl.isNotEmpty) {
                              final parsed = Uri.tryParse(rawUrl);
                              if (parsed != null && parsed.hasScheme) {
                                resolvedUrl = rawUrl;
                              } else {
                                resolvedUrl = Supabase.instance.client.storage
                                    .from('member-photos')
                                    .getPublicUrl(rawUrl);
                              }
                            }

                            return CircleAvatar(
                              radius: 30,
                              backgroundColor: Colors.blue.withValues(alpha: 0.1),
                              child: resolvedUrl != null
                                  ? ClipOval(
                                      child: Image.network(
                                        resolvedUrl,
                                        width: 60,
                                        height: 60,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Text(
                                            member.initials,
                                            style: const TextStyle(
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          );
                                        },
                                      ),
                                    )
                                  : Text(
                                      member.initials,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                            );
                          }),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.displayName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (member.nickname != null)
                                  Text(
                                    '"${member.nickname}"',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Horário do check-in
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Check-in: ${DateFormat('HH:mm:ss').format(DateTime.now())}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetScanner();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _resetScanner() {
    setState(() {
      _isProcessing = false;
      _lastScannedCode = null;
    });
    cameraController.start();
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _getMemberTypeLabel(String? type) {
    switch (type) {
      case 'titular':
        return 'Liderança';
      case 'congregado':
        return 'Congregado';
      case 'cooperador':
        return 'Cooperador';
      case 'crianca':
        return 'Criança';
      default:
        return 'Não informado';
    }
  }
}

/// Painter para desenhar o overlay do scanner
class ScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final scanAreaSize = size.width * 0.7;
    final left = (size.width - scanAreaSize) / 2;
    final top = (size.height - scanAreaSize) / 2;

    // Desenhar overlay escuro
    canvas.drawPath(
      Path()
        ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
        ..addRect(Rect.fromLTWH(left, top, scanAreaSize, scanAreaSize))
        ..fillType = PathFillType.evenOdd,
      paint,
    );

    // Desenhar bordas da área de scan
    final borderPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    final cornerLength = 30.0;

    // Canto superior esquerdo
    canvas.drawLine(Offset(left, top), Offset(left + cornerLength, top), borderPaint);
    canvas.drawLine(Offset(left, top), Offset(left, top + cornerLength), borderPaint);

    // Canto superior direito
    canvas.drawLine(Offset(left + scanAreaSize, top), Offset(left + scanAreaSize - cornerLength, top), borderPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top), Offset(left + scanAreaSize, top + cornerLength), borderPaint);

    // Canto inferior esquerdo
    canvas.drawLine(Offset(left, top + scanAreaSize), Offset(left + cornerLength, top + scanAreaSize), borderPaint);
    canvas.drawLine(Offset(left, top + scanAreaSize), Offset(left, top + scanAreaSize - cornerLength), borderPaint);

    // Canto inferior direito
    canvas.drawLine(Offset(left + scanAreaSize, top + scanAreaSize), Offset(left + scanAreaSize - cornerLength, top + scanAreaSize), borderPaint);
    canvas.drawLine(Offset(left + scanAreaSize, top + scanAreaSize), Offset(left + scanAreaSize, top + scanAreaSize - cornerLength), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
