// Conditional stub for the Drift database connection.
//
// This file is imported by `app_database.dart` and resolves to either
// the mobile/desktop (`connection_io.dart`) or web (`connection_web.dart`)
// implementation at compile time, depending on the available libraries.
//
// Do not put any logic in this file — the `if (dart.library.html)`
// directive is what allows the analyzer to pick the right variant
// without breaking the other platform's build.
export 'connection_io.dart' if (dart.library.html) 'connection_web.dart';
