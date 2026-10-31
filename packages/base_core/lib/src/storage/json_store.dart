import 'json_store_io.dart' if (dart.library.js_interop) 'json_store_web.dart' as impl;

/// Small persistent JSON documents keyed by name (settings, the ledger,
/// each app's own data). Files on device, browser storage on web.
abstract class JsonStore {
  /// [namespace] keeps each app's data apart where apps can share storage
  /// (several apps served from one web origin). Use the app id.
  static Future<JsonStore> open({String namespace = 'app'}) => impl.openStore(namespace);

  Future<Object?> read(String key);

  Future<void> write(String key, Object? value);

  Future<void> delete(String key);

  Future<List<String>> keys(String prefix);

  /// Directory for imported attachments (photos, audio, documents).
  String? get filesDir;

  /// Deletes everything in [filesDir] (imported photos, audio, documents).
  Future<void> deleteFiles();
}
