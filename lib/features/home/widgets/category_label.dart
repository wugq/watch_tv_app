import 'package:tv/data/models/channel.dart';

String categoryLabel(String category) {
  return category == Channel.defaultCategory ? 'Uncategorized' : category;
}
