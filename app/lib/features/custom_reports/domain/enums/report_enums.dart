// Enums para o sistema de relatórios customizados

/// Fonte de dados disponível para relatórios
enum DataSource {
  // PESSOAS
  members('members', 'Membros', 'Dados de membros da igreja'),
  visitors('visitors', 'Visitantes', 'Dados de visitantes'),
  households('households', 'Famílias', 'Dados de famílias'),

  // EVENTOS E AGENDA
  events('events', 'Eventos', 'Dados de eventos'),
  eventRegistrations('event_registrations', 'Inscrições em Eventos', 'Inscrições em eventos'),
  churchSchedule('church_schedule', 'Agenda da Igreja', 'Agenda e compromissos'),

  // FINANÇAS
  contributions('contributions', 'Contribuições', 'Contribuições financeiras'),
  expenses('expenses', 'Despesas', 'Despesas e gastos'),
  financialGoals('financial_goals', 'Metas Financeiras', 'Metas e objetivos financeiros'),
  donations('donations', 'Doações', 'Doações recebidas'),

  // GRUPOS E CÉLULAS
  groups('groups', 'Grupos', 'Grupos e células'),
  groupMembers('group_members', 'Membros de Grupos', 'Membros participantes de grupos'),
  groupMeetings('group_meetings', 'Reuniões de Grupos', 'Reuniões de grupos'),
  groupAttendance('group_attendance', 'Presença em Reuniões', 'Presença em reuniões de grupos'),

  // CONTEÚDO ESPIRITUAL
  testimonies('testimonies', 'Testemunhos', 'Testemunhos compartilhados'),
  prayerRequests('prayer_requests', 'Pedidos de Oração', 'Pedidos de oração'),
  prayers('prayers', 'Orações Realizadas', 'Orações feitas pelos membros'),
  devotionals('devotionals', 'Devocionais', 'Devocionais publicados'),
  devotionalReadings('devotional_readings', 'Leituras de Devocionais', 'Leituras realizadas'),
  readingPlans('reading_plans', 'Planos de Leitura', 'Planos de leitura bíblica'),
  readingPlanProgress('reading_plan_progress', 'Progresso nos Planos', 'Progresso em planos de leitura'),

  // CONTEÚDO DO APP
  banners('banners', 'Banners', 'Banners do sistema'),
  quickNews('quick_news', 'Notícias Rápidas', 'Notícias rápidas'),

  // MINISTÉRIOS E CURSOS
  ministries('ministries', 'Ministérios', 'Ministérios da igreja'),
  ministryMembers('ministry_members', 'Membros de Ministérios', 'Membros participantes de ministérios'),
  courses('courses', 'Cursos', 'Cursos oferecidos'),
  courseEnrollments('course_enrollments', 'Inscrições em Cursos', 'Inscrições em cursos'),

  // CULTOS
  worshipServices('worship_services', 'Cultos', 'Cultos realizados'),
  worshipAttendance('worship_attendance', 'Presença em Cultos', 'Presença em cultos'),

  // JORNADA ESPIRITUAL
  tags('tags', 'Tags', 'Tags e categorias'),
  memberTags('member_tags', 'Tags de Membros', 'Tags atribuídas a membros'),
  steps('steps', 'Passos da Jornada', 'Passos da jornada espiritual'),
  memberSteps('member_steps', 'Progresso nos Passos', 'Progresso dos membros nos passos'),

  // OUTROS
  campus('campus', 'Campus', 'Campus da igreja'),
  notifications('notifications', 'Notificações', 'Notificações enviadas');

  final String value;
  final String label;
  final String description;

  const DataSource(this.value, this.label, this.description);

  static DataSource fromValue(String value) {
    return DataSource.values.firstWhere(
      (e) => e.value == value,
      orElse: () => DataSource.members,
    );
  }

  /// Retorna a categoria do dashboard baseada na fonte de dados
  String get dashboardCategory {
    switch (this) {
      // PESSOAS
      case DataSource.members:
      case DataSource.visitors:
      case DataSource.households:
        return 'members';

      // EVENTOS E AGENDA
      case DataSource.events:
      case DataSource.eventRegistrations:
      case DataSource.churchSchedule:
        return 'events';

      // FINANÇAS
      case DataSource.contributions:
      case DataSource.expenses:
      case DataSource.financialGoals:
      case DataSource.donations:
        return 'financial';

      // GRUPOS E CÉLULAS
      case DataSource.groups:
      case DataSource.groupMembers:
      case DataSource.groupMeetings:
      case DataSource.groupAttendance:
        return 'groups';

      // CONTEÚDO ESPIRITUAL
      case DataSource.testimonies:
      case DataSource.prayerRequests:
      case DataSource.prayers:
      case DataSource.devotionals:
      case DataSource.devotionalReadings:
      case DataSource.readingPlans:
      case DataSource.readingPlanProgress:
        return 'reports';

      // CONTEÚDO DO APP
      case DataSource.banners:
      case DataSource.quickNews:
        return 'reports';

      // MINISTÉRIOS E CURSOS
      case DataSource.ministries:
      case DataSource.ministryMembers:
      case DataSource.courses:
      case DataSource.courseEnrollments:
        return 'reports';

      // CULTOS
      case DataSource.worshipServices:
      case DataSource.worshipAttendance:
        return 'attendance';

      // JORNADA ESPIRITUAL
      case DataSource.tags:
      case DataSource.memberTags:
      case DataSource.steps:
      case DataSource.memberSteps:
        return 'members';

      // OUTROS
      case DataSource.campus:
      case DataSource.notifications:
        return 'reports';
    }
  }
}

/// Tipo de visualização do relatório
enum VisualizationType {
  pie('pie', 'Gráfico de Pizza', 'Gráfico circular para mostrar proporções'),
  bar('bar', 'Gráfico de Barras', 'Gráfico de barras verticais'),
  horizontalBar('horizontal_bar', 'Barras Horizontais', 'Gráfico de barras horizontais'),
  line('line', 'Gráfico de Linhas', 'Gráfico de linhas para tendências'),
  area('area', 'Gráfico de Área', 'Gráfico de área preenchida'),
  table('table', 'Tabela', 'Tabela com dados detalhados'),
  card('card', 'Card de Métrica', 'Card com valor destacado'),
  kpi('kpi', 'KPI', 'Número grande com indicador'),
  multiCard('multi_card', 'Múltiplos Cards', 'Vários cards com métricas'),
  gauge('gauge', 'Medidor', 'Medidor circular de progresso');

  final String value;
  final String label;
  final String description;

  const VisualizationType(this.value, this.label, this.description);

  static VisualizationType fromValue(String value) {
    return VisualizationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => VisualizationType.card,
    );
  }
}

/// Tipo de agregação de dados
enum AggregationType {
  count('count', 'Contagem', 'Contar registros'),
  sum('sum', 'Soma', 'Somar valores'),
  avg('avg', 'Média', 'Calcular média'),
  min('min', 'Mínimo', 'Valor mínimo'),
  max('max', 'Máximo', 'Valor máximo'),
  countDistinct('count_distinct', 'Contagem Única', 'Contar valores únicos');

  final String value;
  final String label;
  final String description;

  const AggregationType(this.value, this.label, this.description);

  static AggregationType fromValue(String value) {
    return AggregationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => AggregationType.count,
    );
  }
}

/// Tipo de filtro
enum FilterType {
  dateRange('date_range', 'Período', 'Filtrar por intervalo de datas'),
  status('status', 'Status', 'Filtrar por status'),
  category('category', 'Categoria', 'Filtrar por categoria'),
  type('type', 'Tipo', 'Filtrar por tipo'),
  boolean('boolean', 'Sim/Não', 'Filtro booleano'),
  text('text', 'Texto', 'Busca por texto'),
  number('number', 'Número', 'Filtro numérico'),
  select('select', 'Seleção', 'Selecionar de uma lista'),
  multiSelect('multi_select', 'Seleção Múltipla', 'Selecionar múltiplos itens');

  final String value;
  final String label;
  final String description;

  const FilterType(this.value, this.label, this.description);

  static FilterType fromValue(String value) {
    return FilterType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FilterType.text,
    );
  }
}

/// Tipo de agrupamento
enum GroupByType {
  none('none', 'Sem Agrupamento'),
  day('day', 'Por Dia'),
  week('week', 'Por Semana'),
  month('month', 'Por Mês'),
  year('year', 'Por Ano'),
  status('status', 'Por Status'),
  category('category', 'Por Categoria'),
  type('type', 'Por Tipo'),
  custom('custom', 'Personalizado');

  final String value;
  final String label;

  const GroupByType(this.value, this.label);

  static GroupByType fromValue(String value) {
    return GroupByType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => GroupByType.none,
    );
  }
}

/// Tipo de permissão
enum PermissionType {
  user('user', 'Usuário'),
  group('group', 'Grupo'),
  public('public', 'Público');

  final String value;
  final String label;

  const PermissionType(this.value, this.label);

  static PermissionType fromValue(String value) {
    return PermissionType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => PermissionType.public,
    );
  }
}

/// Operador de comparação para filtros
enum FilterOperator {
  equals('eq', 'Igual a'),
  notEquals('neq', 'Diferente de'),
  greaterThan('gt', 'Maior que'),
  greaterThanOrEqual('gte', 'Maior ou igual a'),
  lessThan('lt', 'Menor que'),
  lessThanOrEqual('lte', 'Menor ou igual a'),
  contains('like', 'Contém'),
  startsWith('starts_with', 'Começa com'),
  endsWith('ends_with', 'Termina com'),
  inList('in', 'Está em'),
  notInList('not_in', 'Não está em'),
  isNull('is_null', 'É nulo'),
  isNotNull('is_not_null', 'Não é nulo');

  final String value;
  final String label;

  const FilterOperator(this.value, this.label);

  static FilterOperator fromValue(String value) {
    return FilterOperator.values.firstWhere(
      (e) => e.value == value,
      orElse: () => FilterOperator.equals,
    );
  }
}
