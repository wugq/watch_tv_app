import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:tv/core/platform.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/features/home/library_section.dart';
import 'package:tv/features/player/player_controller.dart';
import 'package:tv/widgets/favorite_button.dart';

/// Video surface with a control bar at the bottom, in the style of
/// streaming apps: the bar shows on pointer movement or a tap and hides
/// again while the video plays.
///
/// With a mouse, a click toggles play / pause and a double click toggles
/// full screen. On touch screens, a tap shows or hides the controls.
class PlayerView extends StatefulWidget {
  final PlayerController controller;
  final bool isFullscreen;
  final VoidCallback onToggleFullscreen;

  /// Shows a channel list button in the control bar when set.
  final VoidCallback? onShowChannels;

  /// Show previous / next channel buttons when set.
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;

  /// Shows a favorite button in the control bar when set.
  final ValueChanged<Channel>? onToggleFavorite;

  const PlayerView({
    super.key,
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    this.onShowChannels,
    this.onPreviousChannel,
    this.onNextChannel,
    this.onToggleFavorite,
  });

  @override
  State<PlayerView> createState() => _PlayerViewState();
}

class _PlayerViewState extends State<PlayerView> {
  static const _hideDelay = Duration(seconds: 3);

  bool _controlsVisible = true;

  /// The pointer is over the control bar: keep it visible.
  bool _overControls = false;
  PointerDeviceKind _lastPointer = PointerDeviceKind.touch;
  Timer? _hideTimer;

  PlayerController get player => widget.controller;

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
      if (mounted &&
          !_overControls &&
          player.status.value == PlaybackStatus.playing) {
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
    if (_lastPointer == PointerDeviceKind.mouse) {
      player.togglePlay();
      _showControls();
      return;
    }
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _scheduleHide();
    }
  }

  /// Runs [action] from a control and keeps the controls up a bit longer.
  VoidCallback? _control(VoidCallback? action) {
    if (action == null) {
      return null;
    }
    return () {
      action();
      _scheduleHide();
    };
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _showControls(),
      cursor: _controlsVisible ? MouseCursor.defer : SystemMouseCursors.none,
      child: ColoredBox(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Only around the video: a double tap recognizer above the
            // control bar would delay every button press.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _lastPointer = details.kind ?? _lastPointer,
              onTap: _onTap,
              onDoubleTap: isDesktop ? widget.onToggleFullscreen : null,
              child: Obx(
                () => _VideoSurface(
                  video: player.isVideoReady.value ? player.video.value : null,
                  aspectRatio: player.aspectRatio.value,
                ),
              ),
            ),
            Obx(
              () => _StatusLayer(
                status: player.status.value,
                errorMessage: player.errorMessage.value,
                onRetry: player.retry,
                onPlay: player.togglePlay,
              ),
            ),
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: MouseRegion(
                    onEnter: (_) => _overControls = true,
                    onExit: (_) {
                      _overControls = false;
                      _scheduleHide();
                    },
                    child: _ControlBar(
                      controller: player,
                      isFullscreen: widget.isFullscreen,
                      onToggleFullscreen: _control(widget.onToggleFullscreen),
                      onTogglePlay: _control(player.togglePlay),
                      onNextSource: _control(player.nextSource),
                      onShowChannels: widget.onShowChannels,
                      onPreviousChannel: _control(widget.onPreviousChannel),
                      onNextChannel: _control(widget.onNextChannel),
                      onToggleFavorite: widget.onToggleFavorite,
                      onInteraction: _scheduleHide,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Large play button in the middle of a paused video.
class _CenterPlayButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _CenterPlayButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black45,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: const Tooltip(
          message: 'Play',
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 64,
              color: Colors.white,
            ),
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
  final VoidCallback onPlay;

  const _StatusLayer({
    required this.status,
    required this.errorMessage,
    required this.onRetry,
    required this.onPlay,
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
      case PlaybackStatus.paused:
        return Center(child: _CenterPlayButton(onPressed: onPlay));
      case PlaybackStatus.playing:
        return const SizedBox.shrink();
    }
  }
}

class _ControlBar extends StatelessWidget {
  /// Below this width only the main buttons are shown.
  static const _compactWidth = 600.0;

  final PlayerController controller;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final VoidCallback? onTogglePlay;
  final VoidCallback? onNextSource;
  final VoidCallback? onShowChannels;
  final VoidCallback? onPreviousChannel;
  final VoidCallback? onNextChannel;
  final ValueChanged<Channel>? onToggleFavorite;

  /// Called while the user drags a slider, to keep the bar visible.
  final VoidCallback onInteraction;

  const _ControlBar({
    required this.controller,
    required this.isFullscreen,
    required this.onToggleFullscreen,
    required this.onTogglePlay,
    required this.onNextSource,
    required this.onShowChannels,
    required this.onPreviousChannel,
    required this.onNextChannel,
    required this.onToggleFavorite,
    required this.onInteraction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < _compactWidth;
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black54, Colors.black87],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 4 : 16,
              compact ? 24 : 48,
              compact ? 4 : 16,
              compact ? 4 : 12,
            ),
            child: IconButtonTheme(
              data: IconButtonThemeData(
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white38,
                  iconSize: compact ? 30 : 36,
                  minimumSize: Size.square(compact ? 48 : 56),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Timeline(controller: controller, onSeek: onInteraction),
                  Row(
                    children: [
                      _playButton(),
                      if (!compact && onPreviousChannel != null)
                        IconButton(
                          tooltip: 'Previous channel',
                          onPressed: onPreviousChannel,
                          icon: const Icon(Icons.skip_previous_rounded),
                        ),
                      if (!compact && onNextChannel != null)
                        IconButton(
                          tooltip: 'Next channel',
                          onPressed: onNextChannel,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      if (isDesktop)
                        _VolumeControl(
                          controller: controller,
                          showSlider: !compact,
                          onChanged: onInteraction,
                        ),
                      if (!compact) _LiveBadge(controller: controller),
                      Expanded(child: _title(compact)),
                      _sourceButton(compact),
                      if (onToggleFavorite != null) _favoriteButton(),
                      if (onShowChannels != null)
                        IconButton(
                          tooltip: 'Channels',
                          onPressed: onShowChannels,
                          icon: const Icon(Icons.playlist_play_rounded),
                        ),
                      IconButton(
                        tooltip: isFullscreen
                            ? 'Exit full screen'
                            : 'Full screen',
                        onPressed: onToggleFullscreen,
                        icon: Icon(
                          isFullscreen
                              ? Icons.fullscreen_exit_rounded
                              : Icons.fullscreen_rounded,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _playButton() {
    return Obx(() {
      final playing =
          controller.status.value == PlaybackStatus.playing ||
          controller.status.value == PlaybackStatus.buffering;
      return IconButton(
        tooltip: playing ? 'Pause' : 'Play',
        onPressed: controller.channel.value == null ? null : onTogglePlay,
        icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
      );
    });
  }

  Widget _title(bool compact) {
    return Obx(() {
      final channel = controller.channel.value;
      if (channel == null) {
        return const SizedBox.shrink();
      }
      final count = channel.urls.length;
      final details = [
        categoriesLabel(channel),
        if (count > 1) 'Source ${controller.sourceIndex.value + 1} of $count',
      ].where((text) => text.isNotEmpty).join(' · ');
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              channel.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 16 : 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (!compact && details.isNotEmpty)
              Text(
                details,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
          ],
        ),
      );
    });
  }

  Widget _sourceButton(bool compact) {
    return Obx(() {
      final count = controller.channel.value?.urls.length ?? 0;
      if (count < 2) {
        return const SizedBox.shrink();
      }
      return TextButton.icon(
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          iconSize: compact ? 26 : 30,
          textStyle: const TextStyle(fontSize: 16),
          minimumSize: Size(64, compact ? 48 : 56),
        ),
        onPressed: onNextSource,
        icon: const Icon(Icons.swap_horiz_rounded),
        label: Tooltip(
          message: 'Next source',
          child: Text('${controller.sourceIndex.value + 1}/$count'),
        ),
      );
    });
  }

  Widget _favoriteButton() {
    return Obx(() {
      final channel = controller.channel.value;
      if (channel == null) {
        return const SizedBox.shrink();
      }
      return FavoriteButton(
        favorite: channel.favorite,
        color: Colors.white,
        onPressed: () => onToggleFavorite!(channel),
      );
    });
  }
}

/// Seek bar for streams with a known length. Live streams show nothing
/// here; the [_LiveBadge] marks them instead.
class _Timeline extends StatelessWidget {
  final PlayerController controller;
  final VoidCallback onSeek;

  const _Timeline({required this.controller, required this.onSeek});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final video = controller.isVideoReady.value
          ? controller.video.value
          : null;
      if (video == null) {
        return const SizedBox.shrink();
      }
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: video,
        builder: (context, value, _) {
          if (isLiveStream(controller, value)) {
            return const SizedBox.shrink();
          }
          final total = value.duration.inMilliseconds;
          final position = value.position.inMilliseconds.clamp(0, total);
          return Row(
            children: [
              Expanded(
                child: SliderTheme(
                  data: const SliderThemeData(
                    activeTrackColor: _accent,
                    inactiveTrackColor: Colors.white30,
                    thumbColor: _accent,
                    trackHeight: 4,
                    overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: position.toDouble(),
                    max: total.toDouble(),
                    onChanged: (ms) {
                      onSeek();
                      video.seekTo(Duration(milliseconds: ms.round()));
                    },
                  ),
                ),
              ),
              Text(
                formatDuration(value.duration - value.position),
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(width: 8),
            ],
          );
        },
      );
    });
  }
}

/// Red accent of the seek bar and live badge.
const _accent = Color(0xFFE50914);

/// Live TV has no fixed length. HLS playlists (.m3u8) are treated as live,
/// since players report the current window of a live playlist as length.
bool isLiveStream(PlayerController controller, VideoPlayerValue value) {
  final channel = controller.channel.value;
  final index = controller.sourceIndex.value;
  final url = channel != null && index < channel.urls.length
      ? channel.urls[index].toLowerCase()
      : '';
  return value.duration <= Duration.zero ||
      value.duration > const Duration(days: 1) ||
      Uri.tryParse(url)?.path.endsWith('.m3u8') == true;
}

String formatDuration(Duration duration) {
  final seconds = duration.inSeconds.abs();
  final h = seconds ~/ 3600;
  final m = (seconds ~/ 60) % 60;
  final s = (seconds % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

class _LiveBadge extends StatelessWidget {
  final PlayerController controller;

  const _LiveBadge({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final video = controller.isVideoReady.value
          ? controller.video.value
          : null;
      if (video == null) {
        return const SizedBox.shrink();
      }
      return ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: video,
        builder: (context, value, _) {
          if (!isLiveStream(controller, value)) {
            return const SizedBox.shrink();
          }
          return Container(
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _accent,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'LIVE',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
          );
        },
      );
    });
  }
}

/// Mute button; pointing at it shows a volume slider next to it.
class _VolumeControl extends StatefulWidget {
  final PlayerController controller;
  final bool showSlider;
  final VoidCallback onChanged;

  const _VolumeControl({
    required this.controller,
    required this.showSlider,
    required this.onChanged,
  });

  @override
  State<_VolumeControl> createState() => _VolumeControlState();
}

class _VolumeControlState extends State<_VolumeControl> {
  bool _expanded = false;

  PlayerController get controller => widget.controller;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _expanded = true),
      onExit: (_) => setState(() => _expanded = false),
      child: Obx(() {
        final level = controller.muted.value ? 0.0 : controller.volume.value;
        final IconData icon;
        if (level == 0) {
          icon = Icons.volume_off_rounded;
        } else if (level < 0.5) {
          icon = Icons.volume_down_rounded;
        } else {
          icon = Icons.volume_up_rounded;
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: controller.muted.value ? 'Unmute' : 'Mute',
              onPressed: () {
                controller.toggleMute();
                widget.onChanged();
              },
              icon: Icon(icon),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 150),
              child: SizedBox(
                width: widget.showSlider && _expanded ? 112 : 0,
                child: widget.showSlider && _expanded
                    ? SliderTheme(
                        data: const SliderThemeData(
                          activeTrackColor: Colors.white,
                          inactiveTrackColor: Colors.white30,
                          thumbColor: Colors.white,
                          trackHeight: 3,
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: level,
                          onChanged: (value) {
                            controller.setVolume(value);
                            widget.onChanged();
                          },
                        ),
                      )
                    : null,
              ),
            ),
          ],
        );
      }),
    );
  }
}
