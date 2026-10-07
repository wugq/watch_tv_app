import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/features/channel_editor/channel_editor_controller.dart';
import 'package:tv/features/channel_editor/widgets/category_field.dart';
import 'package:tv/features/channel_editor/widgets/save_button.dart';

class BatchChannelForm extends StatelessWidget {
  static const _example =
      'News,#genre#\n'
      'Channel A, https://example.com/a.m3u8\n'
      'Channel B, https://example.com/b.m3u8';

  final ChannelEditorController controller;

  const BatchChannelForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: controller.batchFormKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'One source per line: "Name, URL". '
                      'A "Category,#genre#" line starts a new category. '
                      'Lines with the same name become one channel with '
                      'several sources. M3U is also supported.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller.batchText,
            keyboardType: TextInputType.multiline,
            autocorrect: false,
            minLines: 8,
            maxLines: 16,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
            decoration: const InputDecoration(
              hintText: _example,
              alignLabelWithHint: true,
            ),
            validator: controller.validateBatch,
          ),
          const SizedBox(height: 16),
          Obx(
            () => CategoryField(
              controller: controller.batchCategoryText,
              suggestions: controller.categories.toList(),
              helperText: 'Used for lines without a category',
            ),
          ),
          const SizedBox(height: 24),
          SaveButton(
            isSaving: controller.isSaving,
            onPressed: controller.saveBatch,
          ),
        ],
      ),
    );
  }
}
