import 'package:flutter_test/flutter_test.dart';
import 'package:church360_app/features/support_chat/domain/admin_action.dart';

void main() {
  test('linha válida com pode=true', () {
    final r = parseAdminAction(
      'Posso fazer.\n[[ADMIN_ACTION]]{"id":"a1","resumo":"Dar cargo","pode":true,"motivo":null,"aprovadores":[]}',
    );
    expect(r.text, 'Posso fazer.');
    expect(r.action!.id, 'a1');
    expect(r.action!.pode, true);
    expect(r.action!.aprovadores, isEmpty);
  });

  test('pode=false com aprovadores', () {
    final r = parseAdminAction(
      '[[ADMIN_ACTION]]{"id":"a2","resumo":"x","pode":false,"motivo":"nível","aprovadores":[{"id":"u1","nome":"Pr. Fulano","nivel":5}]}',
    );
    expect(r.action!.pode, false);
    expect(r.action!.motivo, 'nível');
    expect(r.action!.aprovadores.single.nome, 'Pr. Fulano');
    expect(r.action!.aprovadores.single.nivel, 5);
  });

  test('JSON quebrado some do texto e não quebra', () {
    final r = parseAdminAction('Oi\n[[ADMIN_ACTION]]{quebrado');
    expect(r.action, isNull);
    expect(r.text, 'Oi');
  });

  test('texto sem marcador passa intacto', () {
    final r = parseAdminAction('Só texto');
    expect(r.action, isNull);
    expect(r.text, 'Só texto');
  });

  test('texto do resultado', () {
    expect(adminActionResultText({'status': 'executed'}), 'Feito.');
    expect(
      adminActionResultText({
        'status': 'awaiting_approval',
        'aprovador': 'Ana',
      }),
      'Pedido enviado a Ana. Você será avisado.',
    );
  });
}
