import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/channel.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';
import 'package:tv/pages/home_screen/widgets/control/category_item_widget.dart';

class ControlWidget extends StatelessWidget {
  const ControlWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var controller = Get.find<HomeScreenController>();

    return Expanded(
      child: Container(
        width: Get.width,
        color: const Color(0xFF2c2a38),
        child: Obx(
          () => GridView.count(
            padding: const EdgeInsets.all(10),
            childAspectRatio: 16 / 6,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            crossAxisCount: 2,
            children: controller.sourceList.map((Channel channel) {
              return CategoryItemWidget(channel: channel);
            }).toList(),
          ),
        ),
      ),
    );
  }
}
