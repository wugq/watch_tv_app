import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/app/routes.dart';
import 'package:tv/core/platform.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/features/player/player_controller.dart';
import 'package:window_manager/window_manager.dart';

class HomeController extends GetxController with WindowListener {
  /// Value of [selectedCategory] that shows every channel.
  static const allCategories = '';

  final ChannelRepository _repository;
  final PlayerController player;

  HomeController(this._repository, this.player);

  final channels = <Channel>[].obs;
  final selectedCategory = allCategories.obs;
  final isLoading = true.obs;
  final isFullscreen = false.obs;

  List<String> get categories {
    final seen = <String>{};
    return [
      for (final channel in channels)
        if (seen.add(channel.category)) channel.category,
    ];
  }

  List<Channel> get visibleChannels {
    final category = selectedCategory.value;
    if (category == allCategories) {
      return channels;
    }
    return channels.where((c) => c.category == category).toList();
  }

  @override
  void onInit() {
    super.onInit();
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
    _setFullscreenMode(false);
    super.onClose();
  }

  Future<void> _loadAndAutoPlay() async {
    await reload();
    if (channels.isNotEmpty && player.channel.value == null) {
      player.play(channels.first);
    }
  }

  Future<void> reload() async {
    isLoading.value = true;
    channels.assignAll(await _repository.getAll());
    // Keep the player's copy in sync, e.g. after sources were imported.
    final current = player.channel.value;
    final fresh = channels.firstWhereOrNull((c) => c.key == current?.key);
    if (fresh != null && fresh != current) {
      player.channel.value = fresh;
    }
    if (!categories.contains(selectedCategory.value)) {
      selectedCategory.value = allCategories;
    }
    isLoading.value = false;
  }

  void selectCategory(String category) {
    selectedCategory.value = category;
  }

  void play(Channel channel) {
    player.play(channel);
  }

  bool isPlaying(Channel channel) => player.channel.value?.key == channel.key;

  Future<void> addChannels() async {
    final saved = await _openEditor();
    if (saved == null || saved.isEmpty) {
      return;
    }
    await reload();
    _showMessage(
      saved.length == 1 ? '1 channel saved' : '${saved.length} channels saved',
    );
    if (player.channel.value == null && channels.isNotEmpty) {
      player.play(channels.first);
    }
  }

  Future<void> editChannel(Channel channel) async {
    final saved = await _openEditor(channel);
    if (saved == null || saved.isEmpty) {
      return;
    }
    await reload();
    final edited = saved.first;
    if (isPlaying(channel)) {
      if (listEquals(edited.urls, channel.urls)) {
        player.channel.value = edited;
      } else {
        player.play(edited);
      }
    }
  }

  /// Returns the channels saved in the editor, or null when cancelled.
  Future<List<Channel>?> _openEditor([Channel? channel]) async {
    // GetX creates `GetPageRoute<dynamic>`, so `toNamed<T>` can't be typed.
    final result = await Get.toNamed(Routes.channelEditor, arguments: channel);
    return result is List<Channel> ? result : null;
  }

  Future<void> deleteChannel(Channel channel) async {
    await _repository.delete(channel.key);
    channels.removeWhere((c) => c.key == channel.key);
    if (!categories.contains(selectedCategory.value)) {
      selectedCategory.value = allCategories;
    }
    if (isPlaying(channel)) {
      await player.stop();
    }
  }

  void toggleFullscreen() => setFullscreen(!isFullscreen.value);

  void setFullscreen(bool value) {
    if (isFullscreen.value == value) {
      return;
    }
    isFullscreen.value = value;
    _setFullscreenMode(value);
  }

  void _setFullscreenMode(bool fullscreen) {
    setAppFullscreen(fullscreen);
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
    player.play(list[next]);
  }

  void _showMessage(String message) {
    Get.rawSnackbar(
      message: message,
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.all(12),
      borderRadius: 8,
    );
  }
}
