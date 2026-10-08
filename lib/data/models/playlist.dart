/// An imported channel list (M3U or TXT), from a URL, a file or pasted text.
///
/// Sources remember the playlist they came from, so a playlist can be
/// refreshed or deleted as a whole.
class Playlist {
  final int id;
  final String name;

  /// Where the playlist was downloaded from. Null for files and pasted text,
  /// which cannot be refreshed.
  final String? url;

  final DateTime updatedAt;
  final int channelCount;
  final int sourceCount;

  const Playlist({
    required this.id,
    required this.name,
    required this.url,
    required this.updatedAt,
    this.channelCount = 0,
    this.sourceCount = 0,
  });

  bool get canRefresh => url != null;
}
