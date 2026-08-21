/// Thrown when an export cannot be completed.
class DbExportException implements Exception {
  const DbExportException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'DbExportException: $message${cause == null ? '' : ' ($cause)'}';
}
