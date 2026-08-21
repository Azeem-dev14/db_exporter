/// One table's rows, already materialised in memory.
class TableData {
  const TableData({
    required this.name,
    required this.columns,
    required this.rows,
    this.truncated = false,
  });

  final String name;
  final List<String> columns;
  final List<Map<String, Object?>> rows;

  /// True when a row limit cut the result short.
  final bool truncated;

  int get rowCount => rows.length;

  bool get isEmpty => rows.isEmpty;
}
