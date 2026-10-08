import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/models/playlist.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/manage/manage_controller.dart';
import 'package:tv/widgets/confirm_dialog.dart';
import 'package:tv/widgets/favorite_button.dart';

class ManagePage extends GetView<ManageController> {
  const ManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Builder(
        builder: (context) {
          final tabs = DefaultTabController.of(context);
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
                        bottom: const TabBar(
                          tabs: [
                            Tab(text: 'Playlists'),
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
                        children: [
                          _PlaylistsTab(controller: controller),
                          _ChannelsTab(controller: controller),
                        ],
                      ),
                floatingActionButton: controller.isSelecting
                    ? null
                    : AnimatedBuilder(
                        animation: tabs,
                        builder: (context, _) => tabs.index == 0
                            ? FloatingActionButton.extended(
                                heroTag: null,
                                onPressed: controller.addPlaylist,
                                icon: const Icon(Icons.playlist_add),
                                label: const Text('Add playlist'),
                              )
                            : FloatingActionButton.extended(
                                heroTag: null,
                                onPressed: controller.addChannel,
                                icon: const Icon(Icons.add),
                                label: const Text('Add channel'),
                              ),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _selectionBar(BuildContext context) {
    final count = controller.selected.length;
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
          tooltip: 'Delete selected',
          icon: const Icon(Icons.delete_outline),
          onPressed: () async {
            final confirmed = await showConfirmDialog(
              context,
              title: count == 1
                  ? 'Delete 1 channel?'
                  : 'Delete $count channels?',
              message: 'The channels and all their sources will be removed.',
              confirmLabel: 'Delete',
            );
            if (confirmed) await controller.deleteSelected();
          },
        ),
      ],
    );
  }
}

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
    final text = TextEditingController(text: playlist.name);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename playlist'),
        content: TextField(
          controller: text,
          autofocus: true,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(text.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    text.dispose();
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

class _ChannelsTab extends StatelessWidget {
  final ManageController controller;

  const _ChannelsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            onChanged: (value) => controller.query.value = value,
            decoration: const InputDecoration(
              hintText: 'Search channels',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Long-press to select several channels.',
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
            final selecting = controller.isSelecting;
            final selected = controller.selected.toSet();
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: channels.length,
              itemBuilder: (context, index) => _ChannelRow(
                channel: channels[index],
                selecting: selecting,
                selected: selected.contains(channels[index].key),
                controller: controller,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final Channel channel;
  final bool selecting;
  final bool selected;
  final ManageController controller;

  const _ChannelRow({
    required this.channel,
    required this.selecting,
    required this.selected,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final sources = channel.urls.length;
    return ListTile(
      selected: selected,
      leading: selecting
          ? Checkbox(
              value: selected,
              onChanged: (_) => controller.toggleSelected(channel),
            )
          : null,
      title: Text(channel.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${categoryLabel(channel.category)} · '
        '${sources == 1 ? '1 source' : '$sources sources'}',
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
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Delete channel?',
                      message:
                          '"${channel.name}" and all its sources will be removed.',
                      confirmLabel: 'Delete',
                    );
                    if (confirmed) await controller.deleteChannel(channel);
                  },
                ),
              ],
            ),
    );
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

String formatDateTime(DateTime time) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${time.year}-${two(time.month)}-${two(time.day)} '
      '${two(time.hour)}:${two(time.minute)}';
}
