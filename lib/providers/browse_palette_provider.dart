import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/color_extraction_service.dart';

/// Palettes claimed by open artist / album pages, innermost last. The shell's
/// now playing bar and side panel follow the top entry while one is open, and
/// fall back to the playing track's palette once every page has released.
class BrowsePaletteNotifier extends Notifier<List<(Object, ExtractedPalette)>> {
  @override
  List<(Object, ExtractedPalette)> build() => const [];

  void claim(Object owner, ExtractedPalette palette) {
    final i = state.indexWhere((e) => identical(e.$1, owner));
    final next = [...state];
    if (i >= 0) {
      next[i] = (owner, palette);
    } else {
      next.add((owner, palette));
    }
    state = next;
  }

  void release(Object owner) {
    if (!state.any((e) => identical(e.$1, owner))) return;
    state = state.where((e) => !identical(e.$1, owner)).toList();
  }
}

final browsePaletteProvider =
    NotifierProvider<BrowsePaletteNotifier, List<(Object, ExtractedPalette)>>(
        BrowsePaletteNotifier.new);

/// Whether the Library tab (which hosts artist / album pages) is the visible
/// tab; pages left open in a background tab must not theme the app.
class BrowseTabActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool active) => state = active;
}

final browseTabActiveProvider = NotifierProvider<BrowseTabActiveNotifier, bool>(
    BrowseTabActiveNotifier.new);

final activeBrowsePaletteProvider = Provider<ExtractedPalette?>((ref) {
  if (!ref.watch(browseTabActiveProvider)) return null;
  final list = ref.watch(browsePaletteProvider);
  return list.isEmpty ? null : list.last.$2;
});
