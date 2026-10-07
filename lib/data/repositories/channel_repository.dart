import 'package:sqflite/sqflite.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/sources/channel_database.dart';

abstract class ChannelRepository {
  Future<List<Channel>> getAll();

  /// Inserts [channel], or replaces the channel with the same key.
  Future<void> save(Channel channel);

  Future<void> saveAll(Iterable<Channel> channels);

  /// Replaces [oldChannel] with [newChannel]. The key changes when the name
  /// changes, so the old row is removed first.
  Future<void> replace(Channel oldChannel, Channel newChannel);

  Future<void> delete(String key);
}

class SqfliteChannelRepository implements ChannelRepository {
  final Database _db;

  SqfliteChannelRepository(this._db);

  @override
  Future<List<Channel>> getAll() async {
    final rows = await _db.query(ChannelDatabase.table, orderBy: 'rowid');
    return rows.map(Channel.fromMap).toList();
  }

  @override
  Future<void> save(Channel channel) async {
    await _db.insert(
      ChannelDatabase.table,
      channel.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> saveAll(Iterable<Channel> channels) async {
    final batch = _db.batch();
    for (final channel in channels) {
      batch.insert(
        ChannelDatabase.table,
        channel.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  @override
  Future<void> replace(Channel oldChannel, Channel newChannel) async {
    await _db.transaction((txn) async {
      await txn.delete(
        ChannelDatabase.table,
        where: 'key = ?',
        whereArgs: [oldChannel.key],
      );
      await txn.insert(
        ChannelDatabase.table,
        newChannel.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  @override
  Future<void> delete(String key) async {
    await _db.delete(ChannelDatabase.table, where: 'key = ?', whereArgs: [key]);
  }
}
