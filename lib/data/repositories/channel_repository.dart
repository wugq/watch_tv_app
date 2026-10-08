import 'package:sqflite/sqflite.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/models/playlist.dart';
import 'package:tv/data/sources/channel_database.dart';

class ImportResult {
  final int added;
  final int updated;

  const ImportResult({required this.added, required this.updated});

  int get total => added + updated;
}

abstract class ChannelRepository {
  /// All channels in display order.
  Future<List<Channel>> getAll();

  /// Adds [channels] as sources added by hand. A channel whose name already
  /// exists gets the new sources appended and its category updated.
  Future<ImportResult> import(Iterable<Channel> channels);

  /// Replaces [oldChannel] with [newChannel], including all sources. The
  /// channel keeps its position when the name does not change.
  Future<void> replace(Channel oldChannel, Channel newChannel);

  Future<void> delete(String key);

  Future<void> deleteAll(Iterable<String> keys);

  Future<void> setFavorite(String key, bool favorite);

  Future<void> markWatched(String key, DateTime time);

  /// Playlists with their channel and source counts.
  Future<List<Playlist>> getPlaylists();

  /// Stores a new playlist and its channels, merged like [import].
  Future<ImportResult> addPlaylist({
    required String name,
    String? url,
    required Iterable<Channel> channels,
  });

  /// Replaces the sources of playlist [id] with [channels]. Favorites and
  /// history of channels that are still in the list are kept.
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

  @override
  Future<List<Channel>> getAll() async {
    final channelRows = await _db.query(_channels, orderBy: 'rowid');
    final sourceRows = await _db.query(
      _sources,
      orderBy: 'channel_key, position, rowid',
    );
    final urlsByKey = <String, List<String>>{};
    for (final row in sourceRows) {
      urlsByKey
          .putIfAbsent(row['channel_key'] as String, () => [])
          .add(row['url'] as String);
    }
    return [
      for (final row in channelRows)
        if (urlsByKey[row['key']] case final urls? when urls.isNotEmpty)
          Channel(
            key: row['key'] as String,
            name: row['name'] as String,
            category: row['category'] as String,
            urls: urls,
            favorite: row['favorite'] == 1,
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
      if (oldChannel.key != newChannel.key) {
        await _delete(txn, [oldChannel.key]);
      }
      final row = {
        ..._channelRow(newChannel),
        'favorite': newChannel.favorite ? 1 : 0,
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
      await _appendSources(txn, newChannel, null);
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
  Future<void> markWatched(String key, DateTime time) async {
    await _db.update(
      _channels,
      {'last_watched': time.millisecondsSinceEpoch},
      where: 'key = ?',
      whereArgs: [key],
    );
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

  Future<ImportResult> _import(
    Transaction txn,
    Iterable<Channel> channels,
    int? playlistId,
  ) async {
    var added = 0;
    var updated = 0;
    for (final channel in channels) {
      final updatedRows = await txn.update(
        _channels,
        {'category': channel.category},
        where: 'key = ?',
        whereArgs: [channel.key],
      );
      if (updatedRows == 0) {
        await txn.insert(_channels, _channelRow(channel));
        added++;
      } else {
        updated++;
      }
      await _appendSources(txn, channel, playlistId);
    }
    return ImportResult(added: added, updated: updated);
  }

  Future<void> _delete(Transaction txn, List<String> keys) async {
    if (keys.isEmpty) {
      return;
    }
    // Chunks stay below SQLite's limit of host parameters.
    for (var i = 0; i < keys.length; i += 500) {
      final chunk = keys.sublist(i, (i + 500).clamp(0, keys.length));
      final marks = List.filled(chunk.length, '?').join(',');
      await txn.delete(
        _sources,
        where: 'channel_key IN ($marks)',
        whereArgs: chunk,
      );
      await txn.delete(_channels, where: 'key IN ($marks)', whereArgs: chunk);
    }
  }

  Future<void> _deleteChannelsWithoutSources(Transaction txn) async {
    await txn.execute(
      'DELETE FROM $_channels WHERE key NOT IN '
      '(SELECT DISTINCT channel_key FROM $_sources)',
    );
  }

  Future<void> _appendSources(
    Transaction txn,
    Channel channel,
    int? playlistId,
  ) async {
    final result = await txn.rawQuery(
      'SELECT COALESCE(MAX(position), -1) AS last FROM $_sources '
      'WHERE channel_key = ?',
      [channel.key],
    );
    var position = (result.first['last'] as int) + 1;
    final batch = txn.batch();
    for (final url in channel.urls) {
      batch.insert(_sources, {
        'channel_key': channel.key,
        'position': position++,
        'url': url,
        'playlist_id': playlistId,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  static Map<String, Object?> _channelRow(Channel channel) {
    return {
      'key': channel.key,
      'name': channel.name,
      'category': channel.category,
    };
  }
}
