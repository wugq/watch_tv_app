import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:tv/core/platform.dart';

/// Schema (version 3):
///
/// * `CHANNELS(key, name, category, favorite, last_watched)`: one row per
///   channel, in display order (rowid).
/// * `SOURCES(channel_key, position, url, playlist_id)`: stream URLs of a
///   channel. `playlist_id` is null for sources added by hand.
/// * `PLAYLISTS(id, name, url, created_at, updated_at)`: imported lists.
///
/// Version 1 had a single `url` column in `CHANNELS`. Version 2 added
/// `SOURCES`. Version 3 added favorites, watch history and playlists.
class ChannelDatabase {
  static const channels = 'CHANNELS';
  static const sources = 'SOURCES';
  static const playlists = 'PLAYLISTS';
  static const version = 3;

  static Future<Database> open() async {
    return openDatabase(
      join(await _directory(), 'watch_tv_database.db'),
      version: version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => create(db),
      onUpgrade: (db, oldVersion, newVersion) =>
          upgrade(db, oldVersion, newVersion),
    );
  }

  /// Creates the current schema. Runs the same steps as an upgrade, so new
  /// and upgraded databases are identical.
  static Future<void> create(DatabaseExecutor db) async {
    final batch = db.batch();
    _createV2Tables(batch);
    await batch.commit(noResult: true);
    await migrateV2ToV3(db);
  }

  static Future<void> upgrade(
    DatabaseExecutor db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await migrateV1ToV2(db);
    }
    if (oldVersion < 3) {
      await migrateV2ToV3(db);
    }
  }

  /// Mobile keeps the sqflite default (existing data stays where it is).
  /// Desktop uses the per-user application support directory.
  static Future<String> _directory() async {
    if (isDesktop) {
      return (await getApplicationSupportDirectory()).path;
    }
    return getDatabasesPath();
  }

  static void _createV2Tables(Batch batch) {
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
    _createV2Tables(batch);
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

  /// Adds favorites, watch history and playlists. Existing sources become
  /// "added by hand" (`playlist_id` null).
  static Future<void> migrateV2ToV3(DatabaseExecutor db) async {
    final batch = db.batch();
    batch.execute(
      'CREATE TABLE $playlists('
      'id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'name TEXT NOT NULL, '
      'url TEXT, '
      'created_at INTEGER NOT NULL, '
      'updated_at INTEGER NOT NULL)',
    );
    batch.execute(
      'ALTER TABLE $channels ADD COLUMN favorite INTEGER NOT NULL DEFAULT 0',
    );
    batch.execute('ALTER TABLE $channels ADD COLUMN last_watched INTEGER');
    batch.execute('ALTER TABLE $sources ADD COLUMN playlist_id INTEGER');
    batch.execute('CREATE INDEX sources_playlist ON $sources(playlist_id)');
    await batch.commit(noResult: true);
  }
}
