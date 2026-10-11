import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One entry per icon variant. The first value is the bundled default; its
/// position also picks the Windows icon resource, so only append. Adding a
/// variant also needs native registration, see assets/icons/README.md.
enum AppIconStyle {
  newIcon('new', 'New'),
  classic('classic', 'Classic');

  const AppIconStyle(this.id, this.label);

  final String id;
  final String label;

  static const AppIconStyle defaultStyle = AppIconStyle.newIcon;

  String get previewAsset => 'assets/icons/$id/preview.png';

  /// Suffix the native sides use for aliases, asset sets and resources.
  String get nativeName => '${id[0].toUpperCase()}${id.substring(1)}';

  static AppIconStyle fromId(String? id) => AppIconStyle.values
      .firstWhere((s) => s.id == id, orElse: () => defaultStyle);
}

/// Swaps the app icon at runtime. What actually changes is per-platform:
/// the launcher icon on Android/iOS, the Dock icon on macOS, and the window
/// and taskbar icon on Windows/Linux. File-manager and launcher entries on
/// desktop keep the bundled (new) icon.
class AppIconService {
  AppIconService._();

  static const MethodChannel _channel = MethodChannel('wispie/app_icon');

  static bool get supported =>
      !kIsWeb &&
      (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows ||
          Platform.isLinux);

  static Future<void> apply(AppIconStyle style) async {
    if (!supported) return;
    final args = <String, Object>{
      'name': style.nativeName,
      'all': [for (final s in AppIconStyle.values) s.nativeName],
      'index': style.index,
      'isDefault': style == AppIconStyle.defaultStyle,
    };
    if (Platform.isLinux) {
      final dir = File(Platform.resolvedExecutable).parent.path;
      args['path'] = '$dir/data/flutter_assets/assets/icons/${style.id}/'
          'window.png';
    }
    try {
      await _channel.invokeMethod<void>('setAppIcon', args);
    } on PlatformException catch (e) {
      debugPrint('AppIconService: ${e.message}');
    } on MissingPluginException {
      // Older native runner without the channel.
    }
  }
}
