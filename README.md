# WatchTV

[![CI](https://github.com/wugq/watch_tv_app/actions/workflows/ci.yml/badge.svg)](https://github.com/wugq/watch_tv_app/actions/workflows/ci.yml)

Watch your live stream with WatchTV app. This app DOES NOT provide any live stream content.

## Getting Started

Add a live stream channel to this app and start watching.

| Main Screen                                              | Add multiple Channels                                    | Add a channel                                            |
|:--------------------------------------------------------:|:--------------------------------------------------------:|:--------------------------------------------------------:|
| ![Screen](./screen_shots/Screenshot_20220309-100404.png) | ![Screen](./screen_shots/Screenshot_20220309-100347.png) | ![Screen](./screen_shots/Screenshot_20220309-100210.png) |

## Adding channels

The add page has three tabs:

* **Single**: channel name, one or more stream URLs (one per line) and an optional category.
* **Batch**: paste a channel list (TXT or M3U).
* **Import**: load a TXT or M3U playlist from a file or a URL, check the summary, then import.

TXT format, one source per line:

```text
News,#genre#
Channel A, https://example.com/a.m3u8
Channel A, https://backup.example.com/a.m3u8
Channel B, https://example.com/b.m3u8#https://backup.example.com/b.m3u8
```

* A `Category,#genre#` line sets the category of the lines after it.
* Several URLs on one line can be separated by `#`.

M3U playlists (starting with `#EXTM3U`) use `group-title` as the category.

## Multiple sources

Lines with the same channel name become one channel with several sources.
Importing a channel that already exists appends the new sources (duplicates
are skipped). When a source fails or does not start within 20 seconds, the
player tries the next one. The source button in the player (`1/3`) switches
sources by hand.

Long-press a channel, or use its menu, to edit or delete it.

Plain `http://` streams are allowed: `android:usesCleartextTraffic="true"` on
Android and `NSAllowsArbitraryLoadsForMedia` (media playback only) on iOS and macOS.

## Platforms

| Platform | Video | Database |
|---|---|---|
| Android | video_player (ExoPlayer) | sqflite |
| iOS | video_player (AVPlayer) | sqflite |
| macOS | video_player (AVPlayer) | sqflite |
| Windows | video_player + [video_player_media_kit](https://pub.dev/packages/video_player_media_kit) (libmpv) | sqflite_common_ffi |
| Linux | video_player + video_player_media_kit (libmpv) | sqflite_common_ffi |

The backends are chosen in `lib/core/platform.dart`, so the rest of the app
only uses the `video_player` API.

On desktop the database is stored in the application support directory
(for example `~/.local/share/dev.wugq.tv/` on Linux).

### Linux build requirements

```sh
sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev libmpv-dev mpv
```

The media_kit Linux plugin downloads the mimalloc source from GitHub during
the CMake step.

### Windows

media_kit downloads prebuilt libmpv binaries during the build.

### Keyboard (desktop)

| Key | Action |
|---|---|
| Space | Play / pause |
| F | Full screen |
| Esc | Exit full screen |
| Up / Down | Previous / next channel |
| S | Next source |

## Tech stack

* [Flutter](https://flutter.dev/) 3.47 (Dart 3.13), Material 3 with light and dark theme
* [GetX](https://pub.dev/packages/get) for routing, dependency injection and state
* [video_player](https://pub.dev/packages/video_player) (ExoPlayer on Android, AVPlayer on iOS)
* [sqflite](https://pub.dev/packages/sqflite)
* [wakelock_plus](https://pub.dev/packages/wakelock_plus)
* [file_picker](https://pub.dev/packages/file_picker) and [http](https://pub.dev/packages/http) for playlist import
* [media_kit](https://pub.dev/packages/media_kit) via video_player_media_kit (Windows, Linux)
* [window_manager](https://pub.dev/packages/window_manager) for desktop full screen

## Project structure

```text
lib/
  main.dart                 opens the database, registers ChannelRepository
  app/                      app widget, theme, routes and bindings
  core/                     helpers, platform setup (video / database backends, full screen)
  data/
    models/                 Channel
    sources/                sqflite database (schema v2), playlist loader (file / URL)
    repositories/           ChannelRepository (interface + sqflite implementation)
    parsers/                channel list / M3U parser
  features/
    player/                 PlayerController (video_player wrapper) and PlayerView
    home/                   HomeController, HomePage and its widgets
    channel_editor/         add / edit channel page
```

Controllers get their dependencies through the constructor, so tests use an
in-memory repository and a fake player (`test/helpers/fakes.dart`).

## Development

```sh
flutter pub get
flutter analyze
flutter test
flutter run
```

## CI

`.github/workflows/ci.yml` runs format check, `flutter analyze` and
`flutter test`, then builds Android (APK), Linux, Windows, macOS (unsigned)
and iOS (compile only, no codesign). Builds are uploaded as workflow
artifacts.

The logo is downloaded from [flaticon](https://www.flaticon.com/)

## Roadmap

- [x] support tablet (side-by-side layout on wide screens)

- [ ] support TV (D-pad navigation; arrow keys already switch channels)

- [x] support desktop (macOS, Windows, Linux)

- [x] support Dark and Light Mode

- [x] support m3u / txt playlist (paste, file, URL)

- [x] multiple sources per channel with automatic fallback

- [ ] refresh imported playlists from their URL
