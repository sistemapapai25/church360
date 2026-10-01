import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/features/ministries/louvor/data/praise_repository.dart';
import 'package:church360_app/features/ministries/louvor/presentation/praise_setlist_screen.dart';
import 'package:church360_app/features/ministries/louvor/presentation/praise_setlists_view.dart';
import 'package:church360_app/features/ministries/louvor/presentation/praise_song_reader_screen.dart';
import 'package:church360_app/features/ministries/louvor/presentation/providers/praise_providers.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/ministries/shared/domain/ministry_type_catalog.dart';
import 'package:church360_app/features/ministries/shared/presentation/widgets/ministry_workspace_shell.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _ministry = 'm1';
const _setlist = 's1';

Map<String, dynamic> _version(String id, String key, String chordpro) => {
  'id': id,
  'song_id': 'song-$id',
  'version_number': 2,
  'chordpro': chordpro,
  'original_key': key,
  'capo': 0,
  'bpm': null,
  'change_note': null,
  'created_at': '2026-10-01T10:00:00+00:00',
  'praise_song': {'title': 'Música $id', 'artist': null},
};

Map<String, dynamic> _item(String id, int pos, String version, String key) => {
  'id': id,
  'position': pos,
  'selected_key': key,
  'capo': 0,
  'bpm': null,
  'notes': null,
  'praise_song_version': _version(version, 'G', '{key: G}\n[G]Santo [D]santo'),
};

PraiseSetlist _setlistWith(String status, {int number = 1}) =>
    PraiseSetlist.fromJson({
      'id': _setlist,
      'event_id': null,
      'event': null,
      'ministry': {'name': 'Som das Águas'},
      'praise_setlist_revision': [
        {
          'id': 'r1',
          'revision_number': number,
          'title': 'Culto de domingo',
          'status': status,
          'published_at': null,
          // Fora de ordem de propósito: a ordem vem de `position`.
          'praise_setlist_item': [
            _item('i2', 2, 'B', 'D'),
            _item('i1', 1, 'A', 'A'),
          ],
        },
      ],
    });

class _FakeRepo implements PraiseRepository {
  List<String>? savedOrder;

  @override
  Future<void> saveDraft(
    String revisionId,
    String title,
    List<PraiseSetlistItem> items,
  ) async => savedOrder = [for (final i in items) i.songTitle];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _pump(
  WidgetTester t,
  Widget screen,
  PraiseSetlist setlist, {
  PraiseRepository? repo,
  bool canPublish = true,
  List<Override> extra = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  await t.binding.setSurfaceSize(const Size(420, 900));
  addTearDown(() => t.binding.setSurfaceSize(null));
  // ProviderScope novo a cada montagem (overrides diferentes).
  await t.pumpWidget(const SizedBox());
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        ministriesCanSeeAllProvider.overrideWith((ref) async => true),
        ministryAccessProvider(_ministry).overrideWith((ref) async => true),
        praiseAccessProvider.overrideWith(
          (ref) async => (canView: true, canManage: false),
        ),
        praiseSetlistAccessProvider.overrideWith(
          (ref) async => (canManage: true, canPublish: canPublish),
        ),
        praiseSetlistProvider(_setlist).overrideWith((ref) async => setlist),
        // A música some da biblioteca: o leitor usa a versão do item.
        praiseSongProvider.overrideWith((ref, id) async => null),
        if (repo != null) praiseRepositoryProvider.overrideWithValue(repo),
        praisePublisherNameProvider.overrideWith((ref, id) async => 'Debora'),
        ...extra,
      ],
      child: MaterialApp(home: screen),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  test('revisão ordena itens por posição e conta a lista', () {
    final rev = _setlistWith('published').published!;
    expect([for (final i in rev.items) i.id], ['i1', 'i2']);
    expect(rev.itemCount, 2);
  });

  test('situação do card: rascunho, publicado e editando', () {
    final list = PraiseSetlist.fromJson({
      'id': 's',
      'event_id': null,
      'praise_setlist_revision': [
        {
          'id': 'a',
          'revision_number': 1,
          'title': 't',
          'status': 'published',
          'praise_setlist_item': [
            {'count': 3},
          ],
        },
        {
          'id': 'b',
          'revision_number': 2,
          'title': 't',
          'status': 'draft',
          'praise_setlist_item': [
            {'count': 4},
          ],
        },
      ],
    });
    expect(setlistStatus(list).label, 'Editando · rev. 2');
    expect(list.current!.itemCount, 4);
  });

  test('próximos: hoje conta, ontem não (data de parede, sem fuso)', () {
    final now = DateTime(2026, 10, 5, 21);
    expect(
      PraiseSetlistsView.isUpcoming(DateTime.utc(2026, 10, 5, 9), now),
      isTrue,
    );
    expect(
      PraiseSetlistsView.isUpcoming(DateTime.utc(2026, 10, 4, 23), now),
      isFalse,
    );
  });

  testWidgets('leitor abre no tom do item e mostra a próxima', (t) async {
    await _pump(
      t,
      const PraiseSetlistItemReaderScreen(
        ministryId: _ministry,
        setlistId: _setlist,
        itemId: 'i1',
      ),
      _setlistWith('published'),
    );
    expect(find.text('Tom: A'), findsOneWidget);
    // G e D da versão, transpostos +2 (na faixa de acordes e no corpo).
    expect(find.text('E'), findsNWidgets(2));
    expect(find.text('G'), findsNothing);
    expect(find.text('Culto de domingo · 1 de 2'), findsOneWidget);
    expect(find.text('Próxima · D'), findsOneWidget);

    // Tocar no acorde abre o painel com as notas.
    await t.tap(find.text('E').last);
    await t.pumpAndSettle();
    expect(find.text('Notas: E G# B'), findsOneWidget);
    Navigator.of(t.element(find.text('Notas: E G# B'))).pop();
    await t.pumpAndSettle();

    // Tocar em "1 de 2" lista o repertório para pular direto.
    await t.tap(find.text('Culto de domingo · 1 de 2'));
    await t.pumpAndSettle();
    expect(find.text('Música B'), findsNWidgets(2)); // lista + "Próxima"
    Navigator.of(t.element(find.text('Música B').last)).pop();
    await t.pumpAndSettle();

    // Capo nos Ajustes muda o desenho, não o nome do acorde.
    await t.tap(find.text('Ajustes · Violão e guitarra'));
    await t.pumpAndSettle();
    await t.tap(find.text('Sem capotraste'));
    await t.pumpAndSettle();
    await t.tap(find.text('2ª casa').last);
    await t.pumpAndSettle();
    Navigator.of(t.element(find.text('Capotraste'))).pop();
    await t.pumpAndSettle();
    expect(find.text('Capo 2'), findsOneWidget);
    await t.tap(find.text('E').last);
    await t.pumpAndSettle();
    expect(find.text('Desenho de D (capo/afinação)'), findsOneWidget);
  });

  testWidgets('arrastar reordena o rascunho e salvar manda a nova ordem', (
    t,
  ) async {
    final repo = _FakeRepo();
    await _pump(
      t,
      const PraiseSetlistScreen(ministryId: _ministry, setlistId: _setlist),
      _setlistWith('draft'),
      repo: repo,
    );
    expect(find.text('Música A'), findsOneWidget);

    final handle = find.byIcon(AppIcons.dragHandle).first;
    final gesture = await t.startGesture(t.getCenter(handle));
    await t.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 15));
      await t.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await t.pumpAndSettle();

    await t.tap(find.text('Salvar rascunho'));
    await t.pumpAndSettle();
    expect(repo.savedOrder, ['Música B', 'Música A']);
  });

  // ------------------------------------------------------------- Fase D

  test('o que mudou: entrou, saiu e tom', () {
    PraiseSetlistRevision rev(List<Map<String, dynamic>> items) =>
        PraiseSetlistRevision.fromJson({
          'id': 'r',
          'revision_number': 1,
          'title': 't',
          'status': 'published',
          'praise_setlist_item': items,
        });
    final before = rev([_item('i1', 1, 'A', 'G'), _item('i2', 2, 'B', 'D')]);
    final after = rev([_item('i3', 1, 'A', 'A'), _item('i4', 2, 'C', 'E')]);
    expect(
      [for (final c in setlistChanges(before, after)) c.text],
      ['Música C entrou', 'Música B saiu', 'Música A: tom G → A'],
    );
    expect(setlistChanges(before, before), isEmpty);
  });

  testWidgets('recebido é só leitura mesmo para quem publica', (t) async {
    await _pump(
      t,
      const PraiseSetlistScreen(
        ministryId: _ministry,
        setlistId: _setlist,
        received: true,
      ),
      _setlistWith('published'),
    );
    expect(find.text('Repertório recebido'), findsOneWidget);
    expect(find.text('Só leitura'), findsOneWidget);
    expect(find.text('Recebido de Som das Águas'), findsOneWidget);
    expect(find.text('Música A'), findsOneWidget);
    expect(find.textContaining('Editar'), findsNothing);
    expect(find.text('Excluir repertório'), findsNothing);
    expect(find.text('Destinatários'), findsNothing);
  });

  testWidgets('recebido na rev. 2 mostra o que mudou', (t) async {
    final before = PraiseSetlistRevision.fromJson({
      'id': 'r0',
      'revision_number': 1,
      'title': 'Culto de domingo',
      'status': 'archived',
      'praise_setlist_item': [_item('i0', 1, 'A', 'G')],
    });
    await _pump(
      t,
      const PraiseSetlistScreen(
        ministryId: _ministry,
        setlistId: _setlist,
        received: true,
      ),
      _setlistWith('published', number: 2),
      extra: [
        praiseRevisionProvider((
          _setlist,
          1,
        )).overrideWith((ref) async => before),
      ],
    );
    expect(find.text('O que mudou desde a rev. 1'), findsOneWidget);
    expect(find.text('Música B entrou'), findsOneWidget);
    expect(find.text('Música A: tom G → A'), findsOneWidget);
  });

  testWidgets(
    'publicado mostra destinatários e "Alterar" só para quem publica',
    (t) async {
      final recipients = praiseRecipientsProvider('r1').overrideWith(
        (ref) async => [
          (id: 'm2', name: 'Mídia'),
          (id: 'm3', name: 'Diaconato'),
        ],
      );
      const screen = PraiseSetlistScreen(
        ministryId: _ministry,
        setlistId: _setlist,
      );
      await _pump(t, screen, _setlistWith('published'), extra: [recipients]);
      expect(find.text('Mídia · Diaconato'), findsOneWidget);
      expect(find.text('Alterar'), findsOneWidget);

      await _pump(
        t,
        screen,
        _setlistWith('published'),
        canPublish: false,
        extra: [recipients],
      );
      expect(find.text('Mídia · Diaconato'), findsOneWidget);
      expect(find.text('Alterar'), findsNothing);
    },
  );

  testWidgets('"Só letra" tira os acordes do leitor recebido', (t) async {
    await _pump(
      t,
      const PraiseSetlistItemReaderScreen(
        ministryId: _ministry,
        setlistId: _setlist,
        itemId: 'i1',
        received: true,
      ),
      _setlistWith('published'),
    );
    expect(find.text('E'), findsNWidgets(2));
    await t.tap(find.text('Só letra'));
    await t.pumpAndSettle();
    expect(find.text('E'), findsNothing);
    expect(find.text('Tom: A'), findsNothing);
    expect(find.text('Santo'), findsOneWidget);
  });

  testWidgets('ministério que recebeu ganha a aba Louvores', (t) async {
    Widget shell(List<MinistryWorkspaceTab> tabs, List<PraiseSetlist> got) =>
        ProviderScope(
          overrides: [
            ministryByIdProvider(_ministry).overrideWith((ref) async => null),
            currentUserHasPermissionProvider(
              'ministries.edit',
            ).overrideWith((ref) async => false),
            praiseReceivedProvider(_ministry).overrideWith((ref) async => got),
          ],
          child: MaterialApp(
            home: MinistryWorkspaceShell(
              ministryId: _ministry,
              fallbackTitle: 'Mídia',
              tabs: tabs,
            ),
          ),
        );
    final equipe = MinistryWorkspaceTab(
      label: 'Equipe',
      builder: (_) => const Text('corpo-equipe'),
    );

    await t.pumpWidget(shell([equipe], const []));
    await t.pumpAndSettle();
    expect(find.text('Louvores'), findsNothing);

    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(shell([equipe], [_setlistWith('published')]));
    await t.pumpAndSettle();
    expect(find.text('Louvores'), findsOneWidget);

    // Ministério de louvor já tem a aba: não duplica.
    await t.pumpWidget(const SizedBox());
    await t.pumpWidget(
      shell(
        [
          equipe,
          MinistryWorkspaceTab(
            label: 'Louvores',
            key: MinistryTabKeys.louvores,
            builder: (_) => const Text('corpo-louvores'),
          ),
        ],
        [_setlistWith('published')],
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Louvores'), findsOneWidget);
  });
}
