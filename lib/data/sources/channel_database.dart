import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class ChannelDatabase {
  static const table = 'CHANNELS';

  static Future<Database> open() async {
    return openDatabase(
      join(await getDatabasesPath(), 'watch_tv_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE $table(key TEXT PRIMARY KEY, name TEXT, url TEXT, category TEXT)',
        );
      },
      version: 1,
    );
  }
}
