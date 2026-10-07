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
  Future<void> save(Channel channel) async {
    _channels.removeWhere((c) => c.key == channel.key);
    _channels.add(channel);
  }

  @override
  Future<void> saveAll(Iterable<Channel> channels) async {
    for (final channel in channels) {
      await save(channel);
    }
  }

  @override
  Future<void> replace(Channel oldChannel, Channel newChannel) async {
    await delete(oldChannel.key);
    await save(newChannel);
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
  Future<void> play(Channel newChannel) async {
    played.add(newChannel);
    channel.value = newChannel;
    status.value = PlaybackStatus.playing;
  }

  @override
  Future<void> stop() async {
    channel.value = null;
    status.value = PlaybackStatus.idle;
  }
}
