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
  /// How many times a streamed track's cache is re-checked while it plays.
  /// A track downloads as it plays, so the waveform becomes available mid-song
  /// and the bar upgrades itself instead of waiting for the next play.
  static const int _maxPathAttempts = 20;
  static const Duration _pathRetryDelay = Duration(seconds: 3);

  Future<String?>? _path;
  int _pathAttempts = 0;
  bool _retryScheduled = false;

  @override
  void initState() {
    super.initState();
    _path = _resolvePath();
  }

  @override
  void didUpdateWidget(TrackProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.filename != widget.song.filename) {
      _pathAttempts = 0;
      _path = _resolvePath();
    }
  }

  void _retryRemotePath() {
    if (_retryScheduled || _pathAttempts >= _maxPathAttempts) return;
    _retryScheduled = true;
    Future<void>.delayed(_pathRetryDelay, () {
      _retryScheduled = false;
      if (!mounted) return;
      _pathAttempts++;
      setState(() => _path = _resolvePath());
    });
  }

  Future<String?> _resolvePath() async {
    final song = widget.song;
    if (song.isLocal) return song.url;
    final id = song.remoteId;
    if (song.isYoutube && id != null && id.isNotEmpty) {
      final file = await OnlineAudioCache.instance.completeFile(
        OnlineAudioCache.providerYouTube,
        id,
      );
      return file?.path;
    }
    return null;
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
      future: _path,
      builder: (context, snapshot) {
        final path = snapshot.data;
        if (path == null || path.isEmpty) {
          _retryRemotePath();
          return basic();
        }
        return waveform(path);
      },
    );
  }
}
