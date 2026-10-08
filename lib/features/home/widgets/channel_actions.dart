import 'package:flutter/material.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/home/widgets/channel_tile.dart';
import 'package:tv/widgets/confirm_dialog.dart';
import 'package:tv/widgets/custom_category_picker.dart';

/// A [ChannelTile] wired to the home controller, used by the desktop menu
/// and the phone list.
Widget homeChannelTile(
  BuildContext context,
  HomeController controller,
  Channel channel, {
  required LibrarySection section,
  required bool searching,
  required bool isPlaying,
  required VoidCallback onTap,
}) {
  final customId = !searching && section.kind == SectionKind.custom
      ? section.customId
      : null;
  return ChannelTile(
    key: ValueKey(channel.key),
    channel: channel,
    isPlaying: isPlaying,
    showCategory: searching || section.kind != SectionKind.category,
    onTap: onTap,
    onToggleFavorite: () => controller.toggleFavorite(channel),
    onEdit: () => controller.editChannel(channel),
    onAddToCategory: () => addToCategory(context, controller, channel),
    onRemoveFromCategory: customId == null
        ? null
        : () => controller.removeFromCustomCategory(channel, customId),
    removeFromLabel: section.label,
    onHide: () => controller.hideChannel(channel),
    onDelete: () => confirmDeleteChannel(context, controller, channel),
  );
}

Future<void> addToCategory(
  BuildContext context,
  HomeController controller,
  Channel channel,
) async {
  final choice = await showCustomCategoryPicker(
    context,
    controller.customCategories.toList(),
  );
  if (choice != null) {
    await controller.addToCustomCategory(
      channel,
      id: choice.id,
      newName: choice.newName,
    );
  }
}

Future<void> confirmDeleteChannel(
  BuildContext context,
  HomeController controller,
  Channel channel,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: 'Delete channel?',
    message:
        '"${channel.name}" and all its sources will be removed. To only '
        'stop seeing it, hide it instead.',
    confirmLabel: 'Delete',
  );
  if (confirmed) {
    await controller.deleteChannel(channel);
  }
}
