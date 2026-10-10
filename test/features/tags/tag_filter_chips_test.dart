import 'package:church360_app/features/tags/domain/models/tag.dart';
import 'package:church360_app/features/tags/presentation/providers/tags_provider.dart';
import 'package:church360_app/features/tags/presentation/widgets/tag_filter_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _tags = [
  Tag(id: 'p', name: 'Precisa de visita', createdAt: DateTime(2026, 10, 10)),
  Tag(
    id: 'm',
    name: 'Louvor',
    createdAt: DateTime(2026, 10, 10),
    appliesTo: 'ministry',
  ),
];

Widget _host({required bool ministry}) => ProviderScope(
  overrides: [allTagsProvider.overrideWith((ref) async => _tags)],
  child: MaterialApp(
    home: Scaffold(
      body: TagFilterChips(
        selectedTagId: null,
        onChanged: (_) {},
        ministry: ministry,
      ),
    ),
  ),
);

void main() {
  testWidgets('filtro de pessoas não mostra tag de ministério', (tester) async {
    await tester.pumpWidget(_host(ministry: false));
    await tester.pumpAndSettle();
    expect(find.text('Precisa de visita'), findsOneWidget);
    expect(find.text('Louvor'), findsNothing);
  });

  testWidgets('filtro de ministérios só mostra tag de ministério', (
    tester,
  ) async {
    await tester.pumpWidget(_host(ministry: true));
    await tester.pumpAndSettle();
    expect(find.text('Louvor'), findsOneWidget);
    expect(find.text('Precisa de visita'), findsNothing);
  });
}
