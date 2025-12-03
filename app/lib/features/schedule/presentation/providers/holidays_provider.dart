import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/holiday.dart';

/// Provider que retorna os feriados de um ano específico
final holidaysProvider = Provider.family<List<Holiday>, int>((ref, year) {
  return _getBrazilianHolidays(year);
});

/// Retorna todos os feriados nacionais do Brasil para um ano específico
List<Holiday> _getBrazilianHolidays(int year) {
  final holidays = <Holiday>[];

  // Feriados fixos
  holidays.addAll([
    Holiday(name: 'Confraternização Universal', date: DateTime(year, 1, 1)),
    Holiday(name: 'Tiradentes', date: DateTime(year, 4, 21)),
    Holiday(name: 'Dia do Trabalho', date: DateTime(year, 5, 1)),
    Holiday(name: 'Independência do Brasil', date: DateTime(year, 9, 7)),
    Holiday(name: 'Nossa Senhora Aparecida', date: DateTime(year, 10, 12)),
    Holiday(name: 'Finados', date: DateTime(year, 11, 2)),
    Holiday(name: 'Proclamação da República', date: DateTime(year, 11, 15)),
    Holiday(name: 'Dia da Consciência Negra', date: DateTime(year, 11, 20)),
    Holiday(name: 'Natal', date: DateTime(year, 12, 25)),
  ]);

  // Feriados móveis (baseados na Páscoa)
  final easter = _calculateEaster(year);
  
  holidays.addAll([
    Holiday(
      name: 'Carnaval',
      date: easter.subtract(const Duration(days: 47)),
    ),
    Holiday(
      name: 'Sexta-feira Santa',
      date: easter.subtract(const Duration(days: 2)),
    ),
    Holiday(
      name: 'Páscoa',
      date: easter,
    ),
    Holiday(
      name: 'Corpus Christi',
      date: easter.add(const Duration(days: 60)),
    ),
  ]);

  // Ordenar por data
  holidays.sort((a, b) => a.date.compareTo(b.date));

  return holidays;
}

/// Calcula a data da Páscoa usando o algoritmo de Meeus/Jones/Butcher
/// Referência: https://pt.wikipedia.org/wiki/C%C3%A1lculo_da_P%C3%A1scoa
DateTime _calculateEaster(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;

  return DateTime(year, month, day);
}

/// Provider que retorna os feriados de um mês específico
final holidaysOfMonthProvider = Provider.family<List<Holiday>, DateTime>((ref, date) {
  final year = date.year;
  final month = date.month;
  
  final allHolidays = ref.watch(holidaysProvider(year));
  
  return allHolidays.where((holiday) => holiday.date.month == month).toList();
});

/// Provider que retorna os feriados de uma data específica
final holidaysOfDateProvider = Provider.family<List<Holiday>, DateTime>((ref, date) {
  final year = date.year;
  final allHolidays = ref.watch(holidaysProvider(year));
  
  return allHolidays.where((holiday) => holiday.isOnDate(date)).toList();
});

