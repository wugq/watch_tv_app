import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/pages/add_channel_screen/add_channel_screen.dart';
import 'package:tv/pages/add_channel_screen/controller/add_channel_controller.dart';
import 'package:tv/pages/home_screen/controller/home_screen_controller.dart';
import 'package:tv/pages/home_screen/widgets/control_widget.dart';
import 'package:tv/pages/home_screen/widgets/player_widget.dart';
import 'package:tv/pages/home_screen/widgets/status_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Get.lazyPut(() => HomeScreenController());
    Get.lazyPut(() => AddChannelController());

    return SafeArea(
      child: Scaffold(
        body: Column(
          children: const [
            PlayerWidget(),
            StatusWidget(),
            ControlWidget(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Get.to(() => const AddChannelScreen());
          },
          backgroundColor: const Color(0xFF7e7b7b),
          child: const Icon(Icons.add),
          // child: IconButton(icon: ,),
        ),
      ),
    );
  }
}
