import 'package:flutter/foundation.dart';
import 'package:tv/core/checksum.dart';
import 'package:tv/data/models/stream_source.dart';

export 'package:tv/data/models/stream_source.dart';

/// A live stream channel with one or more stream sources.
///
/// [key] is the SHA-1 of [name]. Channels with the same name are the same
/// channel, so importing a list with repeated names adds sources to one
/// channel instead of creating duplicates.
class Channel {
  static const defaultCategory = 'default';

  final String key;
  final String name;

  /// One or more categories separated by `;`, see [categories].
  final String category;

  /// Sources in order of preference. Never empty.
  final List<StreamSource> sources;

  final bool favorite;

  /// Hidden channels stay in the library but are not shown for browsing.
  final bool hidden;

  /// When the channel was last played, or null if never.
  final DateTime? lastWatched;

  /// Pass either [sources] or plain [urls].
  Channel({
    required this.key,
    required this.name,
    required this.category,
    List<StreamSource>? sources,
    List<String>? urls,
    this.favorite = false,
    this.hidden = false,
    this.lastWatched,
  }) : sources = List.unmodifiable(
         sources ??
             [for (final url in urls ?? const <String>[]) StreamSource(url)],
       ) {
    assert(this.sources.isNotEmpty);
  }

  factory Channel.create({
    required String name,
    List<StreamSource>? sources,
    List<String>? urls,
    String? category,
  }) {
    final parts = _splitCategories(category ?? '');
    return Channel(
      key: sha1Of(name),
      name: name,
      category: parts.isEmpty ? defaultCategory : parts.join(';'),
      sources: _unique([
        ...?sources,
        for (final url in urls ?? const <String>[]) StreamSource(url),
      ]),
    );
  }

  /// Stream URLs in order of preference.
  List<String> get urls => [for (final source in sources) source.url];

  /// [category] can hold several categories separated by `;`, as in
  /// iptv-org playlists (`group-title="Kids;Music"`).
  List<String> get categories {
    final parts = _splitCategories(category);
    return parts.isEmpty ? const [defaultCategory] : parts;
  }

  static List<String> _splitCategories(String value) {
    final seen = <String>{};
    return [
      for (final part in value.split(';').map((p) => p.trim()))
        if (part.isNotEmpty && seen.add(part)) part,
    ];
  }

  /// Returns a copy with the sources of [other] appended (duplicates
  /// skipped) and the category of [other].
  Channel merge(Channel other) {
    return copyWith(
      category: other.category,
      sources: _unique([...sources, ...other.sources]),
    );
  }

  Channel copyWith({
    String? category,
    List<StreamSource>? sources,
    bool? favorite,
    bool? hidden,
    DateTime? lastWatched,
  }) {
    return Channel(
      key: key,
      name: name,
      category: category ?? this.category,
      sources: sources ?? this.sources,
      favorite: favorite ?? this.favorite,
      hidden: hidden ?? this.hidden,
      lastWatched: lastWatched ?? this.lastWatched,
    );
  }

  /// Drops empty and repeated URLs; a repeated URL can still add headers.
  static List<StreamSource> _unique(Iterable<StreamSource> sources) {
    final byUrl = <String, StreamSource>{};
    for (final source in sources) {
      if (source.url.isEmpty) continue;
      final known = byUrl[source.url];
      byUrl[source.url] = known == null ? source : known.fillFrom(source);
    }
    return byUrl.values.toList();
  }

  @override
  bool operator ==(Object other) {
    return other is Channel &&
        other.key == key &&
        other.name == name &&
        other.category == category &&
        other.favorite == favorite &&
        other.hidden == hidden &&
        other.lastWatched == lastWatched &&
        listEquals(other.sources, sources);
  }

  @override
  int get hashCode => Object.hash(
    key,
    name,
    category,
    favorite,
    hidden,
    lastWatched,
    Object.hashAll(sources),
  );

  @override
  String toString() {
    return 'Channel(name: $name, category: $category, sources: $sources)';
  }
}
