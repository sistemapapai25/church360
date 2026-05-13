/// Lote 7.1: helper minimalista para gerar CSV RFC 4180 compatível.
/// Usa vírgula como separador, escapa aspas duplicando-as e envolve
/// em aspas qualquer célula que contenha vírgula, aspas ou quebra de linha.
class CsvWriter {
  final List<String> _headers;
  final List<List<String>> _rows = [];

  CsvWriter(this._headers);

  void addRow(List<Object?> values) {
    _rows.add(values.map((v) => v?.toString() ?? '').toList());
  }

  static String _escape(String cell) {
    final needs = cell.contains(',') || cell.contains('"') ||
        cell.contains('\n') || cell.contains('\r');
    if (!needs) return cell;
    return '"${cell.replaceAll('"', '""')}"';
  }

  String build() {
    final buf = StringBuffer();
    buf.writeln(_headers.map(_escape).join(','));
    for (final row in _rows) {
      buf.writeln(row.map(_escape).join(','));
    }
    return buf.toString();
  }
}
