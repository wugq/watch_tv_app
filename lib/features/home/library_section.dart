import 'package:flutter/material.dart';
import 'package:tv/data/models/channel.dart';

enum SectionKind { favorites, recent, all, custom, category }

/// A group of channels in the navigation: favorites, recently watched, all
/// channels, a category made by the user, or a playlist category.
@immutable
class LibrarySection {
  final SectionKind kind;

  /// Category name for [SectionKind.category], or the name of a custom
  /// category.
  final String? category;

  /// Id of a custom category ([SectionKind.custom]).
  final int? customId;

  const LibrarySection._(this.kind, [this.category, this.customId]);

  static const favorites = LibrarySection._(SectionKind.favorites);
  static const recent = LibrarySection._(SectionKind.recent);
  static const all = LibrarySection._(SectionKind.all);

  const LibrarySection.category(String name)
    : this._(SectionKind.category, name);

  const LibrarySection.custom(int id, String name)
    : this._(SectionKind.custom, name, id);

  String get label => switch (kind) {
    SectionKind.favorites => 'Favorites',
    SectionKind.recent => 'Recently watched',
    SectionKind.all => 'All channels',
    SectionKind.category => categoryLabel(category!),
    SectionKind.custom => category!,
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
    SectionKind.custom => Icons.bookmark_outline,
    SectionKind.category => Icons.folder_outlined,
  };

  @override
  bool operator ==(Object other) =>
      other is LibrarySection &&
      other.kind == kind &&
      (kind == SectionKind.custom
          ? other.customId == customId
          : other.category == category);

  @override
  int get hashCode =>
      Object.hash(kind, kind == SectionKind.custom ? customId : category);

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
