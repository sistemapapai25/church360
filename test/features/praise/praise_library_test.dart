import 'package:church360_app/features/ministries/louvor/data/praise_repository.dart';
import 'package:church360_app/features/ministries/louvor/presentation/louvores_tab.dart';
import 'package:church360_app/features/ministries/louvor/presentation/providers/praise_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

PraiseSong _song(String id, String title, int version, DateTime at) =>
    PraiseSong(
      id: id,
      title: title,
      latest: PraiseSongVersion(
        id: 'v$id',
        songId: id,
        versionNumber: version,
        chordpro: '[G]x',
        changeNote: version > 1 ? 'troquei o tom' : null,
        createdAt: at,
      ),
    );

void main() {
  testWidgets('Biblioteca: favoritas, recentes, mais usadas e o que mudou', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({
      praiseRecentPref: ['b', 'a'],
    });
    await t.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => t.binding.setSurfaceSize(null));
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          praiseAccessProvider.overrideWith(
            (ref) async => (canView: true, canManage: false),
          ),
          praiseReceivedProvider('m1').overrideWith((ref) async => const []),
          praiseSongsProvider.overrideWith(
            (ref) async => [
              _song('a', 'Alfa', 1, DateTime.utc(2026, 9, 1)),
              _song('b', 'Beta', 3, DateTime.utc(2026, 10, 1, 12)),
              _song('c', 'Gama', 1, DateTime.utc(2026, 9, 15)),
            ],
          ),
          praiseUsageProvider(
            'm1',
          ).overrideWith((ref) async => {'c': 4, 'a': 1}),
          praiseActivityProvider('m1').overrideWith(
            (ref) async => [
              PraiseActivity(
                kind: 'setlist_published',
                at: DateTime.utc(2026, 10, 1, 13),
                who: 'Debora',
                setlistId: 'sl1',
                title: 'Culto de domingo',
                number: 2,
              ),
              PraiseActivity(
                kind: 'song_version',
                at: DateTime.utc(2026, 10, 1, 12),
                who: 'Gabriel',
                songId: 'b',
                title: 'Beta',
                number: 3,
                note: 'troquei o tom',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: LouvoresTab(ministryId: 'm1')),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Biblioteca'));
    await t.pumpAndSettle();

    List<String> titles() =>
        [
          for (final s in ['Alfa', 'Beta', 'Gama'])
            if (find.text(s).evaluate().isNotEmpty) s,
        ]..sort(
          (x, y) => t
              .getTopLeft(find.text(x))
              .dy
              .compareTo(t.getTopLeft(find.text(y)).dy),
        );

    expect(titles(), ['Alfa', 'Beta', 'Gama']);

    await t.tap(find.text('Favoritas'));
    await t.pumpAndSettle();
    expect(find.text('Nenhuma favorita ainda'), findsOneWidget);
    await t.tap(find.text('Todas'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Favoritar').at(2)); // Gama
    await t.pump();
    await t.tap(find.text('Favoritas'));
    await t.pumpAndSettle();
    expect(titles(), ['Gama']);

    await t.tap(find.text('Recentes'));
    await t.pumpAndSettle();
    expect(titles(), ['Beta', 'Alfa']);

    await t.tap(find.text('Mais usadas'));
    await t.pumpAndSettle();
    expect(titles(), ['Gama', 'Alfa']);
    expect(find.text('Em 4 repertório(s)'), findsOneWidget);

    await t.tap(find.text('O que mudou'));
    await t.pumpAndSettle();
    // Feed do ministério inteiro, com quem fez.
    expect(
      find.text('Repertório publicado: Culto de domingo (rev. 2)'),
      findsOneWidget,
    );
    expect(find.text('Beta · versão 3'), findsOneWidget);
    expect(
      find.textContaining('Gabriel · troquei o tom · 01/10'),
      findsOneWidget,
    );
    expect(find.text('Alfa'), findsNothing);
  });
}
