import 'package:db_exporter/db_exporter.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'db_exporter',
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        home: const ExportDemoPage(),
      );
}

class ExportDemoPage extends StatefulWidget {
  const ExportDemoPage({super.key});

  @override
  State<ExportDemoPage> createState() => _ExportDemoPageState();
}

class _ExportDemoPageState extends State<ExportDemoPage> {
  Database? _database;
  String _status = 'Seeding demo database…';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  @override
  void dispose() {
    _database?.close();
    super.dispose();
  }

  Future<void> _seed() async {
    final directory = await getApplicationDocumentsDirectory();
    final database = await openDatabase(
      p.join(directory.path, 'demo.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute(
          'CREATE TABLE people (id INTEGER PRIMARY KEY, name TEXT, '
          'score REAL)',
        );
        await db.execute(
          'CREATE TABLE projects (id INTEGER PRIMARY KEY, title TEXT)',
        );
        for (final person in const [
          ['Ada Lovelace', 99.5],
          ['Grace Hopper', 98.0],
          ['Katherine Johnson', 97.5],
        ]) {
          await db.insert('people', {
            'name': person[0],
            'score': person[1],
          });
        }
        await db.insert('projects', {'title': 'Analytical Engine'});
      },
    );

    setState(() {
      _database = database;
      _status = 'Ready. Pick a format.';
    });
  }

  /// The only db_exporter-specific wiring an app needs.
  DbExporter get _exporter => DbExporter(
        SqlSource(
          databasePath: _database!.path,
          query: _database!.rawQuery,
          execute: _database!.execute,
        ),
      );

  Future<void> _run(
    String label,
    Future<ExportResult> Function(DbExporter exporter) action,
  ) async {
    setState(() {
      _busy = true;
      _status = '$label…';
    });
    try {
      final result = await action(_exporter);
      setState(() {
        _status = result.userCancelled
            ? '$label cancelled.'
            : '$label → ${result.files.length} file(s), '
                '${result.totalRows} rows in '
                '${result.duration.inMilliseconds}ms\n'
                '${result.deliveredPath ?? result.files.first.path}';
      });
    } on DbExportException catch (error) {
      setState(() => _status = 'Failed: ${error.message}');
    } finally {
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _database != null && !_busy;
    return Scaffold(
      appBar: AppBar(title: const Text('db_exporter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: ready
                  ? () => _run(
                        'Backup .db',
                        (exporter) => exporter.exportDatabaseFile(
                          destination: const ExportDestination.share(
                            subject: 'Database backup',
                          ),
                        ),
                      )
                  : null,
              child: const Text('Share raw .db backup'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: ready
                  ? () => _run(
                        'Excel export',
                        (exporter) => exporter.exportExcel(
                          destination: const ExportDestination.saveAs(
                            dialogTitle: 'Save workbook',
                          ),
                        ),
                      )
                  : null,
              child: const Text('Save .xlsx via system dialog'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: ready
                  ? () => _run(
                        'CSV export',
                        (exporter) => exporter.exportCsv(
                          destination: const ExportDestination.share(),
                        ),
                      )
                  : null,
              child: const Text('Share one CSV per table'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: ready
                  ? () => _run(
                        'JSON export',
                        (exporter) => exporter.exportJson(
                          // No permissions, no UI — straight to the sandbox.
                          destination: const ExportDestination.appDirectory(),
                        ),
                      )
                  : null,
              child: const Text('Write JSON to app directory'),
            ),
          ],
        ),
      ),
    );
  }
}
