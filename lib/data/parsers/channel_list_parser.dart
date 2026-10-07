import 'package:tv/data/models/channel.dart';

/// Parses a channel list typed or pasted by the user.
///
/// Two formats are supported:
///
/// * Plain text, one channel per line: `Name, URL`. A line of the form
///   `Category,#genre#` sets the category of the lines that follow it.
/// * M3U playlist (starts with `#EXTM3U`). The `group-title` attribute of
///   `#EXTINF` is used as the category.
class ChannelListParser {
  static final _groupTitle = RegExp(r'group-title="([^"]*)"');

  static List<Channel> parse(String text, {String? defaultCategory}) {
    final lines = text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) {
      return const [];
    }
    if (lines.first.startsWith('#EXTM3U')) {
      return _parseM3u(lines, defaultCategory);
    }
    return _parseText(lines, defaultCategory);
  }

  static List<Channel> _parseText(List<String> lines, String? category) {
    final channels = <Channel>[];
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
      if (name.isEmpty || !isStreamUrl(value)) {
        continue;
      }
      channels.add(Channel.create(name: name, url: value, category: category));
    }
    return channels;
  }

  static List<Channel> _parseM3u(List<String> lines, String? defaultCategory) {
    final channels = <Channel>[];
    String? name;
    String? category;
    for (final line in lines) {
      if (line.startsWith('#EXTINF')) {
        final comma = line.lastIndexOf(',');
        name = comma >= 0 ? line.substring(comma + 1).trim() : null;
        category = _groupTitle.firstMatch(line)?.group(1);
      } else if (line.startsWith('#')) {
        continue;
      } else if (name != null && name.isNotEmpty && isStreamUrl(line)) {
        channels.add(
          Channel.create(
            name: name,
            url: line,
            category: category ?? defaultCategory,
          ),
        );
        name = null;
        category = null;
      }
    }
    return channels;
  }

  static bool isStreamUrl(String value) {
    final uri = Uri.tryParse(value);
    return uri != null && uri.hasScheme && uri.host.isNotEmpty;
  }
}
