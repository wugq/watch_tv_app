# WatchTV

Watch your live stream with WatchTV app. This app DOES NOT provide any live stream content.

## Getting Started

Add a live stream channel to this app and start watching.

| Main Screen                                              | Add multiple Channels                                    | Add a channel                                            |
|:--------------------------------------------------------:|:--------------------------------------------------------:|:--------------------------------------------------------:|
| ![Screen](./screen_shots/Screenshot_20220309-100404.png) | ![Screen](./screen_shots/Screenshot_20220309-100347.png) | ![Screen](./screen_shots/Screenshot_20220309-100210.png) |

## Adding channels

* **Single**: channel name, stream URL and an optional category.
* **Batch**: paste a list, one channel per line:

  ```text
  News,#genre#
  Channel A, https://example.com/a.m3u8
  Channel B, https://example.com/b.m3u8
  ```

  A `Category,#genre#` line sets the category of the lines after it.
  M3U playlists (starting with `#EXTM3U`) are also accepted; `group-title` is used as the category.

Long-press a channel, or use its menu, to edit or delete it.

## Tech stack

* [Flutter](https://flutter.dev/) 3.47 (Dart 3.13), Material 3 with light and dark theme
* [GetX](https://pub.dev/packages/get) for routing, dependency injection and state
* [video_player](https://pub.dev/packages/video_player) (ExoPlayer on Android, AVPlayer on iOS)
* [sqflite](https://pub.dev/packages/sqflite)
* [wakelock_plus](https://pub.dev/packages/wakelock_plus)

## Project structure

```text
lib/
  main.dart                 opens the database, registers ChannelRepository
  app/                      app widget, theme, routes and bindings
  core/                     small helpers
  data/
    models/                 Channel
    sources/                sqflite database
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

- [x] support m3u playlist (paste)

- [ ] import m3u file / URL
