import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Keeps phones portrait-only while letting tablets rotate.
///
/// The Android manifest cannot lock orientation per device class, so it
/// declares `unspecified` and this widget enforces the policy from the window
/// size instead: phone-sized windows (shortest side under 600dp, the same
/// threshold the mini player uses to spot tablets) lock to portrait, anything
/// larger rotates freely. iPhones stay portrait-locked in Info.plist and
/// iPads opt into landscape there, so on iOS this only re-asserts the phone
/// lock. Desktop platforms have no orientation concept and are skipped.
class OrientationPolicy extends StatefulWidget {
  final Widget child;

  const OrientationPolicy({super.key, required this.child});

  @override
  State<OrientationPolicy> createState() => _OrientationPolicyState();
}

class _OrientationPolicyState extends State<OrientationPolicy> {
  static const double _tabletShortestSide = 600;

  bool? _portraitOnly;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    final portraitOnly =
        MediaQuery.sizeOf(context).shortestSide < _tabletShortestSide;
    if (portraitOnly == _portraitOnly) return;
    _portraitOnly = portraitOnly;
    SystemChrome.setPreferredOrientations(
      portraitOnly
          ? const [DeviceOrientation.portraitUp]
          : DeviceOrientation.values,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
