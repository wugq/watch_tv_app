import 'package:get/get.dart';
import 'package:tv/data/channel.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';

class AddChannelController extends GetxController {
  var homeScreenController = Get.find<HomeScreenController>();

  addChannel(String name, String url) {
    Channel channel = Channel(name: name, url: url);
    homeScreenController.addChannel(channel);
  }
}
