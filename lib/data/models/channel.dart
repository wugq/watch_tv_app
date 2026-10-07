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

  Channel({
    required this.key,
    required this.name,
    required this.category,
    required List<String> urls,
  }) : assert(urls.isNotEmpty),
       urls = List.unmodifiable(urls);

  factory Channel.create({
    required String name,
    required List<String> urls,
    String? category,
  }) {
    final trimmedCategory = category?.trim() ?? '';
    return Channel(
      key: sha1Of(name),
      name: name,
      category: trimmedCategory.isEmpty ? defaultCategory : trimmedCategory,
      urls: _unique(urls),
    );
  }

  /// Returns a copy with the sources of [other] appended (duplicates
  /// skipped) and the category of [other].
  Channel merge(Channel other) {
    return Channel(
      key: key,
      name: name,
      category: other.category,
      urls: _unique([...urls, ...other.urls]),
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
        _listEquals(other.urls, urls);
  }

  @override
  int get hashCode => Object.hash(key, name, category, Object.hashAll(urls));

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
