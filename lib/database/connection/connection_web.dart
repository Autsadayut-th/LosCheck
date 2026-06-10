import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'loscheck_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse(
        'https://github.com/simolus3/sql.js-wasm/releases/download/v3.46.1-build4/sql-wasm.wasm',
      ),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}

QueryExecutor openConnection() => _openConnection();
