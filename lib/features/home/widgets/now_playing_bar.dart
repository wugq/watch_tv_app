import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/widgets/favorite_button.dart';
import 'package:tv/features/player/player_controller.dart';

class NowPlayingBar extends StatelessWidget {
  final PlayerController player;
  final ValueChanged<Channel> onToggleFavorite;

  const NowPlayingBar({
    super.key,
    required this.player,
    required this.onToggleFavorite,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Obx(() {
        final channel = player.channel.value;
        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel?.name ?? 'Nothing playing',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (channel != null)
                    Text(
                      channel.urls.length > 1
                          ? '${categoriesLabel(channel)} · '
                                'Source ${player.sourceIndex.value + 1} of '
                                '${channel.urls.length}'
                          : categoriesLabel(channel),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _StatusChip(status: player.status.value),
            if (channel != null)
              FavoriteButton(
                favorite: channel.favorite,
                onPressed: () => onToggleFavorite(channel),
              ),
          ],
        );
      }),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final PlaybackStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color background, Color foreground) = switch (status) {
      PlaybackStatus.playing => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      PlaybackStatus.error => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (status == PlaybackStatus.playing) ...[
            Icon(Icons.circle, size: 8, color: scheme.primary),
            const SizedBox(width: 6),
          ],
          Text(
            status == PlaybackStatus.playing ? 'Live' : status.label,
            style: Theme.of(context).textTheme.labelMedium
                ?.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}
