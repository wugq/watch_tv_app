import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tv/core/platform.dart';

/// Schema:
///
/// * `CHANNELS(key, name, category)`: one row per channel, in display order
///   (rowid).
/// * `SOURCES(channel_key, position, url)`: stream URLs of a channel.
///
/// Version 1 had a single `url` column in `CHANNELS`.
class ChannelDatabase {
  static const channels = 'CHANNELS';
  static const sources = 'SOURCES';
  static const version = 2;

  static Future<Database> open() async {
    return openDatabase(
      join(await _directory(), 'watch_tv_database.db'),
      version: version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        final batch = db.batch();
        _createTables(batch);
        await batch.commit(noResult: true);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await migrateV1ToV2(db);
        }
      },
    );
  }

  /// Mobile keeps the sqflite default (existing data stays where it is).
  /// Desktop uses the per-user application support directory.
  static Future<String> _directory() async {
    if (isDesktop) {
      return (await getApplicationSupportDirectory()).path;
    }
    return getDatabasesPath();
  }

  static void _createTables(Batch batch) {
    batch.execute(
      'CREATE TABLE $channels('
      'key TEXT PRIMARY KEY, name TEXT NOT NULL, category TEXT NOT NULL)',
    );
    batch.execute(
      'CREATE TABLE $sources('
      'channel_key TEXT NOT NULL REFERENCES $channels(key) ON DELETE CASCADE, '
      'position INTEGER NOT NULL, '
      'url TEXT NOT NULL, '
      'PRIMARY KEY (channel_key, url))',
    );
  }

  /// Moves `CHANNELS.url` into `SOURCES`. Rebuilds `CHANNELS` because old
  /// Android SQLite versions do not support `DROP COLUMN`.
  static Future<void> migrateV1ToV2(DatabaseExecutor db) async {
    final batch = db.batch();
    batch.execute('ALTER TABLE $channels RENAME TO CHANNELS_V1');
    _createTables(batch);
    batch.execute(
      'INSERT INTO $channels(key, name, category) '
      "SELECT key, name, COALESCE(category, 'default') FROM CHANNELS_V1 "
      'ORDER BY rowid',
    );
    batch.execute(
      'INSERT INTO $sources(channel_key, position, url) '
      'SELECT key, 0, url FROM CHANNELS_V1 '
      "WHERE url IS NOT NULL AND url != ''",
    );
    batch.execute('DROP TABLE CHANNELS_V1');
    await batch.commit(noResult: true);
  }
}
