import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/channel.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';

class CategoryItemWidget extends StatelessWidget {
  final Channel channel;

  const CategoryItemWidget({Key? key, required this.channel}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var controller = Get.find<HomeScreenController>();

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
  }
}
