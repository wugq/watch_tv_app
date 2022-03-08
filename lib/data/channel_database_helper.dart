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

  Future<void> addDemoData() async {
    List<List<String>> list = [
      ["国家地理", "http://iptv.tvfix.org/hls/natlgeo.m3u8"],
      ["Discovery", "http://iptv.tvfix.org/hls/discovery.m3u8"],
      ["动物星球", "http://iptv.tvfix.org/hls/animal.m3u8"],
      ["动物星球 2", "http://iptv.tvfix.org/hls/animal2.m3u8"],
      ["Love Nature", "http://iptv.tvfix.org/hls/lovenature4k.m3u8"],
      ["Love Nature 2", "http://iptv.tvfix.org/hls/lovenature4k2.m3u8"],
      [
        "BBC World",
        "http://103.199.161.254/Content/bbcworld/Live/Channel(BBCworld)/index.m3u8"
      ],
    ];

    for (List item in list) {
      Channel channel = Channel(name: item[0], url: item[1]);
      insertData(channel);
    }

    // addChannel(Channel(name: "国家地理", url: "http://iptv.tvfix.org/hls/natlgeo.m3u8"));
    // addChannel(Channel(name: "Discovery", url: "http://iptv.tvfix.org/hls/discovery.m3u8"));
    // addChannel(Channel(name: "动物星球", url: "http://iptv.tvfix.org/hls/animal.m3u8"));
    // addChannel(Channel(name: "动物星球 2", url: "http://iptv.tvfix.org/hls/animal2.m3u8"));
    // addChannel(Channel(name: "Love Nature", url: "http://iptv.tvfix.org/hls/lovenature4k.m3u8"));
    // addChannel(Channel(name: "Love Nature 2", url: "http://iptv.tvfix.org/hls/lovenature4k2.m3u8"));
    // addChannel(Channel(name: "BBC World", url: "http://103.199.161.254/Content/bbcworld/Live/Channel(BBCworld)/index.m3u8"));
  }
}
