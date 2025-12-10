# Church360 — Visão Geral do Sistema

Este documento descreve a arquitetura, os principais fluxos e componentes do Church360 para que outro agente possa entender e operar o sistema de ponta a ponta.

## Stack e Organização
- Framework: Flutter (Web), gerenciamento de estado com Riverpod.
- Backend: Supabase (REST/Postgrest) para dados e autenticação.
- Estrutura: `app/lib/features/<domínio>` para módulos funcionais; `core` para navegação e utilitários.
- Navegação: `app/lib/core/navigation/app_router.dart` carrega telas, incluindo o gerador de escala.

## Navegação
- Importação da tela do gerador: `app/lib/core/navigation/app_router.dart:53`.
- Telas relevantes de escala:
  - Gerador: `app/lib/features/schedule/presentation/screens/auto_schedule_generator_screen.dart`.
  - Pré‑visualização/edição: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart`.
  - Regras: `app/lib/features/schedule/presentation/screens/schedule_rules_preferences_screen.dart`.

## Telas e Rotas (Catálogo)
- Framework de navegação: `GoRouter` configurado em `app/lib/core/navigation/app_router.dart`.
- Rotas por domínio (paths → tela):
  - Autenticação:
    - `/splash` → `SplashScreen` (`app/lib/core/screens/splash_screen.dart`).
    - `/login` → `LoginScreen` (`app/lib/features/auth/presentation/screens/login_screen.dart`).
    - `/signup` → `SignUpScreen` (`app/lib/features/auth/presentation/screens/signup_screen.dart`).
  - Home/Dashboard:
    - `/home` → `HomeScreen` (`app/lib/core/screens/home_screen.dart`).
    - `/dashboard` → `DashboardScreen` com `DashboardAccessGate` (`app/lib/core/screens/dashboard_screen.dart`).
    - `/dashboard-settings` → `DashboardSettingsScreen` (`app/lib/core/screens/dashboard_settings_screen.dart`).
  - Membros:
    - `/members` → `MembersListScreen`.
    - `/members/new` → `MemberFormScreen`.
    - `/members/:id/edit` → `MemberFormScreen`.
    - `/members/:id/profile` → `MemberProfileScreen`.
    - `/members/:id` → `MemberDetailScreen`.
    - `/profile` → `ProfileScreen`; `/profile/edit` → `EditProfileScreen`.
  - Grupos de Comunhão:
    - `/groups` → `GroupsListScreen`.
    - `/groups/new` → `GroupFormScreen`; `/groups/:id/edit` → `GroupFormScreen`.
    - `/groups/:id` → `GroupDetailScreen`.
    - Reuniões: `/groups/:groupId/meetings/new|:meetingId|:meetingId/edit` → `MeetingFormScreen`/`MeetingDetailScreen`.
    - Visita/Follow‑up de visitante em reunião: paths sob `/groups/:groupId/meetings/:meetingId/...`.
  - Ministérios:
    - `/ministries` → `MinistriesListScreen`.
    - `/ministries/new|:id/edit` → `MinistryFormScreen`.
    - `/ministries/:id` → `MinistryDetailScreen`.
    - Escalas: `/ministries/:id/auto-scheduler` → `AutoScheduleGeneratorScreen` (`app/lib/core/navigation/app_router.dart:294-299`).
    - Regras: `/ministries/:id/schedule-rules` → `ScheduleRulesPreferencesScreen`.
    - Histórico: `/ministries/:id/scale-history` → `ScaleHistoryScreen`.
  - Financeiro:
    - `/financial` → `FinancialScreen`.
    - Contribuições: `/contributions/new|:id/edit` → `ContributionFormScreen`.
    - Despesas: `/expenses/new|:id/edit` → `ExpenseFormScreen`.
    - Metas: `/financial-goals/new|:id/edit` → `FinancialGoalFormScreen`.
    - Relatórios financeiros: `/financial-reports` → `FinancialReportsScreen`.
    - Gestão de contribuição: `/manage-contribution` → `ManageContributionScreen`.
  - Cultos (Worship):
    - `/worship-services` → `WorshipServicesScreen`.
    - `/worship-services/:id/attendance` → `WorshipAttendanceScreen`.
    - `/worship-services/new|:id/edit` → `WorshipServiceFormScreen`.
    - `/worship-statistics` → `WorshipStatisticsScreen`.
  - Visitantes:
    - `/visitors` → `VisitorsListScreen`; `/visitors/statistics` → `VisitorsStatisticsScreen`.
    - `/visitors/new|:id/edit` → `VisitorFormScreen`.
    - `/qr-scanner` → `QRScannerScreen`.
    - Follow‑ups: `/visitors/:id/visit/new`, `/visitors/:id/followup/new|:followupId/edit` → `VisitorVisitFormScreen`/`VisitorFollowupFormScreen`.
  - Níveis de Acesso (Admin):
    - `/access-levels` → `AccessLevelsListScreen`; `/access-levels/history` → `AccessLevelHistoryScreen`.
    - `/access-levels/history/:userId` → `AccessLevelHistoryScreen` (por usuário).
  - Devocionais:
    - `/devotionals` → `DevotionalsListScreen`.
    - `/devotionals/new|:id/edit` → `DevotionalFormScreen`.
    - `/devotionals/:id` → `DevotionalDetailScreen`.
  - Pedidos de Oração:
    - `/prayer-requests` → `PrayerRequestsListScreen`.
    - `/prayer-requests/new|:id|:id/edit` → `PrayerRequestFormScreen`/`PrayerRequestDetailScreen`.
    - Versões admin sob `/home/prayer-requests`.
  - Notificações:
    - `/notifications` → `NotificationsListScreen`.
    - `/notifications/preferences` → `NotificationPreferencesScreen`.
  - Grupos de Estudo:
    - `/study-groups` → `StudyGroupsListScreen`.
    - `/study-groups/new|:id/edit` → `StudyGroupFormScreen`.
    - `/study-groups/:id` → `StudyGroupDetailScreen`.
    - Lições: `/study-groups/:groupId/lessons/:lessonId` → `LessonDetailScreen`.
  - Materiais de Apoio:
    - `/support-materials` → `SupportMaterialsScreen`.
    - `/support-materials/new|:id/edit|:id` → `SupportMaterialFormScreen`/`MaterialViewerScreen`.
    - Módulos: `/support-materials/:id/modules` → `MaterialModulesScreen`; `/support-materials/:materialId/modules/:moduleId` → `ModuleViewerScreen`.
  - Analytics:
    - `/analytics` → `AnalyticsDashboardScreen`.
  - Agenda:
    - `/schedule` → `ScheduleScreen`.
  - Agenda da Igreja:
    - `/church-schedule` → `ChurchScheduleListScreen`.
    - `/church-schedule/new|:id/edit` → `ChurchScheduleFormScreen`.
  - Eventos:
    - `/events` → `EventsListScreen`; `/events/types` → `EventTypesManageScreen`.
    - `/events/new|:id/edit|:id` → `EventFormScreen`/`EventDetailScreen`.
    - `/events/:id/register` → `EventRegistrationScreen`.
  - Cursos:
    - `/courses` → `CoursesListScreen` (com `showFab` via query `from=dashboard`).
    - `/courses/new|:id/edit` → `CourseFormScreen`.
    - Aulas: `/courses/:id/lessons` → `CourseLessonsScreen`; `/courses/:courseId/lessons/new|:lessonId/edit` → `CourseLessonFormScreen`.
    - Visualização: `/courses/:id/view` → `CourseViewerScreen`; `/courses/:courseId/lessons/:lessonId/view` → `LessonViewerScreen`.
  - Informações da Igreja:
    - `/church-info` → `ChurchInfoScreen`; `/church-info/manage` → `ChurchInfoFormScreen`.
  - Notícias:
    - `/news` → `NewsScreen`.
  - Planos de Leitura:
    - `/reading-plans` → `ReadingPlansListScreen`; `/reading-plans/:id` → `ReadingPlanDetailScreen`.
  - Bíblia:
    - `/bible` → `BibleBooksScreen`.
    - `/bible/book/:bookId` → `BibleChaptersScreen`; `/bible/book/:bookId/chapter/:chapter` → `BibleReaderScreen`.
  - Conteúdo da Home:
    - Banners: `/home/banners` (+ `new|:id/edit`) → `BannersListScreen`/`BannerFormScreen`.
    - Fique por dentro: `/home/quick-news` (+ `new|:id/edit`) → `QuickNewsListScreen`/`QuickNewsFormScreen`.
    - Testemunhos: `/home/testimonies` (+ `new|:id/edit`) → `TestimoniesListScreen`/`TestimonyFormScreen`.
  - Relatórios:
    - `/reports/members` → `MembersReportScreen` (query `tab`).
    - `/reports/events` → `EventsReportScreen`.
    - `/reports/groups` → `GroupsReportScreen`.
    - `/reports/attendance` → `AttendanceReportScreen`.
    - Relatórios rápidos: `/upcoming-expenses-report`, `/upcoming-events-report`, `/member-growth-report`, `/events-analysis-report`, `/active-groups-report`.
  - Relatórios Customizados:
    - `/custom-reports` → `CustomReportsListScreen`.
    - `/custom-reports/new|:id/edit|:id/view` → `CustomReportBuilderScreen`/`CustomReportViewScreen`.
  - Sistema de Permissões:
    - `/permissions` → `PermissionsScreen`.
    - `/permissions/roles` (+ `create|edit/:roleId`) → `RolesListScreen`/`RoleFormScreen`.
    - `/permissions/roles/:roleId/permissions` → `RolePermissionsScreen`.
    - Contextos: `/permissions/contexts`, `/permissions/context-form?id=...` → `ContextsListScreen`/`ContextFormScreen`.
    - Usuários: `/permissions/user-roles`, `/permissions/users/:userId/permissions`, `/permissions/assign-role` → `UserRolesListScreen`/`UserPermissionsScreen`/`AssignRoleScreen`.
    - Auditoria e catálogo: `/permissions/audit-log`, `/permissions/catalog` → `AuditLogScreen`/`PermissionsCatalogScreen`.

## Providers e Repositórios
- Schedules: `app/lib/features/schedule/presentation/providers/schedule_provider.dart`.
  - `scheduleRepositoryProvider` fornece acesso a eventos e escalas.
  - `eventsOfMonthProvider`, `eventsOfDateProvider` para consultas de eventos.
- Ministries (membros, funções, escalas por ministério): `ministriesRepositoryProvider` (usado em várias telas e serviços).
- Events: `eventsRepositoryProvider` (usado em regras para catálogo de tipos).
- Role Contexts: `roleContextsRepositoryProvider` expõe `contexts` com metadados de regras e categorias por ministério.

## Modelos Principais
- `Event`: domínio de eventos com `eventType`, `startDate` etc.
- `Ministry`: domínio do ministério com líder, membros e metadados.

## Fluxos de Escala

### 1) Geração de Escala (Persistente)
- Tela: `auto_schedule_generator_screen.dart` dispara geração para o período selecionado.
- Seletor de período otimizado via `showDateRangePicker`: `app/lib/features/schedule/presentation/screens/auto_schedule_generator_screen.dart:62-83`.
- Botão `GERAR ESCALA` chama `AutoSchedulerService.generateForEvent` por evento:
  - Código: `app/lib/features/schedule/presentation/screens/auto_schedule_generator_screen.dart:85-117`.
  - Para eventos normais, usa `byFunction: true` e `overwriteExisting: true`.

- Serviço: `app/lib/features/schedule/domain/auto_scheduler_service.dart`.
  - Método: `generateForEvent(...)` (persistente).
  - Carrega regras e metadados dos contexts: categorias, exclusividades, líderes e suplentes, prioridades, combinações proibidas/preferidas.
  - Normalização de nomes de função (`norm`) para mapear `function_id` de catálogo.
  - Seleção por função com regras:
    - Construção de candidatos: atribuídos + líder + suplentes.
    - Validações: bloqueios, `max_per_month`, `min_days_between`, `max_consecutive`, exclusividades por categoria, combinações proibidas.
    - Reserva de combinações preferidas para outras funções.
    - Fallback explícito de suplentes se faltar gente:
      - Persistente: `app/lib/features/schedule/domain/auto_scheduler_service.dart:566-603`.
  - Remoção de bloqueio global por evento na geração por função (depende apenas das regras de categoria): `app/lib/features/schedule/domain/auto_scheduler_service.dart:533` (não adiciona global ao persistir função).

### 2) Geração de Proposta (Prévia, sem persistir)
- Tela: `scale_preview_screen.dart`.
  - Constrói lista de funções e candidatos a partir de contexts e vínculos.
  - União de fontes de candidatos para cada função: líderes/subs, `assigned_functions`, vínculos `member_function`.
    - `_allowedForEventFunction`: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:533-536`.
  - Preenchimento inicial por proposta: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:283-321`.
  - Auto‑completar desativado e foco no ajuste manual e salvar: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:503-507`.

- Serviço: `app/lib/features/schedule/domain/auto_scheduler_service.dart`.
  - Método: `generateProposalForEvent(...)` (não persiste, retorna `proposals`).
  - Valida e reserva preferências com normalização de nomes: `app/lib/features/schedule/domain/auto_scheduler_service.dart:1080-1099`.
  - Fallbacks de suplentes na prévia: `app/lib/features/schedule/domain/auto_scheduler_service.dart:1104-1139` e `1142-1175`.

### 3) Salvar a Prévia
- Após ajustes manuais, o botão “Salvar Escala” persiste localmente:
  - Deduplicação e mapeamento de `function_id` por catálogo para evitar a constraint de unicidade (`uq_ministry_schedule_event_ministry_user_function_null`).
  - Código: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:439-487`.
  - Invalida caches dos providers para refletir imediatamente a escala salva.

## Regras de Escala
- Editáveis na tela de preferências: `app/lib/features/schedule/presentation/screens/schedule_rules_preferences_screen.dart`.
- Metadados dos contexts incluem:
  - `function_category_by_function` → mapeia função para categoria (`instrument`, `voice_role`, `other`).
  - `category_restrictions` → exclusividade e “alone” por categoria.
  - `assigned_functions` → associação de membros às funções.
  - `leaders_by_function` → líder e lista de suplentes por função.
  - `schedule_rules` → `general_rules` (ex.: `max_per_month`, `min_days_between`, `max_consecutive`, `allow_multi_ministries_per_event`), `prohibited_combinations` e `preferred_combinations`.
- Normalização de nomes para consistência de funções: `norm` em:
  - Persistente: `app/lib/features/schedule/domain/auto_scheduler_service.dart:112-139`.
  - Prévia: `app/lib/features/schedule/presentation/screens/scale_preview_screen.dart:67-93`.

## Políticas de Seleção
- Preferências: ao alocar um membro em uma função, reserva o parceiro preferido para a função correspondente.
- Proibições: evita que pares proibidos entrem em funções simultâneas quando `a_func`/`b_func` se aplicam à função atual (comparação normalizada).
- Exclusividades de categoria:
  - `exclusiveWithinCats`: impede o mesmo usuário de acumular funções da mesma categoria.
  - `exclusiveAloneCats`: impede acumular com outras categorias.
  - Regras específicas por `instrument`, `voice_role`, `other` são aplicadas.

## Considerações de Persistência
- Deduplicação ao salvar evita violar a constraint de unicidade quando `function_id` não é usado.
- Sempre que possível, `function_id` é incluído com base no catálogo de funções.
- Invalidação de providers (`eventSchedulesProvider`, `ministrySchedulesProvider`) após salvar para atualizar a UI.

## Fluxo Operacional (Resumo)
1. Selecionar período na tela do gerador (intervalo) e listar eventos.
2. Gerar a escala para cada evento:
   - Evento normal → por função; eventos de reunião/mutirão/liderança → regras específicas.
3. Pré‑visualizar/editar a escala:
   - Ajustar manualmente por função; candidatos incluem líderes, suplentes e vínculos.
4. Salvar a prévia:
   - Persistência deduplicada com `function_id` quando disponível.
5. Regras e preferências podem ser ajustadas na tela dedicada; refletem nos contexts do ministério.

## Observações de Segurança e Permissões
- Providers de permissões (`permissions_providers.dart`) garantem acesso às telas e ações conforme perfil.
- Logs em runtime exibem usuário atual e permissões (visíveis durante `flutter run`).

## Pontos de Entrada para Extensão
- Novas regras: expandir `schedule_rules` nos contexts; serviço já lê e aplica.
- Novas categorias: atualizar `function_category_by_function` e `category_order` nos contexts.
- Candidatos adicionais: incluir vínculos em `member_function` para aparecerem na prévia.

---
Este overview cobre os principais pontos de arquitetura, regras e fluxos de geração/edição/salvar de escalas, com referências diretas a arquivos e linhas para navegação rápida.
