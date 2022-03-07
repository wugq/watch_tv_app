import 'package:fijkplayer/fijkplayer.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';

class PlayerWidget extends StatelessWidget {
  const PlayerWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var controller = Get.find<HomeScreenController>();

    FijkFit fit = FijkFit(
      sizeFactor: 1.0,
      aspectRatio: controller.videoRatio.value,
      alignment: Alignment.center,
    );

    return SizedBox(
      height: Get.width / controller.videoRatio.value,
      child: FijkView(
        color: Colors.black,
        fit: fit,
        player: controller.player,
        cover: Image.asset('assets/tv_cover.jpg').image,
      ),
    );
  }
}
