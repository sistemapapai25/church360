import '../enums/report_enums.dart';

/// Metadados de um campo
class FieldMetadata {
  final String fieldName;
  final String label;
  final String dataType; // 'string', 'number', 'date', 'boolean'
  final bool isAggregatable;
  final bool isFilterable;
  final bool isGroupable;
  final List<AggregationType> supportedAggregations;
  final List<FilterOperator> supportedOperators;

  const FieldMetadata({
    required this.fieldName,
    required this.label,
    required this.dataType,
    this.isAggregatable = false,
    this.isFilterable = true,
    this.isGroupable = false,
    this.supportedAggregations = const [],
    this.supportedOperators = const [],
  });
}

/// Metadados de uma fonte de dados
class DataSourceMetadata {
  final DataSource dataSource;
  final String tableName;
  final List<FieldMetadata> fields;
  final List<VisualizationType> supportedVisualizations;

  const DataSourceMetadata({
    required this.dataSource,
    required this.tableName,
    required this.fields,
    required this.supportedVisualizations,
  });

  /// Buscar campo por nome
  FieldMetadata? getField(String fieldName) {
    try {
      return fields.firstWhere((f) => f.fieldName == fieldName);
    } catch (e) {
      return null;
    }
  }

  /// Campos agregáveis
  List<FieldMetadata> get aggregatableFields =>
      fields.where((f) => f.isAggregatable).toList();

  /// Campos filtráveis
  List<FieldMetadata> get filterableFields =>
      fields.where((f) => f.isFilterable).toList();

  /// Campos agrupáveis
  List<FieldMetadata> get groupableFields =>
      fields.where((f) => f.isGroupable).toList();
}

/// Classe para gerenciar metadados de todas as fontes de dados
class DataSourceMetadataRegistry {
  static final Map<DataSource, DataSourceMetadata> _metadata = {
    // MEMBROS
    DataSource.members: DataSourceMetadata(
      dataSource: DataSource.members,
      tableName: 'member',
      fields: [
        FieldMetadata(
          fieldName: 'id',
          label: 'ID',
          dataType: 'string',
          isFilterable: false,
        ),
        FieldMetadata(
          fieldName: 'first_name',
          label: 'Nome',
          dataType: 'string',
          isFilterable: true,
          isGroupable: false,
          supportedOperators: [FilterOperator.contains, FilterOperator.equals],
        ),
        FieldMetadata(
          fieldName: 'last_name',
          label: 'Sobrenome',
          dataType: 'string',
          isFilterable: true,
          supportedOperators: [FilterOperator.contains, FilterOperator.equals],
        ),
        FieldMetadata(
          fieldName: 'gender',
          label: 'Gênero',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
        FieldMetadata(
          fieldName: 'marital_status',
          label: 'Estado Civil',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
        FieldMetadata(
          fieldName: 'birthdate',
          label: 'Data de Nascimento',
          dataType: 'date',
          isFilterable: true,
          isGroupable: false,
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
            FilterOperator.greaterThanOrEqual,
            FilterOperator.lessThanOrEqual,
          ],
        ),
        FieldMetadata(
          fieldName: 'baptism_date',
          label: 'Data de Batismo',
          dataType: 'date',
          isFilterable: true,
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
            FilterOperator.isNull,
            FilterOperator.isNotNull,
          ],
        ),
        FieldMetadata(
          fieldName: 'membership_date',
          label: 'Data de Membresia',
          dataType: 'date',
          isFilterable: true,
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
          ],
        ),
        FieldMetadata(
          fieldName: 'is_active',
          label: 'Ativo',
          dataType: 'boolean',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals],
        ),
      ],
      supportedVisualizations: [
        VisualizationType.card,
        VisualizationType.kpi,
        VisualizationType.pie,
        VisualizationType.bar,
        VisualizationType.table,
      ],
    ),

    // VISITANTES
    DataSource.visitors: DataSourceMetadata(
      dataSource: DataSource.visitors,
      tableName: 'visitor',
      fields: [
        FieldMetadata(
          fieldName: 'id',
          label: 'ID',
          dataType: 'string',
          isFilterable: false,
        ),
        FieldMetadata(
          fieldName: 'first_name',
          label: 'Nome',
          dataType: 'string',
          isFilterable: true,
          supportedOperators: [FilterOperator.contains, FilterOperator.equals],
        ),
        FieldMetadata(
          fieldName: 'status',
          label: 'Status',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
        FieldMetadata(
          fieldName: 'first_visit_date',
          label: 'Primeira Visita',
          dataType: 'date',
          isFilterable: true,
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
            FilterOperator.greaterThanOrEqual,
            FilterOperator.lessThanOrEqual,
          ],
        ),
        FieldMetadata(
          fieldName: 'total_visits',
          label: 'Total de Visitas',
          dataType: 'number',
          isAggregatable: true,
          isFilterable: true,
          supportedAggregations: [
            AggregationType.sum,
            AggregationType.avg,
            AggregationType.max,
            AggregationType.min,
          ],
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
            FilterOperator.equals,
          ],
        ),
      ],
      supportedVisualizations: [
        VisualizationType.card,
        VisualizationType.kpi,
        VisualizationType.pie,
        VisualizationType.bar,
        VisualizationType.line,
        VisualizationType.table,
      ],
    ),

    // EVENTOS
    DataSource.events: DataSourceMetadata(
      dataSource: DataSource.events,
      tableName: 'event',
      fields: [
        FieldMetadata(
          fieldName: 'id',
          label: 'ID',
          dataType: 'string',
          isFilterable: false,
        ),
        FieldMetadata(
          fieldName: 'name',
          label: 'Nome',
          dataType: 'string',
          isFilterable: true,
          supportedOperators: [FilterOperator.contains, FilterOperator.equals],
        ),
        FieldMetadata(
          fieldName: 'event_type',
          label: 'Tipo',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
        FieldMetadata(
          fieldName: 'status',
          label: 'Status',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
        FieldMetadata(
          fieldName: 'start_date',
          label: 'Data de Início',
          dataType: 'date',
          isFilterable: true,
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
            FilterOperator.greaterThanOrEqual,
            FilterOperator.lessThanOrEqual,
          ],
        ),
        FieldMetadata(
          fieldName: 'max_capacity',
          label: 'Capacidade Máxima',
          dataType: 'number',
          isAggregatable: true,
          isFilterable: true,
          supportedAggregations: [
            AggregationType.sum,
            AggregationType.avg,
            AggregationType.max,
          ],
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
          ],
        ),
        FieldMetadata(
          fieldName: 'price',
          label: 'Preço',
          dataType: 'number',
          isAggregatable: true,
          isFilterable: true,
          supportedAggregations: [
            AggregationType.sum,
            AggregationType.avg,
            AggregationType.max,
            AggregationType.min,
          ],
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
            FilterOperator.equals,
          ],
        ),
        FieldMetadata(
          fieldName: 'is_free',
          label: 'Gratuito',
          dataType: 'boolean',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals],
        ),
      ],
      supportedVisualizations: [
        VisualizationType.card,
        VisualizationType.kpi,
        VisualizationType.pie,
        VisualizationType.bar,
        VisualizationType.line,
        VisualizationType.table,
      ],
    ),

    // CONTRIBUIÇÕES
    DataSource.contributions: DataSourceMetadata(
      dataSource: DataSource.contributions,
      tableName: 'contribution',
      fields: [
        FieldMetadata(
          fieldName: 'id',
          label: 'ID',
          dataType: 'string',
          isFilterable: false,
        ),
        FieldMetadata(
          fieldName: 'description',
          label: 'Descrição',
          dataType: 'string',
          isFilterable: true,
          supportedOperators: [FilterOperator.contains, FilterOperator.equals],
        ),
        FieldMetadata(
          fieldName: 'type',
          label: 'Tipo',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
        FieldMetadata(
          fieldName: 'category',
          label: 'Categoria',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
        FieldMetadata(
          fieldName: 'amount',
          label: 'Valor',
          dataType: 'number',
          isAggregatable: true,
          isFilterable: true,
          supportedAggregations: [
            AggregationType.sum,
            AggregationType.avg,
            AggregationType.max,
            AggregationType.min,
            AggregationType.count,
          ],
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
            FilterOperator.equals,
            FilterOperator.greaterThanOrEqual,
            FilterOperator.lessThanOrEqual,
          ],
        ),
        FieldMetadata(
          fieldName: 'transaction_date',
          label: 'Data',
          dataType: 'date',
          isFilterable: true,
          supportedOperators: [
            FilterOperator.greaterThan,
            FilterOperator.lessThan,
            FilterOperator.greaterThanOrEqual,
            FilterOperator.lessThanOrEqual,
          ],
        ),
        FieldMetadata(
          fieldName: 'status',
          label: 'Status',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
      ],
      supportedVisualizations: [
        VisualizationType.card,
        VisualizationType.kpi,
        VisualizationType.pie,
        VisualizationType.bar,
        VisualizationType.line,
        VisualizationType.area,
        VisualizationType.table,
      ],
    ),

    // DESPESAS
    DataSource.expenses: DataSourceMetadata(
      dataSource: DataSource.expenses,
      tableName: 'expense',
      fields: [
        FieldMetadata(
          fieldName: 'id',
          label: 'ID',
          dataType: 'string',
          isFilterable: false,
        ),
        FieldMetadata(
          fieldName: 'description',
          label: 'Descrição',
          dataType: 'string',
          isFilterable: true,
          supportedOperators: [FilterOperator.contains],
        ),
        FieldMetadata(
          fieldName: 'amount',
          label: 'Valor',
          dataType: 'number',
          isAggregatable: true,
          isFilterable: true,
          supportedOperators: [FilterOperator.greaterThan, FilterOperator.lessThan],
        ),
        FieldMetadata(
          fieldName: 'date',
          label: 'Data',
          dataType: 'date',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.greaterThan, FilterOperator.lessThan],
        ),
        FieldMetadata(
          fieldName: 'category',
          label: 'Categoria',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
      ],
      supportedVisualizations: [
        VisualizationType.card,
        VisualizationType.kpi,
        VisualizationType.pie,
        VisualizationType.bar,
        VisualizationType.line,
        VisualizationType.table,
      ],
    ),

    // METAS FINANCEIRAS
    DataSource.financialGoals: DataSourceMetadata(
      dataSource: DataSource.financialGoals,
      tableName: 'financial_goal',
      fields: [
        FieldMetadata(
          fieldName: 'id',
          label: 'ID',
          dataType: 'string',
          isFilterable: false,
        ),
        FieldMetadata(
          fieldName: 'name',
          label: 'Nome',
          dataType: 'string',
          isFilterable: true,
          supportedOperators: [FilterOperator.contains],
        ),
        FieldMetadata(
          fieldName: 'target_amount',
          label: 'Meta',
          dataType: 'number',
          isAggregatable: true,
          isFilterable: true,
        ),
        FieldMetadata(
          fieldName: 'current_amount',
          label: 'Valor Atual',
          dataType: 'number',
          isAggregatable: true,
          isFilterable: true,
        ),
        FieldMetadata(
          fieldName: 'is_active',
          label: 'Ativo',
          dataType: 'boolean',
          isFilterable: true,
          isGroupable: true,
        ),
      ],
      supportedVisualizations: [
        VisualizationType.card,
        VisualizationType.kpi,
        VisualizationType.gauge,
        VisualizationType.bar,
        VisualizationType.table,
      ],
    ),

    // INSCRIÇÕES EM EVENTOS
    DataSource.eventRegistrations: DataSourceMetadata(
      dataSource: DataSource.eventRegistrations,
      tableName: 'event_registration',
      fields: [
        FieldMetadata(
          fieldName: 'id',
          label: 'ID',
          dataType: 'string',
          isFilterable: false,
        ),
        FieldMetadata(
          fieldName: 'event_id',
          label: 'Evento',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
        ),
        FieldMetadata(
          fieldName: 'status',
          label: 'Status',
          dataType: 'string',
          isFilterable: true,
          isGroupable: true,
          supportedOperators: [FilterOperator.equals, FilterOperator.inList],
        ),
        FieldMetadata(
          fieldName: 'registered_at',
          label: 'Data de Inscrição',
          dataType: 'date',
          isFilterable: true,
          isGroupable: true,
        ),
      ],
      supportedVisualizations: [
        VisualizationType.card,
        VisualizationType.kpi,
        VisualizationType.pie,
        VisualizationType.bar,
        VisualizationType.table,
      ],
    ),
  };

  /// Obter metadados de uma fonte de dados
  static DataSourceMetadata? getMetadata(DataSource dataSource) {
    return _metadata[dataSource];
  }

  /// Obter todas as fontes de dados disponíveis
  static List<DataSource> get availableDataSources => _metadata.keys.toList();

  /// Verificar se uma visualização é suportada para uma fonte de dados
  static bool isVisualizationSupported(
    DataSource dataSource,
    VisualizationType visualization,
  ) {
    final metadata = _metadata[dataSource];
    if (metadata == null) return false;
    return metadata.supportedVisualizations.contains(visualization);
  }
}

