import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/services/screen_wake_lock_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScreenWakeLockService', () {
    final service = ScreenWakeLockService.instance;

    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(
        'dev.flutter.pigeon.wakelock_plus_platform_interface.WakelockPlusApi.toggle',
        (ByteData? message) async {
          return const StandardMessageCodec().encodeMessage(<Object?>[null]);
        },
      );
    });

    setUp(() {
      service.resetForTest();
    });

    tearDown(() {
      service.resetForTest();
    });

    test('acquires and releases correctly', () async {
      expect(service.isHeld, isFalse);

      await service.acquire('lyrics_screen');
      expect(service.isHeld, isTrue);

      await service.release('lyrics_screen');
      expect(service.isHeld, isFalse);
    });

    test('handles multiple acquisition reasons cleanly', () async {
      await service.acquire('reason_1');
      await service.acquire('reason_2');
      expect(service.isHeld, isTrue);

      await service.release('reason_1');
      expect(service.isHeld, isTrue);

      await service.release('reason_2');
      expect(service.isHeld, isFalse);
    });
  });
}
