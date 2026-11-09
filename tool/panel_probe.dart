// SPDX-License-Identifier: GPL-3.0-only
//
// End-to-end probe for the player panel's release physics.
//
//   dart run tool/panel_probe.dart
//
// The complaints were specific, so the checks are too: pulling the panel past
// either end has to slow down instead of stopping dead, a throw has to carry
// its speed into the settle, and a panel already on its way down has to be
// catchable — including by a fast swipe up that re-opens it.
//
// Artifact: build/panel_probe.json (exit code 1 on any failure).

import 'dart:convert';
import 'dart:io';

import 'package:wispie/domain/services/panel_release.dart';

final List<Map<String, Object?>> _results = [];
int _passed = 0;
int _failed = 0;

void check(String name, bool condition, {Object? detail}) {
  if (condition) {
    _passed++;
    _results.add({'check': name, 'ok': true});
    stdout.writeln('  ok   $name');
  } else {
    _failed++;
    _results.add({'check': name, 'ok': false, 'detail': detail?.toString()});
    stdout.writeln('  FAIL $name${detail == null ? '' : ' -> $detail'}');
  }
}

/// A typical phone: the panel travels most of the screen height.
const double _travel = 800;
const double _low = 0;
const double _high = 1;
const double _room = 0.05;

/// Thresholds the panel actually derives from its travel.
const double _fling = 440;
const double _actuation = 68;

bool _closes({
  required double anchor,
  required double current,
  double velocity = 0,
}) =>
    PanelRelease.closes(
      anchor: anchor,
      current: current,
      travel: _travel,
      velocity: velocity,
      flingVelocity: _fling,
      actuation: _actuation,
    );

void main() {
  stdout.writeln('Panel release probe');

  stdout.writeln('\nPull past either end');
  check('inside the range the surface is exactly where the finger is',
      PanelRelease.resist(0.5, low: _low, high: _high, room: _room) == 0.5);
  check('at the ends it is not damped yet',
      PanelRelease.resist(_low, low: _low, high: _high, room: _room) == _low);
  final List<double> pulls = [
    for (final excess in [0.01, 0.05, 0.2, 1.0, 20.0])
      PanelRelease.resist(_high + excess, low: _low, high: _high, room: _room),
  ];
  check('pull past the end moves the surface', pulls.first > _high,
      detail: pulls.first);
  check(
    'each extra pull moves it less than the one before',
    List.generate(pulls.length - 1, (i) => pulls[i + 1] - pulls[i])
        .every((step) => step > 0),
    detail: pulls,
  );
  check('a huge pull still cannot pass the rubber room',
      pulls.last <= _high + _room + 1e-9,
      detail: pulls.last);
  check(
    'one screen height of over-pull gives only a sliver',
    PanelRelease.resist(_low - 1.0, low: _low, high: _high, room: _room) >=
        _low - _room - 1e-9,
  );

  stdout.writeln('\nRelease decisions');
  check(
    'a flick down from full open closes',
    _closes(anchor: 1, current: 0.9, velocity: 1500),
  );
  check(
    'a flick up from the bar opens',
    _closes(anchor: 0, current: 0.1, velocity: -1500) == false,
  );
  check(
    'a small downward drag from full open springs back open',
    _closes(anchor: 1, current: 1 - 24 / _travel) == false,
  );
  check(
    'a deliberate downward drag from full open closes',
    _closes(anchor: 1, current: 1 - 200 / _travel),
  );
  check(
    'caught below the middle and let go, it finishes the drop',
    _closes(anchor: 0.45, current: 0.45),
  );
  check(
    'caught above the middle and let go, it continues opening',
    _closes(anchor: 0.55, current: 0.55) == false,
  );
  check(
    'a fast swipe up while it closes re-opens it',
    _closes(anchor: 0.3, current: 0.38, velocity: -1600) == false,
  );
  check(
    'a fast swipe down while it opens closes it',
    _closes(anchor: 0.7, current: 0.62, velocity: 1600),
  );
  check(
    'a slow drag near the closed end still settles closed',
    _closes(anchor: 0.3, current: 0.34, velocity: -200),
  );
  check(
    'the same slow drag from low down, pulled past the middle, opens',
    _closes(anchor: 0.3, current: 0.6, velocity: -200) == false,
  );

  stdout.writeln('\nMomentum handed to the spring');
  final double thrownDown =
      PanelRelease.momentum(velocity: 2400, travel: _travel);
  final double thrownUp =
      PanelRelease.momentum(velocity: -2400, travel: _travel);
  check('a downward throw pushes progress down', thrownDown < 0,
      detail: thrownDown);
  check('an upward throw pushes progress up', thrownUp > 0, detail: thrownUp);
  check(
    'the same speed in either direction is the same magnitude',
    (thrownDown + thrownUp).abs() < 1e-12,
  );
  check(
    'a hard throw is faster than a nudge',
    thrownDown.abs() >
        PanelRelease.momentum(velocity: 300, travel: _travel).abs(),
  );
  check(
    'speed is converted by the travel, not used raw',
    PanelRelease.momentum(velocity: 2400, travel: _travel) == -3.0,
  );

  stdout.writeln('\nInterruptible spring');
  final slow = PanelSpring(from: 0.8, to: 0, velocity: -0.3);
  final fast = PanelSpring(from: 0.8, to: 0, velocity: -4);
  final slowLanding = _landingTime(slow);
  final fastLanding = _landingTime(fast);
  check(
    'a slow release leaves at finger speed',
    (slow.velocityAt(0) + 0.3).abs() < 1e-9 &&
        ((slow.positionAt(0.001) - 0.8) / 0.001 + 0.3).abs() < 0.1,
  );
  check(
    'a quick flick lands meaningfully sooner than a gentle release',
    fastLanding < 0.24 && slowLanding - fastLanding > 0.09,
    detail: {'slowSeconds': slowLanding, 'fastSeconds': fastLanding},
  );
  check(
    'an unpadded spring reaches a stable endpoint',
    fast.positionAt(fastLanding) == 0 &&
        fast.positionAt(fastLanding + 0.1) == 0 &&
        fast.velocityAt(fastLanding) == 0,
  );
  final double caught = fast.positionAt(0.06);
  final double caughtVelocity = fast.velocityAt(0.06);
  final reverse = PanelSpring(
    from: caught,
    to: 1,
    velocity: caughtVelocity,
    released: false,
  );
  check(
    'reopening takes over at the current position and speed',
    reverse.positionAt(0) == caught &&
        (reverse.velocityAt(0) - caughtVelocity).abs() < 1e-9 &&
        reverse.velocityAt(0.05) > 0 &&
        reverse.positionAt(_landingTime(reverse)) == 1,
  );
  final rebound = PanelSpring(
    from: 0.8,
    to: 0,
    velocity: -4,
    reboundRoom: _room,
  );
  final double dockContact = _contactTime(rebound);
  final double bounceEnd = _landingTime(rebound);
  check(
    'the spring carries its speed through contact with the dock',
    dockContact < 0.24 &&
        (rebound.velocityAt(dockContact) -
                    rebound.velocityAt(dockContact - 0.001))
                .abs() <
            0.15,
  );
  check(
    'the dock dips once and returns to rest quickly',
    rebound.positionAt(dockContact + 0.04) < -0.02 &&
        rebound.positionAt(dockContact + 0.04) > -_room &&
        rebound.velocityAt(dockContact + 0.09) > 0 &&
        bounceEnd - dockContact < 0.15 &&
        rebound.positionAt(bounceEnd) == 0 &&
        rebound.positionAt(bounceEnd + 0.1) == 0,
  );
  final double overpull = PanelRelease.resist(
    1.08,
    low: 0,
    high: 1,
    room: _room,
  );
  check(
    'grabbing a rubber-banded panel preserves its drag position',
    (PanelRelease.unresist(overpull, low: 0, high: 1, room: _room) - 1.08)
            .abs() <
        1e-9,
  );

  stdout.writeln('\nCover motion');
  final nearOpen = PanelCoverMotion.pose(
    progress: 0.98,
    speed: -1,
    travel: _travel,
    insetChange: 350,
  );
  final double fingerTravel = _travel * 0.02;
  final double coverTravel = fingerTravel - 350 * (1 - nearOpen.inset);
  check(
    'the cover rides the sheet as the finger first pulls it down',
    coverTravel > 0.9 * fingerTravel,
    detail: {'finger': fingerTravel, 'cover': coverTravel},
  );
  final pullingUp = PanelCoverMotion.pose(
    progress: 0.5,
    speed: 3,
    travel: _travel,
    insetChange: 350,
  );
  final pullingDown = PanelCoverMotion.pose(
    progress: 0.5,
    speed: -3,
    travel: _travel,
    insetChange: 350,
  );
  check(
    'the artwork frame unfolds on each axis independently',
    pullingUp.height > pullingUp.width + 0.08,
  );
  check(
    'pull tension changes direction without moving the base geometry',
    pullingUp.tension == -pullingDown.tension &&
        pullingUp.tension > 0 &&
        pullingUp.inset == pullingDown.inset,
  );
  for (final double endpoint in [0.0, 1.0]) {
    final pose = PanelCoverMotion.pose(
      progress: endpoint,
      speed: 10,
      travel: _travel,
      insetChange: 350,
    );
    check(
      'the artwork is undistorted at progress $endpoint',
      pose.inset == endpoint &&
          pose.sideways == endpoint &&
          pose.width == endpoint &&
          pose.height == endpoint &&
          pose.tension == 0,
    );
  }

  final artifact = File('build/panel_probe.json');
  artifact.parent.createSync(recursive: true);
  artifact.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'generatedAt': DateTime.now().toIso8601String(),
      'passed': _passed,
      'failed': _failed,
      'checks': _results,
    }),
  );

  stdout.writeln('\n$_passed passed, $_failed failed');
  stdout.writeln('artifact: ${artifact.path}');
  if (_failed > 0) exitCode = 1;
}

double _landingTime(PanelSpring spring) {
  for (int ms = 0; ms <= 1000; ms++) {
    if (spring.isDone(ms / 1000)) return ms / 1000;
  }
  return double.infinity;
}

double _contactTime(PanelSpring spring) {
  for (int ms = 0; ms <= 1000; ms++) {
    if (spring.positionAt(ms / 1000) <= 0) return ms / 1000;
  }
  return double.infinity;
}
