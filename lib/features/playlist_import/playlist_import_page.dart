import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/playlist_import/playlist_import_controller.dart';
import 'package:tv/widgets/category_field.dart';
import 'package:tv/widgets/save_button.dart';

class PlaylistImportPage extends GetView<PlaylistImportController> {
  static const _pasteExample =
      '#EXTM3U\n'
      '#EXTINF:-1 group-title="News",Channel A\n'
      'https://example.com/a.m3u8\n\n'
      'or TXT:\n'
      'News,#genre#\n'
      'Channel A,https://example.com/a.m3u8';

  const PlaylistImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add playlist')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Obx(
                () => SegmentedButton<ImportMode>(
                  segments: const [
                    ButtonSegment(
                      value: ImportMode.url,
                      icon: Icon(Icons.link),
                      label: Text('URL'),
                    ),
                    ButtonSegment(
                      value: ImportMode.file,
                      icon: Icon(Icons.folder_open),
                      label: Text('File'),
                    ),
                    ButtonSegment(
                      value: ImportMode.text,
                      icon: Icon(Icons.content_paste),
                      label: Text('Paste'),
                    ),
                  ],
                  selected: {controller.mode.value},
                  onSelectionChanged: (value) =>
                      controller.setMode(value.single),
                ),
              ),
              const SizedBox(height: 16),
              Obx(() => _input(context, controller.mode.value)),
              const SizedBox(height: 16),
              Obx(() {
                if (controller.isLoading.value) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final error = controller.error.value;
                if (error != null) {
                  return _ErrorText(error);
                }
                final preview = controller.preview.value;
                if (preview == null) {
                  return const _FormatHelp();
                }
                return _PreviewCard(controller: controller, preview: preview);
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _input(BuildContext context, ImportMode mode) {
    switch (mode) {
      case ImportMode.url:
        return TextField(
          controller: controller.urlText,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => controller.downloadUrl(),
          decoration: InputDecoration(
            labelText: 'Playlist URL',
            hintText: 'https://example.com/tv.m3u',
            helperText: 'URL playlists can be refreshed later',
            prefixIcon: const Icon(Icons.link),
            suffixIcon: IconButton(
              tooltip: 'Download',
              onPressed: controller.downloadUrl,
              icon: const Icon(Icons.download),
            ),
          ),
        );
      case ImportMode.file:
        return OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
          ),
          onPressed: controller.pickFile,
          icon: const Icon(Icons.folder_open),
          label: const Text('Choose an M3U or TXT file'),
        );
      case ImportMode.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: controller.pasteText,
              keyboardType: TextInputType.multiline,
              autocorrect: false,
              minLines: 8,
              maxLines: 16,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: const InputDecoration(
                hintText: _pasteExample,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: controller.parseText,
                icon: const Icon(Icons.checklist),
                label: const Text('Check list'),
              ),
            ),
          ],
        );
    }
  }
}

class _PreviewCard extends StatelessWidget {
  final PlaylistImportController controller;
  final ImportPreview preview;

  const _PreviewCard({required this.controller, required this.preview});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories = preview.categories;
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
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Count('${preview.channels.length} channels'),
                _Count('${preview.sourceCount} sources'),
                _Count('${categories.length} categories'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              categories.take(8).map(categoryLabel).join(' · ') +
                  (categories.length > 8 ? ' …' : ''),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller.nameText,
              decoration: const InputDecoration(
                labelText: 'Playlist name',
                prefixIcon: Icon(Icons.playlist_play),
              ),
            ),
            const SizedBox(height: 16),
            Obx(
              () => CategoryField(
                controller: controller.categoryText,
                suggestions: controller.categories.toList(),
                helperText: 'Used for channels without a category',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Channels that already exist get the new sources added.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SaveButton(
              isSaving: controller.isSaving,
              onPressed: controller.save,
              label: 'Add ${preview.channels.length} channels',
            ),
            Obx(() {
              final error = controller.saveError.value;
              return error == null
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: _ErrorText(error),
                    );
            }),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  final String text;

  const _Count(this.text);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer)),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;

  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.error;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
  }
}

class _FormatHelp extends StatelessWidget {
  const _FormatHelp();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'M3U playlists use group-title as the category. '
                'TXT lists use "Name,URL" lines, and a "Category,#genre#" '
                'line starts a new category. Lines with the same channel '
                'name become one channel with several sources.',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
