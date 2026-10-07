import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/app/app.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/data/sources/channel_database.dart';
import 'package:tv/data/sources/playlist_loader.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = await ChannelDatabase.open();
  Get.put<ChannelRepository>(
    SqfliteChannelRepository(database),
    permanent: true,
  );
  Get.lazyPut(PlaylistLoader.new, fenix: true);
  runApp(const WatchTvApp());
}
