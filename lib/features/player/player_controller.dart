import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:tv/data/models/channel.dart';

enum PlaybackStatus {
  idle('Idle'),
  loading('Loading'),
  buffering('Buffering'),
  playing('Playing'),
  paused('Paused'),
  error('Error');

  final String label;

  const PlaybackStatus(this.label);
}

typedef VideoControllerFactory = VideoPlayerController Function(Uri url);

/// Owns the video player. Only one channel plays at a time.
class PlayerController extends GetxController with WidgetsBindingObserver {
  final VideoControllerFactory _createVideoController;

  PlayerController({VideoControllerFactory? createVideoController})
    : _createVideoController =
          createVideoController ?? VideoPlayerController.networkUrl;

  /// How long a source may take to start before the next one is tried.
  static const openTimeout = Duration(seconds: 20);

  final channel = Rxn<Channel>();

  /// Index of the playing source in `channel.urls`.
  final sourceIndex = 0.obs;
  final status = PlaybackStatus.idle.obs;
  final errorMessage = RxnString();
  final video = Rxn<VideoPlayerController>();

  /// Increases on every [play] call, so a slow `initialize()` of an older
  /// channel does not override the newer one.
  int _generation = 0;

  /// Sources that failed since the last successful start.
  int _failuresInRow = 0;

  double get aspectRatio {
    final value = video.value?.value;
    if (value == null || !value.isInitialized || value.aspectRatio <= 0) {
      return 16 / 9;
    }
    return value.aspectRatio;
  }

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideo();
    _setWakelock(false);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      pause();
    }
  }

  /// Plays [newChannel], starting with source [source]. When a source
  /// fails, the next one is tried until every source failed once.
  Future<void> play(Channel newChannel, {int source = 0}) async {
    _failuresInRow = 0;
    await _open(newChannel, source.clamp(0, newChannel.urls.length - 1));
  }

  /// Switches the current channel to its next source.
  Future<void> nextSource() async {
    final current = channel.value;
    if (current != null && current.urls.length > 1) {
      await play(
        current,
        source: (sourceIndex.value + 1) % current.urls.length,
      );
    }
  }

  Future<void> retry() async {
    final current = channel.value;
    if (current != null) {
      await play(current, source: sourceIndex.value);
    }
  }

  Future<void> _open(Channel newChannel, int index) async {
    final generation = ++_generation;
    _disposeVideo();
    channel.value = newChannel;
    sourceIndex.value = index;
    errorMessage.value = null;
    status.value = PlaybackStatus.loading;

    final uri = Uri.tryParse(newChannel.urls[index]);
    if (uri == null) {
      _onSourceFailed('Invalid URL');
      return;
    }

    final controller = _createVideoController(uri);
    video.value = controller;
    try {
      await controller.initialize().timeout(openTimeout);
    } catch (e) {
      if (generation == _generation) {
        _onSourceFailed(
          e is TimeoutException ? 'Stream timed out' : 'Cannot open stream',
        );
      }
      return;
    }
    if (generation != _generation) {
      return;
    }
    controller.addListener(_onVideoValueChanged);
    await controller.play();
    video.refresh();
  }

  void _onSourceFailed(String message) {
    final current = channel.value;
    _failuresInRow++;
    if (current != null && _failuresInRow < current.urls.length) {
      _open(current, (sourceIndex.value + 1) % current.urls.length);
      return;
    }
    final count = current?.urls.length ?? 0;
    _setError(count > 1 ? '$message (all $count sources failed)' : message);
  }

  Future<void> stop() async {
    _generation++;
    _disposeVideo();
    channel.value = null;
    errorMessage.value = null;
    status.value = PlaybackStatus.idle;
  }

  void pause() {
    final controller = video.value;
    if (controller != null && controller.value.isPlaying) {
      controller.pause();
    }
  }

  void togglePlay() {
    final controller = video.value;
    if (controller == null || !controller.value.isInitialized) {
      retry();
    } else if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
  }

  void _onVideoValueChanged() {
    final value = video.value?.value;
    if (value == null) {
      return;
    }
    if (value.hasError) {
      // Called from the controller's notifyListeners(), where it must not be
      // disposed. Switch the source after this call returns.
      video.value?.removeListener(_onVideoValueChanged);
      final generation = _generation;
      scheduleMicrotask(() {
        if (generation == _generation) {
          _onSourceFailed(value.errorDescription ?? 'Playback error');
        }
      });
      return;
    }
    final PlaybackStatus next;
    if (value.isBuffering) {
      next = PlaybackStatus.buffering;
    } else if (value.isPlaying) {
      next = PlaybackStatus.playing;
    } else {
      next = PlaybackStatus.paused;
    }
    if (next == PlaybackStatus.playing) {
      _failuresInRow = 0;
    }
    if (next != status.value) {
      status.value = next;
      _updateWakelock();
    }
  }

  void _setError(String message) {
    errorMessage.value = message;
    status.value = PlaybackStatus.error;
    _updateWakelock();
  }

  void _updateWakelock() {
    final keepOn =
        status.value == PlaybackStatus.playing ||
        status.value == PlaybackStatus.buffering;
    _setWakelock(keepOn);
  }

  void _setWakelock(bool enable) {
    // Not available on every platform (and in tests). The screen just turns
    // off as usual in that case.
    WakelockPlus.toggle(enable: enable).catchError((Object _) {});
  }

  void _disposeVideo() {
    final controller = video.value;
    if (controller == null) {
      return;
    }
    video.value = null;
    controller.removeListener(_onVideoValueChanged);
    controller.dispose();
  }
}
