import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/widgets/category_bar.dart';
import 'package:tv/features/home/widgets/channel_tile.dart';

/// Category filter and the channel list below it.
class ChannelBrowser extends StatelessWidget {
  final HomeController controller;

  const ChannelBrowser({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.channels.isEmpty) {
        return _EmptyState(onAdd: controller.addChannels);
      }
      final categories = controller.categories;
      final channels = controller.visibleChannels;
      final playingKey = controller.player.channel.value?.key;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (categories.length > 1)
            CategoryBar(
              categories: categories,
              selected: controller.selectedCategory.value,
              onSelected: controller.selectCategory,
            ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 360,
                mainAxisExtent: 64,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: channels.length,
              itemBuilder: (context, index) {
                final channel = channels[index];
                return ChannelTile(
                  key: ValueKey(channel.key),
                  channel: channel,
                  isPlaying: channel.key == playingKey,
                  onTap: () => controller.play(channel),
                  onEdit: () => controller.editChannel(channel),
                  onDelete: () => _confirmDelete(context, channel),
                );
              },
            ),
          ),
        ],
      );
    });
  }

  Future<void> _confirmDelete(BuildContext context, Channel channel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete channel?'),
        content: Text('"${channel.name}" will be removed from your list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed ?? false) {
      await controller.deleteChannel(channel);
    }
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.live_tv_outlined,
              size: 64,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text('No channels yet', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Add a stream URL, or paste a channel list or M3U playlist.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add channels'),
            ),
          ],
        ),
      ),
    );
  }
}
