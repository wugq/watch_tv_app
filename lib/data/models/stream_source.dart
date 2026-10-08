import 'package:flutter/foundation.dart';

/// One stream URL of a channel, with the HTTP headers some servers require.
@immutable
class StreamSource {
  final String url;

  /// Sent as `User-Agent`. From M3U `http-user-agent`.
  final String? userAgent;

  /// Sent as `Referer`. From M3U `http-referrer`.
  final String? referrer;

  StreamSource(String url, {String? userAgent, String? referrer})
    : url = url.trim(),
      userAgent = _blankToNull(userAgent),
      referrer = _blankToNull(referrer);

  bool get hasHeaders => userAgent != null || referrer != null;

  Map<String, String> get headers => {
    'User-Agent': ?userAgent,
    'Referer': ?referrer,
  };

  /// Missing headers are taken from [other] (same URL from another list).
  StreamSource fillFrom(StreamSource other) {
    return StreamSource(
      url,
      userAgent: userAgent ?? other.userAgent,
      referrer: referrer ?? other.referrer,
    );
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  @override
  bool operator ==(Object other) =>
      other is StreamSource &&
      other.url == url &&
      other.userAgent == userAgent &&
      other.referrer == referrer;

  @override
  int get hashCode => Object.hash(url, userAgent, referrer);

  @override
  String toString() => hasHeaders ? '$url $headers' : url;
}
