import 'dart:io';

import 'package:excel/excel.dart';
import 'package:path/path.dart' as p;

import '../model/export_exception.dart';
import '../model/export_format.dart';
import '../model/export_result.dart';
import '../model/table_data.dart';
import '../util/file_naming.dart';
import '../util/value_codec.dart';
import 'tabular_exporter.dart';

/// A single `.xlsx` workbook, one sheet per table.
///
/// Excel is by far the heaviest format here: the whole workbook is built in
/// memory before a byte is written. Treat it as a "send this to a human"
/// format, not a backup format — use [ExportFormat.rawDatabase] for those.
class ExcelExporter implements TabularExporter {
  const ExcelExporter({this.boldHeader = true, this.autoFitColumns = true});

  /// Render the header row in bold.
  final bool boldHeader;

  /// Size each column to its content.
  ///
  /// Costs a pass over every cell in the sheet, so turn it off for wide
  /// exports where readability matters less than speed.
  final bool autoFitColumns;

  @override
  ExportFormat get format => ExportFormat.excel;

  @override
  Future<List<ExportedFile>> write({
    required List<TableData> tables,
    required Directory stagingDirectory,
    required String baseName,
  }) async {
    final workbook = Excel.createExcel();
    // createExcel() seeds an empty default sheet; remember it so we can drop it
    // once real sheets exist (a workbook with zero sheets is invalid).
    final placeholder = workbook.getDefaultSheet();

    final usedNames = <String>{};
    for (final table in tables) {
      final sheetName = FileNaming.sheetName(table.name, taken: usedNames);
      usedNames.add(sheetName);

      final sheet = workbook[sheetName];
      sheet.appendRow([
        for (final column in table.columns) TextCellValue(column),
      ]);
      for (final row in table.rows) {
        sheet.appendRow([
          for (final column in table.columns) _toCell(row[column]),
        ]);
      }

      if (boldHeader) {
        final headerStyle = CellStyle(bold: true);
        for (var column = 0; column < table.columns.length; column++) {
          sheet
              .cell(CellIndex.indexByColumnRow(
                columnIndex: column,
                rowIndex: 0,
              ))
              .cellStyle = headerStyle;
        }
      }
      if (autoFitColumns) {
        for (var column = 0; column < table.columns.length; column++) {
          sheet.setColumnAutoFit(column);
        }
      }
    }

    // Only drop the placeholder if we did not end up writing into it — a
    // table genuinely named "Sheet1" reuses that same sheet, and deleting it
    // would discard the table.
    if (placeholder != null &&
        usedNames.isNotEmpty &&
        !usedNames.contains(placeholder)) {
      workbook.setDefaultSheet(usedNames.first);
      workbook.delete(placeholder);
    }

    final bytes = workbook.encode();
    if (bytes == null) {
      throw const DbExportException('Excel encoder returned no bytes.');
    }

    final file = File(
      p.join(
        stagingDirectory.path,
        FileNaming.build(
          base: baseName,
          extension: format.fileExtension,
          withTimestamp: false,
        ),
      ),
    );
    await file.writeAsBytes(bytes, flush: true);
    return [await ExportedFile.fromFile(file)];
  }

  /// Maps a SQLite value onto the narrowest Excel cell type available, so
  /// numbers stay sortable instead of arriving as text.
  static CellValue? _toCell(Object? value) => switch (value) {
        null => null,
        final int number => IntCellValue(number),
        final double number => DoubleCellValue(number),
        final bool flag => BoolCellValue(flag),
        final String text => TextCellValue(text),
        _ => TextCellValue(ValueCodec.asText(value)),
      };
}
