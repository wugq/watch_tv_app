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

  final channel = Rxn<Channel>();
  final status = PlaybackStatus.idle.obs;
  final errorMessage = RxnString();
  final video = Rxn<VideoPlayerController>();

  /// Increases on every [play] call, so a slow `initialize()` of an older
  /// channel does not override the newer one.
  int _generation = 0;

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

  Future<void> play(Channel newChannel) async {
    final generation = ++_generation;
    _disposeVideo();
    channel.value = newChannel;
    errorMessage.value = null;
    status.value = PlaybackStatus.loading;

    final uri = Uri.tryParse(newChannel.url);
    if (uri == null) {
      _setError('Invalid URL: ${newChannel.url}');
      return;
    }

    final controller = _createVideoController(uri);
    video.value = controller;
    try {
      await controller.initialize();
    } catch (e) {
      if (generation == _generation) {
        _setError('Cannot open stream');
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

  Future<void> retry() async {
    final current = channel.value;
    if (current != null) {
      await play(current);
    }
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
      _setError(value.errorDescription ?? 'Playback error');
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
