import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/presentation/widgets/album_art_image.dart';
import 'package:wispie/presentation/widgets/folder_grid_image.dart';

Song _song(String name, String cover) {
  return Song(
    title: name,
    artist: 'Artist',
    album: 'Album',
    // Image-looking filename so AlbumArtImage skips the lazy song-cover
    // refresh (which needs a database) and exercises only the layout path.
    filename: '$name.jpg',
    url: '/music/$name.mp3',
    coverUrl: cover,
  );
}

void main() {
  testWidgets('AlbumArtImage with infinite dims does not throw toInt',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AlbumArtImage(
            url: '/tmp/does-not-exist.jpg',
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('StaticAlbumArtImage with infinite dims does not throw',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StaticAlbumArtImage(
            url: '/tmp/does-not-exist.jpg',
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('FolderGridImage collage at detail size does not throw',
      (tester) async {
    final songs = [
      _song('s1', '/tmp/cover-1.jpg'),
      _song('s2', '/tmp/cover-2.jpg'),
      _song('s3', '/tmp/cover-3.jpg'),
      _song('s4', '/tmp/cover-4.jpg'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          // Same shape as SongListScreen header: finite size, tiles laid out
          // with infinite constraints inside.
          body: FolderGridImage(songs: songs, size: 220),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
