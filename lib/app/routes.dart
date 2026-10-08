import 'package:get/get.dart';
import 'package:tv/core/platform.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/channel_editor/channel_editor_controller.dart';
import 'package:tv/features/channel_editor/channel_editor_page.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/home_page.dart';
import 'package:tv/features/player/player_controller.dart';

abstract final class Routes {
  static const home = '/';
  static const channelEditor = '/channel-editor';
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
          Get.find(),
          original: argument is Channel ? argument : null,
        ),
      );
    }),
  ),
];
