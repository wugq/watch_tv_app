import 'package:flutter/material.dart';
import 'package:tv/data/models/channel.dart';

enum SectionKind { favorites, recent, all, category }

/// A group of channels in the navigation: favorites, recently watched, all
/// channels, or one category.
@immutable
class LibrarySection {
  final SectionKind kind;

  /// Category name for [SectionKind.category].
  final String? category;

  const LibrarySection._(this.kind, [this.category]);

  static const favorites = LibrarySection._(SectionKind.favorites);
  static const recent = LibrarySection._(SectionKind.recent);
  static const all = LibrarySection._(SectionKind.all);

  const LibrarySection.category(String name)
    : this._(SectionKind.category, name);

  String get label => switch (kind) {
    SectionKind.favorites => 'Favorites',
    SectionKind.recent => 'Recently watched',
    SectionKind.all => 'All channels',
    SectionKind.category => categoryLabel(category!),
  };

  /// Short label for chips on small screens.
  String get shortLabel => switch (kind) {
    SectionKind.recent => 'Recent',
    SectionKind.all => 'All',
    _ => label,
  };

  IconData get icon => switch (kind) {
    SectionKind.favorites => Icons.star_rounded,
    SectionKind.recent => Icons.history,
    SectionKind.all => Icons.apps,
    SectionKind.category => Icons.folder_outlined,
  };

  @override
  bool operator ==(Object other) =>
      other is LibrarySection &&
      other.kind == kind &&
      other.category == category;

  @override
  int get hashCode => Object.hash(kind, category);

  @override
  String toString() => 'LibrarySection($kind, $category)';
}

String categoryLabel(String category) {
  return category == Channel.defaultCategory ? 'Uncategorized' : category;
}

/// All categories of [channel], for display.
String categoriesLabel(Channel channel) {
  return channel.categories.map(categoryLabel).join(', ');
}
