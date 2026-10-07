import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/features/channel_editor/channel_editor_controller.dart';
import 'package:tv/features/channel_editor/widgets/category_field.dart';
import 'package:tv/features/channel_editor/widgets/save_button.dart';

class SingleChannelForm extends StatelessWidget {
  final ChannelEditorController controller;

  const SingleChannelForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: controller.singleFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: controller.nameText,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Channel name',
              prefixIcon: Icon(Icons.tv),
            ),
            validator: controller.validateName,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller.urlText,
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Stream URL',
              hintText: 'https://example.com/live.m3u8',
              prefixIcon: Icon(Icons.link),
            ),
            validator: controller.validateUrl,
          ),
          const SizedBox(height: 16),
          Obx(
            () => CategoryField(
              controller: controller.categoryText,
              suggestions: controller.categories.toList(),
              helperText: 'Channels are grouped by category',
            ),
          ),
          const SizedBox(height: 24),
          SaveButton(
            isSaving: controller.isSaving,
            onPressed: controller.saveSingle,
          ),
        ],
      ),
    );
  }
}
