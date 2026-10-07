import 'package:flutter_test/flutter_test.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/parsers/channel_list_parser.dart';

void main() {
  group('ChannelListParser text format', () {
    test('parses "Name, URL" lines', () {
      final channels = ChannelListParser.parse(
        'A, http://example.com/a.m3u8\n\nB,https://example.com/b.m3u8\n',
      );

      expect(channels.map((c) => c.name), ['A', 'B']);
      expect(channels.first.url, 'http://example.com/a.m3u8');
      expect(channels.first.category, Channel.defaultCategory);
    });

    test('keeps commas in the URL', () {
      final channels = ChannelListParser.parse(
        'A, http://example.com/live?ids=1,2',
      );

      expect(channels.single.url, 'http://example.com/live?ids=1,2');
    });

    test('applies #genre# category to the lines that follow', () {
      final channels = ChannelListParser.parse(
        'X, http://example.com/x\n'
        'News,#genre#\n'
        'A, http://example.com/a\n'
        'Sport,#genre#\n'
        'B, http://example.com/b',
        defaultCategory: 'Mine',
      );

      expect(channels.map((c) => c.category), ['Mine', 'News', 'Sport']);
    });

    test('skips lines without a valid URL', () {
      final channels = ChannelListParser.parse(
        'no comma here\n,http://example.com/x\nA, not a url\n',
      );

      expect(channels, isEmpty);
    });
  });

  group('ChannelListParser M3U format', () {
    test('uses group-title as category', () {
      final channels = ChannelListParser.parse(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="a" group-title="News",Channel A\n'
        'http://example.com/a.m3u8\n'
        '#EXTINF:-1,Channel B\n'
        '#EXTVLCOPT:http-user-agent=x\n'
        'http://example.com/b.m3u8\n',
      );

      expect(channels.map((c) => c.name), ['Channel A', 'Channel B']);
      expect(channels.map((c) => c.category), [
        'News',
        Channel.defaultCategory,
      ]);
      expect(channels.last.url, 'http://example.com/b.m3u8');
    });
  });

  test('isStreamUrl', () {
    expect(ChannelListParser.isStreamUrl('rtmp://host/live'), isTrue);
    expect(ChannelListParser.isStreamUrl('example.com/a.m3u8'), isFalse);
    expect(ChannelListParser.isStreamUrl('http://'), isFalse);
  });
}
