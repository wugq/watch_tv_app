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

  group('iptv-org style M3U', () {
    test('keeps commas in attribute values and in the name', () {
      final channels = ChannelListParser.parse(
        '#EXTM3U\n'
        '#EXTINF:-1 tvg-id="a" http-user-agent="Mozilla/5.0 (KHTML, like '
        'Gecko)" group-title="News",Channel, The\n'
        'http://example.com/a.m3u8\n'
        '#EXTINF:-1,Plain, Name\n'
        'http://example.com/b.m3u8\n',
      );

      expect(channels.map((c) => c.name), ['Channel, The', 'Plain, Name']);
      expect(channels.first.category, 'News');
    });

    test('several categories in group-title', () {
      final channels = ChannelListParser.parse(
        '#EXTM3U\n'
        '#EXTINF:-1 group-title="Entertainment; Family;General",A\n'
        'http://example.com/a.m3u8\n',
      );

      expect(channels.single.categories, [
        'Entertainment',
        'Family',
        'General',
      ]);
    });
  });

  test('parseInBackground gives the same result for large texts', () async {
    final text = [
      '#EXTM3U',
      for (var i = 0; i < 6000; i++) ...[
        '#EXTINF:-1 group-title="G${i % 7}",Channel $i',
        'http://example.com/$i.m3u8',
      ],
    ].join('\n');

    final channels = await ChannelListParser.parseInBackground(text);

    expect(text.length, greaterThan(256 * 1024));
    expect(channels, hasLength(6000));
    expect(channels.last.name, 'Channel 5999');
  });

  group('HTTP headers', () {
    test('M3U attributes and EXTVLCOPT lines', () {
      final channels = ChannelListParser.parse(
        '#EXTM3U\n'
        '#EXTINF:-1 http-user-agent="Agent/1.0 (X11, Linux)" '
        'http-referrer="https://site.example/",A\n'
        'https://a.example/live.m3u8\n'
        '#EXTINF:-1,B\n'
        '#EXTVLCOPT:http-user-agent=VLC/3.0\n'
        '#EXTVLCOPT:http-referrer=https://b.example/\n'
        'https://b.example/live.m3u8\n'
        '#EXTINF:-1,C\n'
        'https://c.example/live.m3u8\n',
      );

      final a = channels[0].sources.single;
      expect(a.userAgent, 'Agent/1.0 (X11, Linux)');
      expect(a.referrer, 'https://site.example/');
      expect(a.headers, {
        'User-Agent': 'Agent/1.0 (X11, Linux)',
        'Referer': 'https://site.example/',
      });
      final b = channels[1].sources.single;
      expect(b.userAgent, 'VLC/3.0');
      expect(b.referrer, 'https://b.example/');
      expect(
        channels[2].sources.single.hasHeaders,
        isFalse,
        reason: 'headers do not carry over to the next entry',
      );
    });

    test('URL|User-Agent=...&Referer=... form', () {
      final channels = ChannelListParser.parse(
        'A,https://a.example/live.m3u8|User-Agent=My%20Agent&Referer=https://r.example/\n',
      );

      final source = channels.single.sources.single;
      expect(source.url, 'https://a.example/live.m3u8');
      expect(source.userAgent, 'My Agent');
      expect(source.referrer, 'https://r.example/');
    });

    test('bad percent encoding keeps the raw value', () {
      final source = ChannelListParser.parseSource(
        'https://a.example/x|User-Agent=100%',
      );

      expect(source?.userAgent, '100%');
    });
  });
}
