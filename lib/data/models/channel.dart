import 'package:tv/core/checksum.dart';

/// A live stream channel.
///
/// [key] is the SHA-1 of [name]. It is the primary key in the database, so
/// two channels with the same name replace each other.
class Channel {
  static const defaultCategory = 'default';

  final String key;
  final String name;
  final String url;
  final String category;

  const Channel({
    required this.key,
    required this.name,
    required this.url,
    required this.category,
  });

  factory Channel.create({
    required String name,
    required String url,
    String? category,
  }) {
    final trimmedCategory = category?.trim() ?? '';
    return Channel(
      key: sha1Of(name),
      name: name,
      url: url,
      category: trimmedCategory.isEmpty ? defaultCategory : trimmedCategory,
    );
  }

  factory Channel.fromMap(Map<String, Object?> map) {
    return Channel(
      key: map['key'] as String,
      name: map['name'] as String,
      url: map['url'] as String,
      category: (map['category'] as String?) ?? defaultCategory,
    );
  }

  Map<String, Object?> toMap() {
    return {'key': key, 'name': name, 'url': url, 'category': category};
  }

  @override
  bool operator ==(Object other) {
    return other is Channel &&
        other.key == key &&
        other.name == name &&
        other.url == url &&
        other.category == category;
  }

  @override
  int get hashCode => Object.hash(key, name, url, category);

  @override
  String toString() {
    return 'Channel(name: $name, url: $url, category: $category, key: $key)';
  }
}
