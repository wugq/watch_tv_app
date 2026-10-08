import 'package:sqflite/sqflite.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/models/custom_category.dart';
import 'package:tv/data/models/playlist.dart';
import 'package:tv/data/sources/channel_database.dart';

class ImportResult {
  final int added;
  final int updated;

  const ImportResult({required this.added, required this.updated});

  int get total => added + updated;
}

abstract class ChannelRepository {
  /// All channels in display order, hidden ones included.
  Future<List<Channel>> getAll();

  /// Adds [channels] as sources added by hand. A channel whose name already
  /// exists gets the new sources appended and its category updated.
  Future<ImportResult> import(Iterable<Channel> channels);

  /// Replaces [oldChannel] with [newChannel], including all sources. The
  /// channel keeps its position and custom categories when renamed.
  Future<void> replace(Channel oldChannel, Channel newChannel);

  Future<void> delete(String key);

  Future<void> deleteAll(Iterable<String> keys);

  Future<void> setFavorite(String key, bool favorite);

  /// Hides channels from browsing, or shows them again.
  Future<void> setHidden(Iterable<String> keys, bool hidden);

  Future<void> markWatched(String key, DateTime time);

  /// Playlist categories the user hid.
  Future<Set<String>> getHiddenCategories();

  Future<void> setCategoryHidden(Iterable<String> names, bool hidden);

  Future<List<CustomCategory>> getCustomCategories();

  /// Returns the id of the new category.
  Future<int> createCustomCategory(String name);

  Future<void> renameCustomCategory(int id, String name);

  Future<void> deleteCustomCategory(int id);

  /// Appends channels to a custom category. Channels already in it stay
  /// where they are.
  Future<void> addToCustomCategory(int id, Iterable<String> keys);

  Future<void> removeFromCustomCategory(int id, Iterable<String> keys);

  /// Playlists with their channel and source counts.
  Future<List<Playlist>> getPlaylists();

  /// Stores a new playlist and its channels, merged like [import].
  Future<ImportResult> addPlaylist({
    required String name,
    String? url,
    required Iterable<Channel> channels,
  });

  /// Replaces the sources of playlist [id] with [channels]. Favorites,
  /// visibility and history of channels that are still in the list are
  /// kept.
  Future<ImportResult> refreshPlaylist(int id, Iterable<Channel> channels);

  Future<void> renamePlaylist(int id, String name);

  /// Deletes the playlist and its sources. Channels left without any
  /// source are deleted too.
  Future<void> deletePlaylist(int id);
}

class SqfliteChannelRepository implements ChannelRepository {
  final Database _db;

  SqfliteChannelRepository(this._db);

  static const _channels = ChannelDatabase.channels;
  static const _sources = ChannelDatabase.sources;
  static const _playlists = ChannelDatabase.playlists;
  static const _categorySettings = ChannelDatabase.categorySettings;
  static const _custom = ChannelDatabase.customCategories;
  static const _customChannels = ChannelDatabase.customCategoryChannels;

  @override
  Future<List<Channel>> getAll() async {
    final channelRows = await _db.query(_channels, orderBy: 'rowid');
    final sourceRows = await _db.query(
      _sources,
      orderBy: 'channel_key, position, rowid',
    );
    final sourcesByKey = <String, List<StreamSource>>{};
    for (final row in sourceRows) {
      sourcesByKey
          .putIfAbsent(row['channel_key'] as String, () => [])
          .add(
            StreamSource(
              row['url'] as String,
              userAgent: row['user_agent'] as String?,
              referrer: row['referrer'] as String?,
            ),
          );
    }
    return [
      for (final row in channelRows)
        if (sourcesByKey[row['key']] case final sources?
            when sources.isNotEmpty)
          Channel(
            key: row['key'] as String,
            name: row['name'] as String,
            category: row['category'] as String,
            sources: sources,
            favorite: row['favorite'] == 1,
            hidden: row['hidden'] == 1,
            lastWatched: switch (row['last_watched']) {
              final int ms => DateTime.fromMillisecondsSinceEpoch(ms),
              _ => null,
            },
          ),
    ];
  }

  @override
  Future<ImportResult> import(Iterable<Channel> channels) {
    return _db.transaction((txn) => _import(txn, channels, null));
  }

  @override
  Future<void> replace(Channel oldChannel, Channel newChannel) {
    return _db.transaction((txn) async {
      final renamed = oldChannel.key != newChannel.key;
      if (renamed) {
        // Keep the custom categories of the old name.
        await txn.execute(
          'UPDATE OR IGNORE $_customChannels SET channel_key = ? '
          'WHERE channel_key = ?',
          [newChannel.key, oldChannel.key],
        );
        await _delete(txn, [oldChannel.key]);
      }
      final row = {
        ..._channelRow(newChannel),
        'favorite': newChannel.favorite ? 1 : 0,
        'hidden': newChannel.hidden ? 1 : 0,
        'last_watched': newChannel.lastWatched?.millisecondsSinceEpoch,
      };
      final updatedRows = await txn.update(
        _channels,
        row,
        where: 'key = ?',
        whereArgs: [newChannel.key],
      );
      if (updatedRows == 0) {
        await txn.insert(_channels, row);
      }
      await txn.delete(
        _sources,
        where: 'channel_key = ?',
        whereArgs: [newChannel.key],
      );
      final batch = txn.batch();
      _insertSources(batch, newChannel, 0, null);
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> delete(String key) => deleteAll([key]);

  @override
  Future<void> deleteAll(Iterable<String> keys) {
    return _db.transaction((txn) => _delete(txn, keys.toList()));
  }

  @override
  Future<void> setFavorite(String key, bool favorite) async {
    await _db.update(
      _channels,
      {'favorite': favorite ? 1 : 0},
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<void> setHidden(Iterable<String> keys, bool hidden) {
    return _db.transaction((txn) async {
      await _forChunks(keys.toList(), (chunk, marks) async {
        await txn.update(
          _channels,
          {'hidden': hidden ? 1 : 0},
          where: 'key IN ($marks)',
          whereArgs: chunk,
        );
      });
    });
  }

  @override
  Future<void> markWatched(String key, DateTime time) async {
    await _db.update(
      _channels,
      {'last_watched': time.millisecondsSinceEpoch},
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  @override
  Future<Set<String>> getHiddenCategories() async {
    final rows = await _db.query(_categorySettings, where: 'hidden = 1');
    return {for (final row in rows) row['name'] as String};
  }

  @override
  Future<void> setCategoryHidden(Iterable<String> names, bool hidden) async {
    final batch = _db.batch();
    for (final name in names) {
      batch.insert(_categorySettings, {
        'name': name,
        'hidden': hidden ? 1 : 0,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<List<CustomCategory>> getCustomCategories() async {
    final categories = await _db.query(_custom, orderBy: 'position, id');
    final members = await _db.query(
      _customChannels,
      orderBy: 'category_id, position',
    );
    final keysById = <int, List<String>>{};
    for (final row in members) {
      keysById
          .putIfAbsent(row['category_id'] as int, () => [])
          .add(row['channel_key'] as String);
    }
    return [
      for (final row in categories)
        CustomCategory(
          id: row['id'] as int,
          name: row['name'] as String,
          channelKeys: keysById[row['id']] ?? const [],
        ),
    ];
  }

  @override
  Future<int> createCustomCategory(String name) async {
    final result = await _db.rawQuery(
      'SELECT COALESCE(MAX(position), -1) + 1 AS next FROM $_custom',
    );
    return _db.insert(_custom, {
      'name': name,
      'position': result.first['next'] as int,
    });
  }

  @override
  Future<void> renameCustomCategory(int id, String name) async {
    await _db.update(_custom, {'name': name}, where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteCustomCategory(int id) {
    return _db.transaction((txn) async {
      await txn.delete(
        _customChannels,
        where: 'category_id = ?',
        whereArgs: [id],
      );
      await txn.delete(_custom, where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> addToCustomCategory(int id, Iterable<String> keys) {
    return _db.transaction((txn) async {
      final result = await txn.rawQuery(
        'SELECT COALESCE(MAX(position), -1) + 1 AS next '
        'FROM $_customChannels WHERE category_id = ?',
        [id],
      );
      var position = result.first['next'] as int;
      final batch = txn.batch();
      for (final key in keys) {
        batch.insert(_customChannels, {
          'category_id': id,
          'channel_key': key,
          'position': position++,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }

  @override
  Future<void> removeFromCustomCategory(int id, Iterable<String> keys) {
    return _db.transaction((txn) async {
      await _forChunks(keys.toList(), (chunk, marks) async {
        await txn.delete(
          _customChannels,
          where: 'category_id = ? AND channel_key IN ($marks)',
          whereArgs: [id, ...chunk],
        );
      });
    });
  }

  @override
  Future<List<Playlist>> getPlaylists() async {
    final rows = await _db.rawQuery(
      'SELECT p.id, p.name, p.url, p.updated_at, '
      'COUNT(DISTINCT s.channel_key) AS channels, COUNT(s.url) AS sources '
      'FROM $_playlists p LEFT JOIN $_sources s ON s.playlist_id = p.id '
      'GROUP BY p.id ORDER BY p.id',
    );
    return [
      for (final row in rows)
        Playlist(
          id: row['id'] as int,
          name: row['name'] as String,
          url: row['url'] as String?,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(
            row['updated_at'] as int,
          ),
          channelCount: row['channels'] as int,
          sourceCount: row['sources'] as int,
        ),
    ];
  }

  @override
  Future<ImportResult> addPlaylist({
    required String name,
    String? url,
    required Iterable<Channel> channels,
  }) {
    return _db.transaction((txn) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await txn.insert(_playlists, {
        'name': name,
        'url': url,
        'created_at': now,
        'updated_at': now,
      });
      return _import(txn, channels, id);
    });
  }

  @override
  Future<ImportResult> refreshPlaylist(int id, Iterable<Channel> channels) {
    return _db.transaction((txn) async {
      await txn.delete(_sources, where: 'playlist_id = ?', whereArgs: [id]);
      final result = await _import(txn, channels, id);
      await txn.update(
        _playlists,
        {'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'id = ?',
        whereArgs: [id],
      );
      await _deleteChannelsWithoutSources(txn);
      return result;
    });
  }

  @override
  Future<void> renamePlaylist(int id, String name) async {
    await _db.update(
      _playlists,
      {'name': name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> deletePlaylist(int id) {
    return _db.transaction((txn) async {
      await txn.delete(_sources, where: 'playlist_id = ?', whereArgs: [id]);
      await txn.delete(_playlists, where: 'id = ?', whereArgs: [id]);
      await _deleteChannelsWithoutSources(txn);
    });
  }

  /// Adds or merges [channels] with one batch, so a playlist with
  /// thousands of channels is saved in one round trip to the database.
  Future<ImportResult> _import(
    Transaction txn,
    Iterable<Channel> channels,
    int? playlistId,
  ) async {
    final existing = {
      for (final row in await txn.query(_channels, columns: ['key']))
        row['key'] as String,
    };
    final nextPosition = {
      for (final row in await txn.rawQuery(
        'SELECT channel_key, MAX(position) AS last FROM $_sources '
        'GROUP BY channel_key',
      ))
        row['channel_key'] as String: (row['last'] as int) + 1,
    };
    var added = 0;
    var updated = 0;
    final batch = txn.batch();
    for (final channel in channels) {
      if (existing.add(channel.key)) {
        batch.insert(_channels, _channelRow(channel));
        added++;
      } else {
        batch.update(
          _channels,
          {'category': channel.category},
          where: 'key = ?',
          whereArgs: [channel.key],
        );
        updated++;
      }
      final first = nextPosition[channel.key] ?? 0;
      _insertSources(batch, channel, first, playlistId);
      nextPosition[channel.key] = first + channel.sources.length;
    }
    await batch.commit(noResult: true);
    return ImportResult(added: added, updated: updated);
  }

  void _insertSources(
    Batch batch,
    Channel channel,
    int firstPosition,
    int? playlistId,
  ) {
    var position = firstPosition;
    for (final source in channel.sources) {
      batch.insert(_sources, {
        'channel_key': channel.key,
        'position': position++,
        'url': source.url,
        'user_agent': source.userAgent,
        'referrer': source.referrer,
        'playlist_id': playlistId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _delete(Transaction txn, List<String> keys) async {
    await _forChunks(keys, (chunk, marks) async {
      await txn.delete(
        _sources,
        where: 'channel_key IN ($marks)',
        whereArgs: chunk,
      );
      await txn.delete(
        _customChannels,
        where: 'channel_key IN ($marks)',
        whereArgs: chunk,
      );
      await txn.delete(_channels, where: 'key IN ($marks)', whereArgs: chunk);
    });
  }

  /// Runs [action] on chunks small enough for SQLite's limit of host
  /// parameters, with the matching `?,?,...` list.
  static Future<void> _forChunks(
    List<String> keys,
    Future<void> Function(List<String> chunk, String marks) action,
  ) async {
    for (var i = 0; i < keys.length; i += 500) {
      final chunk = keys.sublist(i, (i + 500).clamp(0, keys.length));
      await action(chunk, List.filled(chunk.length, '?').join(','));
    }
  }

  Future<void> _deleteChannelsWithoutSources(Transaction txn) async {
    const orphan =
        'NOT IN (SELECT DISTINCT channel_key FROM ${ChannelDatabase.sources})';
    await txn.execute('DELETE FROM $_customChannels WHERE channel_key $orphan');
    await txn.execute('DELETE FROM $_channels WHERE key $orphan');
  }

  static Map<String, Object?> _channelRow(Channel channel) {
    return {
      'key': channel.key,
      'name': channel.name,
      'category': channel.category,
    };
  }
}
