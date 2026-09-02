// Fase 6 — Achado #10 / Pitfall #8 (Plano 06-06, Task 1).
//
// ESTE ARQUIVO EXISTE PARA IMPEDIR O RETORNO DE UM BUG ATIVO EM PRODUÇÃO.
//
// Antes desta fase, o switch "Evento fixo" era renderizado também em modo de
// edição; `_loadEvent` nunca restaurava `_isFixed`; e `_saveEvent` ramificava
// em `if (_isFixed)` ANTES de olhar `_isEditMode`, num ramo que só cria
// ocorrências e nunca atualiza. Abrir uma ocorrência existente, ligar o
// switch e salvar gerava uma série inteira nova (até 52 eventos) sem tocar no
// evento editado.
//
// A correção tem duas metades — a guarda visual (`if (!_isEditMode)` no
// switch) e a guarda lógica (`if (_isFixed && !_isEditMode)` em
// `_saveEvent`). O teste abaixo trava a metade VISUAL: se o texto
// `Evento fixo` reaparecer na árvore em modo de edição, ele falha. A metade
// lógica é inalcançável sem a visual, porque `_isFixed` não é restaurado por
// nenhum caminho de edição.
//
// Espião `MockClient` sobre o PostgREST real, sem mock de repositório —
// mesmo molde de `event_series_repository_test.dart`.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/features/events/data/events_repository.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/events/presentation/screens/event_form_screen.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';

const _eventId = '11111111-0000-4000-8000-000000000001';
const _batchId = '22222222-0000-4000-8000-000000000002';

/// Linha de `public.event` devolvida pelo GET de `getEventById`.
Map<String, dynamic> _eventRow({String? batchId}) => {
  'id': _eventId,
  'name': 'Culto de Domingo',
  'description': null,
  'event_type': 'culto_normal',
  'start_date': '2026-09-06T19:30:00.000',
  'end_date': null,
  'location': 'Templo',
  'max_capacity': null,
  'requires_registration': false,
  'is_free': true,
  'is_mandatory': false,
  'status': 'published',
  'image_url': null,
  'created_at': '2026-08-01T00:00:00.000Z',
  'updated_at': null,
  'batch_id': batchId,
  'visibility_scope': 'all',
  'registration_scope': 'all',
};

/// Linha de `public.event_series` — série COM definição de padrão salva.
Map<String, dynamic> _seriesRow() => {
  'id': _batchId,
  'tenant_id': 'tenant-1',
  'anchor_date': '2026-09-06',
  'pattern_group': 'semanal',
  'variable_type': null,
  'weekdays': [DateTime.sunday],
  'interval_weeks': 1,
  'monthly_ordinal': null,
  'recurrence_end_date': '2026-12-31',
  'start_time_minutes': 1170,
  'created_at': '2026-09-02T00:00:00.000Z',
  'updated_at': '2026-09-02T00:00:00.000Z',
};

class _EventFormApiSpy {
  /// Corpo bruto do GET de `/event`. Uma lista com uma linha, porque
  /// `getEventById` usa `.maybeSingle()`.
  String eventRows = jsonEncode([_eventRow(batchId: _batchId)]);

  /// Corpo bruto do GET de `/event_series`. `'[]'` = série legada (IC-7).
  String seriesRows = jsonEncode([_seriesRow()]);

  http.Client get client => MockClient((request) async {
    final headers = {'content-type': 'application/json; charset=utf-8'};
    final path = request.url.path;

    if (path.endsWith('/event_series') && request.method == 'GET') {
      return http.Response(seriesRows, 200, request: request, headers: headers);
    }
    if (path.endsWith('/event') && request.method == 'GET') {
      return http.Response(eventRows, 200, request: request, headers: headers);
    }

    // Tudo o mais (event_type, event_location, event_audience,
    // event_reminder) responde vazio: o formulário tolera e cai nos padrões.
    return http.Response('[]', 200, request: request, headers: headers);
  });
}

SupabaseClient _clientWith(_EventFormApiSpy spy) => SupabaseClient(
  'https://example.supabase.co',
  'test-anon-key',
  httpClient: spy.client,
  // CHU-321: sem isso o timer de auto-refresh do GoTrue fica pendente e
  // quebra a checagem de "pending timer" do flutter_test.
  authOptions: const AuthClientOptions(autoRefreshToken: false),
);

Future<void> _pumpForm(
  WidgetTester tester,
  _EventFormApiSpy spy, {
  String? eventId,
}) async {
  final supabase = _clientWith(spy);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        supabaseClientProvider.overrideWithValue(supabase),
        eventsRepositoryProvider.overrideWithValue(
          EventsRepository(supabase),
        ),
      ],
      child: MaterialApp(home: EventFormScreen(eventId: eventId)),
    ),
  );
  // `_loadEvent` encadeia várias chamadas assíncronas; `pumpAndSettle` não
  // serve porque o `CircularProgressIndicator` de carregamento nunca para de
  // animar enquanto está montado.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Todo texto renderizado, incluindo `Text.rich`.
List<String> _textos(WidgetTester tester) {
  final saida = <String>[];
  for (final widget in tester.allWidgets) {
    if (widget is Text) {
      final direto = widget.data;
      if (direto != null) {
        saida.add(direto);
      } else {
        final span = widget.textSpan;
        if (span != null) saida.add(span.toPlainText());
      }
    }
  }
  return saida;
}

void main() {
  group('Pitfall #8 — o switch "Evento fixo" some em modo de edição', () {
    testWidgets(
      'ocorrência DE SÉRIE em edição não renderiza "Evento fixo"',
      (tester) async {
        final spy = _EventFormApiSpy();

        await _pumpForm(tester, spy, eventId: _eventId);

        expect(
          _textos(tester),
          isNot(contains('Evento fixo')),
          reason:
              'O switch de geração de série não pode existir em modo de '
              'edição: ligá-lo e salvar gerava uma série inteira nova.',
        );
      },
    );

    testWidgets(
      'evento SEM série em edição também não renderiza "Evento fixo" (A-08)',
      (tester) async {
        final spy = _EventFormApiSpy()
          ..eventRows = jsonEncode([_eventRow(batchId: null)]);

        await _pumpForm(tester, spy, eventId: _eventId);

        expect(_textos(tester), isNot(contains('Evento fixo')));
        // Sem lote não há cabeçalho de série.
        expect(_textos(tester), isNot(contains('Série')));
      },
    );

    testWidgets('em modo de CRIAÇÃO o switch continua existindo', (
      tester,
    ) async {
      final spy = _EventFormApiSpy();

      await _pumpForm(tester, spy, eventId: null);

      expect(_textos(tester), contains('Evento fixo'));
    });
  });

  group('IC-2 — cabeçalho de série no formulário em edição', () {
    testWidgets('ocorrência de série mostra o badge "Série"', (tester) async {
      final spy = _EventFormApiSpy();

      await _pumpForm(tester, spy, eventId: _eventId);

      expect(_textos(tester), contains('Série'));
    });

    testWidgets(
      'com definição salva, a linha de contexto traz data E padrão',
      (tester) async {
        final spy = _EventFormApiSpy();

        await _pumpForm(tester, spy, eventId: _eventId);

        final linha = _textos(
          tester,
        ).firstWhere((t) => t.startsWith('Ocorrência de '));
        expect(linha, contains(' · '));
        expect(linha, contains('Toda semana, domingo'));
      },
    );

    testWidgets(
      'série LEGADA (sem linha em event_series) omite o padrão da linha',
      (tester) async {
        final spy = _EventFormApiSpy()..seriesRows = '[]';

        await _pumpForm(tester, spy, eventId: _eventId);

        final linha = _textos(
          tester,
        ).firstWhere((t) => t.startsWith('Ocorrência de '));
        expect(
          linha,
          isNot(contains(' · ')),
          reason:
              'Série legada não tem padrão salvo — inventar uma descrição '
              'seria pior do que não mostrar nenhuma (IC-7).',
        );
      },
    );
  });
}
