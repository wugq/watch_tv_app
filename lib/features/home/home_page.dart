import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
      child: Obx(() {
        if (controller.isFullscreen.value) {
          return _FullscreenView(controller: controller);
        }
        return LayoutBuilder(
          builder: (context, constraints) => isWide(constraints.biggest)
              ? _WideView(controller: controller)
              : _CompactView(controller: controller),
        );
      }),
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
      if (!controller.isFullscreen.value) {
        return KeyEventResult.ignored;
      }
      controller.setFullscreen(false);
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

/// Sidebar menu on the left, large player on the right.
class _WideView extends StatelessWidget {
  final HomeController controller;

  const _WideView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(width: NavigationMenu.sidebarWidth),
                Expanded(
                  child: Obx(
                    () =>
                        controller.channels.isEmpty &&
                            !controller.isLoading.value
                        ? EmptyLibrary(controller: controller)
                        : _PlayerArea(controller: controller),
                  ),
                ),
              ],
            ),
            // On top of the player, so the second level can open over it.
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: NavigationMenu(controller: controller),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerArea extends StatelessWidget {
  final HomeController controller;

  const _PlayerArea({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: PlayerView(
                controller: controller.player,
                isFullscreen: false,
                onToggleFullscreen: controller.toggleFullscreen,
              ),
            ),
          ),
          NowPlayingBar(
            player: controller.player,
            onToggleFavorite: controller.toggleFavorite,
          ),
        ],
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

/// Player only. The menu slides in when the pointer touches the left edge,
/// or from the menu button in the control bar.
class _FullscreenView extends StatefulWidget {
  final HomeController controller;

  const _FullscreenView({required this.controller});

  @override
  State<_FullscreenView> createState() => _FullscreenViewState();
}

class _FullscreenViewState extends State<_FullscreenView> {
  bool _menuVisible = false;

  void _showMenu() => setState(() => _menuVisible = true);

  void _hideMenu() {
    if (mounted && _menuVisible) setState(() => _menuVisible = false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (_menuVisible) {
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
                isFullscreen: true,
                onToggleFullscreen: controller.toggleFullscreen,
                onShowChannels: _showMenu,
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 12,
              child: MouseRegion(opaque: false, onEnter: (_) => _showMenu()),
            ),
            if (_menuVisible) ...[
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _hideMenu,
                  child: const ColoredBox(color: Colors.black26),
                ),
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: NavigationMenu(
                  controller: controller,
                  onDone: _hideMenu,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
