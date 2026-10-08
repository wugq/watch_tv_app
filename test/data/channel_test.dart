import 'package:flutter_test/flutter_test.dart';
import 'package:tv/data/models/channel.dart';

void main() {
  test('key is derived from the name', () {
    final a = Channel.create(name: 'A', urls: ['http://x/1']);
    final b = Channel.create(name: 'A', urls: ['http://x/2'], category: 'C');

    expect(a.key, b.key);
    expect(a.key, '6dcd4ce23d88e2ee9568ba546c007c63d9131c1b');
  });

  test('blank category falls back to default', () {
    final channel = Channel.create(
      name: 'A',
      urls: ['http://x'],
      category: ' ',
    );

    expect(channel.category, Channel.defaultCategory);
  });

  test('create removes duplicate and blank URLs', () {
    final channel = Channel.create(
      name: 'A',
      urls: ['http://x/1', ' ', 'http://x/1 ', 'http://x/2'],
    );

    expect(channel.urls, ['http://x/1', 'http://x/2']);
  });

  test('merge appends new sources and takes the new category', () {
    final a = Channel.create(name: 'A', urls: ['http://x/1', 'http://x/2']);
    final b = Channel.create(
      name: 'A',
      urls: ['http://x/2', 'http://x/3'],
      category: 'News',
    );

    final merged = a.merge(b);

    expect(merged.urls, ['http://x/1', 'http://x/2', 'http://x/3']);
    expect(merged.category, 'News');
  });

  test('categories splits on ";" and drops blanks and duplicates', () {
    final channel = Channel.create(
      name: 'A',
      urls: ['http://x'],
      category: ' Kids ;Music;; Kids',
    );

    expect(channel.category, 'Kids;Music');
    expect(channel.categories, ['Kids', 'Music']);
  });
}
