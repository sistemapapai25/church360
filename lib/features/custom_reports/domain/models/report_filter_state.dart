import '../enums/report_enums.dart';

/// Estado temporário de filtros aplicados a um relatório
/// Não é salvo no banco - apenas usado durante a visualização
class ReportFilterState {
  final DataSource dataSource;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? gender;
  final String? type;
  final Map<String, dynamic> customFilters;

  const ReportFilterState({
    required this.dataSource,
    this.startDate,
    this.endDate,
    this.status,
    this.gender,
    this.type,
    this.customFilters = const {},
  });

  ReportFilterState copyWith({
    DataSource? dataSource,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? gender,
    String? type,
    Map<String, dynamic>? customFilters,
  }) {
    return ReportFilterState(
      dataSource: dataSource ?? this.dataSource,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      gender: gender ?? this.gender,
      type: type ?? this.type,
      customFilters: customFilters ?? this.customFilters,
    );
  }

  /// Limpar todos os filtros
  ReportFilterState clear() {
    return ReportFilterState(
      dataSource: dataSource,
      startDate: null,
      endDate: null,
      status: null,
      gender: null,
      type: null,
      customFilters: const {},
    );
  }

  /// Verificar se há filtros ativos
  bool get hasActiveFilters {
    return startDate != null ||
        endDate != null ||
        status != null ||
        gender != null ||
        type != null ||
        customFilters.isNotEmpty;
  }

  /// Contar quantos filtros estão ativos
  int get activeFilterCount {
    int count = 0;
    if (startDate != null) count++;
    if (endDate != null) count++;
    if (status != null) count++;
    if (gender != null) count++;
    if (type != null) count++;
    count += customFilters.length;
    return count;
  }

  /// Obter filtros disponíveis baseados na fonte de dados
  static List<FilterOption> getAvailableFilters(DataSource dataSource) {
    final commonFilters = [
      FilterOption(
        key: 'period',
        label: 'Período',
        type: FilterType.dateRange,
        icon: 'calendar_today',
      ),
    ];

    switch (dataSource) {
      // PESSOAS
      case DataSource.members:
      case DataSource.visitors:
        return [
          ...commonFilters,
          FilterOption(
            key: 'status',
            label: 'Status',
            type: FilterType.select,
            icon: 'check_circle',
            options: ['Ativo', 'Inativo'],
          ),
          FilterOption(
            key: 'gender',
            label: 'Gênero',
            type: FilterType.select,
            icon: 'people',
            options: ['Masculino', 'Feminino'],
          ),
        ];

      case DataSource.households:
        return [
          ...commonFilters,
          FilterOption(
            key: 'status',
            label: 'Status',
            type: FilterType.select,
            icon: 'check_circle',
            options: ['Ativa', 'Inativa'],
          ),
        ];

      // EVENTOS
      case DataSource.events:
      case DataSource.eventRegistrations:
        return [
          ...commonFilters,
          FilterOption(
            key: 'status',
            label: 'Status',
            type: FilterType.select,
            icon: 'event',
            options: ['Agendado', 'Em Andamento', 'Concluído', 'Cancelado'],
          ),
        ];

      // FINANÇAS
      case DataSource.contributions:
      case DataSource.expenses:
        return [
          ...commonFilters,
          FilterOption(
            key: 'type',
            label: 'Tipo',
            type: FilterType.select,
            icon: 'category',
            options: ['Dízimo', 'Oferta', 'Doação', 'Outro'],
          ),
        ];

      case DataSource.financialGoals:
        return [
          ...commonFilters,
          FilterOption(
            key: 'status',
            label: 'Status',
            type: FilterType.select,
            icon: 'flag',
            options: ['Em Andamento', 'Concluída', 'Cancelada'],
          ),
        ];

      // GRUPOS
      case DataSource.groups:
        return [
          ...commonFilters,
          FilterOption(
            key: 'status',
            label: 'Status',
            type: FilterType.select,
            icon: 'groups',
            options: ['Ativo', 'Inativo'],
          ),
        ];

      case DataSource.groupMeetings:
        return [
          ...commonFilters,
          FilterOption(
            key: 'status',
            label: 'Status',
            type: FilterType.select,
            icon: 'event',
            options: ['Agendada', 'Realizada', 'Cancelada'],
          ),
        ];

      // CULTOS
      case DataSource.worshipServices:
        return [
          ...commonFilters,
          FilterOption(
            key: 'type',
            label: 'Tipo de Culto',
            type: FilterType.select,
            icon: 'church',
            options: ['Domingo', 'Quarta-feira', 'Especial'],
          ),
        ];

      // PADRÃO: Apenas período
      default:
        return commonFilters;
    }
  }
}

/// Opção de filtro disponível
class FilterOption {
  final String key;
  final String label;
  final FilterType type;
  final String icon;
  final List<String>? options;

  const FilterOption({
    required this.key,
    required this.label,
    required this.type,
    required this.icon,
    this.options,
  });
}

/// Tipo de filtro
enum FilterType {
  dateRange,
  select,
  text,
  number,
}

