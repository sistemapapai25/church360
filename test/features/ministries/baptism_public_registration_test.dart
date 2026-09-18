import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/features/ministries/batismo/data/baptism_repository.dart';
import 'package:church360_app/features/ministries/batismo/domain/models/baptism_public_info.dart';
import 'package:church360_app/features/ministries/batismo/presentation/providers/baptism_providers.dart';
import 'package:church360_app/features/ministries/batismo/presentation/screens/baptism_public_registration_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _ministryId = 'm1';

/// Repositorio de mentira: guarda o que a tela mandou e devolve o que o
/// teste pediu. `implements` + `noSuchMethod` para nao precisar de um
/// SupabaseClient de verdade so para exercitar uma tela.
class _FakeRepo implements BaptismRepository {
  Map<String, Object?>? ultimaInscricao;
  Object? erroAoInscrever;

  @override
  Future<String> registerPublicStudent({
    required String ministryId,
    required String turmaId,
    required String fullName,
    required String phone,
    String? email,
    DateTime? birthDate,
  }) async {
    ultimaInscricao = {
      'ministryId': ministryId,
      'turmaId': turmaId,
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'birthDate': birthDate,
    };
    final erro = erroAoInscrever;
    if (erro != null) throw erro;
    return 'novo-aluno';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} nao usado no teste');
}

BaptismPublicInfo _info({List<BaptismPublicTurma> turmas = const []}) {
  return BaptismPublicInfo(
    ministryName: 'Batismo nas Aguas',
    ministryDescription: 'Preparo dos candidatos.',
    turmas: turmas,
  );
}

BaptismPublicTurma _turma(String id, String name, {DateTime? eventDate}) {
  return BaptismPublicTurma(id: id, name: name, eventDate: eventDate);
}

Widget _host({required BaptismPublicInfo info, required _FakeRepo repo}) {
  return ProviderScope(
    overrides: [
      baptismPublicInfoProvider(_ministryId).overrideWith((ref) async => info),
      baptismRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const BaptismPublicRegistrationScreen(ministryId: _ministryId),
    ),
  );
}

Future<void> _preencher(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Nome completo *'),
    'Joao de Deus',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'WhatsApp *'),
    '(62) 98140-2385',
  );
}

/// Rola ate o botao antes de tocar: com duas turmas na lista ele sai da
/// janela de teste, e o toque no vazio faz o teste falhar por motivo
/// errado.
Future<void> _confirmar(WidgetTester tester) async {
  final botao = find.text('Confirmar inscrição');
  await tester.ensureVisible(botao);
  await tester.pumpAndSettle();
  await tester.tap(botao);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('sem turma aberta avisa que as inscricoes estao fechadas', (
    tester,
  ) async {
    await tester.pumpWidget(_host(info: _info(), repo: _FakeRepo()));
    await tester.pumpAndSettle();

    expect(find.text('Inscricoes fechadas'), findsNothing);
    expect(find.text('Inscrições fechadas'), findsOneWidget);
    // E nao oferece formulario nenhum para preencher em vao.
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('lista as turmas abertas e o formulario', (tester) async {
    await tester.pumpWidget(
      _host(
        info: _info(
          turmas: [
            _turma('t1', 'Turma Sexta', eventDate: DateTime(2026, 10, 25)),
            _turma('t2', 'Turma Domingo'),
          ],
        ),
        repo: _FakeRepo(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Batismo nas Aguas'), findsOneWidget);
    expect(find.text('Turma Sexta'), findsOneWidget);
    expect(find.text('Turma Domingo'), findsOneWidget);
    expect(find.text('Batismo em 25/10/2026'), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(3));
  });

  testWidgets('sem escolher turma nao envia', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      _host(info: _info(turmas: [_turma('t1', 'Turma Sexta')]), repo: repo),
    );
    await tester.pumpAndSettle();

    await _preencher(tester);
    await _confirmar(tester);

    expect(repo.ultimaInscricao, isNull);
    expect(
      find.text('Escolha a turma em que você quer entrar.'),
      findsOneWidget,
    );
  });

  testWidgets('telefone curto e barrado antes de ir ao servidor', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      _host(info: _info(turmas: [_turma('t1', 'Turma Sexta')]), repo: repo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turma Sexta'));
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Nome completo *'),
      'Joao de Deus',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'WhatsApp *'),
      '98140',
    );
    await _confirmar(tester);

    expect(repo.ultimaInscricao, isNull);
    expect(find.text('Informe o WhatsApp com DDD.'), findsOneWidget);
  });

  testWidgets('inscricao completa manda os dados e confirma', (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(
      _host(
        info: _info(
          turmas: [_turma('t1', 'Turma Sexta'), _turma('t2', 'Turma Domingo')],
        ),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turma Domingo'));
    await tester.pump();
    await _preencher(tester);
    await _confirmar(tester);

    expect(repo.ultimaInscricao, isNotNull);
    expect(repo.ultimaInscricao!['turmaId'], 't2');
    expect(repo.ultimaInscricao!['ministryId'], _ministryId);
    expect(repo.ultimaInscricao!['fullName'], 'Joao de Deus');
    expect(repo.ultimaInscricao!['phone'], '(62) 98140-2385');
    // E-mail vazio vai como nulo, e nao como string vazia: a RPC trata
    // NULL, e '' viraria um e-mail invalido no banco.
    expect(repo.ultimaInscricao!['email'], isNull);

    expect(find.text('Inscrição confirmada!'), findsOneWidget);
    expect(find.textContaining('Turma Domingo'), findsOneWidget);
  });

  testWidgets('recusa do servidor vira frase em portugues', (tester) async {
    final repo = _FakeRepo()
      ..erroAoInscrever = Exception(
        'PostgrestException(message: ALREADY_REGISTERED, code: P0001)',
      );

    await tester.pumpWidget(
      _host(info: _info(turmas: [_turma('t1', 'Turma Sexta')]), repo: repo),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Turma Sexta'));
    await tester.pump();
    await _preencher(tester);
    await _confirmar(tester);

    // Nenhum literal cru do servidor chega a quem esta se inscrevendo.
    expect(find.textContaining('ALREADY_REGISTERED'), findsNothing);
    expect(
      find.textContaining('Já existe uma inscrição com este WhatsApp'),
      findsOneWidget,
    );
    // E a tela continua no formulario, nao na confirmacao.
    expect(find.text('Inscrição confirmada!'), findsNothing);
  });
}
