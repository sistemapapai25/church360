import '../enums/report_enums.dart';
import 'report_config.dart';

/// Template de métrica sugerida para um DataSource
class MetricTemplate {
  final String id;
  final String label;
  final String description;
  final String fieldName;
  final AggregationType aggregationType;
  final List<GroupByOption> groupByOptions;

  const MetricTemplate({
    required this.id,
    required this.label,
    required this.description,
    required this.fieldName,
    required this.aggregationType,
    required this.groupByOptions,
  });

  /// Criar agregação a partir deste template
  ReportAggregation toAggregation({
    required GroupByType groupBy,
    String? groupByField,
  }) {
    return ReportAggregation(
      fieldName: fieldName,
      aggregationType: aggregationType,
      label: label,
      groupBy: groupBy,
      groupByField: groupByField,
    );
  }
}

/// Opção de agrupamento disponível
class GroupByOption {
  final GroupByType type;
  final String label;
  final String? fieldName; // Campo a ser usado no GROUP BY

  const GroupByOption({
    required this.type,
    required this.label,
    this.fieldName,
  });
}

/// Templates de métricas por DataSource
class MetricTemplates {
  /// Obter templates de métricas para um DataSource
  static List<MetricTemplate> getTemplatesForDataSource(DataSource dataSource) {
    switch (dataSource) {
      // PESSOAS
      case DataSource.members:
        return [
          MetricTemplate(
            id: 'members_count',
            label: 'Quantidade de Membros',
            description: 'Total de membros cadastrados',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês de cadastro', fieldName: 'created_at'),
              const GroupByOption(type: GroupByType.year, label: 'Por ano de cadastro', fieldName: 'created_at'),
              const GroupByOption(type: GroupByType.status, label: 'Por status', fieldName: 'status'),
              const GroupByOption(type: GroupByType.custom, label: 'Por gênero', fieldName: 'gender'),
              const GroupByOption(type: GroupByType.custom, label: 'Por faixa etária', fieldName: 'age_group'),
            ],
          ),
          MetricTemplate(
            id: 'members_avg_age',
            label: 'Média de Idade',
            description: 'Idade média dos membros',
            fieldName: 'birth_date',
            aggregationType: AggregationType.avg,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.status, label: 'Por status', fieldName: 'status'),
              const GroupByOption(type: GroupByType.custom, label: 'Por gênero', fieldName: 'gender'),
            ],
          ),
        ];

      case DataSource.visitors:
        return [
          MetricTemplate(
            id: 'visitors_count',
            label: 'Quantidade de Visitantes',
            description: 'Total de visitantes cadastrados',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês de visita', fieldName: 'visit_date'),
              const GroupByOption(type: GroupByType.year, label: 'Por ano de visita', fieldName: 'visit_date'),
              const GroupByOption(type: GroupByType.status, label: 'Por status', fieldName: 'status'),
            ],
          ),
        ];

      case DataSource.households:
        return [
          MetricTemplate(
            id: 'households_count',
            label: 'Quantidade de Famílias',
            description: 'Total de famílias cadastradas',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.status, label: 'Por status', fieldName: 'status'),
            ],
          ),
        ];

      // EVENTOS
      case DataSource.events:
        return [
          MetricTemplate(
            id: 'events_count',
            label: 'Quantidade de Eventos',
            description: 'Total de eventos realizados',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'event_date'),
              const GroupByOption(type: GroupByType.year, label: 'Por ano', fieldName: 'event_date'),
              const GroupByOption(type: GroupByType.status, label: 'Por status', fieldName: 'status'),
              const GroupByOption(type: GroupByType.type, label: 'Por tipo', fieldName: 'event_type'),
            ],
          ),
        ];

      case DataSource.eventRegistrations:
        return [
          MetricTemplate(
            id: 'registrations_count',
            label: 'Quantidade de Inscrições',
            description: 'Total de inscrições em eventos',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'created_at'),
              const GroupByOption(type: GroupByType.status, label: 'Por status', fieldName: 'status'),
            ],
          ),
        ];

      // FINANÇAS
      case DataSource.contributions:
        return [
          MetricTemplate(
            id: 'contributions_sum',
            label: 'Total de Contribuições',
            description: 'Soma de todas as contribuições',
            fieldName: 'amount',
            aggregationType: AggregationType.sum,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'contribution_date'),
              const GroupByOption(type: GroupByType.year, label: 'Por ano', fieldName: 'contribution_date'),
              const GroupByOption(type: GroupByType.type, label: 'Por tipo', fieldName: 'contribution_type'),
            ],
          ),
          MetricTemplate(
            id: 'contributions_count',
            label: 'Quantidade de Contribuições',
            description: 'Total de contribuições recebidas',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'contribution_date'),
              const GroupByOption(type: GroupByType.type, label: 'Por tipo', fieldName: 'contribution_type'),
            ],
          ),
          MetricTemplate(
            id: 'contributions_avg',
            label: 'Média de Contribuição',
            description: 'Valor médio das contribuições',
            fieldName: 'amount',
            aggregationType: AggregationType.avg,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'contribution_date'),
              const GroupByOption(type: GroupByType.type, label: 'Por tipo', fieldName: 'contribution_type'),
            ],
          ),
        ];

      case DataSource.expenses:
        return [
          MetricTemplate(
            id: 'expenses_sum',
            label: 'Total de Despesas',
            description: 'Soma de todas as despesas',
            fieldName: 'amount',
            aggregationType: AggregationType.sum,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'expense_date'),
              const GroupByOption(type: GroupByType.year, label: 'Por ano', fieldName: 'expense_date'),
              const GroupByOption(type: GroupByType.category, label: 'Por categoria', fieldName: 'category'),
            ],
          ),
          MetricTemplate(
            id: 'expenses_count',
            label: 'Quantidade de Despesas',
            description: 'Total de despesas registradas',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'expense_date'),
              const GroupByOption(type: GroupByType.category, label: 'Por categoria', fieldName: 'category'),
            ],
          ),
        ];

      // GRUPOS
      case DataSource.groups:
        return [
          MetricTemplate(
            id: 'groups_count',
            label: 'Quantidade de Grupos',
            description: 'Total de grupos cadastrados',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.status, label: 'Por status', fieldName: 'status'),
              const GroupByOption(type: GroupByType.type, label: 'Por tipo', fieldName: 'group_type'),
            ],
          ),
        ];

      case DataSource.groupMembers:
        return [
          MetricTemplate(
            id: 'group_members_count',
            label: 'Quantidade de Membros em Grupos',
            description: 'Total de participantes em grupos',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.custom, label: 'Por grupo', fieldName: 'group_id'),
            ],
          ),
        ];

      // CULTOS
      case DataSource.worshipServices:
        return [
          MetricTemplate(
            id: 'worship_count',
            label: 'Quantidade de Cultos',
            description: 'Total de cultos realizados',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'service_date'),
              const GroupByOption(type: GroupByType.year, label: 'Por ano', fieldName: 'service_date'),
              const GroupByOption(type: GroupByType.type, label: 'Por tipo', fieldName: 'service_type'),
            ],
          ),
        ];

      case DataSource.worshipAttendance:
        return [
          MetricTemplate(
            id: 'attendance_count',
            label: 'Total de Presenças',
            description: 'Soma de todas as presenças',
            fieldName: 'attendance_count',
            aggregationType: AggregationType.sum,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'service_date'),
              const GroupByOption(type: GroupByType.year, label: 'Por ano', fieldName: 'service_date'),
            ],
          ),
          MetricTemplate(
            id: 'attendance_avg',
            label: 'Média de Presença',
            description: 'Média de presença por culto',
            fieldName: 'attendance_count',
            aggregationType: AggregationType.avg,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'service_date'),
            ],
          ),
        ];

      // PADRÃO: Contagem simples
      default:
        return [
          MetricTemplate(
            id: 'default_count',
            label: 'Quantidade de Registros',
            description: 'Total de registros',
            fieldName: 'id',
            aggregationType: AggregationType.count,
            groupByOptions: [
              const GroupByOption(type: GroupByType.none, label: 'Sem agrupamento'),
              const GroupByOption(type: GroupByType.month, label: 'Por mês', fieldName: 'created_at'),
              const GroupByOption(type: GroupByType.year, label: 'Por ano', fieldName: 'created_at'),
            ],
          ),
        ];
    }
  }
}

