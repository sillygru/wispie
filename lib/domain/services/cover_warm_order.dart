import '../../data/rust/wispie_core.dart';

/// [items] reordered so the ones that will be needed soonest come first: the
/// entry after [currentIndex], then forward to the end, then wrapping round to
/// the start and back up to [currentIndex] itself.
///
/// [currentIndex] may be out of range, in which case the list keeps its natural
/// order. The ordering lives in the native core.
List<T> orderForWarming<T>(List<T> items, int currentIndex) {
  if (items.length <= 1) return List<T>.from(items);
  final reply = WispieCore.helper({
    'action': 'warm_order',
    'count': items.length,
    'current': currentIndex,
  });
  return [
    for (final index in (reply['order'] as List).cast<num>())
      items[index.toInt()],
  ];
}
