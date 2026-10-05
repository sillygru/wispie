# Agent Documentation - Wispie Music Player

Local-first Flutter music player. Riverpod 3, `just_audio`, two SQLite files, MVVM/Repository.

## Critical Rules

- **No git write commands.** NEVER run `git checkout`, `git reset`, `git revert`, `git clean`, or any file/branch-discarding operation. Parallel agents work on different files at the same time and destructive git ops destroy their work. Read-only git (`git status`, `git diff`, `git log`) is fine.
- **No building.** Do not run `flutter build` or `flutter run` unless explicitly requested.
- **No emojis** in code, comments, or messages.
- **`filename` is the primary key for all user data.** Never change this (see Architecture).
- **Comments**: minimal, explain _why_ not _what_. No "// added this" style comments.
- **Before finishing any code change:** `dart format .` then `flutter analyze --no-pub`, both clean.

## Verification

CI (`.github/workflows/flutter_tests.yml`) gates on, in this order:

```bash
dart format --set-exit-if-changed .   # runs on third_party/ too (397 files incl. build/)
flutter analyze                       # analysis_options.yaml excludes third_party + platform dirs
flutter test                          # ~90 files, no integration_test/, no goldens
```

Run a focused subset while iterating, e.g. `flutter test test/shuffle_logic_test.dart`. Note the local Flutter is 3.47.2 while the test workflow pins 3.44.2 and the build workflow pins 3.47.2.

`dart format .` walks `build/` (gitignored) and can warn about package resolution there; harmless. There is no codegen: `build_runner` is a dev dependency but no `.g.dart` files exist and nothing invokes it. Don't run it.

## Architecture

### Two generations of layout (mid-migration)

Legacy: `lib/models/`, `lib/services/`, `lib/providers/`, `lib/theme/`. Newer: `lib/data/`, `lib/domain/`, `lib/presentation/`. Prefer the newer layers for new code, but don't bulk-relocate existing files as a side effect of unrelated work. `lib/domain/services/` holds the pure, Flutter-free logic that tests hit directly.

### `filename` is the primary key for user data

Every user-data table (`favorite`, `suggestless`, `hidden`, `playlist_song`, `merged_song`, `song_mood`, `recommendation_*`, `cover_miss`) keys on the song's **filename**, not a path or synthetic id. Renaming a file outside the app orphans its stats. Merged songs map several filenames to one group id (`AudioPlayerManager._getMergedSiblings`).

### Databases

`DatabaseService` (`lib/services/database_service.dart`, `.instance`) owns `wispie_stats.db` (play sessions/events) and `wispie_data.db` (library, playlists, favorites, merged groups, mood tags, queue snapshots).

Schema is canonical in `lib/data/migrations.dart` only: `_userDataTableStmts` / `_createUserDataIndexes` for fresh creates, plus explicit `upgradeUserDataFromNToM` steps wired into `DatabaseService._initAsync`'s `onUpgrade`. Versions are `kStatsDbVersion` / `kUserDataDbVersion`. Adding a table or column means touching both the create path and the upgrade path; `test/migration_test.dart` asserts fresh-create and each step.

### Playback

`AudioPlayerManager` (~3200 lines) wraps `just_audio` + `just_audio_background`, owns queue/shuffle/crossfade/volume/stats. Hot-path state is exposed via `ValueNotifier`s rather than Riverpod, deliberately, to keep rebuilds narrow — don't convert those to providers. Queue mutations serialize through `_queueMutationChain`; keep new queue mutations on that chain.

Linux/Windows swap in `just_audio_media_kit` + `sqflite_common_ffi` (see the `isMediaKitDesktop` branch in `main.dart`); they have no `audio_session`/`audio_service` implementation.

### Shuffle

`lib/domain/services/shuffle_selector.dart` — pure `scoreCandidate(...)`; personalities (`consistent`, `explorer`, `custom`, …) resolve to `ShuffleWeights` and apply as multiplicative penalties/boosts. Covered by `test/shuffle_logic_test.dart`, `test/shuffle_weight_distribution_test.dart`, `test/personality_logic_test.dart`.

### State management

Riverpod 3 `Notifier`/`AsyncNotifier`. `lib/providers/providers.dart` (~2000 lines) is the hub. Derived data belongs in a `Provider` over `songsProvider` + `userDataProvider`, not a duplicated cache.

### Library scanning

`ScannerService` runs in isolates (`Isolate.spawn` / `Isolate.run`), lazy: a fast scan writes minimal rows, then metadata enrichment and cover extraction in throttled batches. Video thumbnails go through `FFmpegService`, which is platform-channel and main-thread only. `MediaDecodePriority` (`lib/services/media_decode_gate.dart`) serializes full-file decodes — waveform and beat analysis must not run concurrently on one file.

### Networking

`SharedHttpClient.instance` is the one pooled `HttpClient` for outbound requests. Don't construct per-request clients; that's the regression its comment describes. Secrets arrive via `--dart-define`: `TELEMETRY_SECRET`, `GOOGLE_CLIENT_SECRET` (plus `WISPIE_MUSIC_UTILS_BASE_URL` for the music API).

## Testing

DB-, prefs- or path-touching tests must use `TestEnvironment` from `test/test_helpers.dart` (`setUpAll`/`tearDownAll`). It creates a temp dir, installs `databaseFactoryFfi`, mocks path_provider / SharedPreferences / package_info_plus / wakelock_plus pigeon, and stubs the `wispie/*` channels (`volume`, `power`, plus legacy `gru_songs/power`, and the `wispie/volume_events`, `wispie/power_events` event channels). It also sets `testWispiePath`, `StorageService.testDocumentsPath`, and `SearchIndexRepository.testDocumentsPath`, and resets them in teardown so state doesn't leak between test files.

Adding a settings key means editing `StorageService._settingsKeys` **and** claiming it in `importableSettingsKeys` or `identitySettingsKeys`, or `test/settings_key_coverage_test.dart` fails. Adding a searchable settings row means a `SettingsDestination` in `lib/presentation/screens/settings_registry.dart` plus a matching `searchId:` in the screen, or `test/settings_search_test.dart` fails.

## UI / Design Standard

- Vibrant color blocking; high-contrast solid fills in large blocks.
- No borders or outlines for separation. Use color blocking, whitespace, layout geometry.
- No gradients for chrome, fills, or text. Gradients are allowed only for cover-art-derived backdrops, legibility scrims, and edge fades (`lib/presentation/cover_gradient/`, `app_screen_header`'s scroll scrim, `progressive_edge_fade.dart`).
- Design tokens first: never hardcode hex or pixel sizes. `lib/presentation/tokens/player_tokens.dart` is the source of truth for spacing/radii/motion; `app_tokens.dart` aliases it and adds foreground/status colors; `app_icons.dart` holds icons. Reach for the shared components in `lib/presentation/components/` (`app_surface`, `app_list_row`, `app_chip`, `app_dialog`, `app_sheet`, `app_feedback`) instead of hand-rolling a row or dialog.
- Motion: deliberate, token-driven durations and curves (`AppTokens.cStandard`, `dFast`, …).
- Semantic widgets (`ListTile`, `IconButton`), proper labels, managed focus.
- `UnifiedPlayerScreen` is a shell around three panes (`lib/presentation/screens/player/`: lyrics / now-playing / queue). Keep chrome out of the panes.

Before returning UI code: no borders used for separation, no gradients outside the allowed cases, all styling from tokens, animations deliberate.

## Release

`git tag v1.4.4-release && git push origin v1.4.4-release` triggers `release-draft.yml`, which reuses a successful `ci-builds.yml` run for the tagged commit when possible and otherwise builds all seven platform artifacts, then creates a **private draft** release for manual review. Artifact names and order in the workflows are load-bearing; the comments say so. macOS builds require `packaging/macos/patch_darwin_headers.sh` and `prepare_spm_artifacts.sh` to run first.

## Quick Reference

| Concern | File |
| --- | --- |
| Playback | `lib/services/audio_player_manager.dart` |
| Library state | `lib/providers/providers.dart` -> `songsProvider` |
| User data | `lib/providers/user_data_provider.dart` |
| Schema + migrations | `lib/data/migrations.dart` |
| Database access | `lib/services/database_service.dart` |
| Search | `lib/domain/services/search_service.dart` |
| Library logic | `lib/services/library_logic.dart` |
| Scanning | `lib/services/scanner_service.dart` |
| Shuffle | `lib/domain/services/shuffle_selector.dart` |
| Player UI shell | `lib/presentation/screens/unified_player_screen.dart` |
| Shared components | `lib/presentation/components/` |
| Design tokens | `lib/presentation/tokens/` |

### Structure

```
lib/
├── main.dart        # entrypoint, platform branch, service init order
├── services/        # legacy layer + platform channels, FFmpeg, scanning
├── providers/       # Riverpod state
├── models/          # core entities (song, playlist, queue item)
├── domain/          # pure logic + value objects (filename)
├── data/            # schema/migrations + repository implementations
└── presentation/    # screens/ (player/ subdir), widgets/, components/, tokens/, routes/
third_party/         # vendored deps, wired via dependency_overrides
```