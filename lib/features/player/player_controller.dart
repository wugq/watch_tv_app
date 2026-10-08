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

  /// Whether an error event after the stream started means the source is
  /// broken. True for ExoPlayer / AVPlayer. media_kit (libmpv) also reports
  /// non-fatal problems as errors, e.g. a missing audio device while the
  /// video keeps playing, so there only [stallTimeout] switches sources.
  final bool errorsAreFatal;

  /// How long the stream may buffer before the next source is tried.
  final Duration stallTimeout;

  /// Pause when the app leaves the foreground. Mobile only: on desktop the
  /// app becomes `inactive` whenever the window loses focus or switches to
  /// full screen, and playback should continue then.
  final bool pauseInBackground;

  PlayerController({
    VideoControllerFactory? createVideoController,
    this.errorsAreFatal = true,
    this.stallTimeout = const Duration(seconds: 20),
    this.pauseInBackground = true,
  }) : _createVideoController =
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

  Timer? _stallTimer;

  /// True once the current source finished `initialize()`.
  ///
  /// Not the same as `video.value.isInitialized`: video_player replaces the
  /// whole value on an error event, which media_kit also sends for
  /// non-fatal problems while the video keeps playing.
  final isVideoReady = false.obs;

  /// Last known aspect ratio of the current stream.
  final aspectRatio = (16 / 9).obs;

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
    if (!pauseInBackground) {
      return;
    }
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
    isVideoReady.value = false;
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
    _updateAspectRatio(controller.value);
    isVideoReady.value = true;
    controller.addListener(_onVideoValueChanged);
    // Not awaited: with media_kit the returned future can take long.
    // Playback errors also arrive through the controller's value.
    controller.play().catchError((Object _) {});
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
    if (controller == null || !isVideoReady.value) {
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
    if (value.hasError && errorsAreFatal) {
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
    _updateAspectRatio(value);
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
    _watchForStall(next == PlaybackStatus.buffering);
    if (next != status.value) {
      status.value = next;
      _updateWakelock();
    }
  }

  void _updateAspectRatio(VideoPlayerValue value) {
    if (value.isInitialized && value.aspectRatio > 0) {
      aspectRatio.value = value.aspectRatio;
    }
  }

  void _watchForStall(bool buffering) {
    if (!buffering) {
      _stallTimer?.cancel();
      _stallTimer = null;
      return;
    }
    if (_stallTimer != null) {
      return;
    }
    final generation = _generation;
    _stallTimer = Timer(stallTimeout, () {
      _stallTimer = null;
      if (generation == _generation) {
        _onSourceFailed('Stream stalled');
      }
    });
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
    _stallTimer?.cancel();
    _stallTimer = null;
    final controller = video.value;
    if (controller == null) {
      return;
    }
    video.value = null;
    isVideoReady.value = false;
    controller.removeListener(_onVideoValueChanged);
    controller.dispose();
  }
}
