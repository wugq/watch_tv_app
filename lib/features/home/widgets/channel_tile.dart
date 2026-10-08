import 'package:flutter/material.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/widgets/favorite_button.dart';

enum _ChannelAction { edit, addToCategory, removeFromCategory, hide, delete }

/// One channel in a list: tap plays, star toggles favorite, menu edits or
/// deletes.
class ChannelTile extends StatelessWidget {
  final Channel channel;
  final bool isPlaying;
  final bool showCategory;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onAddToCategory;
  final VoidCallback? onHide;

  /// Shown in a custom category: removes the channel from it.
  final VoidCallback? onRemoveFromCategory;
  final String removeFromLabel;

  const ChannelTile({
    super.key,
    required this.channel,
    required this.isPlaying,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    this.onAddToCategory,
    this.onHide,
    this.onRemoveFromCategory,
    this.removeFromLabel = '',
    this.showCategory = true,
  });

  /// A tile with every line filled, for `ListView.prototypeItem`. Long
  /// lists need a fixed row height: without it, jumping far (dragging the
  /// scrollbar) lays out every row in between.
  static final prototype = ChannelTile(
    channel: Channel(
      key: 'prototype',
      name: 'Prototype',
      category: 'Category',
      urls: const ['http://example.com/a', 'http://example.com/b'],
    ),
    isPlaying: false,
    onTap: _noop,
    onToggleFavorite: _noop,
    onEdit: _noop,
    onDelete: _noop,
  );

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sources = channel.urls.length;
    final details = [
      if (showCategory) categoriesLabel(channel),
      if (sources > 1) '$sources sources',
    ].join(' · ');

    return Material(
      color: isPlaying ? scheme.primaryContainer : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 0, 6),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isPlaying
                    ? scheme.primary
                    : scheme.secondaryContainer,
                foregroundColor: isPlaying
                    ? scheme.onPrimary
                    : scheme.onSecondaryContainer,
                child: isPlaying
                    ? const Icon(Icons.graphic_eq, size: 18)
                    : Text(
                        _initial(channel.name),
                        style: const TextStyle(fontSize: 14),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isPlaying ? scheme.onPrimaryContainer : null,
                      ),
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isPlaying
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              FavoriteButton(
                favorite: channel.favorite,
                onPressed: onToggleFavorite,
              ),
              PopupMenuButton<_ChannelAction>(
                tooltip: 'More',
                onSelected: (action) => switch (action) {
                  _ChannelAction.edit => onEdit(),
                  _ChannelAction.addToCategory => onAddToCategory?.call(),
                  _ChannelAction.removeFromCategory =>
                    onRemoveFromCategory?.call(),
                  _ChannelAction.hide => onHide?.call(),
                  _ChannelAction.delete => onDelete(),
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _ChannelAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit sources'),
                    ),
                  ),
                  if (onAddToCategory != null)
                    const PopupMenuItem(
                      value: _ChannelAction.addToCategory,
                      child: ListTile(
                        leading: Icon(Icons.bookmark_add_outlined),
                        title: Text('Add to category…'),
                      ),
                    ),
                  if (onRemoveFromCategory != null)
                    PopupMenuItem(
                      value: _ChannelAction.removeFromCategory,
                      child: ListTile(
                        leading: const Icon(Icons.bookmark_remove_outlined),
                        title: Text('Remove from $removeFromLabel'),
                      ),
                    ),
                  if (onHide != null)
                    const PopupMenuItem(
                      value: _ChannelAction.hide,
                      child: ListTile(
                        leading: Icon(Icons.visibility_off_outlined),
                        title: Text('Hide'),
                      ),
                    ),
                  const PopupMenuItem(
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
        ),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
