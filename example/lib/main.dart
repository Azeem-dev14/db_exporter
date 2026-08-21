import 'package:db_exporter/db_exporter.dart';
import 'package:flutter/material.dart';

import 'databases/drift_music.dart';
import 'databases/sqflite_schools.dart';
import 'databases/sqlite3_bookstore.dart';
import 'demo_database.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'db_exporter',
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
        ),
        home: const ExportDemoPage(),
      );
}

class ExportDemoPage extends StatefulWidget {
  const ExportDemoPage({super.key});

  @override
  State<ExportDemoPage> createState() => _ExportDemoPageState();
}

class _ExportDemoPageState extends State<ExportDemoPage> {
  /// Every supported wiring style, each with a distinct dataset so the
  /// exported file makes it obvious which database produced it.
  final List<DemoDatabase> _databases = [
    SqfliteSchools(),
    DriftMusic(),
    Sqlite3Bookstore(),
  ];

  late DemoDatabase _database = _databases.first;
  ExportFormat _format = ExportFormat.excel;
  _Destination _destination = _Destination.deviceFolder;

  bool _busy = false;
  String? _error;
  ExportResult? _result;

  @override
  void dispose() {
    for (final database in _databases) {
      database.close();
    }
    super.dispose();
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });

    try {
      await _database.open();

      final exporter = DbExporter(
        _database.source,
        destination: _destination.build(),
      );

      final result = await exporter.export(
        format: _format,
        onProgress: (done, total, table) =>
            debugPrint('[${_database.package}] $done/$total  ${table ?? ''}'),
      );
      setState(() => _result = result);
    } on DbExportException catch (error) {
      setState(() => _error = error.message);
    } on Object catch (error) {
      setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// CSV writes one file per table, which the save dialog cannot accept.
  bool get _combinationValid =>
      !(_format.isMultiFile && _destination == _Destination.saveAs);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('db_exporter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Database', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          _DatabasePicker(
            databases: _databases,
            selected: _database,
            onChanged: _busy
                ? null
                : (database) => setState(() {
                      _database = database;
                      _result = null;
                      _error = null;
                    }),
          ),
          const SizedBox(height: 24),

          Text('Export format', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<ExportFormat>(
            initialValue: _format,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final format in ExportFormat.values)
                DropdownMenuItem(
                  value: format,
                  child: Text('${_formatLabel(format)}  '
                      '(.${format.fileExtension})'),
                ),
            ],
            onChanged: _busy
                ? null
                : (format) => setState(() => _format = format!),
          ),
          const SizedBox(height: 16),

          Text('Destination', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          DropdownButtonFormField<_Destination>(
            initialValue: _destination,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: [
              for (final destination in _Destination.values)
                DropdownMenuItem(
                  value: destination,
                  child: Text(destination.label),
                ),
            ],
            onChanged: _busy
                ? null
                : (destination) =>
                    setState(() => _destination = destination!),
          ),

          if (!_combinationValid) ...[
            const SizedBox(height: 12),
            _Banner(
              icon: Icons.info_outline,
              color: theme.colorScheme.tertiary,
              text: 'CSV writes one file per table, and the save dialog takes '
                  'only one file. Pick Share or a folder destination.',
            ),
          ],

          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy || !_combinationValid ? null : _export,
            icon: _busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_busy ? 'Exporting…' : 'Export'),
          ),

          if (_error != null) ...[
            const SizedBox(height: 24),
            _Banner(
              icon: Icons.error_outline,
              color: theme.colorScheme.error,
              text: _error!,
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            _ResultCard(result: _result!),
          ],
        ],
      ),
    );
  }

  static String _formatLabel(ExportFormat format) => switch (format) {
        ExportFormat.rawDatabase => 'Raw database file',
        ExportFormat.csv => 'CSV, one file per table',
        ExportFormat.json => 'JSON',
        ExportFormat.excel => 'Excel workbook',
      };
}

/// Destinations the demo offers, kept as an enum so the dropdown is trivial.
enum _Destination {
  deviceFolder('Device folder (dbexports-<package>)'),
  appDirectory('App documents directory'),
  share('Share sheet'),
  saveAs('System save dialog');

  const _Destination(this.label);

  final String label;

  ExportDestination build() => switch (this) {
        _Destination.deviceFolder => const ExportDestination.deviceFolder(),
        _Destination.appDirectory => const ExportDestination.appDirectory(),
        _Destination.share =>
          const ExportDestination.share(subject: 'db_exporter demo'),
        _Destination.saveAs =>
          const ExportDestination.saveAs(dialogTitle: 'Save export'),
      };
}

class _DatabasePicker extends StatelessWidget {
  const _DatabasePicker({
    required this.databases,
    required this.selected,
    required this.onChanged,
  });

  final List<DemoDatabase> databases;
  final DemoDatabase selected;
  final ValueChanged<DemoDatabase>? onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final database in databases)
            ListTile(
              onTap: onChanged == null ? null : () => onChanged!(database),
              selected: database == selected,
              leading: Icon(
                database == selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
              title: Text(database.label),
              subtitle: Text(
                '${database.tables.join(', ')}\n${database.wiring}',
                style: theme.textTheme.bodySmall,
              ),
              isThreeLine: true,
            ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ExportResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (result.userCancelled) {
      return _Banner(
        icon: Icons.cancel_outlined,
        color: theme.colorScheme.outline,
        text: 'Cancelled before the file was saved.',
      );
    }

    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Exported', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            _Row('Format', result.format.name),
            _Row('Tables', result.tables.isEmpty
                ? 'whole file'
                : result.tables.join(', ')),
            _Row('Rows', '${result.totalRows}'),
            _Row('Size', '${result.totalSizeInBytes} bytes'),
            _Row('Took', '${result.duration.inMilliseconds} ms'),
            const SizedBox(height: 12),
            Text('Files', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            for (final file in result.files)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: SelectableText(
                  file.path,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 72, child: Text(label)),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: SelectableText(text)),
          ],
        ),
      );
}
