import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/app/routes.dart';
import 'package:tv/core/platform.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/features/channel_editor/channel_editor_controller.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/player/player_controller.dart';
import 'package:window_manager/window_manager.dart';

class HomeController extends GetxController with WindowListener {
  /// Number of channels in "Recently watched".
  static const recentLimit = 30;

  final ChannelRepository _repository;
  final PlayerController player;

  HomeController(this._repository, this.player);

  final channels = <Channel>[].obs;
  final section = LibrarySection.all.obs;

  /// Search text. When not empty, it replaces [section] in the list.
  final query = ''.obs;
  final isLoading = true.obs;
  final isFullscreen = false.obs;

  /// Channels per category, in order of first use. Rebuilt when
  /// [channels] changes; large playlists have thousands of channels and the
  /// menu reads this on every build.
  Map<String, List<Channel>>? _byCategory;

  Map<String, List<Channel>> get _categoryIndex {
    return _byCategory ??= () {
      final index = <String, List<Channel>>{};
      for (final channel in channels) {
        for (final category in channel.categories) {
          (index[category] ??= []).add(channel);
        }
      }
      return index;
    }();
  }

  List<String> get categories => _categoryIndex.keys.toList();

  /// Favorites, recent and all channels, then one section per category.
  List<LibrarySection> get sections => [
    LibrarySection.favorites,
    LibrarySection.recent,
    LibrarySection.all,
    for (final category in categories) LibrarySection.category(category),
  ];

  List<Channel> channelsIn(LibrarySection section) {
    switch (section.kind) {
      case SectionKind.favorites:
        return channels.where((c) => c.favorite).toList();
      case SectionKind.recent:
        final watched = channels.where((c) => c.lastWatched != null).toList()
          ..sort((a, b) => b.lastWatched!.compareTo(a.lastWatched!));
        return watched.take(recentLimit).toList();
      case SectionKind.all:
        return channels;
      case SectionKind.category:
        return _categoryIndex[section.category] ?? const [];
    }
  }

  /// Channels whose name or category contains [text], ignoring case.
  List<Channel> search(String text) {
    final needle = text.trim().toLowerCase();
    if (needle.isEmpty) {
      return const [];
    }
    return channels
        .where(
          (c) =>
              c.name.toLowerCase().contains(needle) ||
              categoriesLabel(c).toLowerCase().contains(needle),
        )
        .toList();
  }

  /// The list shown now: search results, or the selected section.
  List<Channel> get visibleChannels {
    final text = query.value;
    return text.trim().isEmpty ? channelsIn(section.value) : search(text);
  }

  @override
  void onInit() {
    super.onInit();
    ever(channels, (_) => _byCategory = null);
    if (isDesktop) {
      windowManager.addListener(this);
    }
  }

  // The user can also leave full screen with the window controls or the
  // system shortcut.
  @override
  void onWindowEnterFullScreen() => isFullscreen.value = true;

  @override
  void onWindowLeaveFullScreen() => isFullscreen.value = false;

  @override
  void onReady() {
    super.onReady();
    _loadAndAutoPlay();
  }

  @override
  void onClose() {
    if (isDesktop) {
      windowManager.removeListener(this);
    }
    setAppFullscreen(false);
    super.onClose();
  }

  Future<void> _loadAndAutoPlay() async {
    await reload();
    section.value = channels.any((c) => c.favorite)
        ? LibrarySection.favorites
        : LibrarySection.all;
    if (player.channel.value == null) {
      final first = _startChannel();
      if (first != null) {
        play(first);
      }
    }
  }

  /// The last watched channel, else the first favorite, else the first one.
  Channel? _startChannel() {
    return channelsIn(LibrarySection.recent).firstOrNull ??
        channelsIn(LibrarySection.favorites).firstOrNull ??
        channels.firstOrNull;
  }

  Future<void> reload() async {
    isLoading.value = true;
    channels.assignAll(await _repository.getAll());
    _byCategory = null;
    // Keep the player's copy in sync, e.g. after sources were imported.
    final current = player.channel.value;
    final fresh = channels.firstWhereOrNull((c) => c.key == current?.key);
    if (fresh != null && fresh != current) {
      player.channel.value = fresh;
    }
    if (section.value.kind == SectionKind.category &&
        !categories.contains(section.value.category)) {
      section.value = LibrarySection.all;
    }
    isLoading.value = false;
  }

  void selectSection(LibrarySection value) {
    section.value = value;
    query.value = '';
  }

  void setQuery(String text) {
    query.value = text;
  }

  void play(Channel channel) {
    player.play(channel);
    final now = DateTime.now();
    _replace(channel.copyWith(lastWatched: now));
    _repository.markWatched(channel.key, now);
  }

  bool isPlaying(Channel channel) => player.channel.value?.key == channel.key;

  Future<void> toggleFavorite(Channel channel) async {
    final current =
        channels.firstWhereOrNull((c) => c.key == channel.key) ?? channel;
    final updated = current.copyWith(favorite: !current.favorite);
    _replace(updated);
    await _repository.setFavorite(channel.key, updated.favorite);
  }

  void _replace(Channel updated) {
    final index = channels.indexWhere((c) => c.key == updated.key);
    if (index >= 0) {
      channels[index] = updated;
      _byCategory = null;
    }
    if (player.channel.value?.key == updated.key) {
      player.channel.value = updated;
    }
  }

  /// Opens the playlist import page (M3U / TXT from a URL, file or text).
  Future<void> importPlaylist() async {
    final changed = await Get.toNamed(Routes.importPlaylist);
    if (changed == true) {
      await _afterLibraryChange();
    }
  }

  Future<void> addChannel() async {
    final result = await Get.toNamed(Routes.channelEditor);
    if (result is Channel) {
      await _afterLibraryChange();
    }
  }

  Future<void> openManager() async {
    await Get.toNamed(Routes.manage);
    await _afterLibraryChange();
  }

  Future<void> _afterLibraryChange() async {
    await reload();
    final current = player.channel.value;
    if (current != null && !channels.any((c) => c.key == current.key)) {
      await player.stop();
    }
    if (player.channel.value == null) {
      final first = _startChannel();
      if (first != null) {
        play(first);
      }
    }
  }

  Future<void> editChannel(Channel channel) async {
    final result = await Get.toNamed(Routes.channelEditor, arguments: channel);
    if (result == ChannelEditorController.deleted) {
      await _afterDelete(channel);
      return;
    }
    if (result is! Channel) {
      return;
    }
    await reload();
    if (isPlaying(channel)) {
      if (listEquals(result.urls, channel.urls)) {
        player.channel.value = result;
      } else {
        player.play(result);
      }
    }
  }

  Future<void> deleteChannel(Channel channel) async {
    await _repository.delete(channel.key);
    await _afterDelete(channel);
  }

  Future<void> _afterDelete(Channel channel) async {
    channels.removeWhere((c) => c.key == channel.key);
    _byCategory = null;
    if (section.value.kind == SectionKind.category &&
        !categories.contains(section.value.category)) {
      section.value = LibrarySection.all;
    }
    if (isPlaying(channel)) {
      await player.stop();
    }
    _showMessage('Deleted "${channel.name}"');
  }

  void toggleFullscreen() => setFullscreen(!isFullscreen.value);

  void setFullscreen(bool value) {
    if (isFullscreen.value == value) {
      return;
    }
    isFullscreen.value = value;
    setAppFullscreen(value);
  }

  /// Plays the channel [offset] places from the current one in the visible
  /// list, wrapping around.
  void playAdjacent(int offset) {
    final list = visibleChannels;
    if (list.isEmpty) {
      return;
    }
    final current = list.indexWhere(isPlaying);
    final next = current < 0 ? 0 : (current + offset) % list.length;
    play(list[next]);
  }

  void _showMessage(String message) {
    if (Get.overlayContext == null) {
      return;
    }
    Get.rawSnackbar(
      message: message,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      maxWidth: 480,
    );
  }
}
