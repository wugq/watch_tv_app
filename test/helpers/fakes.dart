import 'package:tv/data/models/channel.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/features/player/player_controller.dart';

class InMemoryChannelRepository implements ChannelRepository {
  final List<Channel> _channels;

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
  Future<void> delete(String key) async {
    _channels.removeWhere((c) => c.key == key);
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
