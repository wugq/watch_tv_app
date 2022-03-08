import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';

class StatusWidget extends StatelessWidget {
  const StatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var controller = Get.find<HomeScreenController>();

    return Container(
      width: Get.width,
      color: const Color(0xFF42424e),
      padding: const EdgeInsets.all(10),
      child: Obx(
        () => Text(
          "${controller.playerStatus} ${controller.channelName}",
          style: const TextStyle(
            color: Color(0xFFfffff8),
          ),
        ),
      ),
    );
  }
}
