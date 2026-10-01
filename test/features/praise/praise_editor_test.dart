import 'package:church360_app/features/ministries/louvor/data/praise_repository.dart';
import 'package:church360_app/features/ministries/louvor/presentation/praise_song_editor_screen.dart';
import 'package:church360_app/features/ministries/louvor/presentation/providers/praise_providers.dart';
import 'package:church360_app/features/ministries/presentation/providers/ministries_provider.dart';
import 'package:church360_app/features/praise/domain/chordpro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('título para comparar: sem acento, caixa e pontuação', () {
    expect(foldTitle('Grande é o Senhor!'), foldTitle('grande e o senhor'));
    expect(foldTitle('  Ação  de   Graças '), 'acao de gracas');
  });

  test('título parecido também avisa', () {
    expect(similarTitle('Escape', 'Escape (Ao vivo)'), isTrue);
    expect(similarTitle('Grande é o Senhor', 'Grande é Senhor'), isTrue);
    expect(similarTitle('Ousado Amor', 'Ousado amor!'), isTrue);
    expect(similarTitle('Deus', 'Jesus'), isFalse);
    expect(similarTitle('Oceanos', 'Oceano'), isTrue);
    expect(similarTitle('Te Louvarei', 'Te Adorarei'), isFalse);
    expect(similarTitle('Céu', 'Céus'), isFalse);
  });

  testWidgets('música nova com título repetido avisa antes de salvar', (
    t,
  ) async {
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          ministriesCanSeeAllProvider.overrideWith((ref) async => true),
          ministryAccessProvider('m1').overrideWith((ref) async => true),
          praiseAccessProvider.overrideWith(
            (ref) async => (canView: true, canManage: true),
          ),
          praiseSongsProvider.overrideWith(
            (ref) async => const [
              PraiseSong(
                id: 's1',
                title: 'Grande é o Senhor',
                artist: 'Adhemar',
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: PraiseSongEditorScreen(ministryId: 'm1'),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.enterText(
      find.widgetWithText(TextFormField, 'Título *'),
      'GRANDE E O SENHOR',
    );
    final chords = find.byWidgetPredicate(
      (w) => w is TextField && w.minLines == 12,
    );
    await t.ensureVisible(chords);
    await t.enterText(chords, '[G]Grande');
    await t.tap(find.text('Salvar'));
    await t.pumpAndSettle();
    expect(find.text('Música já cadastrada'), findsOneWidget);
    expect(find.text('Criar mesmo assim'), findsOneWidget);
    await t.tap(find.text('Cancelar'));
    await t.pumpAndSettle();
    expect(find.text('Música já cadastrada'), findsNothing);
  });
}
