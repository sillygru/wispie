import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/services/remembered_order.dart';

List<String> _apply(List<String> upcoming, List<String> remembered) {
  return applyRememberedOrder<String>(upcoming, remembered, (s) => s);
}

void main() {
  group('applyRememberedOrder', () {
    test('restores the remembered order', () {
      expect(
        _apply(['a', 'b', 'c', 'd'], ['c', 'a', 'd', 'b']),
        ['c', 'a', 'd', 'b'],
      );
    });

    test('ignores remembered entries that are no longer upcoming', () {
      expect(
        _apply(['b', 'd'], ['c', 'd', 'a', 'b']),
        ['d', 'b'],
      );
    });

    test('appends songs added after the order was remembered', () {
      expect(
        _apply(['x', 'b', 'a', 'y'], ['a', 'b']),
        ['a', 'b', 'x', 'y'],
      );
    });

    test('keeps relative order of unknown songs', () {
      expect(_apply(['y', 'x'], ['a']), ['y', 'x']);
    });

    test('empty remembered order keeps upcoming as is', () {
      expect(_apply(['a', 'b', 'c'], []), ['a', 'b', 'c']);
    });

    test('empty upcoming returns empty', () {
      expect(_apply([], ['a', 'b']), isEmpty);
    });

    test('restoring again after a partial play keeps the same remaining order',
        () {
      final shuffled = ['d', 'a', 'c', 'b'];

      expect(_apply(['a', 'b', 'c', 'd'], shuffled), shuffled);
      expect(_apply(['c', 'b'], shuffled), ['c', 'b']);
    });
  });
}
