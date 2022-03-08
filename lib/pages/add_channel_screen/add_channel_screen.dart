import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/pages/add_channel_screen/controller/add_channel_controller.dart';
import 'package:tv/pages/add_channel_screen/widgets/add_channel_form.dart';
import 'package:tv/pages/add_channel_screen/widgets/input_text_widget.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';

class AddChannelScreen extends StatelessWidget {
  const AddChannelScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => HomeScreenController());
    Get.lazyPut(() => AddChannelController());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Add Channel"),
        backgroundColor: const Color(0xFF42424e),
      ),
      body: Container(
        color: const Color(0xFF2c2a38),
        // width: Get.width,
        // height: Get.height,
        child: Column(
          children: const [
            SizedBox(height: 20),
            AddChannelForm(),
          ],
        ),
      ),
      resizeToAvoidBottomInset: false,
    );
  }
}
