# Motion engine

One layer for every animation in the app. It knows about progress, springs,
gestures and clocks; it knows nothing about songs, playlists or providers.

## Rules

- **One driver per gesture.** A surface that a finger can move owns a single
  `AnimationController` covering every state it has. Everything visual is a
  pure function of that value through `motion_math.dart`. A second controller
  for one property means two sources of truth, and they will disagree mid-drag.
- **One timing table.** `MotionTokens` is the only place a duration or curve is
  written. `PlayerTokens` and `AppTokens` alias it; feature code uses one of the
  three, never a raw `Duration`.
- **One reduce-motion answer.** `MotionPolicy.of(context)` decides. Nothing else
  reads the OS flag. Reduced motion removes decoration and instant transitions;
  it never disables an interaction.
- **Springs for anything interruptible.** A press, a toggle, a sheet that can be
  grabbed mid-flight. Curves are for one-shot entrances.
- **Per-frame values do not rebuild parents.** Use `ProgressGeometry` +
  `ListenableTranslate`, or `MotionValueCondition` for a boundary that flips.
- **Side effects at motion start.** Haptics, wakelocks and system-UI changes
  belong with the animation, not after it.
- **Hidden means stopped.** Ticker mode, `FadeIgnoreTransition` and
  `RouteSettledMixin` keep covered surfaces from paying for frames.

## Map

| Need | Use |
| --- | --- |
| Timing, curves | `MotionTokens` |
| Spring feel | `MotionSprings`, `MotionSprings.driveTo` |
| Reduce motion | `MotionPolicy`, `MotionScope` |
| Derived layout from one value | `ProgressGeometry`, `motion_math.dart` |
| Commit to a state after release | `SnapEngine`, `SnapTuning` |
| Curve or landing as a simulation | `CurveSimulation`, `LandingSimulation` |
| Drag with real release velocity | `MotionDragArea`, `MotionDragTracker` |
| Announce a row that changed place | `MotionPop` |
| Toggle that can be re-pressed mid-flight | `SpringMorph` |
| Swipe between items | `decideCarouselSwipe`, `CarouselWindow`, `carouselSlotTravel` |
| Rebuild-free leaves | `ListenableTranslate`, `ListenablePadding`, `MotionValueCondition` |
| Fade out and stop paying | `FadeIgnoreTransition` |
| Wait for a route to land | `RouteSettledMixin.whenRouteSettled` |
| List entrances that run once | `MotionEntranceLimiter`, `MotionEntrance` |
| Row exit before the delete commits | `AnimatedRemoval`, `RemovableEntry` |
| Scroll feel | `MotionScrollBehavior` |
| Ambient time | `MotionClock`, `MotionClockBuilder` |
| Accent crossfade | `MotionColorLerp` |
| Haptics | `MotionHaptics` |

## Applying it to a new surface

1. Decide the rest states and the one progress value that covers them.
2. Give the surface a driver; derive its geometry with `ProgressGeometry` or
   direct expressions in `motion_math.dart`.
3. Wrap the drag in `MotionDragArea`; on release, ask `SnapTuning` or
   `decideCarouselSwipe` for the target, then hand it to `SnapEngine` so a new
   gesture supersedes the old completion.
4. Listen to the geometry in leaves only. No `setState` per tick.
5. Check it once with reduce motion on.

## Extending a surface without a rewrite

The engine is additive. A screen that already animates correctly can adopt
pieces one at a time: tokens first, then `MotionPolicy`, then a drag, then the
entrance limiter. Nothing here requires a screen to be rebuilt around it.
