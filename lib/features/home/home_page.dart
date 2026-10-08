import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:tv/app/theme.dart';
import 'package:tv/features/home/home_controller.dart';
import 'package:tv/features/home/widgets/mobile_browser.dart';
import 'package:tv/features/home/widgets/navigation_menu.dart';
import 'package:tv/features/home/widgets/now_playing_bar.dart';
import 'package:tv/features/player/widgets/player_view.dart';

class HomePage extends GetView<HomeController> {
  /// Minimum width for the sidebar layout (Material "expanded" class).
  static const wideLayoutWidth = 840.0;

  const HomePage({super.key});

  static bool isWide(Size size) =>
      size.width >= wideLayoutWidth ||
      (size.width >= 640 && size.width > size.height * 1.2);

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (node, event) => _handleKey(event),
      child: LayoutBuilder(
        builder: (context, constraints) => Obx(() {
          if (controller.isFullscreen.value) {
            return _TheaterView(controller: controller, fullscreen: true);
          }
          if (!isWide(constraints.biggest)) {
            return _CompactView(controller: controller);
          }
          if (controller.channels.isEmpty && !controller.isLoading.value) {
            return _EmptyWideView(controller: controller);
          }
          return _TheaterView(controller: controller, fullscreen: false);
        }),
      ),
    );
  }

  /// Keyboard control for desktop (and TV remotes with a D-pad). Keys are
  /// left alone while a text field has focus.
  KeyEventResult _handleKey(KeyEvent event) {
    if (event is! KeyDownEvent || _isTyping()) {
      return KeyEventResult.ignored;
    }
    final player = controller.player;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.mediaPlayPause) {
      player.togglePlay();
    } else if (key == LogicalKeyboardKey.keyF) {
      controller.toggleFullscreen();
    } else if (key == LogicalKeyboardKey.escape) {
      if (controller.menuVisible.value) {
        controller.menuVisible.value = false;
      } else if (controller.isFullscreen.value) {
        controller.setFullscreen(false);
      } else {
        return KeyEventResult.ignored;
      }
    } else if (key == LogicalKeyboardKey.keyM) {
      player.toggleMute();
    } else if (key == LogicalKeyboardKey.keyC) {
      controller.menuVisible.toggle();
    } else if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.channelUp) {
      controller.playAdjacent(-1);
    } else if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.channelDown) {
      controller.playAdjacent(1);
    } else if (key == LogicalKeyboardKey.keyS) {
      player.nextSource();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  static bool _isTyping() {
    final context = FocusManager.instance.primaryFocus?.context;
    return context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }
}

/// Wide screen without channels: the menu as a sidebar next to the
/// empty state, so adding a playlist is one click away.
class _EmptyWideView extends StatelessWidget {
  final HomeController controller;

  const _EmptyWideView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            NavigationMenu(controller: controller),
            Expanded(child: EmptyLibrary(controller: controller)),
          ],
        ),
      ),
    );
  }
}

/// Phone layout: player on top, section chips and channel list below.
class _CompactView extends StatefulWidget {
  final HomeController controller;

  const _CompactView({required this.controller});

  @override
  State<_CompactView> createState() => _CompactViewState();
}

class _CompactViewState extends State<_CompactView> {
  bool _searching = false;

  HomeController get controller => widget.controller;

  void _setSearching(bool value) {
    setState(() => _searching = value);
    if (!value) {
      controller.setQuery('');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_searching,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _setSearching(false);
      },
      child: Scaffold(
        appBar: _searching ? _searchBar() : _titleBar(),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: PlayerView(
                controller: controller.player,
                isFullscreen: false,
                onToggleFullscreen: controller.toggleFullscreen,
              ),
            ),
            NowPlayingBar(
              player: controller.player,
              onToggleFavorite: controller.toggleFavorite,
            ),
            Expanded(child: MobileBrowser(controller: controller)),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _titleBar() {
    return AppBar(
      title: const Text('WatchTV'),
      actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: () => _setSearching(true),
          icon: const Icon(Icons.search),
        ),
        IconButton(
          tooltip: 'Add playlist',
          onPressed: controller.importPlaylist,
          icon: const Icon(Icons.playlist_add),
        ),
        IconButton(
          tooltip: 'Manage library',
          onPressed: controller.openManager,
          icon: const Icon(Icons.video_library_outlined),
        ),
      ],
    );
  }

  PreferredSizeWidget _searchBar() {
    return AppBar(
      leading: IconButton(
        tooltip: 'Close search',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _setSearching(false),
      ),
      title: TextField(
        autofocus: true,
        onChanged: controller.setQuery,
        decoration: const InputDecoration(
          hintText: 'Search channels',
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
        ),
      ),
    );
  }
}

/// The video fills the window (or the screen in full screen). The menu
/// slides in over it when the pointer touches the left edge, from the
/// channels button in the control bar, or with the C key.
class _TheaterView extends StatelessWidget {
  final HomeController controller;
  final bool fullscreen;

  const _TheaterView({required this.controller, required this.fullscreen});

  void _hideMenu() => controller.menuVisible.value = false;

  void _showMenu() => controller.menuVisible.value = true;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final menuVisible = controller.menuVisible.value;
      return PopScope(
        canPop: !menuVisible && !fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          if (menuVisible) {
            _hideMenu();
          } else {
            controller.setFullscreen(false);
          }
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: PlayerView(
                  controller: controller.player,
                  isFullscreen: fullscreen,
                  onToggleFullscreen: controller.toggleFullscreen,
                  onShowChannels: _showMenu,
                  onPreviousChannel: () => controller.playAdjacent(-1),
                  onNextChannel: () => controller.playAdjacent(1),
                  onToggleFavorite: controller.toggleFavorite,
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 12,
                child: MouseRegion(opaque: false, onEnter: (_) => _showMenu()),
              ),
              if (menuVisible) ...[
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _hideMenu,
                    child: const SizedBox.expand(),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  // Dark over the video, whatever the app theme.
                  child: Theme(
                    data: AppTheme.dark(),
                    child: SafeArea(
                      right: false,
                      child: NavigationMenu(
                        controller: controller,
                        onDone: _hideMenu,
                        overVideo: true,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
