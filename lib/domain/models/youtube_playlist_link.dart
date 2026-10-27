/// A local playlist that mirrors a playlist on the signed-in YouTube account.
///
/// The mapping stays out of E2EE sync on purpose: it names a playlist on one
/// Google account, so another device signed in as someone else must not inherit
/// it. Tracks themselves are ordinary `youtube:<videoId>` remote songs, which is
/// what keeps favorites, play counts and stats working on them.
class YouTubePlaylistLink {
  final String remotePlaylistId;
  final String localPlaylistId;
  final String remoteTitle;
  final double? lastSyncedAt;

  /// Item count reported by YouTube at the last sync, so the playlist row can
  /// tell "new tracks are waiting" without another request.
  final int? itemCount;

  const YouTubePlaylistLink({
    required this.remotePlaylistId,
    required this.localPlaylistId,
    this.remoteTitle = '',
    this.lastSyncedAt,
    this.itemCount,
  });

  factory YouTubePlaylistLink.fromRow(Map<String, Object?> row) {
    return YouTubePlaylistLink(
      remotePlaylistId: row['remote_playlist_id'] as String? ?? '',
      localPlaylistId: row['local_playlist_id'] as String? ?? '',
      remoteTitle: row['remote_title'] as String? ?? '',
      lastSyncedAt: (row['last_synced_at'] as num?)?.toDouble(),
      itemCount: (row['item_count'] as num?)?.toInt(),
    );
  }

  Map<String, Object?> toRow() => {
        'remote_playlist_id': remotePlaylistId,
        'local_playlist_id': localPlaylistId,
        'remote_title': remoteTitle,
        'last_synced_at': lastSyncedAt,
        'item_count': itemCount,
      };

  YouTubePlaylistLink copyWith({
    String? remoteTitle,
    double? lastSyncedAt,
    int? itemCount,
  }) {
    return YouTubePlaylistLink(
      remotePlaylistId: remotePlaylistId,
      localPlaylistId: localPlaylistId,
      remoteTitle: remoteTitle ?? this.remoteTitle,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      itemCount: itemCount ?? this.itemCount,
    );
  }
}
