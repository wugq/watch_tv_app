import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/app/routes.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/models/playlist.dart';
import 'package:tv/data/parsers/channel_list_parser.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/data/sources/playlist_loader.dart';
import 'package:tv/features/home/library_section.dart';

/// Playlists and channels: refresh, rename, edit and delete.
class ManageController extends GetxController {
  final ChannelRepository _repository;
  final PlaylistLoader _loader;

  ManageController(this._repository, this._loader);

  final playlists = <Playlist>[].obs;
  final channels = <Channel>[].obs;
  final query = ''.obs;

  /// Keys of the selected channels. Not empty means selection mode.
  final selected = <String>{}.obs;
  final isLoading = true.obs;

  /// Playlist that is being refreshed.
  final refreshingId = RxnInt();

  bool get isSelecting => selected.isNotEmpty;

  List<Channel> get visibleChannels {
    final needle = query.value.trim().toLowerCase();
    if (needle.isEmpty) {
      return channels;
    }
    return channels
        .where(
          (c) =>
              c.name.toLowerCase().contains(needle) ||
              categoryLabel(c.category).toLowerCase().contains(needle),
        )
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    playlists.assignAll(await _repository.getPlaylists());
    channels.assignAll(await _repository.getAll());
    selected.removeWhere((key) => !channels.any((c) => c.key == key));
    isLoading.value = false;
  }

  Future<void> addPlaylist() async {
    if (await Get.toNamed(Routes.importPlaylist) == true) {
      await load();
    }
  }

  Future<void> addChannel() async {
    if (await Get.toNamed(Routes.channelEditor) != null) {
      await load();
    }
  }

  Future<void> editChannel(Channel channel) async {
    if (await Get.toNamed(Routes.channelEditor, arguments: channel) != null) {
      await load();
    }
  }

  Future<void> refreshPlaylist(Playlist playlist) async {
    final url = playlist.url;
    if (url == null || refreshingId.value != null) {
      return;
    }
    refreshingId.value = playlist.id;
    try {
      final loaded = await _loader.fromUrl(url);
      final parsed = ChannelListParser.parse(loaded.text);
      if (parsed.isEmpty) {
        _showMessage('No channel found in ${playlist.name}. Nothing changed.');
        return;
      }
      await _repository.refreshPlaylist(playlist.id, parsed);
      _showMessage('${playlist.name}: ${parsed.length} channels');
      await load();
    } on PlaylistLoadException catch (e) {
      _showMessage('${playlist.name}: ${e.message}');
    } finally {
      refreshingId.value = null;
    }
  }

  Future<void> renamePlaylist(Playlist playlist, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == playlist.name) {
      return;
    }
    await _repository.renamePlaylist(playlist.id, trimmed);
    await load();
  }

  Future<void> deletePlaylist(Playlist playlist) async {
    await _repository.deletePlaylist(playlist.id);
    _showMessage('Deleted ${playlist.name}');
    await load();
  }

  Future<void> deleteChannel(Channel channel) async {
    await _repository.delete(channel.key);
    _showMessage('Deleted "${channel.name}"');
    await load();
  }

  Future<void> toggleFavorite(Channel channel) async {
    await _repository.setFavorite(channel.key, !channel.favorite);
    final index = channels.indexWhere((c) => c.key == channel.key);
    if (index >= 0) {
      channels[index] = channel.copyWith(favorite: !channel.favorite);
    }
  }

  void toggleSelected(Channel channel) {
    if (!selected.remove(channel.key)) {
      selected.add(channel.key);
    }
  }

  void selectAllVisible() {
    selected.addAll(visibleChannels.map((c) => c.key));
  }

  void clearSelection() => selected.clear();

  Future<void> deleteSelected() async {
    final count = selected.length;
    await _repository.deleteAll(selected.toList());
    selected.clear();
    _showMessage(count == 1 ? 'Deleted 1 channel' : 'Deleted $count channels');
    await load();
  }

  void _showMessage(String message) {
    if (Get.overlayContext == null) {
      return;
    }
    Get.rawSnackbar(
      message: message,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      maxWidth: 480,
    );
  }
}
