import '../enums/report_enums.dart';

/// Configuração de uma visualização individual
class ReportVisualization {
  final String id; // ID único da visualização
  final VisualizationType type;
  final String title;
  final Map<String, dynamic>? chartOptions;
  final int order;

  const ReportVisualization({
    required this.id,
    required this.type,
    required this.title,
    this.chartOptions,
    this.order = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.value,
      'title': title,
      'chart_options': chartOptions,
      'order': order,
    };
  }

  factory ReportVisualization.fromJson(Map<String, dynamic> json) {
    return ReportVisualization(
      id: json['id'] as String,
      type: VisualizationType.fromValue(json['type'] as String),
      title: json['title'] as String,
      chartOptions: json['chart_options'] as Map<String, dynamic>?,
      order: json['order'] as int? ?? 0,
    );
  }

  ReportVisualization copyWith({
    String? id,
    VisualizationType? type,
    String? title,
    Map<String, dynamic>? chartOptions,
    int? order,
  }) {
    return ReportVisualization(
      id: id ?? this.id,
      type: type ?? this.type,
      title: title ?? this.title,
      chartOptions: chartOptions ?? this.chartOptions,
      order: order ?? this.order,
    );
  }
}

/// Configuração de um filtro
class ReportFilter {
  final String fieldName;
  final FilterType filterType;
  final FilterOperator operator;
  final dynamic value;
  final String? label;

  const ReportFilter({
    required this.fieldName,
    required this.filterType,
    required this.operator,
    this.value,
    this.label,
  });

  Map<String, dynamic> toJson() {
    return {
      'field_name': fieldName,
      'filter_type': filterType.value,
      'operator': operator.value,
      'value': value,
      'label': label,
    };
  }

  factory ReportFilter.fromJson(Map<String, dynamic> json) {
    return ReportFilter(
      fieldName: json['field_name'] as String,
      filterType: FilterType.fromValue(json['filter_type'] as String),
      operator: FilterOperator.fromValue(json['operator'] as String),
      value: json['value'],
      label: json['label'] as String?,
    );
  }

  ReportFilter copyWith({
    String? fieldName,
    FilterType? filterType,
    FilterOperator? operator,
    dynamic value,
    String? label,
  }) {
    return ReportFilter(
      fieldName: fieldName ?? this.fieldName,
      filterType: filterType ?? this.filterType,
      operator: operator ?? this.operator,
      value: value ?? this.value,
      label: label ?? this.label,
    );
  }
}

/// Configuração de agregação
class ReportAggregation {
  final String fieldName;
  final AggregationType aggregationType;
  final String? label;
  final GroupByType groupBy;
  final String? groupByField;

  const ReportAggregation({
    required this.fieldName,
    required this.aggregationType,
    this.label,
    this.groupBy = GroupByType.none,
    this.groupByField,
  });

  Map<String, dynamic> toJson() {
    return {
      'field_name': fieldName,
      'aggregation_type': aggregationType.value,
      'label': label,
      'group_by': groupBy.value,
      'group_by_field': groupByField,
    };
  }

  factory ReportAggregation.fromJson(Map<String, dynamic> json) {
    return ReportAggregation(
      fieldName: json['field_name'] as String,
      aggregationType: AggregationType.fromValue(json['aggregation_type'] as String),
      label: json['label'] as String?,
      groupBy: GroupByType.fromValue(json['group_by'] as String? ?? 'none'),
      groupByField: json['group_by_field'] as String?,
    );
  }

  ReportAggregation copyWith({
    String? fieldName,
    AggregationType? aggregationType,
    String? label,
    GroupByType? groupBy,
    String? groupByField,
  }) {
    return ReportAggregation(
      fieldName: fieldName ?? this.fieldName,
      aggregationType: aggregationType ?? this.aggregationType,
      label: label ?? this.label,
      groupBy: groupBy ?? this.groupBy,
      groupByField: groupByField ?? this.groupByField,
    );
  }
}

/// Configuração de campo para exibição
class ReportField {
  final String fieldName;
  final String label;
  final bool visible;
  final int order;

  const ReportField({
    required this.fieldName,
    required this.label,
    this.visible = true,
    this.order = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'field_name': fieldName,
      'label': label,
      'visible': visible,
      'order': order,
    };
  }

  factory ReportField.fromJson(Map<String, dynamic> json) {
    return ReportField(
      fieldName: json['field_name'] as String,
      label: json['label'] as String,
      visible: json['visible'] as bool? ?? true,
      order: json['order'] as int? ?? 0,
    );
  }

  ReportField copyWith({
    String? fieldName,
    String? label,
    bool? visible,
    int? order,
  }) {
    return ReportField(
      fieldName: fieldName ?? this.fieldName,
      label: label ?? this.label,
      visible: visible ?? this.visible,
      order: order ?? this.order,
    );
  }
}

/// Configuração completa do relatório
class ReportConfig {
  final List<ReportFilter> filters;
  final List<ReportAggregation> aggregations;
  final List<ReportField> fields;
  final List<ReportVisualization> visualizations; // NOVO: Múltiplas visualizações
  final Map<String, dynamic>? chartOptions; // Mantido para compatibilidade
  final int? limit;
  final String? orderBy;
  final bool orderAscending;

  const ReportConfig({
    this.filters = const [],
    this.aggregations = const [],
    this.fields = const [],
    this.visualizations = const [], // NOVO
    this.chartOptions,
    this.limit,
    this.orderBy,
    this.orderAscending = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'filters': filters.map((f) => f.toJson()).toList(),
      'aggregations': aggregations.map((a) => a.toJson()).toList(),
      'fields': fields.map((f) => f.toJson()).toList(),
      'visualizations': visualizations.map((v) => v.toJson()).toList(), // NOVO
      'chart_options': chartOptions,
      'limit': limit,
      'order_by': orderBy,
      'order_ascending': orderAscending,
    };
  }

  factory ReportConfig.fromJson(Map<String, dynamic> json) {
    return ReportConfig(
      filters: (json['filters'] as List<dynamic>?)
              ?.map((f) => ReportFilter.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      aggregations: (json['aggregations'] as List<dynamic>?)
              ?.map((a) => ReportAggregation.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      fields: (json['fields'] as List<dynamic>?)
              ?.map((f) => ReportField.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      visualizations: (json['visualizations'] as List<dynamic>?)
              ?.map((v) => ReportVisualization.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [], // NOVO
      chartOptions: json['chart_options'] as Map<String, dynamic>?,
      limit: json['limit'] as int?,
      orderBy: json['order_by'] as String?,
      orderAscending: json['order_ascending'] as bool? ?? true,
    );
  }

  ReportConfig copyWith({
    List<ReportFilter>? filters,
    List<ReportAggregation>? aggregations,
    List<ReportField>? fields,
    List<ReportVisualization>? visualizations, // NOVO
    Map<String, dynamic>? chartOptions,
    int? limit,
    String? orderBy,
    bool? orderAscending,
  }) {
    return ReportConfig(
      filters: filters ?? this.filters,
      aggregations: aggregations ?? this.aggregations,
      fields: fields ?? this.fields,
      visualizations: visualizations ?? this.visualizations, // NOVO
      chartOptions: chartOptions ?? this.chartOptions,
      limit: limit ?? this.limit,
      orderBy: orderBy ?? this.orderBy,
      orderAscending: orderAscending ?? this.orderAscending,
    );
  }

  /// Adiciona um filtro
  ReportConfig addFilter(ReportFilter filter) {
    return copyWith(filters: [...filters, filter]);
  }

  /// Remove um filtro
  ReportConfig removeFilter(int index) {
    final newFilters = List<ReportFilter>.from(filters);
    newFilters.removeAt(index);
    return copyWith(filters: newFilters);
  }

  /// Atualiza um filtro
  ReportConfig updateFilter(int index, ReportFilter filter) {
    final newFilters = List<ReportFilter>.from(filters);
    newFilters[index] = filter;
    return copyWith(filters: newFilters);
  }

  /// Adiciona uma agregação
  ReportConfig addAggregation(ReportAggregation aggregation) {
    return copyWith(aggregations: [...aggregations, aggregation]);
  }

  /// Remove uma agregação
  ReportConfig removeAggregation(int index) {
    final newAggregations = List<ReportAggregation>.from(aggregations);
    newAggregations.removeAt(index);
    return copyWith(aggregations: newAggregations);
  }

  /// Atualiza uma agregação
  ReportConfig updateAggregation(int index, ReportAggregation aggregation) {
    final newAggregations = List<ReportAggregation>.from(aggregations);
    newAggregations[index] = aggregation;
    return copyWith(aggregations: newAggregations);
  }

  /// Adiciona um campo
  ReportConfig addField(ReportField field) {
    return copyWith(fields: [...fields, field]);
  }

  /// Remove um campo
  ReportConfig removeField(int index) {
    final newFields = List<ReportField>.from(fields);
    newFields.removeAt(index);
    return copyWith(fields: newFields);
  }

  /// Atualiza um campo
  ReportConfig updateField(int index, ReportField field) {
    final newFields = List<ReportField>.from(fields);
    newFields[index] = field;
    return copyWith(fields: newFields);
  }

  /// Adiciona uma visualização
  ReportConfig addVisualization(ReportVisualization visualization) {
    return copyWith(visualizations: [...visualizations, visualization]);
  }

  /// Remove uma visualização
  ReportConfig removeVisualization(int index) {
    final newVisualizations = List<ReportVisualization>.from(visualizations);
    newVisualizations.removeAt(index);
    return copyWith(visualizations: newVisualizations);
  }

  /// Atualiza uma visualização
  ReportConfig updateVisualization(int index, ReportVisualization visualization) {
    final newVisualizations = List<ReportVisualization>.from(visualizations);
    newVisualizations[index] = visualization;
    return copyWith(visualizations: newVisualizations);
  }

  /// Reordena visualizações
  ReportConfig reorderVisualizations(int oldIndex, int newIndex) {
    final newVisualizations = List<ReportVisualization>.from(visualizations);
    final item = newVisualizations.removeAt(oldIndex);
    newVisualizations.insert(newIndex, item);

    // Atualizar ordem
    for (int i = 0; i < newVisualizations.length; i++) {
      newVisualizations[i] = newVisualizations[i].copyWith(order: i);
    }

    return copyWith(visualizations: newVisualizations);
  }
}

