# Backlog

Ideas and planned work that is not scheduled yet. Facts were checked in
October 2026; check them again before starting.

## LG webOS TV version

Run WatchTV as a native app on LG TVs.

### Status of the platform

- LG released Flutter for webOS TV (the `flutter-webos` SDK). It supports
  **webOS 26 Re:New and later**; TVs that shipped with webOS 26 need the
  Re:New update.
  - Announcement: <https://webostv.developer.lge.com/news/flutter-for-webos-tv-is-now-available-for-developers>
  - SDK: <https://github.com/lg-flutter-webos/flutter-webos>
- `flutter-webos` is pinned to **Flutter 3.38.10 / Dart 3.10**
  (`bin/internal/flutter.version`). This project uses Flutter 3.47 / Dart
  3.13, and some dependencies need it too. LG plans Flutter upgrades in the
  second half of 2026.
- Development is supported on Ubuntu only (22.04, 24.04, 26.04); WSL2 or
  a dev container otherwise. Apps are installed on a TV in Developer Mode;
  publishing in the LG Content Store is a separate review process.

### Plugins

From the [plugin list](https://github.com/lg-flutter-webos/plugins/blob/main/doc/plugin-list.md):

| Needed by WatchTV | webOS plugin |
|---|---|
| video_player | `video_player_webos` |
| sqflite | `sqflite_webos` |
| path_provider | `path_provider_webos` |
| http | pure Dart, no plugin needed |
| file_picker | none (import from a URL is enough on a TV) |
| wakelock_plus | none (check whether video playback keeps the screen on) |
| window_manager, media_kit | not needed on a TV |

### Work

1. **Flutter version.** Either wait until `flutter-webos` reaches the
   Flutter version of this project, or move the shared code into a package
   that also builds with Dart 3.10 and add a separate webOS app. Waiting is
   much less work.
2. **Platform detection.** webOS is Linux, so `Platform.isLinux` is true
   there. `lib/core/platform.dart` must detect webOS and not set up
   media_kit, sqflite FFI or window_manager; use the webOS plugins instead.
3. **Remote control.** No pointer hover on a TV:
   - Two-level menu driven by the D-pad and OK, with a clear focus
     highlight. Back steps out one level (webOS Back key code 461).
   - Up/Down already switch channels while the video has focus.
   - Larger text and targets for viewing from a distance ("10-foot UI").
4. **Build.** Build the IPK in CI on an Ubuntu runner
   (`flutter-webos build webos --release`, output in
   `build/webos/{arch}/release/ipk/`).

### Open questions (need a real TV)

- Does `video_player_webos` send custom HTTP headers (User-Agent,
  Referer)? Many iptv-org sources need them.
- Which stream types play (HLS, MPEG-TS over HTTP, RTMP)?
- Performance with large playlists (10 000+ channels) on TV hardware.
