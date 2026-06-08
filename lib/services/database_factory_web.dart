import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// `sqflite` has no native implementation in the browser, so on web we swap in
/// the WASM-backed factory (sqlite3 compiled to WASM, persisted via IndexedDB)
/// before anything tries to open the database.
void configureWebDatabaseFactory() {
  databaseFactory = databaseFactoryFfiWeb;
}
