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
        color: const Color(0xFF2c2a38),
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
                margin: const EdgeInsets.all(1.0),
                padding: const EdgeInsets.only(right: 20, left: 20),
                decoration: const BoxDecoration(
                  color: Color(0xFF373542),
                  borderRadius: BorderRadius.all(
                    Radius.circular(5),
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    channel.name,
                    style: const TextStyle(
                      fontSize: 20.0,
                      color: Color(0xFFfdfef5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
