import 'package:tv/util/checksum.dart';

class Channel {
  String name;

  String url;

  late String category;

  late String key;

  Channel({required this.name, required this.url}) {
    category = "default";
    key = CheckSum.sha1StringOf(name);
  }

  Channel.withCategory({
    required this.name,
    required this.url,
    required this.category,
  }) {
    key = CheckSum.sha1StringOf(name);
  }

  Channel.fromObj({
    required this.key,
    required this.name,
    required this.url,
    required this.category,
  });

  Map<String, dynamic> toMap() {
    return {
      'key': key,
      'name': name,
      'url': url,
      'category': category,
    };
  }

  @override
  String toString() {
    return 'Channel {name: $name, url: $url, category: $category, key: $key}';
  }
}
