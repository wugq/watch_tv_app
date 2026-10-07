import 'package:flutter_test/flutter_test.dart';
import 'package:tv/data/models/channel.dart';

void main() {
  test('key is derived from the name', () {
    final a = Channel.create(name: 'A', url: 'http://x/1');
    final b = Channel.create(name: 'A', url: 'http://x/2', category: 'News');

    expect(a.key, b.key);
    expect(a.key, '6dcd4ce23d88e2ee9568ba546c007c63d9131c1b');
  });

  test('blank category falls back to default', () {
    final channel = Channel.create(name: 'A', url: 'http://x', category: ' ');

    expect(channel.category, Channel.defaultCategory);
  });

  test('map round trip', () {
    final channel = Channel.create(name: 'A', url: 'http://x', category: 'C');

    expect(Channel.fromMap(channel.toMap()), channel);
  });
}
