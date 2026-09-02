// Fase 6 — REC-03/REC-04 (Plano 06-08). As três variantes novas do diálogo de
// impacto (DLG-2, DLG-3, DLG-4) e a forma da chamada de
// `public.regenerate_event_series`.
//
// O que este arquivo trava:
//   1. que DLG-2 (estender) NÃO promete nada sobre inscrições nem sobre
//      ocorrências passadas — a ausência dessas linhas é do `06-UI-SPEC.md`, e
//      um dia alguém vai "corrigir" isso por simetria com DLG-3/DLG-4;
//   2. que a linha de inscrições canceladas segue as regras de contagem do
//      Plano 06-04 (`k == 0` substitui, `k > 0` em destrutivo com
//      `Icons.person_off_outlined`);
//   3. que a descrição do padrão do DLG-4 vem de `describeSeriesPattern`
//      (A-13) e que a linha de escala de ministério só aparece quando HÁ
//      escala para migrar;
//   4. que só `shorten` e `regenerate` usam cor destrutiva — `extend` não
//      remove nada e alarme falso é como um líder aprende a confirmar sem ler;
//   5. a forma da chamada de RPC: 9 chaves exatas, `p_dry_run` correto,
//      `p_recurrence_end_date` em `yyyy-MM-dd`, NENHUM parâmetro de ator
//      (CHU-326) e NENHUM parâmetro de modo — o modo é decisão do servidor.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/domain/models/event_series_impact.dart';
import 'package:church360_app/features/events/presentation/utils/series_pattern_label.dart';
import 'package:church360_app/features/events/presentation/widgets/series_impact_dialog.dart';

const _batchId = '22222222-0000-4000-8000-000000000002';
const _anchorEventId = '11111111-0000-4000-8000-000000000001';

/// As 9 chaves da assinatura de `public.regenerate_event_series`.
const _chavesEsperadas = <String>{
  'p_batch_id',
  'p_anchor_event_id',
  'p_pattern_group',
  'p_variable_type',
  'p_weekdays',
  'p_interval_weeks',
  'p_monthly_ordinal',
  'p_recurrence_end_date',
  'p_dry_run',
};

/// Nomes que NUNCA podem sair do cliente: ator/tenant (CHU-326) e modo (o
/// servidor decide comparando com `event_series`).
const _chavesProibidas = <String>[
  'p_tenant_id',
  'p_actor',
  'p_actor_id',
  'p_user_id',
  'p_user_account_id',
  'p_auth_uid',
  'p_mode',
  'mode',
  'tenant_id',
  'user_id',
];

const _jsonbRegenerate = <String, dynamic>{
  'dry_run': true,
  'mode': 'regenerate',
  'future_count': 12,
  'past_count': 3,
  'first_future': '2026-09-06',
  'last_future': '2026-12-20',
  'affected_registrations': 4,
  'affected_schedules': 2,
  'paid_occurrences': 0,
  'deleted_count': 12,
  'created_count': 11,
  'kept_count': 1,
  'first_new': '2026-09-09',
  'last_new': '2026-12-23',
  'future_after_count': 12,
  'notified_count': 0,
  'migrated_schedules': 0,
};

class _RegenerateApiSpy {
  final List<Uri> rpcPosts = [];
  final List<Map<String, dynamic>> rpcBodies = [];

  Map<String, dynamic> response = Map<String, dynamic>.from(_jsonbRegenerate);
  bool failWithPermissionDenied = false;

  http.Client get client => MockClient((request) async {
    final headers = {'content-type': 'application/json; charset=utf-8'};

    if (request.url.path.endsWith('/rpc/regenerate_event_series') &&
        request.method == 'POST') {
      rpcPosts.add(request.url);
      rpcBodies.add(Map<String, dynamic>.from(jsonDecode(request.body)));

      if (failWithPermissionDenied) {
        return http.Response(
          jsonEncode({
            'code': '42501',
            'message':
                'permission denied for function regenerate_event_series',
            'details': null,
            'hint': null,
          }),
          403,
          request: request,
          headers: headers,
        );
      }

      return http.Response(
        jsonEncode(response),
        200,
        request: request,
        headers: headers,
      );
    }

    return http.Response('[]', 200, request: request, headers: headers);
  });
}

EventsRepository _repoWith(_RegenerateApiSpy spy) => EventsRepository(
  SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: spy.client,
    // CHU-321: evita timer pendente do GoTrue em flutter_test.
    authOptions: const AuthClientOptions(autoRefreshToken: false),
  ),
);

EventSeriesImpact _impacto({
  String mode = 'regenerate',
  int futureCount = 12,
  int pastCount = 3,
  int affectedRegistrations = 4,
  int affectedSchedules = 2,
  int deletedCount = 12,
  int createdCount = 11,
  DateTime? firstNew,
  DateTime? lastNew,
}) => EventSeriesImpact(
  dryRun: true,
  mode: mode,
  futureCount: futureCount,
  pastCount: pastCount,
  affectedRegistrations: affectedRegistrations,
  affectedSchedules: affectedSchedules,
  deletedCount: deletedCount,
  createdCount: createdCount,
  notifiedCount: 0,
  firstNew: firstNew,
  lastNew: lastNew,
);

/// Monta o corpo da variante numa árvore mínima e devolve todo o texto
/// renderizado, concatenado.
Future<String> _textoDoCorpo(
  WidgetTester tester, {
  required SeriesImpactVariant variant,
  required EventSeriesImpact impact,
  DateTime? newEndDate,
  String? newPatternLabel,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: buildImpactBody(
              context,
              variant: variant,
              impact: impact,
              eventName: 'Culto de Domingo',
              newEndDate: newEndDate,
              newPatternLabel: newPatternLabel,
            ),
          ),
        ),
      ),
    ),
  );

  final buffer = StringBuffer();
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    buffer.write(widget.data ?? widget.textSpan?.toPlainText() ?? '');
    buffer.write('\n');
  }
  return buffer.toString();
}

void main() {
  group('DLG-2 — Estender a série', () {
    testWidgets('renderiza a contagem criada e o intervalo de first/last_new', (
      tester,
    ) async {
      final texto = await _textoDoCorpo(
        tester,
        variant: SeriesImpactVariant.extend,
        impact: _impacto(
          mode: 'extend',
          createdCount: 6,
          firstNew: DateTime(2027, 1, 3),
          lastNew: DateTime(2027, 2, 7),
        ),
      );

      expect(texto, contains('Serão criadas'));
      expect(texto, contains('6'));
      expect(texto, contains('03/01/2027'));
      expect(texto, contains('07/02/2027'));
      expect(
        texto,
        contains('As ocorrências que já existem não serão alteradas.'),
      );
    });

    testWidgets('NÃO tem linha de inscrições nem de passadas', (tester) async {
      // A ausência é deliberada e vem do `06-UI-SPEC.md`: estender não cancela
      // inscrição nenhuma e não toca em ocorrência existente.
      final texto = await _textoDoCorpo(
        tester,
        variant: SeriesImpactVariant.extend,
        impact: _impacto(
          mode: 'extend',
          createdCount: 6,
          pastCount: 9,
          affectedRegistrations: 7,
          firstNew: DateTime(2027, 1, 3),
          lastNew: DateTime(2027, 2, 7),
        ),
      );

      expect(texto, isNot(contains('inscrições serão canceladas')));
      expect(texto, isNot(contains('Nenhuma pessoa inscrita')));
      expect(texto, isNot(contains('ocorrências passadas')));
      expect(texto, isNot(contains('Esta ação não pode ser desfeita.')));
    });

    testWidgets('não usa cor destrutiva em nenhum elemento', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SeriesImpactDialog(
              variant: SeriesImpactVariant.extend,
              impact: _impacto(
                mode: 'extend',
                createdCount: 6,
                firstNew: DateTime(2027, 1, 3),
                lastNew: DateTime(2027, 2, 7),
              ),
              eventName: 'Culto de Domingo',
            ),
          ),
        ),
      );

      expect(seriesImpactIsDestructive(SeriesImpactVariant.extend), isFalse);
      expect(find.byIcon(Icons.person_off_outlined), findsNothing);

      final erro = Theme.of(
        tester.element(find.byType(SeriesImpactDialog)),
      ).colorScheme.error;
      for (final texto in tester.widgetList<Text>(find.byType(Text))) {
        expect(texto.style?.color, isNot(erro));
      }
    });
  });

  group('DLG-3 — Encurtar a série', () {
    testWidgets('usa a data NOVA do formulário e a contagem excluída', (
      tester,
    ) async {
      final texto = await _textoDoCorpo(
        tester,
        variant: SeriesImpactVariant.shorten,
        impact: _impacto(mode: 'shorten', deletedCount: 9, pastCount: 4),
        newEndDate: DateTime(2026, 10, 31),
      );

      expect(texto, contains('9'));
      expect(texto, contains('depois de 31/10/2026'));
      expect(texto, contains('serão excluídas'));
      expect(
        texto,
        contains(
          'ocorrências passadas serão preservadas, com inscrições, presença '
          'e escalas.',
        ),
      );
      expect(texto, contains('Esta ação não pode ser desfeita.'));
    });

    testWidgets('k > 0 renderiza a linha destrutiva com person_off_outlined', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: buildImpactBody(
                  context,
                  variant: SeriesImpactVariant.shorten,
                  impact: _impacto(
                    mode: 'shorten',
                    deletedCount: 9,
                    affectedRegistrations: 4,
                  ),
                  eventName: 'Culto de Domingo',
                  newEndDate: DateTime(2026, 10, 31),
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person_off_outlined), findsOneWidget);
      expect(
        find.textContaining('recebem um aviso com link', findRichText: true),
        findsOneWidget,
      );
    });

    testWidgets('k == 0 substitui a linha, nunca "0 inscrições"', (
      tester,
    ) async {
      final texto = await _textoDoCorpo(
        tester,
        variant: SeriesImpactVariant.shorten,
        impact: _impacto(
          mode: 'shorten',
          deletedCount: 9,
          affectedRegistrations: 0,
        ),
        newEndDate: DateTime(2026, 10, 31),
      );

      expect(texto, contains('Nenhuma pessoa inscrita será afetada.'));
      expect(texto, isNot(contains('0 inscrições')));
    });

    testWidgets('m == 0 omite a linha de passadas', (tester) async {
      final texto = await _textoDoCorpo(
        tester,
        variant: SeriesImpactVariant.shorten,
        impact: _impacto(mode: 'shorten', deletedCount: 9, pastCount: 0),
        newEndDate: DateTime(2026, 10, 31),
      );

      expect(texto, isNot(contains('passadas serão preservadas')));
    });

    test('botão primário é destrutivo', () {
      expect(seriesImpactIsDestructive(SeriesImpactVariant.shorten), isTrue);
      expect(
        seriesImpactTitle(SeriesImpactVariant.shorten),
        'Encurtar a série?',
      );
      expect(
        seriesImpactConfirmLabel(
          SeriesImpactVariant.shorten,
          _impacto(mode: 'shorten'),
        ),
        'Encurtar série',
      );
    });
  });

  group('DLG-4 — Mudar o padrão de repetição', () {
    testWidgets('a descrição do padrão vem de describeSeriesPattern', (
      tester,
    ) async {
      final rotulo = describeSeriesPattern(
        patternGroup: 'semanal',
        weekdays: const [3],
        intervalWeeks: 1,
      );

      final texto = await _textoDoCorpo(
        tester,
        variant: SeriesImpactVariant.regenerate,
        impact: _impacto(),
        newPatternLabel: rotulo,
      );

      expect(rotulo, 'Toda semana, quarta');
      expect(texto, contains('serão apagadas e geradas de novo em:'));
      expect(texto, contains(rotulo));
    });

    testWidgets('affectedSchedules > 0 mostra a linha de escala de ministério',
        (tester) async {
      final texto = await _textoDoCorpo(
        tester,
        variant: SeriesImpactVariant.regenerate,
        impact: _impacto(affectedSchedules: 2),
        newPatternLabel: 'Toda semana, quarta',
      );

      expect(
        texto,
        contains(
          'As escalas de ministério das datas futuras vão junto para a data '
          'equivalente.',
        ),
      );
    });

    testWidgets('affectedSchedules == 0 NÃO mostra a linha de escala', (
      tester,
    ) async {
      final texto = await _textoDoCorpo(
        tester,
        variant: SeriesImpactVariant.regenerate,
        impact: _impacto(affectedSchedules: 0),
        newPatternLabel: 'Toda semana, quarta',
      );

      expect(texto, isNot(contains('escalas de ministério')));
    });

    test('botão primário é destrutivo', () {
      expect(seriesImpactIsDestructive(SeriesImpactVariant.regenerate), isTrue);
      expect(
        seriesImpactTitle(SeriesImpactVariant.regenerate),
        'Mudar o padrão de repetição?',
      );
      expect(
        seriesImpactConfirmLabel(SeriesImpactVariant.regenerate, _impacto()),
        'Regerar ocorrências',
      );
    });
  });

  group('Plural real — nenhuma variante nova usa parêntese', () {
    testWidgets('as três variantes não contêm plural por parêntese', (
      tester,
    ) async {
      for (final caso in [
        (
          SeriesImpactVariant.extend,
          _impacto(mode: 'extend', createdCount: 1),
        ),
        (SeriesImpactVariant.shorten, _impacto(mode: 'shorten')),
        (SeriesImpactVariant.regenerate, _impacto()),
      ]) {
        final texto = await _textoDoCorpo(
          tester,
          variant: caso.$1,
          impact: caso.$2,
          newEndDate: DateTime(2026, 10, 31),
          newPatternLabel: 'Toda semana, quarta',
        );
        expect(texto.contains('(s)'), isFalse);
      }
    });
  });

  group('previewRegenerateSeries / regenerateSeries — forma da chamada', () {
    test('a prévia envia p_dry_run: true e EXATAMENTE as 9 chaves', () async {
      final spy = _RegenerateApiSpy();

      await _repoWith(spy).previewRegenerateSeries(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        patternGroup: 'semanal',
        weekdays: const [3],
        intervalWeeks: 1,
        recurrenceEndDate: DateTime(2027, 3, 31),
      );

      expect(
        spy.rpcPosts.single.path,
        endsWith('/rpc/regenerate_event_series'),
      );
      expect(spy.rpcBodies.single.keys.toSet(), _chavesEsperadas);
      expect(spy.rpcBodies.single['p_dry_run'], isTrue);
      expect(spy.rpcBodies.single['p_batch_id'], _batchId);
      expect(spy.rpcBodies.single['p_weekdays'], [3]);
    });

    test('p_recurrence_end_date sai como yyyy-MM-dd, nunca ISO completo',
        () async {
      final spy = _RegenerateApiSpy();

      await _repoWith(spy).previewRegenerateSeries(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        patternGroup: 'semanal',
        weekdays: const [3],
        intervalWeeks: 1,
        recurrenceEndDate: DateTime(2027, 3, 31, 19, 30),
      );

      expect(spy.rpcBodies.single['p_recurrence_end_date'], '2027-03-31');
    });

    test('data nula viaja como null, não como string vazia', () async {
      final spy = _RegenerateApiSpy();

      await _repoWith(spy).previewRegenerateSeries(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        patternGroup: 'semanal',
        weekdays: const [3],
        intervalWeeks: 1,
      );

      expect(spy.rpcBodies.single.containsKey('p_recurrence_end_date'), isTrue);
      expect(spy.rpcBodies.single['p_recurrence_end_date'], isNull);
    });

    test('a execução envia a MESMA chamada com p_dry_run: false', () async {
      final spy = _RegenerateApiSpy()
        ..response = {
          ..._jsonbRegenerate,
          'dry_run': false,
          'future_after_count': 12,
          'notified_count': 4,
        };

      final impacto = await _repoWith(spy).regenerateSeries(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        patternGroup: 'semanal',
        weekdays: const [3],
        intervalWeeks: 1,
        recurrenceEndDate: DateTime(2027, 3, 31),
      );

      expect(spy.rpcBodies.single.keys.toSet(), _chavesEsperadas);
      expect(spy.rpcBodies.single['p_dry_run'], isFalse);
      // O SnackBar de sucesso usa ESTES números, não os da prévia.
      expect(impacto.mode, 'regenerate');
      expect(impacto.futureAfterCount, 12);
      expect(impacto.dryRun, isFalse);
    });

    test('nenhuma das duas envia parâmetro de ator, de tenant ou de modo',
        () async {
      final spy = _RegenerateApiSpy();
      final repo = _repoWith(spy);

      await repo.previewRegenerateSeries(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        patternGroup: 'semanal',
        weekdays: const [3],
        intervalWeeks: 1,
      );
      await repo.regenerateSeries(
        batchId: _batchId,
        anchorEventId: _anchorEventId,
        patternGroup: 'semanal',
        weekdays: const [3],
        intervalWeeks: 1,
      );

      for (final body in spy.rpcBodies) {
        for (final proibida in _chavesProibidas) {
          expect(
            body.containsKey(proibida),
            isFalse,
            reason: '`$proibida` não pode sair do cliente — CHU-326, e o modo '
                'é decidido pelo servidor',
          );
        }
      }
    });

    test('42501 PROPAGA nos dois modos — nunca vira sucesso silencioso',
        () async {
      final spy = _RegenerateApiSpy()..failWithPermissionDenied = true;
      final repo = _repoWith(spy);

      await expectLater(
        () => repo.previewRegenerateSeries(
          batchId: _batchId,
          anchorEventId: _anchorEventId,
          patternGroup: 'semanal',
          weekdays: const [3],
          intervalWeeks: 1,
        ),
        throwsA(isA<PostgrestException>()),
      );
      await expectLater(
        () => repo.regenerateSeries(
          batchId: _batchId,
          anchorEventId: _anchorEventId,
          patternGroup: 'semanal',
          weekdays: const [3],
          intervalWeeks: 1,
        ),
        throwsA(isA<PostgrestException>()),
      );
    });

    test('EventSeriesImpact lê as 7 chaves novas do jsonb de regeneração', () {
      final impacto = EventSeriesImpact.fromJson(_jsonbRegenerate);

      expect(impacto.mode, 'regenerate');
      expect(impacto.keptCount, 1);
      expect(impacto.firstNew, DateTime(2026, 9, 9));
      expect(impacto.lastNew, DateTime(2026, 12, 23));
      expect(impacto.futureAfterCount, 12);
      expect(impacto.paidOccurrences, 0);
      expect(impacto.migratedSchedules, 0);
    });
  });
}
