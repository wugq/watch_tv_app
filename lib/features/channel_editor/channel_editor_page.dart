import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/features/channel_editor/channel_editor_controller.dart';
import 'package:tv/widgets/category_field.dart';
import 'package:tv/widgets/confirm_dialog.dart';
import 'package:tv/widgets/save_button.dart';

class ChannelEditorPage extends GetView<ChannelEditorController> {
  const ChannelEditorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(controller.isEditing ? 'Edit channel' : 'Add channel'),
        actions: [
          if (controller.isEditing)
            IconButton(
              tooltip: 'Delete channel',
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Form(
            key: controller.formKey,
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
                Obx(
                  () => CategoryField(
                    controller: controller.categoryText,
                    suggestions: controller.categories.toList(),
                    helperText: 'Channels are grouped by category',
                  ),
                ),
                if (controller.isEditing) ...[
                  const SizedBox(height: 8),
                  Obx(
                    () => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      secondary: Icon(
                        controller.favorite.value
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: controller.favorite.value ? Colors.amber : null,
                      ),
                      title: const Text('Favorite'),
                      value: controller.favorite.value,
                      onChanged: (value) => controller.favorite.value = value,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Sources', style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Tried from top to bottom. When one fails, the next '
                  'one plays.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => _SourceList(
                    controller: controller,
                    urls: controller.urls.toList(),
                  ),
                ),
                const SizedBox(height: 8),
                Obx(
                  () => TextField(
                    controller: controller.newUrlText,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => controller.addUrl(),
                    decoration: InputDecoration(
                      labelText: 'Add a stream URL',
                      hintText: 'https://example.com/live.m3u8',
                      errorText: controller.urlError.value,
                      prefixIcon: const Icon(Icons.link),
                      suffixIcon: IconButton(
                        tooltip: 'Add source',
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: controller.addUrl,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SaveButton(
                  isSaving: controller.isSaving,
                  onPressed: controller.save,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete channel?',
      message:
          '"${controller.original!.name}" and all its sources will be removed.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      await controller.delete();
    }
  }
}

class _SourceList extends StatelessWidget {
  final ChannelEditorController controller;
  final List<String> urls;

  const _SourceList({required this.controller, required this.urls});

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) {
      return const SizedBox.shrink();
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < urls.length; i++)
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 12, child: Text('${i + 1}')),
              title: Text(
                urls[i],
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (i > 0)
                    IconButton(
                      tooltip: 'Move up',
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: () => controller.moveUp(i),
                    ),
                  IconButton(
                    tooltip: 'Remove source',
                    icon: const Icon(Icons.close),
                    onPressed: () => controller.removeUrl(i),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
