import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/features/channel_editor/channel_editor_controller.dart';
import 'package:tv/features/channel_editor/widgets/category_field.dart';
import 'package:tv/features/channel_editor/widgets/save_button.dart';

/// Imports a TXT / M3U playlist from a file or a URL.
class ImportPlaylistForm extends StatelessWidget {
  final ChannelEditorController controller;

  const ImportPlaylistForm({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('From a file', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Obx(
          () => OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: controller.isLoadingPlaylist.value
                ? null
                : controller.pickFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Choose TXT or M3U file'),
          ),
        ),
        const SizedBox(height: 24),
        Text('From a URL', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        TextField(
          controller: controller.importUrlText,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => controller.downloadUrl(),
          decoration: InputDecoration(
            labelText: 'Playlist URL',
            hintText: 'https://example.com/tv.m3u',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: Obx(
              () => IconButton(
                tooltip: 'Download',
                onPressed: controller.isLoadingPlaylist.value
                    ? null
                    : controller.downloadUrl,
                icon: const Icon(Icons.download),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Obx(() {
          if (controller.isLoadingPlaylist.value) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final error = controller.importError.value;
          if (error != null) {
            return _Message(
              icon: Icons.error_outline,
              color: theme.colorScheme.error,
              text: error,
            );
          }
          final preview = controller.importPreview.value;
          if (preview == null) {
            return const SizedBox.shrink();
          }
          return _PreviewCard(controller: controller, preview: preview);
        }),
      ],
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final ChannelEditorController controller;
  final ImportPreview preview;

  const _PreviewCard({required this.controller, required this.preview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    preview.playlist.source,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: controller.clearImport,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Count(value: preview.channels.length, label: 'channels'),
                _Count(value: preview.sourceCount, label: 'sources'),
                _Count(value: preview.categoryCount, label: 'categories'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Channels that already exist get the new sources added.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => CategoryField(
                controller: controller.importCategoryText,
                suggestions: controller.categories.toList(),
                helperText: 'Used for channels without a category',
              ),
            ),
            const SizedBox(height: 16),
            SaveButton(
              isSaving: controller.isSaving,
              onPressed: controller.saveImport,
              label: 'Import ${preview.channels.length} channels',
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final int value;
  final String label;

  const _Count({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$value $label',
        style: TextStyle(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _Message({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}
