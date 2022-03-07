import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/channel.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';

class ControlWidget extends StatelessWidget {
  const ControlWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var controller = Get.find<HomeScreenController>();

    return Expanded(
      child: Container(
        width: Get.width,
        color: Colors.teal[600],
        child: GridView.count(
          padding: const EdgeInsets.all(10),
          childAspectRatio: 16 / 6,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          crossAxisCount: 2,
          // shrinkWrap: true,
          children: controller.sourceList.map((Channel channel) {
            return InkWell(
              onTap: () {
                controller.switchChannel(channel);
              },
              child: Container(
                color: Colors.teal[200],
                margin: const EdgeInsets.all(1.0),
                child: Center(
                  child: AutoSizeText(
                    channel.name,
                    style: const TextStyle(
                      fontSize: 28.0,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
