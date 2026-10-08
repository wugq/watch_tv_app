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

  static const invalidUrlMessage =
      'Enter a full URL, for example https://example.com/live.m3u8';

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
  final newUserAgentText = TextEditingController();
  final newReferrerText = TextEditingController();

  late final sources = <StreamSource>[...?original?.sources].obs;
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
    newUserAgentText.dispose();
    newReferrerText.dispose();
    super.onClose();
  }

  Future<void> _loadCategories() async {
    final channels = await _repository.getAll();
    categories.assignAll(
      channels
          .expand((c) => c.categories)
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

  /// A source from user input, or null when the URL is not valid. Accepts
  /// the `URL|User-Agent=...` form too; filled-in fields win over it.
  static StreamSource? validSource(
    String url, {
    String? userAgent,
    String? referrer,
  }) {
    final parsed = ChannelListParser.parseSource(url);
    if (parsed == null) {
      return null;
    }
    return StreamSource(
      parsed.url,
      userAgent: (userAgent?.trim().isNotEmpty ?? false)
          ? userAgent
          : parsed.userAgent,
      referrer: (referrer?.trim().isNotEmpty ?? false)
          ? referrer
          : parsed.referrer,
    );
  }

  /// Adds the URL in [newUrlText] with the optional headers. Returns false
  /// when it is not valid.
  bool addUrl() {
    final url = newUrlText.text.trim();
    if (url.isEmpty) {
      return false;
    }
    final source = validSource(
      url,
      userAgent: newUserAgentText.text,
      referrer: newReferrerText.text,
    );
    if (source == null) {
      urlError.value = invalidUrlMessage;
      return false;
    }
    final index = sources.indexWhere((s) => s.url == source.url);
    if (index >= 0) {
      sources[index] = source;
    } else {
      sources.add(source);
    }
    newUrlText.clear();
    newUserAgentText.clear();
    newReferrerText.clear();
    urlError.value = null;
    return true;
  }

  void replaceSource(int index, StreamSource source) {
    sources[index] = source;
  }

  void removeSource(int index) => sources.removeAt(index);

  /// Moves a source one place up, so it is tried earlier.
  void moveUp(int index) {
    if (index <= 0) return;
    final source = sources.removeAt(index);
    sources.insert(index - 1, source);
  }

  Future<void> save() async {
    // A URL typed but not added yet still counts.
    if (newUrlText.text.trim().isNotEmpty && !addUrl()) {
      return;
    }
    final nameValid = formKey.currentState?.validate() ?? false;
    if (sources.isEmpty) {
      urlError.value = 'Add at least one stream URL';
    }
    if (!nameValid || sources.isEmpty || isSaving.value) {
      return;
    }
    final created = Channel.create(
      name: nameText.text.trim(),
      sources: sources,
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
          sources: created.sources,
          favorite: favorite.value,
          hidden: old.hidden,
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
