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
/// Lines with the same channel name are merged into one [Channel] with
/// several sources, in the order they appear. The category of the first
/// line wins.
class ChannelListParser {
  static final _groupTitle = RegExp(r'group-title="([^"]*)"');
  static final _urlSeparator = RegExp(r'#(?=[a-zA-Z][a-zA-Z0-9+.-]*://)');

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
      for (final url in value.split(_urlSeparator)) {
        if (isStreamUrl(url.trim())) {
          builder.add(name, url.trim(), category);
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
    for (final line in lines) {
      if (line.startsWith('#EXTINF')) {
        final comma = line.lastIndexOf(',');
        name = comma >= 0 ? line.substring(comma + 1).trim() : null;
        category = _groupTitle.firstMatch(line)?.group(1)?.trim();
      } else if (line.startsWith('#')) {
        continue;
      } else if (name != null && name.isNotEmpty && isStreamUrl(line)) {
        builder.add(
          name,
          line,
          (category?.isEmpty ?? true) ? defaultCategory : category,
        );
        name = null;
        category = null;
      }
    }
  }

  static bool isStreamUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}

class _ChannelListBuilder {
  final _names = <String>[];
  final _urls = <String, List<String>>{};
  final _categories = <String, String?>{};

  void add(String name, String url, String? category) {
    final urls = _urls[name];
    if (urls == null) {
      _names.add(name);
      _urls[name] = [url];
      _categories[name] = category;
    } else {
      urls.add(url);
    }
  }

  List<Channel> build() {
    return [
      for (final name in _names)
        Channel.create(
          name: name,
          urls: _urls[name]!,
          category: _categories[name],
        ),
    ];
  }
}
