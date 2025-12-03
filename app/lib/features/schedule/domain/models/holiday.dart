/// Modelo de Feriado
class Holiday {
  final String name;
  final DateTime date;
  final bool isNational;

  Holiday({
    required this.name,
    required this.date,
    this.isNational = true,
  });

  /// Retorna true se o feriado é na data especificada
  bool isOnDate(DateTime date) {
    return this.date.year == date.year &&
        this.date.month == date.month &&
        this.date.day == date.day;
  }

  @override
  String toString() => '$name - ${date.day}/${date.month}/${date.year}';
}

