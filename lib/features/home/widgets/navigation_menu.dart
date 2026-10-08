import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/home/widgets/channel_actions.dart';
import 'package:tv/features/home/widgets/channel_tile.dart';

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
  final _sidebarScroll = ScrollController();
  final _panelScroll = ScrollController();

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
    _sidebarScroll.dispose();
    _panelScroll.dispose();
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
              Widget item(LibrarySection section) => _SidebarItem(
                section: section,
                count: controller.channelsIn(section).length,
                selected: section == selected,
                open: section == _open,
                onHover: () => _hoverItem(section),
                onTap: () => _clickItem(section),
              );
              Widget header(String text) => Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                child: Text(
                  text,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              );
              final fixed = sections.take(3);
              final custom = sections.where(
                (s) => s.kind == SectionKind.custom,
              );
              final categories = sections.where(
                (s) => s.kind == SectionKind.category,
              );
              return Scrollbar(
                controller: _sidebarScroll,
                thumbVisibility: true,
                interactive: true,
                child: ListView(
                  controller: _sidebarScroll,
                  padding: const EdgeInsets.fromLTRB(8, 0, 16, 8),
                  children: [
                    ...fixed.map(item),
                    if (custom.isNotEmpty) ...[
                      const Divider(height: 16),
                      header('My categories'),
                      ...custom.map(item),
                    ],
                    if (categories.isNotEmpty) ...[
                      const Divider(height: 16),
                      header('Categories'),
                      ...categories.map(item),
                    ],
                  ],
                ),
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
                  : Scrollbar(
                      controller: _panelScroll,
                      thumbVisibility: true,
                      interactive: true,
                      child: ListView.builder(
                        key: ValueKey(searching ? 'search' : section),
                        controller: _panelScroll,
                        padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
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
                            onTap: () => _play(channel),
                          );
                        },
                      ),
                    ),
            ),
          ],
        );
      }),
    );
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
