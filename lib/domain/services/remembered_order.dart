import 'native_accel.dart';

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
  final order = NativeAccel.rememberedOrder(
    upcomingIds: [for (final item in upcoming) idOf(item)],
    rememberedIds: rememberedIds,
  );
  return [for (final index in order) upcoming[index]];
}
