import 'package:flutter_test/flutter_test.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/parsers/channel_list_parser.dart';

void main() {
  group('TXT', () {
    test('parses "Name,URL" lines', () {
      final channels = ChannelListParser.parse(
        'A, http://example.com/a.m3u8\n\nB,https://example.com/b.m3u8\n',
      );

      expect(channels.map((c) => c.name), ['A', 'B']);
      expect(channels.first.urls, ['http://example.com/a.m3u8']);
      expect(channels.first.category, Channel.defaultCategory);
    });

    test('keeps commas in the URL', () {
      final channels = ChannelListParser.parse(
        'A, http://example.com/live?ids=1,2',
      );

      expect(channels.single.urls, ['http://example.com/live?ids=1,2']);
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

    test('merges lines with the same name into sources', () {
      final channels = ChannelListParser.parse(
        '央视频道,#genre#\n'
        'CCTV1,http://a/1.m3u8\n'
        'CCTV2,http://a/2.m3u8\n'
        'CCTV1,http://b/1.m3u8?key=x&playlive=0\n'
        'CCTV1,http://a/1.m3u8\n',
      );

      expect(channels.map((c) => c.name), ['CCTV1', 'CCTV2']);
      expect(channels.first.urls, [
        'http://a/1.m3u8',
        'http://b/1.m3u8?key=x&playlive=0',
      ]);
      expect(channels.first.category, '央视频道');
    });

    test('splits several URLs separated by #', () {
      final channels = ChannelListParser.parse(
        'A,http://a/1.m3u8#http://b/1.m3u8#rtmp://c/live',
      );

      expect(channels.single.urls, [
        'http://a/1.m3u8',
        'http://b/1.m3u8',
        'rtmp://c/live',
      ]);
    });

    test('skips lines without a valid URL', () {
      final channels = ChannelListParser.parse(
        'no comma here\n,http://example.com/x\nA, not a url\n',
      );

      expect(channels, isEmpty);
    });

    test('ignores a UTF-8 BOM and CRLF line ends', () {
      final channels = ChannelListParser.parse(
        '﻿News,#genre#\r\nA,http://a/1\r\n',
      );

      expect(channels.single.category, 'News');
      expect(channels.single.urls, ['http://a/1']);
    });
  });

  group('M3U', () {
    test('uses group-title as category and merges same names', () {
      final channels = ChannelListParser.parse(
        '#EXTM3U x-tvg-url="http://epg.example.com/e.xml"\n'
        '#EXTINF:-1 tvg-name="CCTV1" tvg-logo="https://l/1.png" '
        'group-title="央视频道", CCTV1\n'
        'http://example.com/a.m3u8\n'
        '#EXTINF:-1,Channel B\n'
        '#EXTVLCOPT:http-user-agent=x\n'
        'http://example.com/b.m3u8\n'
        '#EXTINF:-1 group-title="Other",CCTV1\n'
        'http://example.com/a2.m3u8\n',
      );

      expect(channels.map((c) => c.name), ['CCTV1', 'Channel B']);
      expect(channels.map((c) => c.category), [
        '央视频道',
        Channel.defaultCategory,
      ]);
      expect(channels.first.urls, [
        'http://example.com/a.m3u8',
        'http://example.com/a2.m3u8',
      ]);
    });
  });

  test('isStreamUrl', () {
    expect(ChannelListParser.isStreamUrl('rtmp://host/live'), isTrue);
    expect(ChannelListParser.isStreamUrl('example.com/a.m3u8'), isFalse);
    expect(ChannelListParser.isStreamUrl('http://'), isFalse);
  });
}
