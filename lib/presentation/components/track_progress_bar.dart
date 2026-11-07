import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../models/song.dart';
import '../../providers/settings_provider.dart';
import '../../services/online_audio_cache.dart';
import '../widgets/basic_progress_bar.dart';
import '../widgets/reactive_waveform_progress_bar.dart';
import '../widgets/waveform_progress_bar.dart';

/// Seek bar shared by both player shells.
///
/// A waveform is decoded from a file, so a streamed track only gets one once the
/// download cache holds the whole track. Until then this shows the plain bar
/// instead of a flat placeholder waveform, which reads as a broken control.
class TrackProgressBar extends ConsumerStatefulWidget {
  const TrackProgressBar({
    super.key,
    required this.song,
    required this.total,
    required this.player,
  });

  final Song song;
  final Duration total;
  final AudioPlayer player;

  @override
  ConsumerState<TrackProgressBar> createState() => _TrackProgressBarState();
}

class _TrackProgressBarState extends ConsumerState<TrackProgressBar> {
  Future<String?>? _path;
  StreamSubscription<String>? _downloadSubscription;

  @override
  void initState() {
    super.initState();
    _watchPath();
  }

  @override
  void didUpdateWidget(TrackProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.filename != widget.song.filename) {
      _watchPath();
    }
  }

  @override
  void dispose() {
    _downloadSubscription?.cancel();
    super.dispose();
  }

  void _watchPath() {
    _downloadSubscription?.cancel();
    _downloadSubscription = null;
    _path = null;
    final song = widget.song;
    final id = song.remoteId;
    if (!song.isYoutube || id == null || id.isEmpty) return;

    final cache = OnlineAudioCache.instance;
    Future<String?> resolvePath() async =>
        (await cache.completeFile(OnlineAudioCache.providerYouTube, id))?.path;
    _downloadSubscription = cache.completions.listen((completed) {
      if (completed == id) setState(() => _path = resolvePath());
    });
    _path = resolvePath();
  }

  @override
  Widget build(BuildContext context) {
    final type = ref.watch(settingsProvider.select((s) => s.progressBarType));
    final player = widget.player;
    final total = widget.total;
    final filename = widget.song.filename;

    Widget basic() => BasicProgressBar(
          key: ValueKey('basic_$filename'),
          player: player,
          total: total,
          onSeek: player.seek,
        );

    if (type == ProgressBarType.basic) return basic();

    Widget waveform(String path) {
      if (type == ProgressBarType.reactive) {
        return ReactiveWaveformProgressBar(
          key: ValueKey('reactive_$filename'),
          filename: filename,
          path: path,
          progress: player.position,
          total: total,
          positionStream: player.positionStream,
          onSeek: player.seek,
        );
      }
      return WaveformProgressBar(
        key: ValueKey('waveform_$filename'),
        filename: filename,
        path: path,
        progress: player.position,
        total: total,
        positionStream: player.positionStream,
        onSeek: player.seek,
      );
    }

    if (widget.song.isLocal) return waveform(widget.song.url);

    return FutureBuilder<String?>(
      key: ValueKey(filename),
      future: _path,
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null || path.isEmpty) {
          return basic();
        }
        return waveform(path);
      },
    );
  }
}
