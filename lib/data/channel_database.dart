import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class ChannelDatabase {
  static Future<Database> getDatabase() async {
    Database database = await openDatabase(
      join(await getDatabasesPath(), 'watch_tv_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE CHANNELS(key TEXT PRIMARY KEY, name TEXT, url TEXT, category TEXT)',
        );
      },
      version: 1,
    );
    return database;
  }
}
