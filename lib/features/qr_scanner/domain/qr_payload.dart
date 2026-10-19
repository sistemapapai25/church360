import 'package:intl/intl.dart';

/// O que um QR lido significa. Contrato em
/// .planning/ROADMAP-2026-10-19-QR-CODES.md §2.1/§2.4.
enum QrPayloadKind { eventTicket, kids, internalLink, unknown }

class QrPayload {
  final QrPayloadKind kind;
  final String raw;

  /// Rota interna (só [QrPayloadKind.internalLink]).
  final String? path;

  const QrPayload(this.kind, this.raw, {this.path});
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

/// Classifica o texto lido. Não valida nada: quem decide é o servidor.
/// [appHosts] são os hosts do próprio app (link de outro site é desconhecido).
QrPayload parseQrPayload(String text, {required Set<String> appHosts}) {
  final raw = text.trim();
  final upper = raw.toUpperCase();
  if (upper.startsWith('C360:TKT:') || raw.startsWith('EVENT_TICKET:')) {
    return QrPayload(QrPayloadKind.eventTicket, raw);
  }
  if (upper.startsWith('C360:KIN:') ||
      upper.startsWith('C360:KOUT:') ||
      _uuid.hasMatch(raw)) {
    return QrPayload(QrPayloadKind.kids, raw);
  }
  final uri = Uri.tryParse(raw);
  if (uri != null &&
      (uri.scheme == 'https' || uri.scheme == 'http') &&
      appHosts.contains(uri.host.toLowerCase()) &&
      uri.path.isNotEmpty &&
      uri.path != '/') {
    return QrPayload(
      QrPayloadKind.internalLink,
      raw,
      path: uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path,
    );
  }
  return QrPayload(QrPayloadKind.unknown, raw);
}

/// Frase curta para o status devolvido pelas RPCs de check-in de evento.
String checkInStatusMessage(Map<String, dynamic> res) {
  final at = DateTime.tryParse('${res['checked_in_at'] ?? ''}')?.toLocal();
  final by = (res['checked_in_by'] as String?)?.trim();
  switch (res['status']) {
    case 'ok':
      return 'Entrada registrada.';
    case 'already':
      final hora = at == null ? '' : ' às ${DateFormat('HH:mm').format(at)}';
      final quem = (by == null || by.isEmpty) ? '' : ' (por $by)';
      return 'Já tinha entrado$hora$quem.';
    case 'legacy':
      return 'Ingresso no formato antigo: confira a pessoa antes de confirmar.';
    case 'cancelled':
      return 'Inscrição cancelada.';
    case 'forbidden':
      return 'Você não tem permissão para check-in deste evento.';
    default:
      return 'QR inválido.';
  }
}
