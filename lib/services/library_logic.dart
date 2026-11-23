import '../models/song.dart';
import '../models/shuffle_config.dart';
import '../domain/services/native_accel.dart';
import '../domain/services/shuffle_selector.dart';
import '../domain/services/smart_weights.dart';
import '../domain/services/song_affinity.dart';
import '../domain/services/taste_model.dart';
import '../providers/user_data_provider.dart';

class LibraryFolderContent {
  final List<String> subFolders;
  final List<Song> immediateSongs;
  final List<Song> allSongsInFolder;
  final Map<String, List<Song>> subFolderSongs;

  LibraryFolderContent({
    required this.subFolders,
    required this.immediateSongs,
    required this.allSongsInFolder,
    required this.subFolderSongs,
  });
}

/// Library view math — folder roots, folder trees, sorting and grouping.
///
/// Rust owns the rules; this class maps `Song` rows in and filenames back out.
class LibraryLogic {
  /// Picks the folder the "Folders" tab should be rooted at.
  ///
  /// Configured folders that hold songs win, several of them collapse to their
  /// common ancestor, and if none match the scanned paths the root is the common
  /// ancestor of the songs themselves. Only sub-folders with songs are listed,
  /// so a shallow root never exposes unrelated directories.
  static String? resolveLibraryRoot({
    required List<Song> allSongs,
    required List<String> configuredFolders,
  }) =>
      _view({
        'op': 'root',
        'songs': _rows(allSongs),
        'configuredFolders': configuredFolders,
      })['root'] as String?;

  static List<Song> sortSongs(
    List<Song> songs,
    SongSortOrder sortOrder, {
    UserDataState? userData,
    ShuffleConfig? shuffleConfig,
    Map<String, int>? playCounts,
    Map<String, double>? lastPlayedTimestamps,
    Map<String, SongAffinity>? affinities,
    TasteSnapshot? tasteSnapshot,
  }) {
    final request = _sortRequest(
      songs,
      sortOrder,
      userData: userData,
      shuffleConfig: shuffleConfig,
      playCounts: playCounts,
      lastPlayedTimestamps: lastPlayedTimestamps,
      affinities: affinities,
      tasteSnapshot: tasteSnapshot,
    );
    return _applyOrder(
        songs, _view({'op': 'sort', ...request})['order'] as List);
  }

  /// Smart "Recommended" order: the shuffle's sort-context weights, then the
  /// per-artist diversity cap so one artist cannot fill the top of the list.
  static List<Song> smartRecommendedOrder(
    List<Song> songs,
    TasteSnapshot taste,
    ShuffleConfig config,
    UserDataState userData,
  ) =>
      sortSongs(
        songs,
        SongSortOrder.recommended,
        userData: userData,
        shuffleConfig: config,
        tasteSnapshot: taste,
      );

  static LibraryFolderContent getFolderContent({
    required List<Song> allSongs,
    required String currentFullPath,
    SongSortOrder sortOrder = SongSortOrder.title,
    UserDataState? userData,
    ShuffleConfig? shuffleConfig,
    Map<String, int>? playCounts,
    Map<String, double>? lastPlayedTimestamps,
    Map<String, SongAffinity>? affinities,
    TasteSnapshot? tasteSnapshot,
  }) {
    final reply = _view({
      'op': 'folder',
      'root': currentFullPath,
      ..._sortRequest(
        allSongs,
        sortOrder,
        userData: userData,
        shuffleConfig: shuffleConfig,
        playCounts: playCounts,
        lastPlayedTimestamps: lastPlayedTimestamps,
        affinities: affinities,
        tasteSnapshot: tasteSnapshot,
      ),
      // Folder membership reads every path, not only the sort fields.
      'songs': _rows(allSongs),
    });

    return LibraryFolderContent(
      subFolders: [
        for (final name in reply['subFolders'] as List) name as String
      ],
      immediateSongs: _applyOrder(allSongs, reply['immediate'] as List),
      allSongsInFolder: _applyOrder(allSongs, reply['all'] as List),
      subFolderSongs: {
        for (final entry
            in (reply['subFolderSongs'] as Map<String, dynamic>).entries)
          entry.key: _applyOrder(allSongs, entry.value as List),
      },
    );
  }

  /// Splits a multi-artist string into individual artist names, handling
  /// `&`, `/`, `;`, commas, `and`, `x`, `ft.`, `feat.` and `vs.`.
  static List<String> splitArtistNames(String artistField) => [
        for (final name
            in _view({'op': 'splitArtists', 'artist': artistField})['artists']
                as List)
          name as String,
      ];

  static bool looksLikeArtist(List<Song> songs, String title) => _view({
        'op': 'looksLikeArtist',
        'songs': _rowsOf(songs, const ['artist']),
        'title': title,
      })['value'] as bool;

  static Map<String, List<Song>> groupByArtist(List<Song> songs) => _groups(
        _view({
          'op': 'groupArtist',
          'songs': _rowsOf(songs, const ['artist', 'title', 'album']),
        }),
        songs,
      );

  static Map<String, List<Song>> groupByAlbum(List<Song> songs) => _groups(
        _view({
          'op': 'groupAlbum',
          'songs': _rowsOf(songs, const ['album', 'title']),
        }),
        songs,
      );

  /// Returns sorted album names from [albumMap] with most tracks first.
  static List<String> sortAlbumsByTrackCount(
          Map<String, List<Song>> albumMap) =>
      _namesByCount(albumMap, 'namesByTracks');

  /// Returns sorted artist names from [artistMap] with most tracks first.
  static List<String> sortArtistsByTrackCount(
          Map<String, List<Song>> artistMap) =>
      _namesByCount(artistMap, 'namesByTracks');

  /// Display name for a song's album, collapsing blank tags so every song
  /// lands in exactly one group.
  static String albumDisplayName(Song song) =>
      _view({'op': 'albumName', 'album': song.album})['name'] as String;

  /// Groups [songs] by album, case-insensitively, preserving the first-seen
  /// casing as the display name.
  static Map<String, List<Song>> groupSongsByAlbum(List<Song> songs) => _groups(
        _view({
          'op': 'groupSongsByAlbum',
          'songs': _rowsOf(songs, const ['album']),
        }),
        songs,
      );

  /// Whether [songs] span more than one album.
  static bool hasMultipleAlbums(List<Song> songs) => _view({
        'op': 'multipleAlbums',
        'songs': _rowsOf(songs, const ['album']),
      })['value'] as bool;

  /// Total plays across [songs], preferring live [playCounts] over the
  /// snapshot on each song.
  static int totalPlaysForSongs(
    List<Song> songs, [
    Map<String, int>? playCounts,
  ]) =>
      (_view({
        'op': 'totalPlays',
        'songs': _rowsOf(songs, const ['play_count']),
        if (playCounts != null) 'playCounts': playCounts,
      })['value'] as num)
          .toInt();

  /// Returns album names ordered by total plays (descending), then track
  /// count, then name — so an artist's biggest albums lead the chip row.
  static List<String> sortAlbumsByTotalPlays(
    Map<String, List<Song>> albumGroups, {
    Map<String, int>? playCounts,
  }) {
    final request = _groupsRequest(albumGroups, 'namesByPlays');
    if (playCounts != null) request['playCounts'] = playCounts;
    return [for (final name in _view(request)['names'] as List) name as String];
  }

  /// Most-listened ordering with a title tiebreak, so unplayed songs still
  /// read alphabetically instead of in scan order.
  static List<Song> sortSongsByPlayCount(
    List<Song> songs, {
    Map<String, int>? playCounts,
  }) =>
      _applyOrder(
        songs,
        _view({
          'op': 'byPlayCount',
          'songs': _rowsOf(songs, const ['title', 'play_count']),
          if (playCounts != null) 'playCounts': playCounts,
        })['order'] as List,
      );

  /// The song whose cover represents a whole collection — an album, an artist,
  /// a playlist or a folder. Picks the most-listened track with a cover,
  /// preferring file-backed art over streamed URLs.
  static Song? pickCoverSong(
    List<Song> songs, {
    Map<String, int>? playCounts,
  }) {
    final index = _view({
      'op': 'coverSong',
      'songs': _rowsOf(songs, const ['title', 'play_count', 'cover_url']),
      if (playCounts != null) 'playCounts': playCounts,
    })['index'] as int?;
    return index == null ? null : songs[index];
  }

  static Map<String, Object?> _sortRequest(
    List<Song> songs,
    SongSortOrder sortOrder, {
    UserDataState? userData,
    ShuffleConfig? shuffleConfig,
    Map<String, int>? playCounts,
    Map<String, double>? lastPlayedTimestamps,
    Map<String, SongAffinity>? affinities,
    TasteSnapshot? tasteSnapshot,
  }) {
    final request = <String, Object?>{
      'songs': _rowsOf(songs, _sortFields(sortOrder)),
      'order': sortOrder.name,
    };
    if (playCounts != null) request['playCounts'] = playCounts;
    if (lastPlayedTimestamps != null) {
      request['lastPlayed'] = lastPlayedTimestamps;
    }
    if (affinities != null) {
      request['affinities'] = {
        for (final entry in affinities.entries)
          entry.key: {
            'affinity': entry.value.affinity,
            'playCount': entry.value.playCount,
            'skipRate': entry.value.skipRate,
            'recentSaturation': entry.value.recentSaturation,
          },
      };
    }
    if (sortOrder != SongSortOrder.recommended ||
        userData == null ||
        shuffleConfig == null) {
      return request;
    }

    request['weights'] = ShuffleWeights.fallback(shuffleConfig).toNative();
    if (tasteSnapshot == null) return request;

    request['taste'] = nativeTasteSnapshot(tasteSnapshot);
    request['familiarity'] = 1 - shuffleConfig.discoveryLevel;
    request['favoriteMultiplier'] = shuffleConfig.favoriteMultiplier;
    request['suggestLessMultiplier'] = shuffleConfig.suggestLessMultiplier;
    final artistKeys = tasteArtistKeys([
      for (final song in songs) (artist: song.artist, filename: song.filename),
    ]);
    request['artistKeys'] = {
      for (var index = 0; index < songs.length; index++)
        songs[index].filename: artistKeys[index],
    };
    final playlists = _userPlaylistFilenames(userData);
    request['favorites'] = [
      for (final song in songs)
        if (userData.isFavorite(song.filename)) song.filename
    ];
    request['suggestLess'] = [
      for (final song in songs)
        if (userData.isSuggestLess(song.filename)) song.filename
    ];
    request['playlist'] = playlists.toList();
    return request;
  }

  static Set<String> _userPlaylistFilenames(UserDataState userData) => {
        for (final playlist in userData.playlists)
          if (!playlist.isRecommendation)
            for (final song in playlist.songs) song.songFilename,
      };

  static Map<String, dynamic> _view(Map<String, Object?> request) =>
      NativeAccel.libraryView(request);

  static List<Map<String, Object?>> _rows(List<Song> songs) =>
      [for (final song in songs) song.toJson()];

  /// Only the fields the requested rule reads: a sort of a large library
  /// should not pay to encode artwork URLs and durations it never looks at.
  static List<Map<String, Object?>> _rowsOf(
    List<Song> songs,
    List<String> fields,
  ) =>
      [
        for (final song in songs)
          {
            'filename': song.filename,
            for (final field in fields) field: _field(song, field),
          }
      ];

  static Object? _field(Song song, String field) => switch (field) {
        'title' => song.title,
        'artist' => song.artist,
        'album' => song.album,
        'url' => song.url,
        'play_count' => song.playCount,
        'mtime' => song.mtime,
        'created_epoch_sec' => song.createdEpochSec,
        'song_date_epoch_sec' => song.songDateEpochSec,
        'cover_url' => song.coverUrl,
        _ => throw ArgumentError('unknown row field: $field'),
      };

  static List<String> _sortFields(SongSortOrder order) => switch (order) {
        SongSortOrder.title => const ['title'],
        SongSortOrder.artist => const ['title', 'artist'],
        SongSortOrder.album => const ['title', 'album', 'song_date_epoch_sec'],
        SongSortOrder.dateAdded => const ['created_epoch_sec', 'mtime'],
        SongSortOrder.playCount => const ['play_count'],
        SongSortOrder.recommended => const ['title', 'album', 'play_count'],
        SongSortOrder.songDateNewOld || SongSortOrder.songDateOldNew => const [
            'title',
            'song_date_epoch_sec'
          ],
        SongSortOrder.recentlyPlayed => const ['title'],
      };

  static List<Song> _applyOrder(List<Song> songs, List<dynamic> order) => [
        for (final index in order) songs[(index as num).toInt()],
      ];

  static Map<String, List<Song>> _groups(
    Map<String, dynamic> reply,
    List<Song> songs,
  ) =>
      {
        for (final group in reply['groups'] as List)
          (group as Map<String, dynamic>)['name'] as String: _applyOrder(
            songs,
            group['indices'] as List,
          ),
      };

  static Map<String, Object?> _groupsRequest(
    Map<String, List<Song>> groups,
    String op,
  ) {
    final songs = <Song>[];
    final definitions = <Map<String, Object?>>[];
    for (final entry in groups.entries) {
      final indices = <int>[];
      for (final song in entry.value) {
        indices.add(songs.length);
        songs.add(song);
      }
      definitions.add({'name': entry.key, 'indices': indices});
    }
    return {
      'op': op,
      'songs': _rowsOf(songs, const ['play_count']),
      'groups': definitions,
    };
  }

  static List<String> _namesByCount(
    Map<String, List<Song>> groups,
    String op,
  ) {
    final request = _groupsRequest(groups, op);
    return [for (final name in _view(request)['names'] as List) name as String];
  }
}
