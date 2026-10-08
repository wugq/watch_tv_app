import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/app/routes.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/models/custom_category.dart';
import 'package:tv/data/models/playlist.dart';
import 'package:tv/data/parsers/channel_list_parser.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/data/sources/playlist_loader.dart';
import 'package:tv/features/home/library_section.dart';

enum FilterKind { all, hidden, category, custom }

/// Which channels the Channels tab lists.
@immutable
class ChannelFilter {
  final FilterKind kind;
  final String? category;
  final int? customId;

  const ChannelFilter._(this.kind, {this.category, this.customId});

  static const all = ChannelFilter._(FilterKind.all);
  static const hidden = ChannelFilter._(FilterKind.hidden);

  const ChannelFilter.category(String name)
    : this._(FilterKind.category, category: name);

  const ChannelFilter.custom(int id) : this._(FilterKind.custom, customId: id);

  @override
  bool operator ==(Object other) =>
      other is ChannelFilter &&
      other.kind == kind &&
      other.category == category &&
      other.customId == customId;

  @override
  int get hashCode => Object.hash(kind, category, customId);
}

/// A playlist category with its channel count.
class CategoryInfo {
  final String name;
  final int channelCount;
  final bool hidden;

  const CategoryInfo(this.name, this.channelCount, {required this.hidden});
}

/// Library management: playlists, categories and channels.
class ManageController extends GetxController {
  final ChannelRepository _repository;
  final PlaylistLoader _loader;

  ManageController(this._repository, this._loader);

  final playlists = <Playlist>[].obs;
  final channels = <Channel>[].obs;
  final hiddenCategories = <String>{}.obs;
  final customCategories = <CustomCategory>[].obs;
  final query = ''.obs;
  final filter = ChannelFilter.all.obs;

  /// Keys of the selected channels. Not empty means selection mode.
  final selected = <String>{}.obs;
  final isLoading = true.obs;

  /// Playlist that is being refreshed.
  final refreshingId = RxnInt();

  bool get isSelecting => selected.isNotEmpty;

  /// Playlist categories in order of first use.
  List<CategoryInfo> get categoryInfos {
    final counts = <String, int>{};
    for (final channel in channels) {
      for (final category in channel.categories) {
        counts[category] = (counts[category] ?? 0) + 1;
      }
    }
    return [
      for (final entry in counts.entries)
        CategoryInfo(
          entry.key,
          entry.value,
          hidden: hiddenCategories.contains(entry.key),
        ),
    ];
  }

  CustomCategory? customCategory(int? id) =>
      customCategories.firstWhereOrNull((c) => c.id == id);

  String filterLabel(ChannelFilter value) => switch (value.kind) {
    FilterKind.all => 'All channels',
    FilterKind.hidden => 'Hidden channels',
    FilterKind.category => categoryLabel(value.category!),
    FilterKind.custom => customCategory(value.customId)?.name ?? '',
  };

  List<Channel> get visibleChannels {
    final current = filter.value;
    final Iterable<Channel> base;
    switch (current.kind) {
      case FilterKind.all:
        base = channels;
      case FilterKind.hidden:
        base = channels.where((c) => c.hidden);
      case FilterKind.category:
        base = channels.where((c) => c.categories.contains(current.category));
      case FilterKind.custom:
        final keys = customCategory(current.customId)?.channelKeys ?? const [];
        final byKey = {for (final c in channels) c.key: c};
        base = [for (final key in keys) ?byKey[key]];
    }
    final needle = query.value.trim().toLowerCase();
    if (needle.isEmpty) {
      return base.toList();
    }
    return base
        .where(
          (c) =>
              c.name.toLowerCase().contains(needle) ||
              categoriesLabel(c).toLowerCase().contains(needle),
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
    final hidden = await _repository.getHiddenCategories();
    hiddenCategories
      ..clear()
      ..addAll(hidden);
    customCategories.assignAll(await _repository.getCustomCategories());
    selected.removeWhere((key) => !channels.any((c) => c.key == key));
    final current = filter.value;
    if (current.kind == FilterKind.custom &&
        customCategory(current.customId) == null) {
      filter.value = ChannelFilter.all;
    }
    isLoading.value = false;
  }

  // Playlists

  Future<void> addPlaylist() async {
    if (await Get.toNamed(Routes.importPlaylist) == true) {
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
      final parsed = await ChannelListParser.parseInBackground(loaded.text);
      if (parsed.isEmpty) {
        _showMessage('No channel found in ${playlist.name}. Nothing changed.');
        return;
      }
      await _repository.refreshPlaylist(playlist.id, parsed);
      _showMessage('${playlist.name}: ${parsed.length} channels');
      await load();
    } on PlaylistLoadException catch (e) {
      _showMessage('${playlist.name}: ${e.message}');
    } catch (e) {
      _showMessage('${playlist.name}: could not refresh ($e)');
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

  // Categories

  Future<void> setCategoryVisible(String name, bool visible) async {
    await _repository.setCategoryHidden([name], !visible);
    if (visible) {
      hiddenCategories.remove(name);
    } else {
      hiddenCategories.add(name);
    }
  }

  Future<void> setAllCategoriesVisible(bool visible) async {
    final names = categoryInfos.map((c) => c.name).toList();
    await _repository.setCategoryHidden(names, !visible);
    if (visible) {
      hiddenCategories.clear();
    } else {
      hiddenCategories.addAll(names);
    }
  }

  Future<int> createCustomCategory(String name) async {
    final id = await _repository.createCustomCategory(name.trim());
    customCategories.assignAll(await _repository.getCustomCategories());
    return id;
  }

  Future<void> renameCustomCategory(
    CustomCategory category,
    String name,
  ) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed == category.name) {
      return;
    }
    await _repository.renameCustomCategory(category.id, trimmed);
    customCategories.assignAll(await _repository.getCustomCategories());
  }

  Future<void> deleteCustomCategory(CustomCategory category) async {
    await _repository.deleteCustomCategory(category.id);
    _showMessage('Deleted ${category.name}. Its channels were not deleted.');
    await load();
  }

  /// Lists the channels of a category in the Channels tab.
  void showChannelsOf(ChannelFilter value) {
    filter.value = value;
    query.value = '';
    selected.clear();
  }

  // Channels

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

  Future<void> deleteChannel(Channel channel) async {
    await _repository.delete(channel.key);
    _showMessage('Deleted "${channel.name}"');
    await load();
  }

  Future<void> toggleFavorite(Channel channel) async {
    await _repository.setFavorite(channel.key, !channel.favorite);
    _update([channel.key], (c) => c.copyWith(favorite: !channel.favorite));
  }

  Future<void> setHidden(Iterable<String> keys, bool hidden) async {
    final list = keys.toList();
    await _repository.setHidden(list, hidden);
    _update(list, (c) => c.copyWith(hidden: hidden));
  }

  void _update(List<String> keys, Channel Function(Channel) change) {
    final set = keys.toSet();
    for (var i = 0; i < channels.length; i++) {
      if (set.contains(channels[i].key)) {
        channels[i] = change(channels[i]);
      }
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

  Future<void> setSelectedHidden(bool hidden) async {
    final count = selected.length;
    await setHidden(selected, hidden);
    selected.clear();
    _showMessage(
      hidden ? 'Hid $count channels' : 'Showing $count channels again',
    );
  }

  /// Adds the selected channels to custom category [id], or to a new one.
  Future<void> addSelectedToCategory({int? id, String? newName}) async {
    final targetId = id ?? await createCustomCategory(newName!);
    final count = selected.length;
    await _repository.addToCustomCategory(targetId, selected.toList());
    customCategories.assignAll(await _repository.getCustomCategories());
    selected.clear();
    _showMessage('Added $count channels to ${customCategory(targetId)?.name}');
  }

  Future<void> removeSelectedFromCategory(int id) async {
    await _repository.removeFromCustomCategory(id, selected.toList());
    customCategories.assignAll(await _repository.getCustomCategories());
    selected.clear();
  }

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
      maxWidth: 520,
    );
  }
}
