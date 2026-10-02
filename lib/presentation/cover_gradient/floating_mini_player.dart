import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/providers.dart';
import '../widgets/now_playing_bar.dart';
import 'glass_chrome.dart';

/// Floating glass wrapper around the existing mini player.
///
/// The wrapped [NowPlayingBar] is untouched so every other screen keeps its
/// exact look. Used only inside the gradient detail screen.
class FloatingGlassMiniPlayer extends ConsumerWidget {
  const FloatingGlassMiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.watch(audioPlayerManagerProvider).currentSongNotifier;
    return ValueListenableBuilder<Song?>(
      valueListenable: notifier,
      builder: (context, current, _) {
        if (current == null) return const SizedBox.shrink();
        return const GlassPill(
          margin: EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: NowPlayingBar(
            padding: EdgeInsets.zero,
            embedded: true,
            compact: true,
          ),
        );
      },
    );
  }
}
