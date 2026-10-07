import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tv/core/checksum.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/data/sources/channel_database.dart';

Future<Database> openV2() {
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      singleInstance: false,
      version: ChannelDatabase.version,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        // Same path as a real upgrade: create v1, then migrate.
        await db.execute(
          'CREATE TABLE CHANNELS(key TEXT PRIMARY KEY, name TEXT, url TEXT, category TEXT)',
        );
        await ChannelDatabase.migrateV1ToV2(db);
      },
    ),
  );
}

void main() {
  sqfliteFfiInit();

  late Database db;
  late ChannelRepository repository;

  setUp(() async {
    db = await openV2();
    repository = SqfliteChannelRepository(db);
  });

  tearDown(() => db.close());

  Channel channel(String name, List<String> urls, [String? category]) =>
      Channel.create(name: name, urls: urls, category: category);

  test(
    'import adds new channels and merges sources of existing ones',
    () async {
      await repository.import([
        channel('A', ['http://a/1'], 'News'),
        channel('B', ['http://b/1']),
      ]);

      final result = await repository.import([
        channel('A', ['http://a/1', 'http://a/2'], 'Live'),
        channel('C', ['http://c/1']),
      ]);

      expect(result.added, 1);
      expect(result.updated, 1);
      final all = await repository.getAll();
      expect(all.map((c) => c.name), ['A', 'B', 'C']);
      expect(all.first.urls, ['http://a/1', 'http://a/2']);
      expect(all.first.category, 'Live');
    },
  );

  test('replace keeps position and replaces all sources', () async {
    final a = channel('A', ['http://a/1', 'http://a/2']);
    await repository.import([
      a,
      channel('B', ['http://b/1']),
    ]);

    await repository.replace(a, channel('A', ['http://a/3'], 'News'));

    final all = await repository.getAll();
    expect(all.map((c) => c.name), ['A', 'B']);
    expect(all.first.urls, ['http://a/3']);
  });

  test('replace with a new name removes the old channel', () async {
    final a = channel('A', ['http://a/1']);
    await repository.import([a]);

    await repository.replace(a, channel('A2', ['http://a/1']));

    final all = await repository.getAll();
    expect(all.map((c) => c.name), ['A2']);
  });

  test('delete removes the channel and its sources', () async {
    final a = channel('A', ['http://a/1', 'http://a/2']);
    await repository.import([a]);

    await repository.delete(a.key);

    expect(await repository.getAll(), isEmpty);
    expect(await db.query(ChannelDatabase.sources), isEmpty);
  });

  test('migration from v1 keeps channels, order and URLs', () async {
    final v1 = await databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false),
    );
    await v1.execute(
      'CREATE TABLE CHANNELS(key TEXT PRIMARY KEY, name TEXT, url TEXT, category TEXT)',
    );
    for (final name in ['Z', 'A', 'M']) {
      await v1.insert('CHANNELS', {
        'key': sha1Of(name),
        'name': name,
        'url': 'http://x/$name',
        'category': 'default',
      });
    }

    await v1.transaction(ChannelDatabase.migrateV1ToV2);

    final all = await SqfliteChannelRepository(v1).getAll();
    expect(all.map((c) => c.name), ['Z', 'A', 'M']);
    expect(all.first.urls, ['http://x/Z']);
    expect(all.first.key, sha1Of('Z'));
    await v1.close();
  });
}
