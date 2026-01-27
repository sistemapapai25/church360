# Church360 - Funcionalidades por nivel de acesso e permissoes

## Fontes no codigo
- app/lib/core/navigation/app_router.dart (rotas e gates)
- app/lib/features/access_levels/domain/models/access_level.dart (niveis de acesso)
- backend-scripts/16_permissions_seed.sql (catalogo de permissoes)
- supabase/migrations/20250617080520_5332d185-b605-420b-b255-bdc91a8ce6d5.sql (roles admin/pastor/lider/diacono/membro)
- supabase/migrations/20250617092019_4c7555bf-54e8-4d37-8671-c54deaefb76b.sql (financeiro - RLS admin/pastor)
- supabase/migrations/20250618022049_a6890c87-1af6-468b-aefc-8f397bc54402.sql (conteudo home - RLS admin/pastor)
- supabase/migrations/20250618023324_c96fd597-d72f-4c3e-a5f0-ac8b888bbabd.sql (devocionais - RLS admin/pastor)
- supabase/migrations/20250618024846_f2147963-ea06-406f-b9d7-911f55043b0a.sql (banners - RLS admin/pastor)

## Acesso base (usuarios autenticados, sem DashboardAccessGate)
- Home e jornada: /home, /my-journey
- Comunidade: /community
- Perfil: /profile, /profile/edit
- Biblia: /bible, /bible/book/:bookId, /bible/book/:bookId/chapter/:chapter
- Devocionais (consumo): /devotionals, /devotionals/:id, /devotionals/saved
- Planos de leitura (consumo): /reading-plans, /reading-plans/:id
- Noticias (consumo): /news
- Igreja: /church-info, /church-info/manage (sem gate no router)
- Eventos: /events, /events/:id, /events/new, /events/:id/edit, /events/types, /events/:id/register
- Grupos: /groups, /groups/new, /groups/:id, /groups/:id/edit, reunioes e visitantes
- Cursos (consumo): /courses, /courses/:id/view, /courses/:courseId/lessons/:lessonId/view
- Cultos: /worship-services, /worship-services/new, /worship-services/:id/edit, /worship-services/:id/attendance, /worship-statistics
- Visitantes: /visitors, /visitors/new, /visitors/:id/edit, /visitors/:id/visit/new, /visitors/:id/followup/new, /visitors/:id/followup/:followupId/edit, /visitors/statistics
- Membros: /members, /members/new, /members/:id, /members/:id/edit, /members/:id/profile
- Agenda: /schedule, /church-schedule, /church-schedule/new, /church-schedule/:id/edit
- Kids: /kids, /kids-registration, /kids/:childId/registration
- Conteudo da home: /home/banners, /home/quick-news, /home/testimonies, /home/prayer-requests (+ new/edit)
- Notificacoes: /notifications, /notifications/preferences
- Oracao (modulo publico): /prayer-requests, /prayer-requests/:id, /prayer-requests/new, /prayer-requests/:id/edit
- Relatorios sem gate: /upcoming-expenses-report, /upcoming-events-report, /member-growth-report, /events-analysis-report, /active-groups-report
- Sistema de permissoes (rotas sem gate no router): /permissions, /permissions/roles, /permissions/assign-role, /permissions/audit-log, /permissions/users/:userId/permissions, /permissions/catalog, /permissions/context-form, /permissions/contexts, /permissions/user-roles, /permissions/roles/:roleId/permissions

Obs: Mesmo sem gate no router, o acesso final pode ser restrito por RLS no Supabase ou por PermissionGate dentro das telas.

## Niveis de acesso (user_access_level)
- Visitante (0) / Frequentador (1): acesso ao "Acesso base" acima; sem Dashboard.
- Membro (2): tudo do acesso base + DashboardAccessGate.
  - Rotas com DashboardAccessGate: /dashboard, /community/admin, /agents-center, /news/admin (CRUD), /reading-plans/admin (CRUD).
- Lider (3): tudo de Membro. Nao ha rotas exclusivas por nivel no app_router; nivel usado como patamar para regras no banco.
- Coordenador (4): tudo de Lider + /dispatch-config (por nivel >= coordinator ou permissao dispatch.configure).
- Admin (5) / Pastor: tudo de Coordenador + gestao de niveis de acesso (permission: settings.manage_access_levels).

## Owner global (user_account.role_global = owner)
- /developer-settings (OwnerOnlyRoute).

## Permissoes com gate no app_router (PermissionOnlyRoute/PermissionOrLevelRoute)
- settings.manage_access_levels: /access-levels, /access-levels/history, /access-levels/history/:userId
- ministries.view: /ministries, /ministries/:id
- ministries.create: /ministries/new
- ministries.edit: /ministries/:id/edit
- ministries.manage_schedule: /ministries/:id/auto-scheduler, /ministries/:id/schedule-rules, /ministries/:id/scale-history
- financial.view: /financial
- financial.view_reports: /financial-reports
- financial.create_contribution: /contributions/new
- financial.create_expense: /expenses/new
- financial.edit: /contributions/:id/edit, /expenses/:id/edit, /manage-contribution
- financial.manage_goals: /financial-goals/new, /financial-goals/:id/edit
- events.checkin: /qr-scanner
- devotionals.create: /devotionals/admin, /devotionals/new
- devotionals.edit: /devotionals/:id/edit
- study_groups.view: /study-groups, /study-groups/:id
- study_groups.create: /study-groups/new
- study_groups.edit: /study-groups/:id/edit
- study_groups.manage_lessons: /study-groups/:groupId/lessons/:lessonId
- support_materials.view: /support-materials, /support-materials/:id, /support-materials/:materialId/modules/:moduleId
- support_materials.create: /support-materials/new
- support_materials.edit: /support-materials/:id/edit
- support_materials.manage_modules: /support-materials/:id/modules
- reports.view_analytics: /analytics
- reports.view: /reports/members, /reports/events, /reports/groups, /reports/attendance, /custom-reports, /custom-reports/:id/view
- reports.create: /custom-reports/new
- reports.edit: /custom-reports/:id/edit
- courses.create: /courses/new
- courses.edit: /courses/:id/edit
- courses.manage_lessons: /courses/:id/lessons, /courses/:courseId/lessons/new, /courses/:courseId/lessons/:lessonId/edit
- bible.manage_lexicon: /bible/lexicon
- dashboard.configure: /dashboard-settings
- dispatch.configure (ou nivel >= coordinator): /dispatch-config

## Permissoes catalogadas no banco (sem gate explicito no app_router)
- members.*, groups.*, events.*, visitors.*, worship.*, prayer_requests.*, testimonies.*, tags.*, news.*, church_info.*, settings.*, dashboard.access.
- Essas permissoes existem no catalogo e podem ser usadas em PermissionGate ou RLS para restringir telas/acoes.

## Pastores e admins (role app_role = pastor/admin)
RLS no banco libera ou amplia acesso para:
- ministerios (gestao e membros), eventos (criacao/edicao), presencas em eventos
- financeiro (categorias, transacoes, orcamentos, dizimos/ofertas)
- devocionais, banners e conteudo da home (edificacao/quick news)
- configuracoes da igreja (church_info) e outros modulos marcados com is_admin_or_pastor