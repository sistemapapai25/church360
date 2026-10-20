import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/share_link_utils.dart';
import '../../../../core/widgets/church_qr_card.dart';

/// QR de presença (E5, migration 011600). O líder abre o QR do culto ou da
/// aula (`attendance_qr_open`); o membro logado lê com a câmera e cai em
/// `/presenca/<token>`, que chama `attendance_qr_checkin`. O servidor decide
/// tudo (quem abre, quem pode marcar, validade de 3 h, uma vez só).

/// Mostra o QR da sessão. Abrir de novo (ou "Gerar novo") troca o token e o
/// anterior para de valer.
Future<void> showAttendanceQr(
  BuildContext context, {
  String? eventId,
  String? lessonId,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AttendanceQrDialog(eventId: eventId, lessonId: lessonId),
  );
}

class _AttendanceQrDialog extends StatefulWidget {
  final String? eventId;
  final String? lessonId;
  const _AttendanceQrDialog({this.eventId, this.lessonId});

  @override
  State<_AttendanceQrDialog> createState() => _AttendanceQrDialogState();
}

class _AttendanceQrDialogState extends State<_AttendanceQrDialog> {
  late Future<Map<String, dynamic>> _future = _open();

  Future<Map<String, dynamic>> _open() async {
    final r = await Supabase.instance.client.rpc(
      'attendance_qr_open',
      params: {'p_event_id': widget.eventId, 'p_lesson_id': widget.lessonId},
    );
    return Map<String, dynamic>.from(r as Map);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.all(16),
      content: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) {
            final denied =
                snap.error is PostgrestException &&
                (snap.error as PostgrestException).code == '42501';
            return Text(
              denied
                  ? 'Você não tem permissão para abrir a presença desta sessão.'
                  : 'Não foi possível gerar o QR. Tente de novo.',
            );
          }
          if (!snap.hasData) {
            return const SizedBox(
              height: 120,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final d = snap.data!;
          final url = ShareLinkUtils.buildShareUrl('/presenca/${d['token']}');
          return SingleChildScrollView(
            child: ChurchQrCard(
              data: url,
              title: 'Presença: ${d['title'] ?? ''}',
              subtitle: 'Aponte a câmera do celular e entre com o seu login.',
              expiresAt: DateTime.parse(d['expires_at'] as String).toLocal(),
              onRefresh: () => setState(() => _future = _open()),
              actions: const {ChurchQrAction.share, ChurchQrAction.print},
              size: 260,
            ),
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fechar'),
        ),
      ],
    );
  }
}

/// Miolo de `/presenca/<token>`: marca a presença e mostra o resultado.
class AttendanceQrCheckinPanel extends StatefulWidget {
  final String token;
  const AttendanceQrCheckinPanel({super.key, required this.token});

  @override
  State<AttendanceQrCheckinPanel> createState() =>
      _AttendanceQrCheckinPanelState();
}

class _AttendanceQrCheckinPanelState extends State<AttendanceQrCheckinPanel> {
  late final Future<Map<String, dynamic>> _future = Supabase.instance.client
      .rpc('attendance_qr_checkin', params: {'p_token': widget.token})
      .then((r) => Map<String, dynamic>.from(r as Map));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (!snap.hasData && !snap.hasError) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final d = snap.data ?? const {};
        final culto = d['kind'] == 'culto';
        final (color, icon, title, text) = switch (d['status']) {
          'ok' => (
            const Color(0xFF2E7D32),
            Icons.check_circle,
            'Presença registrada',
            culto
                ? 'Um diácono confere a presença pelo celular.'
                : 'Bom estudo!',
          ),
          'already' => (
            const Color(0xFFB26A00),
            Icons.warning_amber_rounded,
            'Presença já registrada',
            'Você já está marcado nesta sessão.',
          ),
          'expired' => (
            cs.error,
            Icons.cancel,
            'QR vencido',
            'Peça ao líder para mostrar o QR de novo.',
          ),
          'forbidden' => (
            cs.error,
            Icons.cancel,
            'Você não é aluno desta turma',
            'Fale com o líder da turma.',
          ),
          'invalid' => (
            cs.error,
            Icons.cancel,
            'QR inválido',
            'Este QR não vale mais. Peça ao líder o QR atual.',
          ),
          _ => (
            cs.error,
            Icons.cancel,
            'Não foi possível registrar',
            'Confira a internet e leia o QR de novo.',
          ),
        };
        return Semantics(
          label: title,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 56),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (d['title'] != null) ...[
                const SizedBox(height: 4),
                Text(d['title'] as String, textAlign: TextAlign.center),
              ],
              const SizedBox(height: 8),
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}
