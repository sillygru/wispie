// SPDX-License-Identifier: GPL-3.0-only
//
// Probe for music search containers, artist pages and thumbnail right-sizing.
//
//   dart run tool/youtube_music_probe.dart
//
// Drives the shipping parsers against fixtures shaped like the InnerTube pages
// they read, so a query that names an album, a playlist or an artist produces
// the rows the app needs, and a row never downloads a bigger still than it
// draws.
//
// Artifact: build/youtube_music_probe.json (exit code 1 on any failure).

import 'dart:convert';
import 'dart:io';

import 'package:wispie/domain/services/cover_path.dart';
import 'package:wispie/domain/services/youtube_library.dart';

final List<Map<String, Object?>> _checks = <Map<String, Object?>>[];

void check(String name, bool ok, {Object? detail}) {
  _checks.add({'check': name, 'ok': ok, if (detail != null) 'detail': detail});
  stdout.writeln(
      '${ok ? 'ok  ' : 'FAIL'} $name${detail == null ? '' : '  ($detail)'}');
}

Map<String, Object?> _text(String value) => {
      'runs': [
        {'text': value},
      ],
    };

Map<String, Object?> _thumbs(String url, int width) => {
      'musicThumbnailRenderer': {
        'thumbnail': {
          'thumbnails': [
            {'url': url, 'width': width, 'height': width},
          ],
        },
      },
    };

Map<String, Object?> _shelfRow({
  required String title,
  String? videoId,
  String? browseId,
  String byline = 'Song • 4:11',
  List<String> extraColumns = const [],
}) {
  final columns = <Map<String, Object?>>[
    {
      'musicResponsiveListItemFlexColumnRenderer': {'text': _text(title)},
    },
    {
      'musicResponsiveListItemFlexColumnRenderer': {'text': _text(byline)},
    },
    for (final column in extraColumns)
      {
        'musicResponsiveListItemFlexColumnRenderer': {'text': _text(column)},
      },
  ];
  return {
    'musicResponsiveListItemRenderer': {
      'flexColumns': columns,
      if (videoId != null) 'playlistItemData': {'videoId': videoId},
      if (videoId != null)
        'overlay': {
          'musicItemThumbnailOverlayRenderer': {
            'content': {
              'musicPlayButtonRenderer': {
                'playNavigationEndpoint': {
                  'watchEndpoint': {'videoId': videoId},
                },
              },
            },
          },
        },
      if (browseId != null)
        'navigationEndpoint': {
          'browseEndpoint': {'browseId': browseId},
        },
      'thumbnail': _thumbs(
        'https://i.ytimg.com/vi/${videoId ?? 'x'}/hqdefault.jpg',
        480,
      ),
    },
  };
}

Map<String, Object?> _twoRow({
  required String title,
  required String subtitle,
  required String browseId,
}) =>
    {
      'musicTwoRowItemRenderer': {
        'title': _text(title),
        'subtitle': _text(subtitle),
        'navigationEndpoint': {
          'browseEndpoint': {'browseId': browseId},
        },
        'thumbnail':
            _thumbs('https://i.ytimg.com/pl/$browseId/hqdefault.jpg', 480),
      },
    };

/// A search page that names a song, an album, a playlist and an artist.
Map<String, Object?> _searchPage() => {
      'contents': {
        'sectionListRenderer': {
          'contents': [
            {
              'musicShelfRenderer': {
                'contents': [
                  _shelfRow(
                    title: 'Runaway',
                    videoId: 'v1',
                    extraColumns: ['36M plays'],
                  ),
                  _shelfRow(
                    title: 'All My Demons',
                    browseId: 'MPREb_album1',
                    byline: 'Album • Aurora',
                    extraColumns: ['2016'],
                  ),
                ],
              },
            },
            {
              'musicCarouselShelfRenderer': {
                'contents': [
                  _twoRow(
                    title: 'Aurora Mix',
                    subtitle: 'Playlist • YouTube Music',
                    browseId: 'VLPLmix1',
                  ),
                  _twoRow(
                    title: 'Aurora',
                    subtitle: 'Artist',
                    browseId: 'UCartist1',
                  ),
                ],
              },
            },
          ],
        },
      },
    };

/// An artist page: header, its own sort chips, songs and albums.
Map<String, Object?> _artistPage() => {
      'header': {
        'musicImmersiveHeaderRenderer': {
          'title': _text('Aurora'),
          'thumbnail': _thumbs('https://yt3.ggpht.com/a=s120', 120),
        },
      },
      'contents': {
        'sectionListRenderer': {
          'contents': [
            {
              'musicShelfRenderer': {
                'header': {
                  'musicChipCloudRenderer': {
                    'chips': [
                      {
                        'musicSortFilterButtonRenderer': {
                          'title': _text('Popularity'),
                          'params': '',
                          'icon': {'iconType': 'CHECK'},
                        },
                      },
                      {
                        'musicSortFilterButtonRenderer': {
                          'title': _text('Release date'),
                          'params': 'SORT_BY_DATE',
                        },
                      },
                    ],
                  },
                },
                'contents': [
                  _shelfRow(
                    title: 'Runaway',
                    videoId: 'v1',
                    byline: '4:11',
                    extraColumns: ['36M plays'],
                  ),
                ],
              },
            },
            {
              'musicCarouselShelfRenderer': {
                'contents': [
                  _twoRow(
                    title: 'All My Demons',
                    subtitle: 'Album • 2016',
                    browseId: 'MPREb_album1',
                  ),
                ],
              },
            },
          ],
        },
      },
    };

Map<String, Object?> _albumPage() => {
      'header': {
        'musicResponsiveHeaderRenderer': {
          'title': _text('All My Demons'),
          'subtitle': _text('Album • Aurora • 2016'),
          'thumbnail': _thumbs('https://i.ytimg.com/vi/x/hqdefault.jpg', 480),
        },
      },
      'contents': {
        'sectionListRenderer': {
          'contents': [
            {
              'musicShelfRenderer': {
                'contents': [
                  _shelfRow(
                    title: 'Runaway',
                    videoId: 'v1',
                    byline: '4:11',
                  ),
                  _shelfRow(
                    title: 'In Boxes',
                    videoId: 'v2',
                    byline: '3:08',
                  ),
                ],
              },
            },
          ],
        },
      },
    };

void main() {
  final search = _searchPage();
  final tracks = parseMusicTracks(search);
  final containers = parseMusicContainers(search);
  final albums = containers.where((c) => c.kind == YouTubeContainerKind.album);
  final playlists =
      containers.where((c) => c.kind == YouTubeContainerKind.playlist);
  final artists =
      containers.where((c) => c.kind == YouTubeContainerKind.artist);

  check('search: only the song is a track', tracks.length == 1,
      detail: tracks.map((t) => t.title).join(', '));
  check('search: the song keeps its plays', tracks.first.viewCountText != null,
      detail: tracks.first.viewCountText);
  check('search: the album row is an album', albums.length == 1,
      detail: albums.map((c) => '${c.title}/${c.id}').join(', '));
  check('search: the album keeps its byline without the type label',
      albums.firstOrNull?.subtitle == 'Aurora • 2016',
      detail: albums.firstOrNull?.subtitle);
  check('search: the carousel playlist is a playlist',
      playlists.length == 1 && playlists.first.id == 'VLPLmix1',
      detail: playlists.map((c) => c.id).join(', '));
  check('search: the artist is an artist',
      artists.length == 1 && artists.first.id == 'UCartist1',
      detail: artists.map((c) => c.id).join(', '));

  final artist = _artistPage();
  final header = parseArtistHeader(artist);
  final sorts = parseMusicSortOptions(artist);
  final artistAlbums = parseMusicContainers(artist)
      .where((c) => c.kind == YouTubeContainerKind.album)
      .toList();

  check('artist: the header names the artist', header.name == 'Aurora',
      detail: header.name);
  check('artist: the avatar is kept', (header.thumbnailUrl ?? '').isNotEmpty,
      detail: header.thumbnailUrl);
  check('artist: both sorts are read', sorts.length == 2,
      detail: sorts.map((s) => s.label).join(', '));
  check('artist: the selected sort leads', sorts.first.selected,
      detail: sorts.first.label);
  check('artist: a sort keeps its token',
      sorts.last.params == 'SORT_BY_DATE' && !sorts.last.selected,
      detail: sorts.last.params);
  check('artist: its albums are read', artistAlbums.length == 1,
      detail: artistAlbums.firstOrNull?.title);

  final albumHeader = parseCollectionHeader(_albumPage());
  check('album: title and artist come from the header',
      albumHeader.title == 'All My Demons' && albumHeader.artist == 'Aurora',
      detail: '${albumHeader.title} / ${albumHeader.artist}');
  check('album: its tracks are parsed',
      parseMusicTracks(_albumPage()).length == 2,
      detail: parseMusicTracks(_albumPage()).length);

  // Data: a 52dp row must not download a 480px still, and a full-size cover
  // must still be able to ask for more than the row did.
  const still = 'https://i.ytimg.com/vi/v1/hqdefault.jpg';
  check(
      'size: a row downgrades a 480px still to 320',
      CoverPath.renditionUrl(still, wanted: 156) ==
          'https://i.ytimg.com/vi/v1/mqdefault.jpg',
      detail: CoverPath.renditionUrl(still, wanted: 156));
  check(
      'size: a big cover upgrades a 320px still',
      CoverPath.renditionUrl('https://i.ytimg.com/vi/v1/mqdefault.jpg',
              wanted: 640) ==
          'https://i.ytimg.com/vi/v1/sddefault.jpg',
      detail: CoverPath.renditionUrl('https://i.ytimg.com/vi/v1/mqdefault.jpg',
          wanted: 640));
  check(
      'size: a matching rendition is left alone',
      CoverPath.renditionUrl('https://i.ytimg.com/vi/v1/sddefault.jpg',
              wanted: 640) ==
          null);
  check(
      'size: catalogue rows ask for 320, not 720',
      upscaleThumbnailUrl('https://yt3.ggpht.com/a=s60', size: 320) ==
          'https://yt3.ggpht.com/a=s320',
      detail: upscaleThumbnailUrl('https://yt3.ggpht.com/a=s60', size: 320));

  final failed = _checks.where((c) => c['ok'] != true).toList();
  final artifact = File('build/youtube_music_probe.json');
  artifact.parent.createSync(recursive: true);
  artifact.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'passed': _checks.length - failed.length,
      'failed': failed.length,
      'checks': _checks,
    }),
  );
  stdout.writeln(
    '\n${_checks.length - failed.length}/${_checks.length} checks passed'
    ' -> ${artifact.path}',
  );
  if (failed.isNotEmpty) exitCode = 1;
}
