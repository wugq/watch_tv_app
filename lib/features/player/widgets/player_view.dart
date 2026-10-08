import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:tv/features/player/player_controller.dart';

/// Video surface with a tap-to-show control bar.
class PlayerView extends StatefulWidget {
  final PlayerController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  /// Shows a channel list button in the control bar when set.
  final VoidCallback? onShowChannels;

  const PlayerView({
    super.key,
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.onShowChannels,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  static const _hideDelay = Duration(seconds: 3);

  bool _controlsVisible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideDelay, () {
      if (mounted && widget.controller.status.value == PlaybackStatus.playing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  /// Mouse movement shows the controls; they hide again after a delay.
  void _showControls() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _scheduleHide();
  }

  void _onTap() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.controller;
    return MouseRegion(
      onHover: (_) => _showControls(),
      child: ColoredBox(
        color: Colors.black,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Obx(
                () => _VideoSurface(
                  video: player.isVideoReady.value ? player.video.value : null,
                  aspectRatio: player.aspectRatio.value,
                ),
              ),
              Obx(
                () => _StatusLayer(
                  status: player.status.value,
                  errorMessage: player.errorMessage.value,
                  onRetry: player.retry,
                ),
              ),
              AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: _ControlBar(
                    controller: player,
                    isFullscreen: widget.isFullscreen,
                    onToggleFullscreen: () {
                      widget.onToggleFullscreen();
                      _scheduleHide();
                    },
                    onTogglePlay: () {
                      player.togglePlay();
                      _scheduleHide();
                    },
                    onNextSource: () {
                      player.nextSource();
                      _scheduleHide();
                    },
                    onShowChannels: widget.onShowChannels,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoSurface extends StatelessWidget {
  final VideoPlayerController? video;
  final double aspectRatio;

  const _VideoSurface({required this.video, required this.aspectRatio});

  @override
  Widget build(BuildContext context) {
    final video = this.video;
    if (video == null) {
      return const _Cover();
    }
    return Center(
      child: AspectRatio(aspectRatio: aspectRatio, child: VideoPlayer(video)),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.35,
      child: Image.asset('assets/tv_cover.jpg', fit: BoxFit.cover),
    );
  }
}

class _StatusLayer extends StatelessWidget {
  final PlaybackStatus status;
  final String? errorMessage;
  final VoidCallback onRetry;

  const _StatusLayer({
    required this.status,
    required this.errorMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case PlaybackStatus.loading:
      case PlaybackStatus.buffering:
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      case PlaybackStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 40),
                const SizedBox(height: 8),
                Text(
                  errorMessage ?? 'Playback error',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      case PlaybackStatus.idle:
        return const Center(
          child: Text(
            'Select a channel to start watching',
            style: TextStyle(color: Colors.white70),
          ),
        );
      case PlaybackStatus.playing:
      case PlaybackStatus.paused:
        return const SizedBox.shrink();
    }
  }
}

class _ControlBar extends StatelessWidget {
  final PlayerController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onTogglePlay;
  final VoidCallback onNextSource;
  final VoidCallback? onShowChannels;

  const _ControlBar({
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onTogglePlay,
    required this.onNextSource,
    required this.onShowChannels,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black87],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 4),
          child: IconTheme(
            data: const IconThemeData(color: Colors.white),
            child: Row(
              children: [
                if (onShowChannels != null)
                  IconButton(
                    tooltip: 'Channels',
                    onPressed: onShowChannels,
                    icon: const Icon(Icons.menu),
                  ),
                Obx(() {
                  final playing =
                      controller.status.value == PlaybackStatus.playing ||
                      controller.status.value == PlaybackStatus.buffering;
                  return IconButton(
                    tooltip: playing ? 'Pause' : 'Play',
                    onPressed: controller.channel.value == null
                        ? null
                        : onTogglePlay,
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow),
                  );
                }),
                Expanded(
                  child: Obx(
                    () => Text(
                      controller.channel.value?.name ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                Obx(() {
                  final count = controller.channel.value?.urls.length ?? 0;
                  if (count < 2) {
                    return const SizedBox.shrink();
                  }
                  return TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    onPressed: onNextSource,
                    icon: const Icon(Icons.swap_horiz),
                    label: Text('${controller.sourceIndex.value + 1}/$count'),
                  );
                }),
                IconButton(
                  tooltip: isFullscreen ? 'Exit full screen' : 'Full screen',
                  onPressed: onToggleFullscreen,
                  icon: Icon(
                    isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
