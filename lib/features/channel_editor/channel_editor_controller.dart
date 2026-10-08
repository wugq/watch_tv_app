import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/parsers/channel_list_parser.dart';
import 'package:tv/data/repositories/channel_repository.dart';

/// Adds one channel, or edits the channel passed as route argument.
///
/// Pops with the saved [Channel], or with [deleted] after a delete.
class ChannelEditorController extends GetxController {
  static const deleted = 'deleted';

  final ChannelRepository _repository;

  /// The channel being edited, or null when adding a channel.
  final Channel? original;

  ChannelEditorController(this._repository, {this.original});

  bool get isEditing => original != null;

  final formKey = GlobalKey<FormState>();
  late final nameText = TextEditingController(text: original?.name);
  late final categoryText = TextEditingController(
    text: original?.category == Channel.defaultCategory
        ? ''
        : original?.category,
  );
  final newUrlText = TextEditingController();

  late final urls = <String>[...?original?.urls].obs;
  late final favorite = (original?.favorite ?? false).obs;
  final categories = <String>[].obs;
  final isSaving = false.obs;
  final urlError = RxnString();

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
  }

  @override
  void onClose() {
    nameText.dispose();
    categoryText.dispose();
    newUrlText.dispose();
    super.onClose();
  }

  Future<void> _loadCategories() async {
    final channels = await _repository.getAll();
    categories.assignAll(
      channels
          .map((c) => c.category)
          .where((c) => c != Channel.defaultCategory)
          .toSet(),
    );
  }

  String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a channel name';
    }
    return null;
  }

  /// Adds the URL in [newUrlText]. Returns false when it is not valid.
  bool addUrl() {
    final url = newUrlText.text.trim();
    if (url.isEmpty) {
      return false;
    }
    if (!ChannelListParser.isStreamUrl(url)) {
      urlError.value =
          'Enter a full URL, for example https://example.com/live.m3u8';
      return false;
    }
    if (!urls.contains(url)) {
      urls.add(url);
    }
    newUrlText.clear();
    urlError.value = null;
    return true;
  }

  void removeUrl(int index) => urls.removeAt(index);

  /// Moves a source one place up, so it is tried earlier.
  void moveUp(int index) {
    if (index <= 0) return;
    final url = urls.removeAt(index);
    urls.insert(index - 1, url);
  }

  Future<void> save() async {
    // A URL typed but not added yet still counts.
    if (newUrlText.text.trim().isNotEmpty && !addUrl()) {
      return;
    }
    final nameValid = formKey.currentState?.validate() ?? false;
    if (urls.isEmpty) {
      urlError.value = 'Add at least one stream URL';
    }
    if (!nameValid || urls.isEmpty || isSaving.value) {
      return;
    }
    final created = Channel.create(
      name: nameText.text.trim(),
      urls: urls,
      category: categoryText.text,
    );
    isSaving.value = true;
    try {
      final old = original;
      final Channel channel;
      if (old == null) {
        // Same name as an existing channel: the URLs become extra sources.
        await _repository.import([created]);
        channel = created;
      } else {
        channel = Channel(
          key: created.key,
          name: created.name,
          category: created.category,
          urls: created.urls,
          favorite: favorite.value,
          lastWatched: old.lastWatched,
        );
        await _repository.replace(old, channel);
      }
      Get.back(result: channel);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> delete() async {
    final old = original;
    if (old == null) {
      return;
    }
    await _repository.delete(old.key);
    Get.back(result: deleted);
  }
}
