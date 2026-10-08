import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:tv/data/models/channel.dart';
import 'package:tv/data/parsers/channel_list_parser.dart';
import 'package:tv/data/repositories/channel_repository.dart';
import 'package:tv/data/sources/playlist_loader.dart';

enum ImportMode { url, file, text }

/// A loaded playlist and the channels found in it.
class ImportPreview {
  final LoadedPlaylist playlist;

  /// Set when the playlist was downloaded, so it can be refreshed later.
  final String? url;
  final List<Channel> channels;

  const ImportPreview(this.playlist, this.url, this.channels);

  int get sourceCount => channels.fold(0, (sum, c) => sum + c.urls.length);

  List<String> get categories =>
      channels.map((c) => c.category).toSet().toList();
}

/// Imports an M3U / TXT playlist from a URL, a file or pasted text.
/// Pops with `true` when a playlist was added.
class PlaylistImportController extends GetxController {
  final ChannelRepository _repository;
  final PlaylistLoader _loader;

  PlaylistImportController(this._repository, this._loader);

  final mode = ImportMode.url.obs;
  final urlText = TextEditingController();
  final pasteText = TextEditingController();
  final nameText = TextEditingController();
  final categoryText = TextEditingController();

  final categories = <String>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final error = RxnString();
  final preview = Rxn<ImportPreview>();

  @override
  void onInit() {
    super.onInit();
    _loadCategories();
  }

  @override
  void onClose() {
    urlText.dispose();
    pasteText.dispose();
    nameText.dispose();
    categoryText.dispose();
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

  void setMode(ImportMode value) {
    mode.value = value;
    error.value = null;
  }

  Future<void> downloadUrl() {
    final url = urlText.text.trim();
    return _load(() => _loader.fromUrl(url), url: url);
  }

  Future<void> pickFile() => _load(_loader.pickFile);

  Future<void> parseText() {
    return _load(
      () async => LoadedPlaylist(source: 'Pasted list', text: pasteText.text),
    );
  }

  void clear() {
    preview.value = null;
    error.value = null;
  }

  Future<void> save() async {
    final current = preview.value;
    if (current == null || isSaving.value) {
      return;
    }
    final category = categoryText.text.trim();
    final channels = ChannelListParser.parse(
      current.playlist.text,
      defaultCategory: category.isEmpty ? null : category,
    );
    final name = nameText.text.trim();
    isSaving.value = true;
    try {
      await _repository.addPlaylist(
        name: name.isEmpty ? current.playlist.source : name,
        url: current.url,
        channels: channels,
      );
      Get.back(result: true);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> _load(
    Future<LoadedPlaylist?> Function() load, {
    String? url,
  }) async {
    if (isLoading.value) {
      return;
    }
    isLoading.value = true;
    error.value = null;
    try {
      final playlist = await load();
      if (playlist == null) {
        return;
      }
      final channels = ChannelListParser.parse(playlist.text);
      if (channels.isEmpty) {
        preview.value = null;
        error.value =
            'No channel found in ${playlist.source}. Supported formats are '
            'M3U and TXT ("Name,URL").';
        return;
      }
      preview.value = ImportPreview(playlist, url, channels);
      nameText.text = suggestName(playlist.source);
    } on PlaylistLoadException catch (e) {
      error.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// A short name from a URL or file name: `.../tv/iptv4.m3u` -> `iptv4`.
  static String suggestName(String source) {
    final uri = Uri.tryParse(source);
    final path = (uri != null && uri.hasScheme) ? uri.path : source;
    final base = p.basenameWithoutExtension(path);
    if (base.isNotEmpty) {
      return base;
    }
    return (uri != null && uri.host.isNotEmpty) ? uri.host : source;
  }
}
