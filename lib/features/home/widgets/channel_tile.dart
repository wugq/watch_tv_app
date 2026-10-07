import 'package:flutter/material.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/widgets/category_label.dart';

enum _ChannelAction { edit, delete }

class ChannelTile extends StatelessWidget {
  final Channel channel;
  final bool isPlaying;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ChannelTile({
    super.key,
    required this.channel,
    required this.isPlaying,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final foreground = isPlaying ? scheme.onPrimaryContainer : scheme.onSurface;

    return Card(
      color: isPlaying ? scheme.primaryContainer : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onEdit,
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isPlaying
                    ? scheme.primary
                    : scheme.secondaryContainer,
                foregroundColor: isPlaying
                    ? scheme.onPrimary
                    : scheme.onSecondaryContainer,
                child: isPlaying
                    ? const Icon(Icons.graphic_eq, size: 20)
                    : Text(_initial(channel.name)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      channel.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: foreground,
                      ),
                    ),
                    Text(
                      channel.urls.length > 1
                          ? '${categoryLabel(channel.category)} · '
                                '${channel.urls.length} sources'
                          : categoryLabel(channel.category),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: foreground.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_ChannelAction>(
                tooltip: 'More',
                iconColor: foreground,
                onSelected: (action) => switch (action) {
                  _ChannelAction.edit => onEdit(),
                  _ChannelAction.delete => onDelete(),
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _ChannelAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
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
