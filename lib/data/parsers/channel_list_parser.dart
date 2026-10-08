import 'dart:isolate';

import 'package:tv/data/models/channel.dart';

/// Parses a channel list from a file, a URL or pasted text.
///
/// Two formats are supported:
///
/// * Plain text (TXT), one source per line: `Name,URL`. A line of the form
///   `Category,#genre#` sets the category of the lines that follow it.
///   Several URLs on one line can be separated by `#`.
/// * M3U playlist (starts with `#EXTM3U`). The `group-title` attribute of
///   `#EXTINF` is used as the category.
///
/// HTTP headers are read from the M3U attributes `http-user-agent` and
/// `http-referrer`, from `#EXTVLCOPT:http-user-agent=` /
/// `#EXTVLCOPT:http-referrer=` lines, and from the `URL|User-Agent=...&
/// Referer=...` form (both formats).
///
/// Lines with the same channel name are merged into one [Channel] with
/// several sources, in the order they appear. The category of the first
/// line wins.
class ChannelListParser {
  /// `#EXTINF:-1 key="value" key="value",Name`. Attribute values may contain
  /// commas (for example `http-user-agent`), and so may the name.
  static final _extinf = RegExp(
    r'^#EXTINF:\s*-?[\d.]+((?:\s+[\w-]+="[^"]*")*)\s*,(.*)$',
  );
  static final _attribute = RegExp(r'([\w-]+)="([^"]*)"');
  static final _urlSeparator = RegExp(r'#(?=[a-zA-Z][a-zA-Z0-9+.-]*://)');

  /// Larger texts are parsed in a background isolate so the UI stays
  /// responsive.
  static const _backgroundThreshold = 256 * 1024;

  /// [parse] off the UI thread for large playlists.
  static Future<List<Channel>> parseInBackground(
    String text, {
    String? defaultCategory,
  }) {
    if (text.length < _backgroundThreshold) {
      return Future.value(parse(text, defaultCategory: defaultCategory));
    }
    return Isolate.run(() => parse(text, defaultCategory: defaultCategory));
  }

  static List<Channel> parse(String text, {String? defaultCategory}) {
    final lines = text
        .replaceFirst('﻿', '')
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const [];
    }
    final builder = _ChannelListBuilder();
    if (lines.first.startsWith('#EXTM3U')) {
      _parseM3u(lines, defaultCategory, builder);
    } else {
      _parseText(lines, defaultCategory, builder);
    }
    return builder.build();
  }

  static void _parseText(
    List<String> lines,
    String? category,
    _ChannelListBuilder builder,
  ) {
    for (final line in lines) {
      final comma = line.indexOf(',');
      if (comma <= 0) {
        continue;
      }
      final name = line.substring(0, comma).trim();
      final value = line.substring(comma + 1).trim();
      if (value == '#genre#') {
        category = name;
        continue;
      }
      if (name.isEmpty) {
        continue;
      }
      for (final part in value.split(_urlSeparator)) {
        final source = parseSource(part);
        if (source != null) {
          builder.add(name, source, category);
        }
      }
    }
  }

  static void _parseM3u(
    List<String> lines,
    String? defaultCategory,
    _ChannelListBuilder builder,
  ) {
    String? name;
    String? category;
    String? userAgent;
    String? referrer;
    for (final line in lines) {
      if (line.startsWith('#EXTINF')) {
        final match = _extinf.firstMatch(line);
        final attributes = <String, String>{
          for (final m in _attribute.allMatches(match?.group(1) ?? line))
            m.group(1)!.toLowerCase(): m.group(2)!,
        };
        if (match != null) {
          name = match.group(2)!.trim();
        } else {
          final comma = line.lastIndexOf(',');
          name = comma >= 0 ? line.substring(comma + 1).trim() : null;
        }
        category = attributes['group-title']?.trim();
        userAgent = attributes['http-user-agent'];
        referrer = attributes['http-referrer'] ?? attributes['http-referer'];
      } else if (line.startsWith('#EXTVLCOPT:')) {
        final option = line.substring('#EXTVLCOPT:'.length);
        final equals = option.indexOf('=');
        if (equals > 0) {
          final key = option.substring(0, equals).trim().toLowerCase();
          final value = option.substring(equals + 1).trim();
          if (key == 'http-user-agent') userAgent = value;
          if (key == 'http-referrer' || key == 'http-referer') {
            referrer = value;
          }
        }
      } else if (line.startsWith('#')) {
        continue;
      } else if (name != null && name.isNotEmpty) {
        final parsed = parseSource(line);
        if (parsed != null) {
          final source = StreamSource(
            parsed.url,
            userAgent: parsed.userAgent ?? userAgent,
            referrer: parsed.referrer ?? referrer,
          );
          builder.add(
            name,
            source,
            (category?.isEmpty ?? true) ? defaultCategory : category,
          );
        }
        name = null;
        category = null;
        userAgent = null;
        referrer = null;
      }
    }
  }

  /// Parses `URL` or `URL|User-Agent=...&Referer=...`. Returns null when
  /// the URL is not valid.
  static StreamSource? parseSource(String value) {
    final text = value.trim();
    final pipe = text.indexOf('|');
    final url = (pipe < 0 ? text : text.substring(0, pipe)).trim();
    if (!isStreamUrl(url)) {
      return null;
    }
    String? userAgent;
    String? referrer;
    if (pipe >= 0) {
      for (final pair in text.substring(pipe + 1).split('&')) {
        final equals = pair.indexOf('=');
        if (equals <= 0) continue;
        final key = pair.substring(0, equals).trim().toLowerCase();
        final raw = pair.substring(equals + 1).trim();
        final decoded = _decode(raw);
        if (key == 'user-agent') userAgent = decoded;
        if (key == 'referer' || key == 'referrer') referrer = decoded;
      }
    }
    return StreamSource(url, userAgent: userAgent, referrer: referrer);
  }

  /// Header values in `URL|...` are usually percent-encoded; keep the raw
  /// text when they are not valid encoding.
  static String _decode(String value) {
    try {
      return Uri.decodeComponent(value.replaceAll('+', '%20'));
    } catch (_) {
      return value;
    }
  }

  static bool isStreamUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}

class _ChannelListBuilder {
  final _names = <String>[];
  final _sources = <String, List<StreamSource>>{};
  final _categories = <String, String?>{};

  void add(String name, StreamSource source, String? category) {
    final sources = _sources[name];
    if (sources == null) {
      _names.add(name);
      _sources[name] = [source];
      _categories[name] = category;
    } else {
      sources.add(source);
    }
  }

  List<Channel> build() {
    return [
      for (final name in _names)
        Channel.create(
          name: name,
          sources: _sources[name]!,
          category: _categories[name],
        ),
    ];
  }
}
