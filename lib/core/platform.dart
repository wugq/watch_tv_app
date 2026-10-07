import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:video_player_media_kit/video_player_media_kit.dart';
import 'package:window_manager/window_manager.dart';

bool get isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Windows and Linux have no official video_player / sqflite implementation,
/// so media_kit and sqflite FFI are used there.
bool get usesMediaKit => !kIsWeb && (Platform.isWindows || Platform.isLinux);

/// Registers the platform implementations. Call once before `runApp`.
///
/// * Windows / Linux: media_kit (libmpv) for video_player, sqflite FFI.
/// * Android / iOS / macOS: the official implementations.
Future<void> setUpPlatform() async {
  if (usesMediaKit) {
    VideoPlayerMediaKit.ensureInitialized(windows: true, linux: true);
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  if (isDesktop) {
    await windowManager.ensureInitialized();
    await windowManager.setMinimumSize(const Size(480, 360));
  }
}

/// Full screen: the window on desktop, immersive landscape on mobile.
Future<void> setAppFullscreen(bool fullscreen) async {
  try {
    if (isDesktop) {
      await windowManager.setFullScreen(fullscreen);
    } else if (fullscreen) {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      await SystemChrome.setPreferredOrientations(const []);
    }
  } on MissingPluginException {
    // No window plugin (e.g. in widget tests): the layout still switches.
  }
}
