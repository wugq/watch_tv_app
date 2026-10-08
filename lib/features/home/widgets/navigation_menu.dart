import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/home/widgets/channel_tile.dart';
import 'package:tv/widgets/confirm_dialog.dart';

/// Two-level menu for wide screens, like a desktop start menu.
///
/// Level 1 is a sidebar with Favorites, Recently watched, All channels and
/// the categories. Pointing at an item opens level 2, a panel with its
/// channels, next to the sidebar. The panel closes when the pointer leaves
/// both. Clicking an item (or touch) keeps the panel open until it is
/// closed or a channel is chosen.
class NavigationMenu extends StatefulWidget {
  static const sidebarWidth = 264.0;
  static const panelWidth = 340.0;

  final HomeController controller;

  /// Called when the pointer leaves the whole menu, and after a channel was
  /// chosen. Used to hide the menu over the full screen player.
  final VoidCallback? onDone;

  const NavigationMenu({super.key, required this.controller, this.onDone});

  @override
  State<NavigationMenu> createState() => _NavigationMenuState();
}

class _NavigationMenuState extends State<NavigationMenu> {
  static const _openDelay = Duration(milliseconds: 120);
  static const _closeDelay = Duration(milliseconds: 350);

  final _search = TextEditingController();

  /// Section shown in the panel, or null when the panel is closed.
  LibrarySection? _open;

  /// Opened by a click: stays open when the pointer leaves.
  bool _pinned = false;

  Timer? _openTimer;
  Timer? _closeTimer;

  HomeController get controller => widget.controller;

  bool get _searching => _search.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _search.text = controller.query.value;
  }

  @override
  void dispose() {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _hoverItem(LibrarySection section) {
    _closeTimer?.cancel();
    if (_pinned && _open != null) {
      return;
    }
    _openTimer?.cancel();
    _openTimer = Timer(_openDelay, () {
      if (mounted) setState(() => _open = section);
    });
  }

  void _clickItem(LibrarySection section) {
    _openTimer?.cancel();
    _closeTimer?.cancel();
    controller.selectSection(section);
    _search.clear();
    setState(() {
      if (_open == section && _pinned) {
        _open = null;
        _pinned = false;
      } else {
        _open = section;
        _pinned = true;
      }
    });
  }

  void _leave() {
    _openTimer?.cancel();
    if (_pinned || _searching) {
      return;
    }
    _closeTimer?.cancel();
    _closeTimer = Timer(_closeDelay, () {
      if (!mounted) return;
      setState(() => _open = null);
      widget.onDone?.call();
    });
  }

  void _enterMenu() => _closeTimer?.cancel();

  void _closePanel() {
    _search.clear();
    controller.setQuery('');
    setState(() {
      _open = null;
      _pinned = false;
    });
  }

  void _play(Channel channel) {
    controller.play(channel);
    if (!_pinned && !_searching) {
      setState(() => _open = null);
    }
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final showPanel = _open != null || _searching;
    return MouseRegion(
      onEnter: (_) => _enterMenu(),
      onExit: (_) => _leave(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: NavigationMenu.sidebarWidth,
            child: _buildSidebar(context),
          ),
          if (showPanel)
            SizedBox(
              width: NavigationMenu.panelWidth,
              child: _buildPanel(context),
            ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: Border(right: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _search,
              onChanged: (value) {
                controller.setQuery(value);
                setState(() {});
              },
              decoration: InputDecoration(
                hintText: 'Search channels',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                suffixIcon: _searching
                    ? IconButton(
                        tooltip: 'Clear',
                        icon: const Icon(Icons.close),
                        onPressed: _closePanel,
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              final sections = controller.sections;
              final selected = controller.section.value;
              final fixed = sections.take(3).toList();
              final categories = sections.skip(3).toList();
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: [
                  for (final section in fixed)
                    _SidebarItem(
                      section: section,
                      count: controller.channelsIn(section).length,
                      selected: section == selected,
                      open: section == _open,
                      onHover: () => _hoverItem(section),
                      onTap: () => _clickItem(section),
                    ),
                  if (categories.isNotEmpty) ...[
                    const Divider(height: 16),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: Text(
                        'Categories',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    for (final section in categories)
                      _SidebarItem(
                        section: section,
                        count: controller.channelsIn(section).length,
                        selected: section == selected,
                        open: section == _open,
                        onHover: () => _hoverItem(section),
                        onTap: () => _clickItem(section),
                      ),
                  ],
                ],
              );
            }),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: controller.importPlaylist,
                    icon: const Icon(Icons.playlist_add),
                    label: const Text('Add playlist'),
                  ),
                ),
                IconButton(
                  tooltip: 'Manage library',
                  onPressed: controller.openManager,
                  icon: const Icon(Icons.video_library_outlined),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanel(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainer,
      shape: Border(right: BorderSide(color: theme.colorScheme.outlineVariant)),
      child: Obx(() {
        final searching = controller.query.value.trim().isNotEmpty;
        final section = _open ?? controller.section.value;
        final channels = searching
            ? controller.search(controller.query.value)
            : controller.channelsIn(section);
        final playingKey = controller.player.channel.value?.key;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 4, 4),
              child: Row(
                children: [
                  Icon(
                    searching ? Icons.search : section.icon,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      searching
                          ? 'Results for "${controller.query.value.trim()}"'
                          : section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${channels.length}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: _closePanel,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: channels.isEmpty
                  ? _PanelEmpty(section: section, searching: searching)
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: channels.length,
                      itemBuilder: (context, index) {
                        final channel = channels[index];
                        return ChannelTile(
                          key: ValueKey(channel.key),
                          channel: channel,
                          isPlaying: channel.key == playingKey,
                          showCategory:
                              searching || section.kind != SectionKind.category,
                          onTap: () => _play(channel),
                          onToggleFavorite: () =>
                              controller.toggleFavorite(channel),
                          onEdit: () => controller.editChannel(channel),
                          onDelete: () => _delete(context, channel),
                        );
                      },
                    ),
            ),
          ],
        );
      }),
    );
  }

  Future<void> _delete(BuildContext context, Channel channel) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete channel?',
      message: '"${channel.name}" and all its sources will be removed.',
      confirmLabel: 'Delete',
    );
    if (confirmed) {
      await controller.deleteChannel(channel);
    }
  }
}

class _SidebarItem extends StatelessWidget {
  final LibrarySection section;
  final int count;
  final bool selected;
  final bool open;
  final VoidCallback onHover;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.section,
    required this.count,
    required this.selected,
    required this.open,
    required this.onHover,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlighted = open || selected;
    return MouseRegion(
      onEnter: (_) => onHover(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: Material(
          color: open
              ? scheme.secondaryContainer
              : selected
              ? scheme.secondaryContainer.withValues(alpha: 0.5)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    section.icon,
                    size: 20,
                    color: section.kind == SectionKind.favorites
                        ? Colors.amber
                        : highlighted
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      section.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: highlighted
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                  Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelMedium
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  final LibrarySection section;
  final bool searching;

  const _PanelEmpty({required this.section, required this.searching});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, text) = searching
        ? (Icons.search_off, 'No channel matches the search.')
        : switch (section.kind) {
            SectionKind.favorites => (
              Icons.star_outline_rounded,
              'Tap the star next to a channel to add it here.',
            ),
            SectionKind.recent => (
              Icons.history,
              'Channels you watch appear here.',
            ),
            _ => (Icons.live_tv_outlined, 'No channels.'),
          };
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(
              text,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
