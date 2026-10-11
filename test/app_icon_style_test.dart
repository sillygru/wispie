import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/services/app_icon_service.dart';

void main() {
  test('new icon is the default and unknown ids fall back to it', () {
    expect(AppIconStyle.fromId(null), AppIconStyle.newIcon);
    expect(AppIconStyle.fromId('garbage'), AppIconStyle.newIcon);
  });

  test('ids round-trip', () {
    for (final s in AppIconStyle.values) {
      expect(AppIconStyle.fromId(s.id), s);
    }
  });
}
