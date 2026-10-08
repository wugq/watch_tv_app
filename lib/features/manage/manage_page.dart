import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/models/custom_category.dart';
import 'package:tv/data/models/playlist.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/manage/manage_controller.dart';
import 'package:tv/widgets/confirm_dialog.dart';
import 'package:tv/widgets/custom_category_picker.dart';
import 'package:tv/widgets/favorite_button.dart';

/// Library: playlists, categories and channels.
class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage>
    with SingleTickerProviderStateMixin {
  static const _channelsTab = 2;

  final controller = Get.find<ManageController>();
  late final _tabs = TabController(length: 3, vsync: this)
    ..addListener(() => setState(() {}));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _showChannelsOf(ChannelFilter filter) {
    controller.showChannelsOf(filter);
    _tabs.animateTo(_channelsTab);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => PopScope(
        canPop: !controller.isSelecting,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) controller.clearSelection();
        },
        child: Scaffold(
          appBar: controller.isSelecting
              ? _selectionBar(context)
              : AppBar(
                  title: const Text('Library'),
                  bottom: TabBar(
                    controller: _tabs,
                    tabs: const [
                      Tab(text: 'Playlists'),
                      Tab(text: 'Categories'),
                      Tab(text: 'Channels'),
                    ],
                  ),
                ),
          body:
              controller.isLoading.value &&
                  controller.channels.isEmpty &&
                  controller.playlists.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabs,
                  children: [
                    _PlaylistsTab(controller: controller),
                    _CategoriesTab(
                      controller: controller,
                      onShowChannels: _showChannelsOf,
                    ),
                    _ChannelsTab(controller: controller),
                  ],
                ),
          floatingActionButton: controller.isSelecting ? null : _fab(context),
        ),
      ),
    );
  }

  Widget _fab(BuildContext context) {
    return switch (_tabs.index) {
      0 => FloatingActionButton.extended(
        heroTag: null,
        onPressed: controller.addPlaylist,
        icon: const Icon(Icons.playlist_add),
        label: const Text('Add playlist'),
      ),
      1 => FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => _newCategory(context),
        icon: const Icon(Icons.bookmark_add_outlined),
        label: const Text('New category'),
      ),
      _ => FloatingActionButton.extended(
        heroTag: null,
        onPressed: controller.addChannel,
        icon: const Icon(Icons.add),
        label: const Text('Add channel'),
      ),
    };
  }

  Future<void> _newCategory(BuildContext context) async {
    final name = await showTextDialog(
      context,
      title: 'New category',
      label: 'Name',
      confirmLabel: 'Create',
    );
    if (name != null && name.trim().isNotEmpty) {
      await controller.createCustomCategory(name);
    }
  }

  PreferredSizeWidget _selectionBar(BuildContext context) {
    final count = controller.selected.length;
    final filter = controller.filter.value;
    return AppBar(
      leading: IconButton(
        tooltip: 'Cancel selection',
        icon: const Icon(Icons.close),
        onPressed: controller.clearSelection,
      ),
      title: Text('$count selected'),
      actions: [
        IconButton(
          tooltip: 'Select all',
          icon: const Icon(Icons.select_all),
          onPressed: controller.selectAllVisible,
        ),
        IconButton(
          tooltip: 'Show selected',
          icon: const Icon(Icons.visibility_outlined),
          onPressed: () => controller.setSelectedHidden(false),
        ),
        IconButton(
          tooltip: 'Hide selected',
          icon: const Icon(Icons.visibility_off_outlined),
          onPressed: () => controller.setSelectedHidden(true),
        ),
        IconButton(
          tooltip: 'Add to category',
          icon: const Icon(Icons.bookmark_add_outlined),
          onPressed: () async {
            final choice = await showCustomCategoryPicker(
              context,
              controller.customCategories.toList(),
              title: 'Add $count channels to',
            );
            if (choice != null) {
              await controller.addSelectedToCategory(
                id: choice.id,
                newName: choice.newName,
              );
            }
          },
        ),
        if (filter.kind == FilterKind.custom)
          IconButton(
            tooltip: 'Remove from ${controller.filterLabel(filter)}',
            icon: const Icon(Icons.bookmark_remove_outlined),
            onPressed: () =>
                controller.removeSelectedFromCategory(filter.customId!),
          ),
        IconButton(
          tooltip: 'Delete selected',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: count == 1
                  ? 'Delete 1 channel?'
                  : 'Delete $count channels?',
              message:
                  'The channels and all their sources will be removed. To '
                  'only stop seeing them, hide them instead.',
              confirmLabel: 'Delete',
            );
            if (confirmed) await controller.deleteSelected();
          },
        ),
      ],
    );
  }
}

// Playlists

class _PlaylistsTab extends StatelessWidget {
  final ManageController controller;

  const _PlaylistsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final playlists = controller.playlists;
      if (playlists.isEmpty) {
        return _Empty(
          icon: Icons.playlist_play,
          title: 'No playlists',
          text:
              'Add an M3U playlist from a URL or a file. URL playlists can '
              'be refreshed later.',
          action: FilledButton.icon(
            onPressed: controller.addPlaylist,
            icon: const Icon(Icons.playlist_add),
            label: const Text('Add playlist'),
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: playlists.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) =>
            _PlaylistCard(controller: controller, playlist: playlists[index]),
      );
    });
  }
}

enum _PlaylistAction { rename, delete }

class _PlaylistCard extends StatelessWidget {
  final ManageController controller;
  final Playlist playlist;

  const _PlaylistCard({required this.controller, required this.playlist});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          children: [
            Icon(
              playlist.canRefresh
                  ? Icons.cloud_outlined
                  : Icons.description_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(playlist.name, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    '${playlist.channelCount} channels · '
                    '${playlist.sourceCount} sources · '
                    'updated ${formatDateTime(playlist.updatedAt)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (playlist.url != null)
                    Text(
                      playlist.url!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (playlist.canRefresh)
              Obx(
                () => controller.refreshingId.value == playlist.id
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Refresh',
                        icon: const Icon(Icons.refresh),
                        onPressed: () => controller.refreshPlaylist(playlist),
                      ),
              ),
            PopupMenuButton<_PlaylistAction>(
              tooltip: 'More',
              onSelected: (action) => switch (action) {
                _PlaylistAction.rename => _rename(context),
                _PlaylistAction.delete => _delete(context),
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _PlaylistAction.rename,
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Rename'),
                  ),
                ),
                PopupMenuItem(
                  value: _PlaylistAction.delete,
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context) async {
    final name = await showTextDialog(
      context,
      title: 'Rename playlist',
      label: 'Name',
      initial: playlist.name,
      confirmLabel: 'Rename',
    );
    if (name != null) {
      await controller.renamePlaylist(playlist, name);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${playlist.name}?',
      message:
          'Its ${playlist.sourceCount} sources are removed. Channels '
          'without other sources are deleted too.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      await controller.deletePlaylist(playlist);
    }
  }
}

// Categories

class _CategoriesTab extends StatelessWidget {
  final ManageController controller;
  final ValueChanged<ChannelFilter> onShowChannels;

  const _CategoriesTab({
    required this.controller,
    required this.onShowChannels,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Obx(() {
      final custom = controller.customCategories.toList();
      final infos = controller.categoryInfos;
      final shown = infos.where((c) => !c.hidden).length;
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _SectionHeader(
            title: 'My categories',
            text:
                'Pick channels yourself: select channels in the Channels '
                'tab, or use "Add to category" in a channel menu.',
          ),
          if (custom.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('No categories yet.'),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final category in custom)
                    _CustomCategoryTile(
                      controller: controller,
                      category: category,
                      onOpen: () =>
                          onShowChannels(ChannelFilter.custom(category.id)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          _SectionHeader(
            title: 'Playlist categories',
            text:
                'Turn off the categories you do not watch. Their channels '
                'are not shown when browsing, but stay in Favorites and in '
                'your own categories.',
          ),
          if (infos.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$shown of ${infos.length} shown',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed: () => controller.setAllCategoriesVisible(true),
                    child: const Text('Show all'),
                  ),
                  TextButton(
                    onPressed: () => controller.setAllCategoriesVisible(false),
                    child: const Text('Hide all'),
                  ),
                ],
              ),
            ),
          Card(
            child: Column(
              children: [
                for (final info in infos)
                  ListTile(
                    leading: Icon(
                      Icons.folder_outlined,
                      color: info.hidden
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                    ),
                    title: Text(categoryLabel(info.name)),
                    subtitle: Text('${info.channelCount} channels'),
                    onTap: () =>
                        onShowChannels(ChannelFilter.category(info.name)),
                    trailing: Switch(
                      value: !info.hidden,
                      onChanged: (value) =>
                          controller.setCategoryVisible(info.name, value),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

enum _CustomAction { rename, delete }

class _CustomCategoryTile extends StatelessWidget {
  final ManageController controller;
  final CustomCategory category;
  final VoidCallback onOpen;

  const _CustomCategoryTile({
    required this.controller,
    required this.category,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.bookmark_outline,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: Text(category.name),
      subtitle: Text('${category.channelKeys.length} channels'),
      onTap: onOpen,
      trailing: PopupMenuButton<_CustomAction>(
        tooltip: 'More',
        onSelected: (action) async {
          switch (action) {
            case _CustomAction.rename:
              final name = await showTextDialog(
                context,
                title: 'Rename category',
                label: 'Name',
                initial: category.name,
                confirmLabel: 'Rename',
              );
              if (name != null) {
                await controller.renameCustomCategory(category, name);
              }
            case _CustomAction.delete:
              final confirmed = await showConfirmDialog(
                context,
                title: 'Delete ${category.name}?',
                message: 'Only the category is deleted, not its channels.',
                confirmLabel: 'Delete',
              );
              if (confirmed) await controller.deleteCustomCategory(category);
          }
        },
        itemBuilder: (context) => const [
          PopupMenuItem(
            value: _CustomAction.rename,
            child: ListTile(
              leading: Icon(Icons.edit_outlined),
              title: Text('Rename'),
            ),
          ),
          PopupMenuItem(
            value: _CustomAction.delete,
            child: ListTile(
              leading: Icon(Icons.delete_outline),
              title: Text('Delete'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String text;

  const _SectionHeader({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// Channels

class _ChannelsTab extends StatefulWidget {
  final ManageController controller;

  const _ChannelsTab({required this.controller});

  @override
  State<_ChannelsTab> createState() => _ChannelsTabState();
}

class _ChannelsTabState extends State<_ChannelsTab> {
  final _scroll = ScrollController();
  late final _search = TextEditingController(
    text: widget.controller.query.value,
  );

  ManageController get controller => widget.controller;

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Wrap(
            alignment: WrapAlignment.start,
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: TextField(
                  controller: _search,
                  onChanged: (value) => controller.query.value = value,
                  decoration: const InputDecoration(
                    hintText: 'Search channels',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              _FilterMenu(controller: controller),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Tap the eye to show or hide a channel. Long-press to select '
              'several.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ),
        Expanded(
          child: Obx(() {
            final channels = controller.visibleChannels;
            if (controller.channels.isEmpty) {
              return const _Empty(
                icon: Icons.live_tv_outlined,
                title: 'No channels',
                text: 'Add a playlist or a single channel.',
              );
            }
            if (channels.isEmpty) {
              return const _Empty(
                icon: Icons.filter_alt_off_outlined,
                title: 'Nothing here',
                text: 'No channel matches the filter.',
              );
            }
            final selecting = controller.isSelecting;
            final selected = controller.selected.toSet();
            return Scrollbar(
              controller: _scroll,
              thumbVisibility: true,
              interactive: true,
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.only(bottom: 96),
                // Fixed row height: jumping far (dragging the scrollbar
                // through thousands of channels) stays instant.
                prototypeItem: _ChannelRow(
                  channel: _ChannelRow.prototypeChannel,
                  selecting: selecting,
                  selected: false,
                  controller: controller,
                ),
                itemCount: channels.length,
                itemBuilder: (context, index) => _ChannelRow(
                  channel: channels[index],
                  selecting: selecting,
                  selected: selected.contains(channels[index].key),
                  controller: controller,
                ),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _FilterMenu extends StatelessWidget {
  final ManageController controller;

  const _FilterMenu({required this.controller});

  @override
  Widget build(BuildContext context) => Obx(() => _build(context));

  Widget _build(BuildContext context) {
    final current = controller.filter.value;
    final filters = [
      ChannelFilter.all,
      ChannelFilter.hidden,
      for (final custom in controller.customCategories)
        ChannelFilter.custom(custom.id),
      for (final info in controller.categoryInfos)
        ChannelFilter.category(info.name),
    ];
    return MenuAnchor(
      menuChildren: [
        for (final filter in filters)
          MenuItemButton(
            leadingIcon: Icon(switch (filter.kind) {
              FilterKind.all => Icons.apps,
              FilterKind.hidden => Icons.visibility_off_outlined,
              FilterKind.custom => Icons.bookmark_outline,
              FilterKind.category => Icons.folder_outlined,
            }),
            trailingIcon: filter == current ? const Icon(Icons.check) : null,
            onPressed: () => controller.showChannelsOf(filter),
            child: Text(controller.filterLabel(filter)),
          ),
      ],
      builder: (context, menu, _) => OutlinedButton.icon(
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
        icon: const Icon(Icons.filter_list),
        label: Text(controller.filterLabel(current)),
      ),
    );
  }
}

enum _ChannelAction { edit, addToCategory, delete }

class _ChannelRow extends StatelessWidget {
  final Channel channel;
  final bool selecting;
  final bool selected;
  final ManageController controller;

  static final prototypeChannel = Channel(
    key: 'prototype',
    name: 'Prototype',
    category: 'Category',
    urls: const ['http://example.com/a'],
  );

  const _ChannelRow({
    required this.channel,
    required this.selecting,
    required this.selected,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sources = channel.urls.length;
    final muted = theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6);
    return ListTile(
      selected: selected,
      leading: selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => controller.toggleSelected(channel),
            )
          : IconButton(
              tooltip: channel.hidden ? 'Show channel' : 'Hide channel',
              onPressed: () =>
                  controller.setHidden([channel.key], !channel.hidden),
              icon: Icon(
                channel.hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: channel.hidden ? muted : theme.colorScheme.primary,
              ),
            ),
      title: Text(
        channel.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: channel.hidden ? TextStyle(color: muted) : null,
      ),
      subtitle: Text(
        [
          categoriesLabel(channel),
          sources == 1 ? '1 source' : '$sources sources',
          if (channel.hidden) 'hidden',
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: selecting
          ? () => controller.toggleSelected(channel)
          : () => controller.editChannel(channel),
      onLongPress: () => controller.toggleSelected(channel),
      trailing: selecting
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FavoriteButton(
                  favorite: channel.favorite,
                  onPressed: () => controller.toggleFavorite(channel),
                ),
                PopupMenuButton<_ChannelAction>(
                  tooltip: 'More',
                  onSelected: (action) => _onAction(context, action),
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: _ChannelAction.edit,
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit sources'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ChannelAction.addToCategory,
                      child: ListTile(
                        leading: Icon(Icons.bookmark_add_outlined),
                        title: Text('Add to category…'),
                      ),
                    ),
                    PopupMenuItem(
                      value: _ChannelAction.delete,
                      child: ListTile(
                        leading: Icon(Icons.delete_outline),
                        title: Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Future<void> _onAction(BuildContext context, _ChannelAction action) async {
    switch (action) {
      case _ChannelAction.edit:
        await controller.editChannel(channel);
      case _ChannelAction.addToCategory:
        final choice = await showCustomCategoryPicker(
          context,
          controller.customCategories.toList(),
        );
        if (choice != null) {
          controller.selected
            ..clear()
            ..add(channel.key);
          await controller.addSelectedToCategory(
            id: choice.id,
            newName: choice.newName,
          );
        }
      case _ChannelAction.delete:
        final confirmed = await showConfirmDialog(
          context,
          title: 'Delete channel?',
          message:
              '"${channel.name}" and all its sources will be removed. To '
              'only stop seeing it, hide it instead.',
          confirmLabel: 'Delete',
        );
        if (confirmed) await controller.deleteChannel(channel);
    }
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  const _Empty({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Asks for a short text such as a name.
Future<String?> showTextDialog(
  BuildContext context, {
  required String title,
  required String label,
  required String confirmLabel,
  String? initial,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextDialog(
      title: title,
      label: label,
      confirmLabel: confirmLabel,
      initial: initial,
    ),
  );
}

class _TextDialog extends StatefulWidget {
  final String title;
  final String label;
  final String confirmLabel;
  final String? initial;

  const _TextDialog({
    required this.title,
    required this.label,
    required this.confirmLabel,
    this.initial,
  });

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _text = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _text,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_text.text),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

String formatDateTime(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
