// QR E1 (roadmap QR 19/10/2026 §2.4): o leitor único classifica o texto lido;
// quem valida é o servidor.
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/qr_scanner/domain/qr_payload.dart';

QrPayload _p(String s) =>
    parseQrPayload(s, appHosts: {'papai.church360.com.br'});

void main() {
  test('ingresso: legado e C360:TKT', () {
    expect(_p('EVENT_TICKET:e1:u1').kind, QrPayloadKind.eventTicket);
    expect(_p('  C360:TKT:abc123  ').kind, QrPayloadKind.eventTicket);
    expect(_p('  C360:TKT:abc123  ').raw, 'C360:TKT:abc123');
    expect(_p('c360:tkt:abc').kind, QrPayloadKind.eventTicket);
  });

  test('Kids: KIN, KOUT e o UUID dos tokens atuais', () {
    expect(_p('C360:KIN:ff').kind, QrPayloadKind.kids);
    expect(_p('C360:KOUT:ff').kind, QrPayloadKind.kids);
    expect(_p('3cdf7740-db4f-4725-af78-52be758df96a').kind, QrPayloadKind.kids);
  });

  test('link do próprio app vira rota interna; outro site não', () {
    final p = _p('https://papai.church360.com.br/raizes/abc/cadastro');
    expect(p.kind, QrPayloadKind.internalLink);
    expect(p.path, '/raizes/abc/cadastro');
    expect(
      _p('https://papai.church360.com.br/events/1?x=2').path,
      '/events/1?x=2',
    );
    expect(_p('https://evil.example.com/events/1').kind, QrPayloadKind.unknown);
    expect(_p('https://papai.church360.com.br/').kind, QrPayloadKind.unknown);
  });

  test('lixo é desconhecido', () {
    for (final s in ['', 'qualquer coisa', 'EVENT', 'C360:XYZ:1', '1234']) {
      expect(_p(s).kind, QrPayloadKind.unknown, reason: s);
    }
  });

  test('mensagens por status', () {
    expect(checkInStatusMessage({'status': 'ok'}), 'Entrada registrada.');
    expect(
      checkInStatusMessage({
        'status': 'already',
        'checked_in_at': DateTime(
          2026,
          10,
          19,
          19,
          12,
        ).toUtc().toIso8601String(),
        'checked_in_by': 'Ana Souza',
      }),
      'Já tinha entrado às 19:12 (por Ana Souza).',
    );
    expect(checkInStatusMessage({'status': 'already'}), 'Já tinha entrado.');
    expect(checkInStatusMessage({'status': 'legacy'}), contains('confira'));
    expect(
      checkInStatusMessage({'status': 'forbidden'}),
      contains('permissão'),
    );
    expect(checkInStatusMessage({'status': 'wrong_tenant'}), 'QR inválido.');
    expect(checkInStatusMessage({}), 'QR inválido.');
  });
}
