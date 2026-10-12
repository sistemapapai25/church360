import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/widgets/age_range_filter.dart';
import '../../financeiro/data/lancamentos_scope.dart';
import '../../members/domain/models/member.dart';
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

    // Construir query base (mesma tabela e recorte da tela de cada módulo)
    var query = _baseQuery(report.dataSource);

    // Data escolhida no construtor (Contribuições/Despesas); senão a da fonte.
    final dateField = _isLedger(report.dataSource) && report.config.dateField != null
        ? report.config.dateField!
        : null;

    // Aplicar filtros temporários (do botão de funil)
    if (filterState != null) {
      query = _applyFilters(
          query, filterState, dateField ?? _getDateField(report.dataSource));
    }

    // Executar query
    final response = await query;
    final data = (response as List)
        .map((row) => _withDerivedFields(row, report.dataSource))
        .toList();

    // Processar dados baseado na agregação
    return processData(data, aggregation, report.dataSource, dateField);
  }

  static bool _isLedger(DataSource s) =>
      s == DataSource.contributions || s == DataSource.expenses;

  /// Query base por DataSource: as fontes que o construtor oferece
  /// (DataSourceMetadataRegistry) leem a tabela que a tela do módulo lê.
  PostgrestFilterBuilder<List<Map<String, dynamic>>> _baseQuery(
    DataSource dataSource,
  ) {
    final tenantId = SupabaseConstants.currentTenantId;
    switch (dataSource) {
      // Membros sem visitantes (Visitantes tem fonte própria).
      case DataSource.members:
        return _supabase
            .from('user_account')
            .select()
            .eq('tenant_id', tenantId)
            .or('status.is.null,status.neq.visitor');
      case DataSource.visitors:
        return _supabase
            .from('user_account')
            .select()
            .eq('tenant_id', tenantId)
            .eq('status', 'visitor');
      case DataSource.events:
        return _supabase
            .from('event')
            .select('*, tipo:event_type(label)')
            .eq('tenant_id', tenantId);
      case DataSource.eventRegistrations:
        return _supabase
            .from('event_registration')
            .select()
            .eq('tenant_id', tenantId);
      // Contribuições/Despesas: mesmo recorte do FinancialRepository
      // (lançamento pago, não apagado, da igreja).
      case DataSource.contributions:
      case DataSource.expenses:
        return _supabase
            .from('lancamentos')
            .select('*, categoria:categoria_id(name)')
            .eq('tipo',
                dataSource == DataSource.contributions ? 'RECEITA' : 'DESPESA')
            .eq('tenant_id', tenantId)
            .eq('status', 'PAGO')
            .isFilter('deleted_at', null)
            .or(kLancamentosIgrejaScope);
      case DataSource.financialGoals:
        return _supabase
            .from('financial_goal')
            .select()
            .eq('tenant_id', tenantId);
      default:
        throw Exception('Fonte de dados sem suporte: ${dataSource.label}');
    }
  }

  /// Campos calculados usados pelos templates: nome da categoria do
  /// lançamento, nome do tipo de evento, idade e faixa etária do membro.
  Map<String, dynamic> _withDerivedFields(dynamic raw, DataSource dataSource) {
    final row = Map<String, dynamic>.from(raw as Map);
    final categoria = row['categoria'];
    if (categoria is Map) row['categoria'] = categoria['name'];
    final tipo = row.remove('tipo');
    if (tipo is Map) row['event_type'] = tipo['label'];

    if (dataSource == DataSource.members || dataSource == DataSource.visitors) {
      final age = Member.fromJson(row).age;
      row['age'] = age;
      row['age_group'] = ageGroupLabel(age);
    }
    return row;
  }

  /// Rótulo da faixa etária, nas mesmas faixas do filtro de idade.
  static String ageGroupLabel(int? age) {
    if (age == null) return 'Sem data de nascimento';
    return AgeRange.values
        .firstWhere(
          (r) => r.min != null && age >= r.min! && (r.max == null || age <= r.max!),
          orElse: () => AgeRange.all,
        )
        .label;
  }

  /// Aplicar filtros temporários na query
  PostgrestFilterBuilder<List<Map<String, dynamic>>> _applyFilters(
    PostgrestFilterBuilder<List<Map<String, dynamic>>> query,
    ReportFilterState filterState,
    String dateField,
  ) {
    // Filtro de período por dia. A data final entra inteira: < dia seguinte
    // (com lte 00:00 o último dia sumia nas colunas timestamptz).
    if (filterState.startDate != null) {
      query = query.gte(dateField, _day(filterState.startDate!));
    }
    if (filterState.endDate != null) {
      query = query.lt(
        dateField,
        _day(filterState.endDate!.add(const Duration(days: 1))),
      );
    }

    // Filtro de status
    if (filterState.status != null && filterState.status!.isNotEmpty) {
      query = query.eq('status', filterState.status!);
    }

    // Filtro de gênero (membros e visitantes)
    if (filterState.gender != null && filterState.gender!.isNotEmpty) {
      query = query.eq('gender', filterState.gender!);
    }

    // Filtros customizados
    for (var filter in filterState.customFilters.entries) {
      if (filter.value != null && filter.value.toString().isNotEmpty) {
        query = query.eq(filter.key, filter.value);
      }
    }

    return query;
  }

  static String _day(DateTime d) => d.toIso8601String().substring(0, 10);

  /// Obter campo de data baseado no DataSource
  String _getDateField(DataSource dataSource) {
    switch (dataSource) {
      case DataSource.visitors:
        return 'first_visit_date';
      case DataSource.events:
      case DataSource.financialGoals:
        return 'start_date';
      case DataSource.eventRegistrations:
        return 'registered_at';
      // Padrão do Financeiro; o construtor pode trocar por data_pagamento.
      case DataSource.contributions:
      case DataSource.expenses:
        return 'vencimento';
      default:
        return 'created_at';
    }
  }

  /// Obter campo de tipo baseado no DataSource
  String? _getTypeField(DataSource dataSource) {
    switch (dataSource) {
      case DataSource.contributions:
      case DataSource.expenses:
        return 'categoria';
      case DataSource.events:
        return 'event_type';
      default:
        return null;
    }
  }

  /// Processar dados baseado na agregação
  @visibleForTesting
  List<Map<String, dynamic>> processData(
    List<dynamic> data,
    ReportAggregation aggregation,
    DataSource dataSource,
    String? dateField,
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
      final groupKey = _getGroupKey(item, aggregation, dataSource, dateField);
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
    String? dateField,
  ) {
    switch (aggregation.groupBy) {
      case GroupByType.day:
      case GroupByType.week:
      case GroupByType.month:
      case GroupByType.year:
        return _getDateGroupKey(item, aggregation, dataSource, dateField);

      case GroupByType.status:
        final status = item['status']?.toString();
        return status == null ? 'Sem status' : reportValueLabel(status);

      case GroupByType.category:
      case GroupByType.type:
        final typeField = _getTypeField(dataSource);
        return item[typeField]?.toString() ??
            (aggregation.groupBy == GroupByType.category
                ? 'Sem categoria'
                : 'Sem tipo');

      case GroupByType.custom:
        if (aggregation.groupByField != null) {
          final value = item[aggregation.groupByField]?.toString();
          return value == null ? 'Sem valor' : reportValueLabel(value);
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
    String? chosenDateField,
  ) {
    final dateField = chosenDateField ??
        aggregation.groupByField ??
        _getDateField(dataSource);
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
        // Só quem tem valor entra na média (membro sem nascimento não é idade 0).
        final values = data
            .map((item) => item[aggregation.fieldName])
            .whereType<num>()
            .toList();
        if (values.isEmpty) return 0;
        return values.fold<double>(0, (sum, v) => sum + v) / values.length;

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

