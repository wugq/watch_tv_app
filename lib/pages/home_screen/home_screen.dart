import 'package:flutter/material.dart';
import 'package:tv/pages/home_screen/widgets/control_widget.dart';
import 'package:tv/pages/home_screen/widgets/player_widget.dart';
import 'package:tv/pages/home_screen/widgets/status_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Column(
          children: const [
            PlayerWidget(),
            StatusWidget(),
            ControlWidget(),
          ],
        ),
      ),
    );
  }
}
