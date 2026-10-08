import 'package:flutter/material.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/widgets/favorite_button.dart';

enum _ChannelAction { edit, delete }

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

  const ChannelTile({
    super.key,
    required this.channel,
    required this.isPlaying,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
    this.showCategory = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sources = channel.urls.length;
    final details = [
      if (showCategory) categoryLabel(channel.category),
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
                  _ChannelAction.delete => onDelete(),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ChannelAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit sources'),
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
        ),
      ),
    );
  }

  static String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
