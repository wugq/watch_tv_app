import 'package:tv/core/checksum.dart';

/// A live stream channel with one or more stream sources.
///
/// [key] is the SHA-1 of [name]. Channels with the same name are the same
/// channel, so importing a list with repeated names adds sources to one
/// channel instead of creating duplicates.
class Channel {
  static const defaultCategory = 'default';

  final String key;
  final String name;
  final String category;

  /// Stream URLs in order of preference. Never empty.
  final List<String> urls;

  final bool favorite;

  /// When the channel was last played, or null if never.
  final DateTime? lastWatched;

  Channel({
    required this.key,
    required this.name,
    required this.category,
    required List<String> urls,
    this.favorite = false,
    this.lastWatched,
  }) : assert(urls.isNotEmpty),
       urls = List.unmodifiable(urls);

  factory Channel.create({
    required String name,
    required List<String> urls,
    String? category,
  }) {
    final parts = _splitCategories(category ?? '');
    return Channel(
      key: sha1Of(name),
      name: name,
      category: parts.isEmpty ? defaultCategory : parts.join(';'),
      urls: _unique(urls),
    );
  }

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
      urls: _unique([...urls, ...other.urls]),
    );
  }

  Channel copyWith({
    String? category,
    List<String>? urls,
    bool? favorite,
    DateTime? lastWatched,
  }) {
    return Channel(
      key: key,
      name: name,
      category: category ?? this.category,
      urls: urls ?? this.urls,
      favorite: favorite ?? this.favorite,
      lastWatched: lastWatched ?? this.lastWatched,
    );
  }

  static List<String> _unique(Iterable<String> urls) {
    final seen = <String>{};
    return [
      for (final url in urls.map((u) => u.trim()))
        if (url.isNotEmpty && seen.add(url)) url,
    ];
  }

  @override
  bool operator ==(Object other) {
    return other is Channel &&
        other.key == key &&
        other.name == name &&
        other.category == category &&
        other.favorite == favorite &&
        other.lastWatched == lastWatched &&
        _listEquals(other.urls, urls);
  }

  @override
  int get hashCode => Object.hash(
    key,
    name,
    category,
    favorite,
    lastWatched,
    Object.hashAll(urls),
  );

  @override
  String toString() {
    return 'Channel(name: $name, category: $category, urls: $urls)';
  }

  static bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
