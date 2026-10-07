import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/parsers/channel_list_parser.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/data/sources/playlist_loader.dart';

/// A loaded playlist and the channels found in it.
class ImportPreview {
  final LoadedPlaylist playlist;
  final List<Channel> channels;

  const ImportPreview(this.playlist, this.channels);

  int get sourceCount => channels.fold(0, (sum, c) => sum + c.urls.length);

  int get categoryCount => channels.map((c) => c.category).toSet().length;
}

/// Adds channels (single, pasted list or imported playlist), or edits one
/// channel when the route argument is a [Channel]. Pops with the saved
/// channels.
class ChannelEditorController extends GetxController {
  final ChannelRepository _repository;
  final PlaylistLoader _loader;

  /// The channel being edited, or null when adding channels.
  final Channel? original;

  ChannelEditorController(this._repository, this._loader, {this.original});

  bool get isEditing => original != null;

  final singleFormKey = GlobalKey<FormState>();
  final batchFormKey = GlobalKey<FormState>();

  late final nameText = TextEditingController(text: original?.name);
  late final urlsText = TextEditingController(text: original?.urls.join('\n'));
  late final categoryText = TextEditingController(
    text: original?.category == Channel.defaultCategory
        ? ''
        : original?.category,
  );
  final batchText = TextEditingController();
  final batchCategoryText = TextEditingController();
  final importUrlText = TextEditingController();
  final importCategoryText = TextEditingController();

  final categories = <String>[].obs;
  final isSaving = false.obs;
  final isLoadingPlaylist = false.obs;
  final importError = RxnString();
  final importPreview = Rxn<ImportPreview>();

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
  }

  @override
  void onClose() {
    nameText.dispose();
    urlsText.dispose();
    categoryText.dispose();
    batchText.dispose();
    batchCategoryText.dispose();
    importUrlText.dispose();
    importCategoryText.dispose();
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

  String? validateUrls(String? value) {
    final lines = _lines(value ?? '');
    if (lines.isEmpty) {
      return 'Enter at least one stream URL';
    }
    for (final line in lines) {
      if (!ChannelListParser.isStreamUrl(line)) {
        return 'Not a full URL: $line';
      }
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
      urls: _lines(urlsText.text),
      category: categoryText.text,
    );
    await _save(() async {
      final old = original;
      if (old == null) {
        // Same name as an existing channel: the URLs become extra sources.
        await _repository.import([channel]);
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
    final channels = ChannelListParser.parse(
      batchText.text,
      defaultCategory: _textOrNull(batchCategoryText),
    );
    await _save(() async {
      await _repository.import(channels);
      return channels;
    });
  }

  Future<void> pickFile() {
    return _loadPlaylist(_loader.pickFile);
  }

  Future<void> downloadUrl() {
    return _loadPlaylist(() => _loader.fromUrl(importUrlText.text));
  }

  Future<void> saveImport() async {
    final preview = importPreview.value;
    if (preview == null) {
      return;
    }
    final channels = ChannelListParser.parse(
      preview.playlist.text,
      defaultCategory: _textOrNull(importCategoryText),
    );
    await _save(() async {
      await _repository.import(channels);
      return channels;
    });
  }

  void clearImport() {
    importPreview.value = null;
    importError.value = null;
  }

  Future<void> _loadPlaylist(Future<LoadedPlaylist?> Function() load) async {
    if (isLoadingPlaylist.value) {
      return;
    }
    isLoadingPlaylist.value = true;
    importError.value = null;
    try {
      final playlist = await load();
      if (playlist == null) {
        return;
      }
      final channels = ChannelListParser.parse(playlist.text);
      if (channels.isEmpty) {
        importPreview.value = null;
        importError.value =
            'No channel found in ${playlist.source}. Supported formats are '
            'TXT ("Name,URL") and M3U.';
        return;
      }
      importPreview.value = ImportPreview(playlist, channels);
    } on PlaylistLoadException catch (e) {
      importError.value = e.message;
    } finally {
      isLoadingPlaylist.value = false;
    }
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

  static List<String> _lines(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  static String? _textOrNull(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }
}
