/// A category the user made, with channels picked by hand.
class CustomCategory {
  final int id;
  final String name;

  /// Keys of the channels in this category, in the order they were added.
  final List<String> channelKeys;

  const CustomCategory({
    required this.id,
    required this.name,
    this.channelKeys = const [],
  });
}
