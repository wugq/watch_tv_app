# WatchTV

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
Android and `NSAllowsArbitraryLoadsForMedia` (media playback only) on iOS.

## Tech stack

* [Flutter](https://flutter.dev/) 3.47 (Dart 3.13), Material 3 with light and dark theme
* [GetX](https://pub.dev/packages/get) for routing, dependency injection and state
* [video_player](https://pub.dev/packages/video_player) (ExoPlayer on Android, AVPlayer on iOS)
* [sqflite](https://pub.dev/packages/sqflite)
* [wakelock_plus](https://pub.dev/packages/wakelock_plus)
* [file_picker](https://pub.dev/packages/file_picker) and [http](https://pub.dev/packages/http) for playlist import

## Project structure

```text
lib/
  main.dart                 opens the database, registers ChannelRepository
  app/                      app widget, theme, routes and bindings
  core/                     small helpers
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

The logo is downloaded from [flaticon](https://www.flaticon.com/)

## Roadmap

- [x] support tablet (side-by-side layout on wide screens)

- [ ] support TV (D-pad navigation)

- [x] support Dark and Light Mode

- [x] support m3u / txt playlist (paste, file, URL)

- [x] multiple sources per channel with automatic fallback

- [ ] refresh imported playlists from their URL
