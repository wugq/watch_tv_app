import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

class PlaylistLoadException implements Exception {
  final String message;

  const PlaylistLoadException(this.message);

  @override
  String toString() => message;
}

/// Text of a playlist and where it came from.
class LoadedPlaylist {
  final String source;
  final String text;

  const LoadedPlaylist({required this.source, required this.text});
}

/// Reads TXT / M3U playlists from a local file or a URL.
class PlaylistLoader {
  static const _timeout = Duration(seconds: 30);

  /// Playlists larger than this are rejected (10 MB).
  static const maxBytes = 10 * 1024 * 1024;

  final http.Client _client;

  PlaylistLoader({http.Client? client}) : _client = client ?? http.Client();

  /// Opens the system file picker. Returns null when the user cancels.
  Future<LoadedPlaylist?> pickFile() async {
    final PlatformFile? file;
    try {
      // FileType.any: Android has no reliable MIME type for .m3u / .txt.
      file = await FilePicker.pickFile(dialogTitle: 'Choose a playlist');
    } catch (e) {
      throw PlaylistLoadException('Cannot open the file picker: $e');
    }
    if (file == null) {
      return null;
    }
    final Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      throw PlaylistLoadException('Cannot read ${file.name}');
    }
    return LoadedPlaylist(source: file.name, text: decode(bytes));
  }

  Future<LoadedPlaylist> fromUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw const PlaylistLoadException('Enter an http or https URL');
    }
    final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const PlaylistLoadException('The server did not respond in time');
    } catch (e) {
      throw PlaylistLoadException('Download failed: $e');
    }
    if (response.statusCode != 200) {
      throw PlaylistLoadException(
        'Download failed: HTTP ${response.statusCode}',
      );
    }
    return LoadedPlaylist(
      source: uri.toString(),
      text: decode(response.bodyBytes),
    );
  }

  /// Decodes playlist bytes as UTF-8. Invalid bytes are replaced instead of
  /// failing the whole import.
  static String decode(Uint8List bytes) {
    if (bytes.length > maxBytes) {
      throw const PlaylistLoadException('The playlist is larger than 10 MB');
    }
    return utf8.decode(bytes, allowMalformed: true);
  }
}
