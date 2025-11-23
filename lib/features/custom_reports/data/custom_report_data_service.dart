import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/models/custom_report.dart';
import '../domain/models/report_config.dart';
import '../domain/models/report_filter_state.dart';
import '../domain/enums/report_enums.dart';

/// Serviço para buscar dados dinâmicos para relatórios customizados
class CustomReportDataService {
  final SupabaseClient _supabase;

  CustomReportDataService(this._supabase);

  /// Buscar dados para um relatório customizado
  Future<List<Map<String, dynamic>>> fetchReportData(
    CustomReport report, {
    ReportFilterState? filterState,
  }) async {
    // Pegar a primeira agregação (por enquanto suportamos apenas uma)
    if (report.config.aggregations.isEmpty) {
      throw Exception('Relatório não possui agregação configurada');
    }

    final aggregation = report.config.aggregations.first;
    final tableName = _getTableName(report.dataSource);

    // Construir query base
    var query = _supabase.from(tableName).select('*');

    // Aplicar filtros temporários (do botão de funil)
    if (filterState != null) {
      query = _applyFilters(query, filterState, report.dataSource);
    }

    // Executar query
    final response = await query;
    final data = response as List;

    // Processar dados baseado na agregação
    return _processData(data, aggregation, report.dataSource);
  }

  /// Obter nome da tabela baseado no DataSource
  String _getTableName(DataSource dataSource) {
    switch (dataSource) {
      case DataSource.members:
        return 'member';
      case DataSource.visitors:
        return 'visitor';
      case DataSource.households:
        return 'household';
      case DataSource.events:
        return 'event';
      case DataSource.eventRegistrations:
        return 'event_registration';
      case DataSource.contributions:
        return 'contribution';
      case DataSource.expenses:
        return 'expense';
      case DataSource.donations:
        return 'donation';
      case DataSource.financialGoals:
        return 'financial_goal';
      case DataSource.groups:
        return 'group';
      case DataSource.groupMembers:
        return 'group_member';
      case DataSource.groupMeetings:
        return 'group_meeting';
      case DataSource.groupAttendance:
        return 'group_attendance';
      case DataSource.worshipServices:
        return 'worship_service';
      case DataSource.worshipAttendance:
        return 'worship_attendance';
      case DataSource.churchSchedule:
        return 'church_schedule';
      default:
        throw Exception('DataSource não suportado: $dataSource');
    }
  }

  /// Aplicar filtros temporários na query
  PostgrestFilterBuilder<List<Map<String, dynamic>>> _applyFilters(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
    ReportFilterState filterState,
    DataSource dataSource,
  ) {
    // Filtro de período
    if (filterState.startDate != null) {
      final dateField = _getDateField(dataSource);
      query = query.gte(dateField, filterState.startDate!.toIso8601String());
    }
    if (filterState.endDate != null) {
      final dateField = _getDateField(dataSource);
      query = query.lte(dateField, filterState.endDate!.toIso8601String());
    }

    // Filtro de status
    if (filterState.status != null && filterState.status!.isNotEmpty) {
      query = query.eq('status', filterState.status!);
    }

    // Filtro de gênero (para membros)
    if (filterState.gender != null && filterState.gender!.isNotEmpty && dataSource == DataSource.members) {
      query = query.eq('gender', filterState.gender!);
    }

    // Filtro de tipo
    if (filterState.type != null && filterState.type!.isNotEmpty) {
      final typeField = _getTypeField(dataSource);
      if (typeField != null) {
        query = query.eq(typeField, filterState.type!);
      }
    }

    // Filtros customizados
    for (var filter in filterState.customFilters.entries) {
      if (filter.value != null && filter.value.toString().isNotEmpty) {
        query = query.eq(filter.key, filter.value);
      }
    }

    return query;
  }

  /// Obter campo de data baseado no DataSource
  String _getDateField(DataSource dataSource) {
    switch (dataSource) {
      case DataSource.members:
      case DataSource.visitors:
      case DataSource.groups:
        return 'created_at';
      case DataSource.events:
        return 'start_date';
      case DataSource.contributions:
      case DataSource.expenses:
        return 'date';
      case DataSource.groupMeetings:
        return 'meeting_date';
      case DataSource.worshipServices:
        return 'service_date';
      default:
        return 'created_at';
    }
  }

  /// Obter campo de tipo baseado no DataSource
  String? _getTypeField(DataSource dataSource) {
    switch (dataSource) {
      case DataSource.contributions:
        return 'type';
      case DataSource.expenses:
        return 'category';
      case DataSource.events:
        return 'event_type';
      default:
        return null;
    }
  }

  /// Processar dados baseado na agregação
  List<Map<String, dynamic>> _processData(
    List<dynamic> data,
    ReportAggregation aggregation,
    DataSource dataSource,
  ) {
    // Se não há agrupamento, retornar valor único
    if (aggregation.groupBy == GroupByType.none) {
      final value = _calculateAggregation(data, aggregation);
      return [
        {
          'label': 'Total',
          'value': value,
        }
      ];
    }

    // Agrupar dados
    final Map<String, List<dynamic>> groups = {};

    for (var item in data) {
      final groupKey = _getGroupKey(item, aggregation, dataSource);
      if (!groups.containsKey(groupKey)) {
        groups[groupKey] = [];
      }
      groups[groupKey]!.add(item);
    }

    // Calcular agregação para cada grupo
    final result = <Map<String, dynamic>>[];
    for (var entry in groups.entries) {
      final value = _calculateAggregation(entry.value, aggregation);
      result.add({
        'label': entry.key,
        'value': value,
      });
    }

    // Ordenar por label
    result.sort((a, b) => a['label'].toString().compareTo(b['label'].toString()));

    return result;
  }

  /// Obter chave de agrupamento
  String _getGroupKey(
    dynamic item,
    ReportAggregation aggregation,
    DataSource dataSource,
  ) {
    switch (aggregation.groupBy) {
      case GroupByType.day:
      case GroupByType.week:
      case GroupByType.month:
      case GroupByType.year:
        return _getDateGroupKey(item, aggregation, dataSource);

      case GroupByType.status:
        return item['status']?.toString() ?? 'Sem status';

      case GroupByType.category:
        return item['category']?.toString() ?? 'Sem categoria';

      case GroupByType.type:
        final typeField = _getTypeField(dataSource);
        return item[typeField]?.toString() ?? 'Sem tipo';

      case GroupByType.custom:
        if (aggregation.groupByField != null) {
          return item[aggregation.groupByField]?.toString() ?? 'Sem valor';
        }
        return 'Sem agrupamento';

      case GroupByType.none:
        return 'Total';
    }
  }

  /// Obter chave de agrupamento por data
  String _getDateGroupKey(
    dynamic item,
    ReportAggregation aggregation,
    DataSource dataSource,
  ) {
    final dateField = aggregation.groupByField ?? _getDateField(dataSource);
    final dateStr = item[dateField]?.toString();
    
    if (dateStr == null) return 'Sem data';

    final date = DateTime.parse(dateStr);

    switch (aggregation.groupBy) {
      case GroupByType.day:
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      case GroupByType.week:
        final weekNumber = ((date.difference(DateTime(date.year, 1, 1)).inDays) / 7).ceil();
        return 'Semana $weekNumber/${date.year}';
      case GroupByType.month:
        final months = ['Jan', 'Fev', 'Mar', 'Abr', 'Mai', 'Jun', 'Jul', 'Ago', 'Set', 'Out', 'Nov', 'Dez'];
        return '${months[date.month - 1]}/${date.year}';
      case GroupByType.year:
        return date.year.toString();
      default:
        return dateStr;
    }
  }

  /// Calcular agregação
  double _calculateAggregation(
    List<dynamic> data,
    ReportAggregation aggregation,
  ) {
    if (data.isEmpty) return 0;

    switch (aggregation.aggregationType) {
      case AggregationType.count:
        return data.length.toDouble();

      case AggregationType.countDistinct:
        final distinctValues = data
            .map((item) => item[aggregation.fieldName])
            .where((value) => value != null)
            .toSet();
        return distinctValues.length.toDouble();

      case AggregationType.sum:
        return data.fold<double>(0, (sum, item) {
          final value = item[aggregation.fieldName];
          if (value == null) return sum;
          return sum + (value is num ? value.toDouble() : 0);
        });

      case AggregationType.avg:
        final sum = data.fold<double>(0, (sum, item) {
          final value = item[aggregation.fieldName];
          if (value == null) return sum;
          return sum + (value is num ? value.toDouble() : 0);
        });
        return sum / data.length;

      case AggregationType.min:
        return data.fold<double>(double.infinity, (min, item) {
          final value = item[aggregation.fieldName];
          if (value == null) return min;
          final numValue = value is num ? value.toDouble() : double.infinity;
          return numValue < min ? numValue : min;
        });

      case AggregationType.max:
        return data.fold<double>(double.negativeInfinity, (max, item) {
          final value = item[aggregation.fieldName];
          if (value == null) return max;
          final numValue = value is num ? value.toDouble() : double.negativeInfinity;
          return numValue > max ? numValue : max;
        });
    }
  }
}

