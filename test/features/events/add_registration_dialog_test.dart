import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:church360_app/features/events/presentation/widgets/add_registration_dialog.dart';
import 'package:church360_app/features/events/presentation/providers/events_provider.dart';
import 'package:church360_app/features/members/domain/models/member_directory_entry.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';

// Nenhum teste aqui toca `eventsRepositoryProvider` (só é lido ao tocar
// "Adicionar", fora do escopo destes 5 testes) nem `supabaseClientProvider`
// (memberDirectoryProvider é sobrescrito por inteiro, então nunca chega a
// resolver `membersRepositoryProvider`) — por isso não é preciso instanciar
// `SupabaseClient` nem mockar rede neste arquivo.
const _eventId = '11111111-0000-4000-8000-000000000001';

Future<void> _pumpDialog(
  WidgetTester tester, {
  required List<Override> overrides,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: const MaterialApp(
        home: Scaffold(
          body: AddRegistrationDialog(eventId: _eventId),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'lista os membros do diretório (prova REG-01: lista não vem vazia)',
    (tester) async {
      await _pumpDialog(
        tester,
        overrides: [
          memberDirectoryProvider.overrideWith(
            (ref) async => [
              MemberDirectoryEntry(id: 'm1', fullName: 'Ana Silva'),
              MemberDirectoryEntry(id: 'm2', fullName: 'Bruno Souza'),
            ],
          ),
          eventRegistrationsProvider(_eventId).overrideWith(
            (ref) async => const [],
          ),
        ],
      );

      expect(find.text('Ana Silva'), findsOneWidget);
      expect(find.text('Bruno Souza'), findsOneWidget);
    },
  );

  testWidgets(
    'renderiza apelido como subtitle quando presente, e omite quando nulo',
    (tester) async {
      await _pumpDialog(
        tester,
        overrides: [
          memberDirectoryProvider.overrideWith(
            (ref) async => [
              MemberDirectoryEntry(id: 'm1', fullName: 'Ana Silva', nickname: 'Aninha'),
              MemberDirectoryEntry(id: 'm2', fullName: 'Bruno Souza'),
            ],
          ),
          eventRegistrationsProvider(_eventId).overrideWith(
            (ref) async => const [],
          ),
        ],
      );

      expect(find.text('Aninha'), findsOneWidget);

      final brunoTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Bruno Souza'),
          matching: find.byType(ListTile),
        ),
      );
      expect(brunoTile.subtitle, isNull);
    },
  );

  testWidgets(
    'nenhum texto renderizado contém e-mail (modelo não expõe email)',
    (tester) async {
      await _pumpDialog(
        tester,
        overrides: [
          memberDirectoryProvider.overrideWith(
            (ref) async => [
              MemberDirectoryEntry(id: 'm1', fullName: 'Ana Silva', nickname: 'Aninha'),
            ],
          ),
          eventRegistrationsProvider(_eventId).overrideWith(
            (ref) async => const [],
          ),
        ],
      );

      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final widget in textWidgets) {
        final data = widget.data;
        if (data != null) {
          expect(data.contains('@'), isFalse, reason: 'texto renderizado: "$data"');
        }
      }
    },
  );

  testWidgets(
    'lista vazia mostra "Todos já estão inscritos"',
    (tester) async {
      await _pumpDialog(
        tester,
        overrides: [
          memberDirectoryProvider.overrideWith((ref) async => []),
          eventRegistrationsProvider(_eventId).overrideWith(
            (ref) async => const [],
          ),
        ],
      );

      expect(find.text('Todos já estão inscritos'), findsOneWidget);
    },
  );

  testWidgets(
    'erro ao carregar mostra copy PT-BR e botão de retry, sem "Erro:" cru',
    (tester) async {
      await _pumpDialog(
        tester,
        overrides: [
          memberDirectoryProvider.overrideWith(
            (ref) async => throw Exception('boom'),
          ),
          eventRegistrationsProvider(_eventId).overrideWith(
            (ref) async => const [],
          ),
        ],
      );

      expect(
        find.text('Não foi possível carregar a lista de membros.'),
        findsOneWidget,
      );
      expect(find.text('Tentar novamente'), findsOneWidget);
      expect(find.textContaining('Erro:'), findsNothing);
    },
  );
}
