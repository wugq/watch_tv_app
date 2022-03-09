import 'package:get/get.dart';
import 'package:tv/data/channel.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';

class AddChannelController extends GetxController {
  var homeScreenController = Get.find<HomeScreenController>();

  addChannel(String name, String url) async {
    Channel channel = Channel(name: name, url: url);
    await homeScreenController.addChannel(channel);
  }

  batchAddChannel(String text) async {
    List<String> list = text.split("\n");
    for (String line in list) {
      List<String> item = line.split(",");
      if (item.length != 2) {
        continue;
      }
      String name = item[0].trim();
      String url = item[1].trim();
      await addChannel(name, url);
    }
  }
}
