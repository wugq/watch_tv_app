import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
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
                    sources: controller.sources.toList(),
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
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: const Text('HTTP headers for the new URL'),
                  subtitle: const Text(
                    'Only needed when the server checks them',
                  ),
                  children: [
                    _HeaderFields(
                      userAgent: controller.newUserAgentText,
                      referrer: controller.newReferrerText,
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
                const SizedBox(height: 16),
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
  final List<StreamSource> sources;

  const _SourceList({required this.controller, required this.sources});

  @override
  Widget build(BuildContext context) {
    if (sources.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < sources.length; i++)
            ListTile(
              dense: true,
              leading: CircleAvatar(radius: 12, child: Text('${i + 1}')),
              title: Text(
                sources[i].url,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: sources[i].hasHeaders
                  ? Text(
                      [
                        if (sources[i].userAgent != null)
                          'User-Agent: ${sources[i].userAgent}',
                        if (sources[i].referrer != null)
                          'Referrer: ${sources[i].referrer}',
                      ].join('\n'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    )
                  : null,
              onTap: () => _edit(context, i),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Edit source',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _edit(context, i),
                  ),
                  if (i > 0)
                    IconButton(
                      tooltip: 'Move up',
                      icon: const Icon(Icons.arrow_upward),
                      onPressed: () => controller.moveUp(i),
                    ),
                  IconButton(
                    tooltip: 'Remove source',
                    icon: const Icon(Icons.close),
                    onPressed: () => controller.removeSource(i),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, int index) async {
    final updated = await showDialog<StreamSource>(
      context: context,
      builder: (context) => _SourceDialog(source: sources[index]),
    );
    if (updated != null) {
      controller.replaceSource(index, updated);
    }
  }
}

class _SourceDialog extends StatefulWidget {
  final StreamSource source;

  const _SourceDialog({required this.source});

  @override
  State<_SourceDialog> createState() => _SourceDialogState();
}

class _SourceDialogState extends State<_SourceDialog> {
  late final _url = TextEditingController(text: widget.source.url);
  late final _userAgent = TextEditingController(text: widget.source.userAgent);
  late final _referrer = TextEditingController(text: widget.source.referrer);
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _userAgent.dispose();
    _referrer.dispose();
    super.dispose();
  }

  void _submit() {
    final value = ChannelEditorController.validSource(
      _url.text,
      userAgent: _userAgent.text,
      referrer: _referrer.text,
    );
    if (value == null) {
      setState(() => _error = ChannelEditorController.invalidUrlMessage);
    } else {
      Navigator.of(context).pop(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit source'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Stream URL',
                  errorText: _error,
                ),
              ),
              const SizedBox(height: 12),
              _HeaderFields(userAgent: _userAgent, referrer: _referrer),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}

class _HeaderFields extends StatelessWidget {
  final TextEditingController userAgent;
  final TextEditingController referrer;

  const _HeaderFields({required this.userAgent, required this.referrer});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: userAgent,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'User-Agent (optional)',
            hintText: 'Mozilla/5.0 ...',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: referrer,
          autocorrect: false,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'Referrer (optional)',
            hintText: 'https://example.com/',
          ),
        ),
      ],
    );
  }
}
