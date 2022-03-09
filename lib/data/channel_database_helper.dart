import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:tv/data/channel.dart';

class ChannelDatabaseHelper {
  final Database database;

  ChannelDatabaseHelper(this.database);

  Future<List<Channel>> showAllData() async {
    final List<Map<String, dynamic>> maps = await database.query("CHANNELS");

    return List.generate(maps.length, (i) {
      return Channel.fromObj(
        key: maps[i]["key"],
        name: maps[i]["name"],
        category: maps[i]["category"],
        url: maps[i]["url"],
      );
    });
  }

  Future<int> insertData(Channel channel) async {
    return await database.insert(
      "CHANNELS",
      channel.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> updateData(Channel channel) async {
    await database.update(
      "CHANNELS",
      channel.toMap(),
      where: "key = ?",
      whereArgs: [channel.key],
    );
  }

  Future<void> deleteData(String key) async {
    await database.delete(
      "CHANNELS",
      where: "key = ?",
      whereArgs: [key],
    );
  }

  Future<void> clearTable() async {
    await database.delete("CHANNELS");
  }
}
