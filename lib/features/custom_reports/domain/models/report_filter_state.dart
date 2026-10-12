import '../enums/report_enums.dart';

/// Estado temporário de filtros aplicados a um relatório
/// Não é salvo no banco - apenas usado durante a visualização
class ReportFilterState {
  final DataSource dataSource;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? status;
  final String? gender;
  final Map<String, dynamic> customFilters;

  const ReportFilterState({
    required this.dataSource,
    this.startDate,
    this.endDate,
    this.status,
    this.gender,
    this.customFilters = const {},
  });

  ReportFilterState copyWith({
    DataSource? dataSource,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
    String? gender,
    Map<String, dynamic>? customFilters,
  }) {
    return ReportFilterState(
      dataSource: dataSource ?? this.dataSource,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      gender: gender ?? this.gender,
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
      customFilters: const {},
    );
  }

  /// Verificar se há filtros ativos
  bool get hasActiveFilters {
    return startDate != null ||
        endDate != null ||
        status != null ||
        gender != null ||
        customFilters.isNotEmpty;
  }

  /// Contar quantos filtros estão ativos
  int get activeFilterCount {
    int count = 0;
    if (startDate != null) count++;
    if (endDate != null) count++;
    if (status != null) count++;
    if (gender != null) count++;
    count += customFilters.length;
    return count;
  }

  /// Obter filtros disponíveis baseados na fonte de dados.
  /// Só as fontes que o construtor oferece têm filtro além do período.
  static List<FilterOption> getAvailableFilters(DataSource dataSource) {
    const period = FilterOption(
      key: 'period',
      label: 'Período',
      type: FilterType.dateRange,
      icon: 'calendar_today',
    );
    final gender = FilterOption(
      key: 'gender',
      label: 'Gênero',
      type: FilterType.select,
      icon: 'people',
      options: _options(['male', 'female', 'other']),
    );

    switch (dataSource) {
      case DataSource.members:
        return [
          period,
          FilterOption(
            key: 'status',
            label: 'Status',
            type: FilterType.select,
            icon: 'check_circle',
            options: _options([
              'visitor',
              'new_convert',
              'member_active',
              'member_inactive',
              'transferred',
              'deceased',
            ]),
          ),
          gender,
        ];

      // Visitantes já são só status visitor.
      case DataSource.visitors:
        return [period, gender];

      case DataSource.events:
        return [
          period,
          FilterOption(
            key: 'status',
            label: 'Status',
            type: FilterType.select,
            icon: 'event',
            options: _options(
                ['draft', 'published', 'ongoing', 'completed', 'cancelled']),
          ),
        ];

      case DataSource.eventRegistrations:
        return [
          period,
          FilterOption(
            key: 'status',
            label: 'Status',
            type: FilterType.select,
            icon: 'event',
            options: _options(
                ['pending', 'confirmed', 'checked_in', 'cancelled', 'no_show']),
          ),
        ];

      // Contribuições/Despesas são sempre lançamentos pagos e metas não têm
      // status no banco: só período.
      default:
        return const [period];
    }
  }

  static Map<String, String> _options(List<String> values) =>
      {for (final v in values) v: reportValueLabel(v)};
}

/// Rótulo em português dos valores de enum do banco (status, gênero).
const _valueLabels = <String, String>{
  // member_status
  'visitor': 'Visitante',
  'new_convert': 'Novo convertido',
  'member_active': 'Membro ativo',
  'member_inactive': 'Membro inativo',
  'transferred': 'Transferido',
  'deceased': 'Falecido',
  // member_gender
  'male': 'Masculino',
  'female': 'Feminino',
  'other': 'Outro',
  // event_status
  'draft': 'Rascunho',
  'published': 'Publicado',
  'ongoing': 'Em andamento',
  'completed': 'Concluído',
  'cancelled': 'Cancelado',
  // registration_status
  'pending': 'Pendente',
  'confirmed': 'Confirmado',
  'checked_in': 'Presente',
  'no_show': 'Não compareceu',
};

String reportValueLabel(String value) => _valueLabels[value] ?? value;

/// Opção de filtro disponível
class FilterOption {
  final String key;
  final String label;
  final FilterType type;
  final String icon;
  final Map<String, String>? options; // valor no banco -> rótulo

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

