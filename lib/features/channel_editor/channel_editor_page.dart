import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/features/channel_editor/channel_editor_controller.dart';
import 'package:tv/features/channel_editor/widgets/batch_channel_form.dart';
import 'package:tv/features/channel_editor/widgets/single_channel_form.dart';

class ChannelEditorPage extends GetView<ChannelEditorController> {
  const ChannelEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    if (controller.isEditing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit channel')),
        body: SingleChannelForm(controller: controller),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Add channels'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.add_link), text: 'Single'),
              Tab(icon: Icon(Icons.playlist_add), text: 'Batch'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            SingleChannelForm(controller: controller),
            BatchChannelForm(controller: controller),
          ],
        ),
      ),
    );
  }
}
