import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/channel.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';

class CategoryItemWidget extends StatelessWidget {
  final Channel channel;

  const CategoryItemWidget({Key? key, required this.channel}) : super(key: key);

  Future<bool> confirmDismissFn(BuildContext context) async {
    return await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Confirm"),
          content: const Text("Are you sure you wish to delete this channel?"),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text("DELETE")),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text("CANCEL"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    var controller = Get.find<HomeScreenController>();

    return Dismissible(
      key: Key(channel.key),
      onDismissed: (DismissDirection direction) {
        controller.deleteChannel(channel);
      },
      confirmDismiss: (DismissDirection direction) async {
        return confirmDismissFn(context);
      },
      child: InkWell(
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
      ),
    );
  }
}
