import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

Future<BorderRadius> readDisplayCorners() async {
  if (!Platform.isAndroid && !Platform.isIOS) return BorderRadius.zero;
  try {
    const channel = MethodChannel('wispie/display_corners');
    final corners = await channel.invokeListMethod<num>('getRoundedCorners');
    if (corners == null || corners.length != 4) return BorderRadius.zero;
    return BorderRadius.only(
      topLeft: Radius.circular(corners[0].toDouble()),
      topRight: Radius.circular(corners[1].toDouble()),
      bottomLeft: Radius.circular(corners[2].toDouble()),
      bottomRight: Radius.circular(corners[3].toDouble()),
    );
  } on PlatformException {
    return BorderRadius.zero;
  } on MissingPluginException {
    return BorderRadius.zero;
  }
}
