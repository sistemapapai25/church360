import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:church360_app/core/design/app_icons.dart';
import 'package:church360_app/core/theme/app_theme.dart';
import 'package:church360_app/core/widgets/glass_card.dart';
import 'package:church360_app/core/widgets/status_badge.dart';
import 'package:church360_app/features/members/presentation/providers/members_provider.dart';
import 'package:church360_app/features/permissions/providers/permissions_providers.dart';
import 'package:church360_app/features/study_groups/data/study_group_repository.dart';
import 'package:church360_app/features/study_groups/domain/models/study_group.dart';
import 'package:church360_app/features/study_groups/presentation/providers/study_group_provider.dart';
import 'package:church360_app/features/study_groups/presentation/screens/lesson_detail_screen.dart';
import 'package:church360_app/features/study_groups/presentation/screens/study_group_detail_screen.dart';
import 'package:church360_app/features/study_groups/presentation/screens/study_group_form_screen.dart';

final _now = DateTime(2026, 9, 25);

StudyGroup _group() {
  return StudyGroup(
    id: 'study-1',
    name: 'Evangelho de João',
    description: 'Leitura e conversa sobre o quarto evangelho.',
    studyTopic: 'João 1–3',
    status: StudyGroupStatus.active,
    startDate: _now,
    meetingDay: 'Quarta-feira',
    meetingTime: '19:30',
    meetingLocation: 'Sala 3',
    maxParticipants: 12,
    isPublic: true,
    createdAt: _now,
    updatedAt: _now,
  );
}

StudyLesson _lesson() {
  return StudyLesson(
    id: 'lesson-1',
    studyGroupId: 'study-1',
    lessonNumber: 1,
    title: 'A Palavra e a Vida',
    description: 'Uma introdução ao texto.',
    bibleReferences: 'João 1:1-18',
    content: '## A Palavra\n\nConteúdo da lição.',
    discussionQuestions: const ['O que chamou sua atenção?'],
    status: LessonStatus.published,
    videoUrl: 'https://example.com/video',
    createdAt: _now,
    updatedAt: _now,
  );
}

class _FakeStudyGroupRepository extends StudyGroupRepository {
  final StudyGroup group;
  final StudyLesson lesson;

  _FakeStudyGroupRepository(this.group, this.lesson)
    : super(
        SupabaseClient(
          'http://localhost',
          'test-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );

  @override
  Future<List<StudyGroup>> getActiveStudyGroups() async => [group];

  @override
  Future<StudyGroup?> getStudyGroupById(String id) async => group;

  @override
  Future<List<StudyLesson>> getPublishedLessons(String groupId) async => [
    lesson,
  ];

  @override
  Future<List<StudyParticipant>> getGroupParticipants(String groupId) async =>
      const [];

  @override
  Future<StudyParticipant?> getUserParticipation(
    String groupId,
    String userId,
  ) async => null;

  @override
  Future<StudyLesson?> getLessonById(String id) async => lesson;

  @override
  Future<bool> isUserLeader(String groupId, String userId) async => false;
}

Widget _host(Widget child, List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(theme: AppTheme.lightTheme, home: child),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await Supabase.initialize(
      url: 'https://example.supabase.co',
      anonKey: 'test-anon-key',
    );
  });

  testWidgets('detalhe de grupo organiza abas e superfícies compartilhadas', (
    tester,
  ) async {
    final repo = _FakeStudyGroupRepository(_group(), _lesson());
    await tester.pumpWidget(
      _host(const StudyGroupDetailScreen(groupId: 'study-1'), [
        studyGroupRepositoryProvider.overrideWithValue(repo),
        studyGroupByIdProvider(
          'study-1',
        ).overrideWith((ref) async => repo.group),
        publishedLessonsProvider(
          'study-1',
        ).overrideWith((ref) async => [repo.lesson]),
        groupParticipantsProvider('study-1').overrideWith((ref) async => []),
        allMembersProvider.overrideWith((ref) async => []),
        currentMemberProvider.overrideWith((ref) async => null),
        currentUserHasPermissionProvider.overrideWith(
          (ref, permission) async => false,
        ),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.text('Evangelho de João'), findsOneWidget);
    expect(find.byType(GlassCard), findsOneWidget);
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.byIcon(AppIcons.info), findsOneWidget);
  });

  testWidgets('formulário de grupo agrupa contexto e usa catálogo semântico', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(const StudyGroupFormScreen(), [
        currentUserHasPermissionProvider(
          'study_groups.create',
        ).overrideWith((ref) async => true),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GlassCard), findsAtLeastNWidgets(2));
    expect(find.text('Informações do grupo'), findsOneWidget);
    expect(find.byIcon(AppIcons.group), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Acesso e status'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(GlassCard), findsAtLeastNWidgets(1));
    await tester.scrollUntilVisible(
      find.byIcon(AppIcons.save),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byIcon(AppIcons.save), findsOneWidget);
  });

  testWidgets('detalhe da lição usa vidro, status e recursos semânticos', (
    tester,
  ) async {
    final repo = _FakeStudyGroupRepository(_group(), _lesson());
    await tester.pumpWidget(
      _host(
        const LessonDetailScreen(groupId: 'study-1', lessonId: 'lesson-1'),
        [
          studyGroupRepositoryProvider.overrideWithValue(repo),
          lessonByIdProvider(
            'lesson-1',
          ).overrideWith((ref) async => repo.lesson),
        ],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A Palavra e a Vida'), findsOneWidget);
    expect(find.byType(GlassCard), findsNWidgets(2));
    expect(find.byType(StatusBadge), findsOneWidget);
    expect(find.byIcon(AppIcons.videoLibrary), findsOneWidget);
  });
}
