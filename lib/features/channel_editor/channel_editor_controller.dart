import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/parsers/channel_list_parser.dart';
import 'package:tv/data/repositories/channel_repository.dart';

/// Adds channels (one or many), or edits one channel when the route
/// argument is a [Channel]. Pops with the saved channels.
class ChannelEditorController extends GetxController {
  final ChannelRepository _repository;

  /// The channel being edited, or null when adding channels.
  final Channel? original;

  ChannelEditorController(this._repository, {this.original});

  bool get isEditing => original != null;

  final singleFormKey = GlobalKey<FormState>();
  final batchFormKey = GlobalKey<FormState>();

  late final nameText = TextEditingController(text: original?.name);
  late final urlText = TextEditingController(text: original?.url);
  late final categoryText = TextEditingController(
    text: original?.category == Channel.defaultCategory
        ? ''
        : original?.category,
  );
  final batchText = TextEditingController();
  final batchCategoryText = TextEditingController();

  final categories = <String>[].obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
  }

  @override
  void onClose() {
    nameText.dispose();
    urlText.dispose();
    categoryText.dispose();
    batchText.dispose();
    batchCategoryText.dispose();
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

  String? validateUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Enter a stream URL';
    }
    if (!ChannelListParser.isStreamUrl(value.trim())) {
      return 'Enter a full URL, for example https://example.com/live.m3u8';
    }
    return null;
  }

  String? validateBatch(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Paste one or more channels';
    }
    if (ChannelListParser.parse(value).isEmpty) {
      return 'No valid channel found. Use "Name, URL" on each line';
    }
    return null;
  }

  Future<void> saveSingle() async {
    if (!(singleFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final channel = Channel.create(
      name: nameText.text.trim(),
      url: urlText.text.trim(),
      category: categoryText.text,
    );
    await _save(() async {
      final old = original;
      if (old == null) {
        await _repository.save(channel);
      } else {
        await _repository.replace(old, channel);
      }
      return [channel];
    });
  }

  Future<void> saveBatch() async {
    if (!(batchFormKey.currentState?.validate() ?? false)) {
      return;
    }
    final category = batchCategoryText.text.trim();
    final channels = ChannelListParser.parse(
      batchText.text,
      defaultCategory: category.isEmpty ? null : category,
    );
    await _save(() async {
      await _repository.saveAll(channels);
      return channels;
    });
  }

  Future<void> _save(Future<List<Channel>> Function() action) async {
    if (isSaving.value) {
      return;
    }
    isSaving.value = true;
    try {
      final saved = await action();
      Get.back(result: saved);
    } finally {
      isSaving.value = false;
    }
  }
}
