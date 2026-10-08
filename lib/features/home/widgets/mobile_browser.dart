import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/home/widgets/channel_actions.dart';
import 'package:tv/features/home/widgets/channel_tile.dart';

/// Channel browser for narrow screens: a row of section chips (level 1)
/// above the channel list (level 2). The grid button opens all categories
/// in a sheet.
class MobileBrowser extends StatelessWidget {
  final HomeController controller;

  const MobileBrowser({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.channels.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }
      if (controller.channels.isEmpty) {
        return EmptyLibrary(controller: controller);
      }
      final searching = controller.query.value.trim().isNotEmpty;
      final section = controller.section.value;
      final channels = controller.visibleChannels;
      final playingKey = controller.player.channel.value?.key;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!searching) _SectionChips(controller: controller),
          Expanded(
            child: channels.isEmpty
                ? _EmptySection(section: section, searching: searching)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                    prototypeItem: ChannelTile.prototype,
                    itemCount: channels.length,
                    itemBuilder: (context, index) {
                      final channel = channels[index];
                      return homeChannelTile(
                        context,
                        controller,
                        channel,
                        section: section,
                        searching: searching,
                        isPlaying: channel.key == playingKey,
                        onTap: () => controller.play(channel),
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

class _SectionChips extends StatelessWidget {
  final HomeController controller;

  const _SectionChips({required this.controller});

  @override
  Widget build(BuildContext context) {
    final sections = controller.sections;
    final selected = controller.section.value;
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: IconButton(
              tooltip: 'All categories',
              icon: const Icon(Icons.grid_view_rounded),
              onPressed: () => _showCategories(context),
            ),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
              itemCount: sections.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final section = sections[index];
                return ChoiceChip(
                  avatar: section.kind != SectionKind.category
                      ? Icon(
                          section.icon,
                          size: 18,
                          color: section.kind == SectionKind.favorites
                              ? Colors.amber
                              : null,
                        )
                      : null,
                  label: Text(section.shortLabel),
                  selected: section == selected,
                  showCheckmark: false,
                  onSelected: (_) => controller.selectSection(section),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showCategories(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) {
          final theme = Theme.of(context);
          final sections = controller.sections;
          return ListView(
            controller: scroll,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Text('Browse', style: theme.textTheme.titleLarge),
              ),
              for (final section in sections)
                ListTile(
                  leading: Icon(
                    section.icon,
                    color: section.kind == SectionKind.favorites
                        ? Colors.amber
                        : null,
                  ),
                  title: Text(section.label),
                  trailing: Text('${controller.channelsIn(section).length}'),
                  selected: section == controller.section.value,
                  onTap: () {
                    controller.selectSection(section);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptySection extends StatelessWidget {
  final LibrarySection section;
  final bool searching;

  const _EmptySection({required this.section, required this.searching});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = searching
        ? 'No channel matches the search.'
        : switch (section.kind) {
            SectionKind.favorites =>
              'Tap the star next to a channel to add it to your favorites.',
            SectionKind.recent => 'Channels you watch appear here.',
            _ => 'No channels.',
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Shown when there are no channels at all.
class EmptyLibrary extends StatelessWidget {
  final HomeController controller;

  const EmptyLibrary({super.key, required this.controller});

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
              'Add an M3U playlist from a URL or a file.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: controller.importPlaylist,
              icon: const Icon(Icons.playlist_add),
              label: const Text('Add playlist'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: controller.addChannel,
              child: const Text('Add a single channel'),
            ),
          ],
        ),
      ),
    );
  }
}
