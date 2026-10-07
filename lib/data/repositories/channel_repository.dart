import 'package:sqflite/sqflite.dart';
import 'package:tv/data/models/channel.dart';
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

  /// Adds [channels]. A channel whose name already exists gets the new
  /// sources appended and its category updated.
  Future<ImportResult> import(Iterable<Channel> channels);

  /// Replaces [oldChannel] with [newChannel], including all sources. The
  /// channel keeps its position when the name does not change.
  Future<void> replace(Channel oldChannel, Channel newChannel);

  Future<void> delete(String key);
}

class SqfliteChannelRepository implements ChannelRepository {
  final Database _db;

  SqfliteChannelRepository(this._db);

  static const _channels = ChannelDatabase.channels;
  static const _sources = ChannelDatabase.sources;

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
          ),
    ];
  }

  @override
  Future<ImportResult> import(Iterable<Channel> channels) {
    return _db.transaction((txn) async {
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
        await _appendSources(txn, channel);
      }
      return ImportResult(added: added, updated: updated);
    });
  }

  @override
  Future<void> replace(Channel oldChannel, Channel newChannel) {
    return _db.transaction((txn) async {
      if (oldChannel.key != newChannel.key) {
        await _delete(txn, oldChannel.key);
      }
      final updatedRows = await txn.update(
        _channels,
        _channelRow(newChannel),
        where: 'key = ?',
        whereArgs: [newChannel.key],
      );
      if (updatedRows == 0) {
        await txn.insert(_channels, _channelRow(newChannel));
      }
      await txn.delete(
        _sources,
        where: 'channel_key = ?',
        whereArgs: [newChannel.key],
      );
      await _appendSources(txn, newChannel);
    });
  }

  @override
  Future<void> delete(String key) {
    return _db.transaction((txn) => _delete(txn, key));
  }

  Future<void> _delete(Transaction txn, String key) async {
    await txn.delete(_sources, where: 'channel_key = ?', whereArgs: [key]);
    await txn.delete(_channels, where: 'key = ?', whereArgs: [key]);
  }

  Future<void> _appendSources(Transaction txn, Channel channel) async {
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
