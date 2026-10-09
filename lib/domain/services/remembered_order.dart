/// Reorders [upcoming] to follow [rememberedIds].
///
/// Entries the remembered order no longer lists (already played, or removed)
/// are dropped by virtue of not being in [upcoming]. Entries it does not know
/// about (added after the order was remembered) keep their relative order and
/// go to the end.
List<T> applyRememberedOrder<T>(
  List<T> upcoming,
  List<String> rememberedIds,
  String Function(T item) idOf,
) {
  final rank = <String, int>{};
  for (int i = 0; i < rememberedIds.length; i++) {
    rank.putIfAbsent(rememberedIds[i], () => i);
  }

  final known = <T>[];
  final unknown = <T>[];
  for (final item in upcoming) {
    (rank.containsKey(idOf(item)) ? known : unknown).add(item);
  }

  known.sort((a, b) => rank[idOf(a)]!.compareTo(rank[idOf(b)]!));
  return [...known, ...unknown];
}
