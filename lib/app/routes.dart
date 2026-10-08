import 'package:get/get.dart';
import 'package:tv/core/platform.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/channel_editor/channel_editor_controller.dart';
import 'package:tv/features/channel_editor/channel_editor_page.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/home_page.dart';
import 'package:tv/features/manage/manage_controller.dart';
import 'package:tv/features/manage/manage_page.dart';
import 'package:tv/features/player/player_controller.dart';
import 'package:tv/features/playlist_import/playlist_import_controller.dart';
import 'package:tv/features/playlist_import/playlist_import_page.dart';

abstract final class Routes {
  static const home = '/';
  static const channelEditor = '/channel';
  static const importPlaylist = '/playlist/import';
  static const manage = '/manage';
}

final appPages = [
  GetPage(
    name: Routes.home,
    page: () => const HomePage(),
    binding: BindingsBuilder(() {
      Get.put(
        PlayerController(
          errorsAreFatal: !usesMediaKit,
          pauseInBackground: !isDesktop,
        ),
      );
      Get.put(HomeController(Get.find(), Get.find()));
    }),
  ),
  GetPage(
    name: Routes.channelEditor,
    page: () => const ChannelEditorPage(),
    binding: BindingsBuilder(() {
      final argument = Get.arguments;
      Get.put(
        ChannelEditorController(
          Get.find(),
          original: argument is Channel ? argument : null,
        ),
      );
    }),
  ),
  GetPage(
    name: Routes.importPlaylist,
    page: () => const PlaylistImportPage(),
    binding: BindingsBuilder(() {
      Get.put(PlaylistImportController(Get.find(), Get.find()));
    }),
  ),
  GetPage(
    name: Routes.manage,
    page: () => const ManagePage(),
    binding: BindingsBuilder(() {
      Get.put(ManageController(Get.find(), Get.find()));
    }),
  ),
];
