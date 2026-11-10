import '../../models/song.dart';
import 'native_accel.dart';

class MergeCandidateGroup {
  final String title;
  final List<Song> songs;

  const MergeCandidateGroup({
    required this.title,
    required this.songs,
  });
}

class SongMergeFinder {
  const SongMergeFinder._();

  static List<MergeCandidateGroup> findCandidates(
    List<Song> songs,
    Map<String, List<String>> existingMergedGroups,
  ) {
    if (songs.length < 2) return [];
    final response = NativeAccel.mergeCandidates(
      songs: [
        for (final song in songs)
          {
            'title': song.title,
            'artist': song.artist,
            'filename': song.filename,
          },
      ],
      existingGroups: existingMergedGroups,
    );
    return [
      for (final row in response['groups'] as List<dynamic>)
        MergeCandidateGroup(
          title: (row as Map<String, dynamic>)['title'] as String,
          songs: [
            for (final index in row['indices'] as List<dynamic>)
              songs[(index as num).toInt()],
          ],
        ),
    ];
  }
}
