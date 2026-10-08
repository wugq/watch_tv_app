import 'package:tv/data/models/channel.dart';
import 'package:tv/data/models/custom_category.dart';
import 'package:tv/data/models/playlist.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/features/player/player_controller.dart';

class InMemoryChannelRepository implements ChannelRepository {
  final List<Channel> _channels;
  final _playlists = <Playlist>[];
  final _hiddenCategories = <String>{};
  final _custom = <CustomCategory>[];

  InMemoryChannelRepository([List<Channel>? channels])
    : _channels = [...?channels];

  @override
  Future<List<Channel>> getAll() async => List.of(_channels);

  @override
  Future<ImportResult> import(Iterable<Channel> channels) async {
    var added = 0;
    var updated = 0;
    for (final channel in channels) {
      final index = _channels.indexWhere((c) => c.key == channel.key);
      if (index < 0) {
        _channels.add(channel);
        added++;
      } else {
        _channels[index] = _channels[index].merge(channel);
        updated++;
      }
    }
    return ImportResult(added: added, updated: updated);
  }

  @override
  Future<void> replace(Channel oldChannel, Channel newChannel) async {
    final index = _channels.indexWhere((c) => c.key == oldChannel.key);
    _channels.removeWhere((c) => c.key == newChannel.key);
    if (index < 0 || index > _channels.length) {
      _channels.add(newChannel);
    } else {
      _channels.insert(index, newChannel);
    }
  }

  @override
  Future<void> delete(String key) => deleteAll([key]);

  @override
  Future<void> deleteAll(Iterable<String> keys) async {
    final set = keys.toSet();
    _channels.removeWhere((c) => set.contains(c.key));
  }

  @override
  Future<void> setFavorite(String key, bool favorite) async {
    _update(key, (c) => c.copyWith(favorite: favorite));
  }

  @override
  Future<void> markWatched(String key, DateTime time) async {
    _update(key, (c) => c.copyWith(lastWatched: time));
  }

  @override
  Future<void> setHidden(Iterable<String> keys, bool hidden) async {
    for (final key in keys) {
      _update(key, (c) => c.copyWith(hidden: hidden));
    }
  }

  @override
  Future<Set<String>> getHiddenCategories() async => {..._hiddenCategories};

  @override
  Future<void> setCategoryHidden(Iterable<String> names, bool hidden) async {
    hidden
        ? _hiddenCategories.addAll(names)
        : _hiddenCategories.removeAll(names);
  }

  @override
  Future<List<CustomCategory>> getCustomCategories() async => List.of(_custom);

  @override
  Future<int> createCustomCategory(String name) async {
    final id = _custom.length + 1;
    _custom.add(CustomCategory(id: id, name: name));
    return id;
  }

  @override
  Future<void> renameCustomCategory(int id, String name) async {
    _replaceCustom(
      id,
      (c) => CustomCategory(id: id, name: name, channelKeys: c.channelKeys),
    );
  }

  @override
  Future<void> deleteCustomCategory(int id) async {
    _custom.removeWhere((c) => c.id == id);
  }

  @override
  Future<void> addToCustomCategory(int id, Iterable<String> keys) async {
    _replaceCustom(
      id,
      (c) => CustomCategory(
        id: id,
        name: c.name,
        channelKeys: {...c.channelKeys, ...keys}.toList(),
      ),
    );
  }

  @override
  Future<void> removeFromCustomCategory(int id, Iterable<String> keys) async {
    final remove = keys.toSet();
    _replaceCustom(
      id,
      (c) => CustomCategory(
        id: id,
        name: c.name,
        channelKeys: c.channelKeys.where((k) => !remove.contains(k)).toList(),
      ),
    );
  }

  void _replaceCustom(int id, CustomCategory Function(CustomCategory) change) {
    final index = _custom.indexWhere((c) => c.id == id);
    if (index >= 0) _custom[index] = change(_custom[index]);
  }

  void _update(String key, Channel Function(Channel) change) {
    final index = _channels.indexWhere((c) => c.key == key);
    if (index >= 0) _channels[index] = change(_channels[index]);
  }

  @override
  Future<List<Playlist>> getPlaylists() async => List.of(_playlists);

  @override
  Future<ImportResult> addPlaylist({
    required String name,
    String? url,
    required Iterable<Channel> channels,
  }) async {
    final list = channels.toList();
    _playlists.add(
      Playlist(
        id: _playlists.length + 1,
        name: name,
        url: url,
        updatedAt: DateTime(2026),
        channelCount: list.length,
        sourceCount: list.fold(0, (sum, c) => sum + c.urls.length),
      ),
    );
    return import(list);
  }

  @override
  Future<ImportResult> refreshPlaylist(int id, Iterable<Channel> channels) =>
      import(channels);

  @override
  Future<void> renamePlaylist(int id, String name) async {}

  @override
  Future<void> deletePlaylist(int id) async {
    _playlists.removeWhere((p) => p.id == id);
  }
}

/// Records what would be played, without a real video player.
class FakePlayerController extends PlayerController {
  final played = <Channel>[];

  @override
  Future<void> play(Channel newChannel, {int source = 0}) async {
    played.add(newChannel);
    channel.value = newChannel;
    sourceIndex.value = source;
    status.value = PlaybackStatus.playing;
  }

  @override
  Future<void> stop() async {
    channel.value = null;
    status.value = PlaybackStatus.idle;
  }
}
