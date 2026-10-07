import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/widgets/channel_browser.dart';
import 'package:tv/features/home/widgets/now_playing_bar.dart';
import 'package:tv/features/player/widgets/player_view.dart';

class HomePage extends GetView<HomeController> {
  /// Minimum width for the side-by-side layout (Material "expanded" class).
  static const wideLayoutWidth = 840.0;

  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isFullscreen.value) {
        return _FullscreenPlayer(controller: controller);
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('WatchTV'),
          actions: [
            IconButton(
              tooltip: 'Add channels',
              onPressed: controller.addChannels,
              icon: const Icon(Icons.playlist_add),
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            final wide =
                constraints.maxWidth >= wideLayoutWidth ||
                constraints.maxWidth > constraints.maxHeight * 1.2;
            return wide
                ? _WideLayout(controller: controller)
                : _CompactLayout(controller: controller);
          },
        ),
      );
    });
  }
}

class _CompactLayout extends StatelessWidget {
  final HomeController controller;

  const _CompactLayout({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InlinePlayer(controller: controller),
        NowPlayingBar(player: controller.player),
        const SizedBox(height: 4),
        Expanded(child: ChannelBrowser(controller: controller)),
      ],
    );
  }
}

class _WideLayout extends StatelessWidget {
  final HomeController controller;

  const _WideLayout({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(left: 16, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _InlinePlayer(controller: controller),
                ),
                NowPlayingBar(player: controller.player),
              ],
            ),
          ),
        ),
        Expanded(flex: 2, child: ChannelBrowser(controller: controller)),
      ],
    );
  }
}

class _InlinePlayer extends StatelessWidget {
  final HomeController controller;

  const _InlinePlayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: PlayerView(
        controller: controller.player,
        isFullscreen: false,
        onToggleFullscreen: controller.toggleFullscreen,
      ),
    );
  }
}

class _FullscreenPlayer extends StatelessWidget {
  final HomeController controller;

  const _FullscreenPlayer({required this.controller});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => controller.setFullscreen(false),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: PlayerView(
          controller: controller.player,
          isFullscreen: true,
          onToggleFullscreen: controller.toggleFullscreen,
        ),
      ),
    );
  }
}
