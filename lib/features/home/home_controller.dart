import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/app/routes.dart';
import 'package:tv/core/platform.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/models/custom_category.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/features/channel_editor/channel_editor_controller.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/player/player_controller.dart';
import 'package:window_manager/window_manager.dart';

/// Browsing and playing.
///
/// What is shown: hidden channels never; channels whose categories are all
/// hidden only in Favorites, Recently watched and custom categories, where
/// the user put them on purpose.
class HomeController extends GetxController with WindowListener {
  /// Number of channels in "Recently watched".
  static const recentLimit = 30;

  final ChannelRepository _repository;
  final PlayerController player;

  HomeController(this._repository, this.player);

  /// All channels, hidden ones included.
  final channels = <Channel>[].obs;
  final hiddenCategories = <String>{}.obs;
  final customCategories = <CustomCategory>[].obs;
  final section = LibrarySection.all.obs;

  /// Search text. When not empty, it replaces [section] in the list.
  final query = ''.obs;
  final isLoading = true.obs;
  final isFullscreen = false.obs;

  _Index? _cache;

  /// Visible channels per category, rebuilt after any change. Large
  /// playlists have thousands of channels and the menu reads this on every
  /// build.
  _Index get _index => _cache ??= _Index.build(channels, hiddenCategories);

  void _invalidate() => _cache = null;

  /// Visible playlist categories, in order of first use.
  List<String> get categories => _index.byCategory.keys.toList();

  /// Favorites, recent and all channels, the custom categories, then one
  /// section per visible playlist category.
  List<LibrarySection> get sections => [
    LibrarySection.favorites,
    LibrarySection.recent,
    LibrarySection.all,
    for (final custom in customCategories)
      LibrarySection.custom(custom.id, custom.name),
    for (final category in categories) LibrarySection.category(category),
  ];

  List<Channel> channelsIn(LibrarySection section) {
    switch (section.kind) {
      case SectionKind.favorites:
        return _index.notHidden.where((c) => c.favorite).toList();
      case SectionKind.recent:
        final watched =
            _index.notHidden.where((c) => c.lastWatched != null).toList()
              ..sort((a, b) => b.lastWatched!.compareTo(a.lastWatched!));
        return watched.take(recentLimit).toList();
      case SectionKind.all:
        return _index.visible;
      case SectionKind.custom:
        final custom = customCategories.firstWhereOrNull(
          (c) => c.id == section.customId,
        );
        return [
          for (final key in custom?.channelKeys ?? const <String>[])
            if (_index.byKey[key] case final channel? when !channel.hidden)
              channel,
        ];
      case SectionKind.category:
        return _index.byCategory[section.category] ?? const [];
    }
  }

  /// Visible channels whose name or category contains [text], ignoring
  /// case.
  List<Channel> search(String text) {
    final needle = text.trim().toLowerCase();
    if (needle.isEmpty) {
      return const [];
    }
    return _index.visible
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
    ever(channels, (_) => _invalidate());
    ever(hiddenCategories, (_) => _invalidate());
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
    section.value = channelsIn(LibrarySection.favorites).isNotEmpty
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
        channelsIn(LibrarySection.all).firstOrNull;
  }

  Future<void> reload() async {
    isLoading.value = true;
    final all = await _repository.getAll();
    final hidden = await _repository.getHiddenCategories();
    final custom = await _repository.getCustomCategories();
    channels.assignAll(all);
    hiddenCategories
      ..clear()
      ..addAll(hidden);
    customCategories.assignAll(custom);
    _invalidate();
    // Keep the player's copy in sync, e.g. after sources were imported.
    final current = player.channel.value;
    final fresh = _index.byKey[current?.key];
    if (fresh != null && fresh != current) {
      player.channel.value = fresh;
    }
    _keepSectionValid();
    isLoading.value = false;
  }

  /// Falls back to "All channels" when the selected section is gone.
  void _keepSectionValid() {
    if (!sections.contains(section.value)) {
      section.value = LibrarySection.all;
    }
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
    final current = _index.byKey[channel.key] ?? channel;
    final updated = current.copyWith(favorite: !current.favorite);
    _replace(updated);
    await _repository.setFavorite(channel.key, updated.favorite);
  }

  /// Hides a channel from browsing. It stays in the library and can be
  /// shown again there; the message offers to undo.
  Future<void> hideChannel(Channel channel) async {
    await _setHidden(channel, true);
    _showMessage(
      'Hid "${channel.name}". Show it again in the library.',
      actionLabel: 'Undo',
      onAction: () => _setHidden(channel, false),
    );
  }

  Future<void> _setHidden(Channel channel, bool hidden) async {
    final current = _index.byKey[channel.key] ?? channel;
    _replace(current.copyWith(hidden: hidden));
    await _repository.setHidden([channel.key], hidden);
    _keepSectionValid();
  }

  void _replace(Channel updated) {
    final index = channels.indexWhere((c) => c.key == updated.key);
    if (index >= 0) {
      channels[index] = updated;
      _invalidate();
    }
    if (player.channel.value?.key == updated.key) {
      player.channel.value = updated;
    }
  }

  /// Adds [channel] to custom category [id], or to a new category named
  /// [newName].
  Future<void> addToCustomCategory(
    Channel channel, {
    int? id,
    String? newName,
  }) async {
    final targetId = id ?? await _repository.createCustomCategory(newName!);
    await _repository.addToCustomCategory(targetId, [channel.key]);
    customCategories.assignAll(await _repository.getCustomCategories());
    final name = customCategories
        .firstWhereOrNull((c) => c.id == targetId)
        ?.name;
    _showMessage('Added "${channel.name}" to $name');
  }

  Future<void> removeFromCustomCategory(Channel channel, int id) async {
    await _repository.removeFromCustomCategory(id, [channel.key]);
    customCategories.assignAll(await _repository.getCustomCategories());
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
    if (current != null && _index.byKey[current.key] == null) {
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
      if (listEquals(result.sources, channel.sources)) {
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
    _invalidate();
    _keepSectionValid();
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

  void _showMessage(
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (Get.overlayContext == null) {
      return;
    }
    Get.rawSnackbar(
      message: message,
      duration: const Duration(seconds: 4),
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
      maxWidth: 520,
      mainButton: actionLabel == null
          ? null
          : TextButton(
              onPressed: () {
                Get.closeCurrentSnackbar();
                onAction?.call();
              },
              child: Text(actionLabel),
            ),
    );
  }
}

/// Lookups derived from the channel list.
class _Index {
  final Map<String, Channel> byKey;

  /// Channels not hidden by the user.
  final List<Channel> notHidden;

  /// Not hidden, with at least one visible category.
  final List<Channel> visible;

  /// Visible channels per visible category, in order of first use.
  final Map<String, List<Channel>> byCategory;

  _Index(this.byKey, this.notHidden, this.visible, this.byCategory);

  factory _Index.build(List<Channel> channels, Set<String> hiddenCategories) {
    final byKey = <String, Channel>{};
    final notHidden = <Channel>[];
    final visible = <Channel>[];
    final byCategory = <String, List<Channel>>{};
    for (final channel in channels) {
      byKey[channel.key] = channel;
      if (channel.hidden) continue;
      notHidden.add(channel);
      var shown = false;
      for (final category in channel.categories) {
        if (hiddenCategories.contains(category)) continue;
        (byCategory[category] ??= []).add(channel);
        shown = true;
      }
      if (shown) visible.add(channel);
    }
    return _Index(byKey, notHidden, visible, byCategory);
  }
}
